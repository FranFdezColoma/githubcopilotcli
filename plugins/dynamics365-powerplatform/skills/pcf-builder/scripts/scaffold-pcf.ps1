<#
.SYNOPSIS
    Scaffolds a PowerApps Component Framework (PCF) control project.

.DESCRIPTION
    Creates a new PCF control project using the Power Platform CLI (pac),
    installs dependencies, generates boilerplate code, and optionally
    sets up Jest testing infrastructure for React-based components.

.PARAMETER ComponentName
    Name of the PCF component (PascalCase). Used as the control constructor name.

.PARAMETER Namespace
    Namespace for the component (e.g., Contoso, Acme.Controls).

.PARAMETER Template
    Component template type: 'field' (single column) or 'dataset' (view/subgrid).

.PARAMETER Framework
    UI framework: 'react' or 'none' (vanilla TypeScript).

.PARAMETER OutputPath
    Directory where the project will be created. Defaults to current directory.

.EXAMPLE
    .\scaffold-pcf.ps1 -ComponentName "RatingControl" -Namespace "Contoso" -Template field -Framework react

.EXAMPLE
    .\scaffold-pcf.ps1 -ComponentName "DataGrid" -Namespace "Contoso" -Template dataset -Framework none -OutputPath "C:\Dev\PCF"

.NOTES
    Requires: Node.js (LTS), npm, Power Platform CLI (pac).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the PCF component (PascalCase).")]
    [ValidatePattern('^[A-Z][a-zA-Z0-9]+$')]
    [string]$ComponentName,

    [Parameter(Mandatory = $true, HelpMessage = "Namespace for the component.")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace,

    [Parameter(Mandatory = $true, HelpMessage = "Component type: 'field' or 'dataset'.")]
    [ValidateSet('field', 'dataset')]
    [string]$Template,

    [Parameter(Mandatory = $false, HelpMessage = "UI framework: 'react' or 'none'.")]
    [ValidateSet('react', 'none')]
    [string]$Framework = 'none',

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for the project.")]
    [string]$OutputPath = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Helper Functions ─────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Test-Prerequisite {
    param(
        [string]$Command,
        [string]$DisplayName,
        [string]$InstallHint
    )
    try {
        $null = & $Command --version 2>&1
        return $true
    }
    catch {
        Write-Host "❌ $DisplayName is not installed or not in PATH." -ForegroundColor Red
        Write-Host "   Install: $InstallHint" -ForegroundColor Yellow
        return $false
    }
}

# ─── Prerequisite Checks ─────────────────────────────────────────────────────

Write-Host "`n🔍 Checking prerequisites..." -ForegroundColor Cyan

$allPrereqsMet = $true

if (-not (Test-Prerequisite -Command "node" -DisplayName "Node.js" -InstallHint "https://nodejs.org")) {
    $allPrereqsMet = $false
}

if (-not (Test-Prerequisite -Command "npm" -DisplayName "npm" -InstallHint "Bundled with Node.js")) {
    $allPrereqsMet = $false
}

if (-not (Test-Prerequisite -Command "pac" -DisplayName "Power Platform CLI" -InstallHint "dotnet tool install --global Microsoft.PowerApps.CLI.Tool")) {
    $allPrereqsMet = $false
}

if (-not $allPrereqsMet) {
    Write-Host "`n❌ One or more prerequisites are missing. Aborting." -ForegroundColor Red
    exit 1
}

Write-Step "All prerequisites verified."

# ─── Create Project Directory ─────────────────────────────────────────────────

$projectDir = Join-Path $OutputPath $ComponentName

if (Test-Path $projectDir) {
    Write-Host "❌ Directory already exists: $projectDir" -ForegroundColor Red
    Write-Host "   Remove it or choose a different name/path." -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
Set-Location $projectDir
Write-Step "Created project directory: $projectDir"

# ─── Scaffold PCF Project ────────────────────────────────────────────────────

Write-Info "Running: pac pcf init --namespace $Namespace --name $ComponentName --template $Template --framework $Framework"
pac pcf init --namespace $Namespace --name $ComponentName --template $Template --framework $Framework

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ pac pcf init failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
Write-Step "PCF project scaffolded."

# ─── Install Dependencies ─────────────────────────────────────────────────────

Write-Info "Running: npm install"
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}
Write-Step "npm dependencies installed."

# ─── Create CSS Directory and File ────────────────────────────────────────────

$cssDir = Join-Path $projectDir "$ComponentName\css"
if (-not (Test-Path $cssDir)) {
    New-Item -ItemType Directory -Path $cssDir -Force | Out-Null
}

$cssContent = @"
/* $ComponentName styles */
.$($ComponentName.ToLower())-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

.$($ComponentName.ToLower())-container:focus-within {
    outline: 2px solid #0078d4;
    outline-offset: -2px;
}
"@

$cssFile = Join-Path $cssDir "$ComponentName.css"
Set-Content -Path $cssFile -Value $cssContent -Encoding UTF8
Write-Step "Created CSS file: $cssFile"

# ─── Jest Test Setup (React projects) ────────────────────────────────────────

if ($Framework -eq 'react') {
    Write-Info "Setting up Jest + React Testing Library..."
    npm install --save-dev jest ts-jest @types/jest @testing-library/react @testing-library/jest-dom

    $jestConfig = @"
module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'jsdom',
    roots: ['<rootDir>/$ComponentName'],
    moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx'],
    testMatch: ['**/__tests__/**/*.test.(ts|tsx)', '**/*.test.(ts|tsx)'],
    transform: {
        '^.+\\.tsx?$': 'ts-jest',
    },
    moduleNameMapper: {
        '\\.(css|less|scss)$': '<rootDir>/__mocks__/styleMock.js',
    },
};
"@
    Set-Content -Path (Join-Path $projectDir "jest.config.js") -Value $jestConfig -Encoding UTF8

    # Style mock
    $mocksDir = Join-Path $projectDir "__mocks__"
    New-Item -ItemType Directory -Path $mocksDir -Force | Out-Null
    Set-Content -Path (Join-Path $mocksDir "styleMock.js") -Value "module.exports = {};" -Encoding UTF8

    # Example test file
    $testDir = Join-Path $projectDir "$ComponentName\__tests__"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testContent = @"
import { } from '@testing-library/jest-dom';

describe('$ComponentName', () => {
    it('should be defined', () => {
        // TODO: Import your component and write meaningful tests
        expect(true).toBe(true);
    });
});
"@
    Set-Content -Path (Join-Path $testDir "$ComponentName.test.tsx") -Value $testContent -Encoding UTF8
    Write-Step "Jest + React Testing Library configured."
}

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PCF Component '$ComponentName' scaffolded successfully!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📁 Location:   $projectDir" -ForegroundColor White
Write-Host "  📦 Namespace:  $Namespace" -ForegroundColor White
Write-Host "  🧩 Template:   $Template" -ForegroundColor White
Write-Host "  🔧 Framework:  $Framework" -ForegroundColor White
Write-Host ""
Write-Host "  Next Steps:" -ForegroundColor Yellow
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  1. Edit ControlManifest.Input.xml to define properties" -ForegroundColor White
Write-Host "  2. Implement component logic in $ComponentName\index.ts" -ForegroundColor White
Write-Host "  3. Add styles in $ComponentName\css\$ComponentName.css" -ForegroundColor White
Write-Host "  4. Test locally:   npm start watch" -ForegroundColor White
Write-Host "  5. Build:          npm run build" -ForegroundColor White
Write-Host "  6. Deploy:         pac pcf push --publisher-prefix <prefix>" -ForegroundColor White
Write-Host ""
if ($Framework -eq 'react') {
    Write-Host "  7. Run tests:      npx jest" -ForegroundColor White
    Write-Host ""
}
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
