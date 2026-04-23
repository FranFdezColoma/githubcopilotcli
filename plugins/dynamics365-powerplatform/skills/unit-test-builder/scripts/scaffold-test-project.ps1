<#
.SYNOPSIS
    Scaffolds a unit test project for Dynamics 365 CE and Power Platform code.

.DESCRIPTION
    Creates a test project with the appropriate framework, dependencies, mock
    helpers, and example test files for C# plugins, JavaScript web resources,
    or TypeScript PCF components.

.PARAMETER ProjectType
    The type of test project: CSharpPlugin, JavaScript, or TypeScriptPCF.

.PARAMETER ProjectName
    Name of the test project (e.g., Contoso.Crm.Plugins.Tests).

.PARAMETER SourceProjectPath
    Path to the source project being tested.

.PARAMETER OutputPath
    Directory where the test project will be created. Defaults to current directory.

.EXAMPLE
    .\scaffold-test-project.ps1 -ProjectType CSharpPlugin -ProjectName "Contoso.Crm.Plugins.Tests" -SourceProjectPath "C:\Dev\Plugins" -OutputPath "C:\Dev\Tests"

.EXAMPLE
    .\scaffold-test-project.ps1 -ProjectType JavaScript -ProjectName "webresource-tests" -SourceProjectPath "C:\Dev\WebResources"

.EXAMPLE
    .\scaffold-test-project.ps1 -ProjectType TypeScriptPCF -ProjectName "pcf-tests" -SourceProjectPath "C:\Dev\MyPCFControl"

.NOTES
    Requires: .NET SDK (for CSharpPlugin), Node.js + npm (for JavaScript/TypeScriptPCF).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Test project type.")]
    [ValidateSet('CSharpPlugin', 'JavaScript', 'TypeScriptPCF')]
    [string]$ProjectType,

    [Parameter(Mandatory = $true, HelpMessage = "Test project name.")]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectName,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the source project being tested.")]
    [string]$SourceProjectPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Output directory.")]
    [string]$OutputPath = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Helper Functions ─────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n`u{2705} $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Cyan
}

# ─── CSharpPlugin Test Project ────────────────────────────────────────────────

function New-CSharpPluginTestProject {
    param([string]$Name, [string]$OutDir, [string]$SourcePath)

    $projectDir = Join-Path $OutDir $Name
    if (Test-Path $projectDir) {
        Write-Host "Directory already exists: $projectDir" -ForegroundColor Red
        exit 1
    }
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

    # Generate .csproj
    $relativeSrc = ""
    if ($SourcePath -and (Test-Path $SourcePath)) {
        $relativeSrc = [System.IO.Path]::GetRelativePath($projectDir, $SourcePath)
        $srcCsprojs = Get-ChildItem $SourcePath -Filter "*.csproj" -File | Select-Object -First 1
        if ($srcCsprojs) {
            $relativeSrc = [System.IO.Path]::GetRelativePath($projectDir, $srcCsprojs.FullName)
        }
    }

    $projectRef = ""
    if ($relativeSrc) {
        $projectRef = @"
  <ItemGroup>
    <ProjectReference Include="$relativeSrc" />
  </ItemGroup>
"@
    }

    $csproj = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net471</TargetFramework>
    <RootNamespace>$Name</RootNamespace>
    <AssemblyName>$Name</AssemblyName>
    <IsPackable>false</IsPackable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.56" />
    <PackageReference Include="MSTest.TestFramework" Version="2.2.10" />
    <PackageReference Include="MSTest.TestAdapter" Version="2.2.10" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.6.0" />
    <PackageReference Include="Moq" Version="4.20.72" />
    <PackageReference Include="Castle.Core" Version="5.1.1" />
  </ItemGroup>
$projectRef
</Project>
"@
    Set-Content -Path (Join-Path $projectDir "$Name.csproj") -Value $csproj -Encoding UTF8
    Write-Step "Generated $Name.csproj"

    # Base test class with mock setup
    $baseTestClass = @"
using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Moq;

namespace $Name
{
    /// <summary>
    /// Base class providing common mock setup for Dataverse plugin tests.
    /// Inherit from this class in your test classes.
    /// </summary>
    public abstract class PluginTestBase
    {
        protected Mock<IOrganizationService> ServiceMock { get; private set; }
        protected Mock<IPluginExecutionContext> ContextMock { get; private set; }
        protected Mock<ITracingService> TracingMock { get; private set; }
        protected Mock<IOrganizationServiceFactory> FactoryMock { get; private set; }
        protected Mock<IServiceProvider> ServiceProviderMock { get; private set; }

        [TestInitialize]
        public virtual void BaseSetup()
        {
            ServiceMock = new Mock<IOrganizationService>();
            ContextMock = new Mock<IPluginExecutionContext>();
            TracingMock = new Mock<ITracingService>();
            FactoryMock = new Mock<IOrganizationServiceFactory>();
            ServiceProviderMock = new Mock<IServiceProvider>();

            ServiceProviderMock
                .Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
                .Returns(ContextMock.Object);
            ServiceProviderMock
                .Setup(sp => sp.GetService(typeof(ITracingService)))
                .Returns(TracingMock.Object);
            ServiceProviderMock
                .Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
                .Returns(FactoryMock.Object);
            FactoryMock
                .Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
                .Returns(ServiceMock.Object);

            // Sensible defaults
            ContextMock.Setup(c => c.Depth).Returns(1);
            ContextMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
            ContextMock.Setup(c => c.InitiatingUserId).Returns(Guid.NewGuid());
            ContextMock.Setup(c => c.OrganizationId).Returns(Guid.NewGuid());
            ContextMock.Setup(c => c.IsInTransaction).Returns(true);
            ContextMock.Setup(c => c.PreEntityImages).Returns(new EntityImageCollection());
            ContextMock.Setup(c => c.PostEntityImages).Returns(new EntityImageCollection());
            ContextMock.Setup(c => c.SharedVariables).Returns(new ParameterCollection());
        }

        protected ParameterCollection CreateInputWithTarget(Entity target)
        {
            return new ParameterCollection { { "Target", target } };
        }

        protected ParameterCollection CreateInputWithEntityRef(EntityReference target)
        {
            return new ParameterCollection { { "Target", target } };
        }
    }
}
"@
    Set-Content -Path (Join-Path $projectDir "PluginTestBase.cs") -Value $baseTestClass -Encoding UTF8
    Write-Step "Generated PluginTestBase.cs"

    # Example test
    $exampleTest = @"
using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Moq;

namespace $Name
{
    [TestClass]
    public class ExamplePluginTests : PluginTestBase
    {
        [TestInitialize]
        public override void BaseSetup()
        {
            base.BaseSetup();
            ContextMock.Setup(c => c.MessageName).Returns("Create");
            ContextMock.Setup(c => c.PrimaryEntityName).Returns("account");
            ContextMock.Setup(c => c.Stage).Returns(20);
        }

        [TestMethod]
        [TestCategory("Plugin")]
        public void Execute_ValidTarget_ShouldComplete()
        {
            // Arrange
            var target = new Entity("account", Guid.NewGuid());
            target["name"] = "Test Account";
            ContextMock.Setup(c => c.InputParameters)
                .Returns(CreateInputWithTarget(target));

            // TODO: Instantiate your plugin class
            // var plugin = new YourPlugin("", "");

            // Act
            // plugin.Execute(ServiceProviderMock.Object);

            // Assert
            Assert.IsTrue(true, "Replace with real assertions.");
        }
    }
}
"@
    Set-Content -Path (Join-Path $projectDir "ExamplePluginTests.cs") -Value $exampleTest -Encoding UTF8
    Write-Step "Generated ExamplePluginTests.cs"
}

# ─── JavaScript Test Project ─────────────────────────────────────────────────

function New-JavaScriptTestProject {
    param([string]$Name, [string]$OutDir, [string]$SourcePath)

    $projectDir = Join-Path $OutDir $Name
    if (Test-Path $projectDir) {
        Write-Host "Directory already exists: $projectDir" -ForegroundColor Red
        exit 1
    }
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projectDir "tests\setup") -Force | Out-Null

    # package.json
    $packageJson = @"
{
  "name": "$($Name.ToLower())",
  "version": "1.0.0",
  "description": "Unit tests for Dynamics 365 web resources",
  "scripts": {
    "test": "jest --verbose",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  }
}
"@
    Set-Content -Path (Join-Path $projectDir "package.json") -Value $packageJson -Encoding UTF8

    # jest.config.js
    $jestConfig = @"
module.exports = {
    testEnvironment: 'jsdom',
    roots: ['<rootDir>/tests'],
    testMatch: ['**/*.test.js'],
    setupFiles: ['<rootDir>/tests/setup/xrm-mock.js'],
    collectCoverageFrom: ['src/**/*.js'],
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov', 'clover'],
};
"@
    Set-Content -Path (Join-Path $projectDir "jest.config.js") -Value $jestConfig -Encoding UTF8

    # Xrm mock
    $xrmMock = @"
// Global Xrm mock for Dynamics 365 web resource testing
global.Xrm = {
    WebApi: {
        createRecord: jest.fn().mockResolvedValue({ id: '00000000-0000-0000-0000-000000000001' }),
        retrieveRecord: jest.fn().mockResolvedValue({}),
        updateRecord: jest.fn().mockResolvedValue({}),
        deleteRecord: jest.fn().mockResolvedValue({}),
        retrieveMultipleRecords: jest.fn().mockResolvedValue({ entities: [], nextLink: null }),
    },
    Navigation: {
        openAlertDialog: jest.fn().mockResolvedValue({}),
        openConfirmDialog: jest.fn().mockResolvedValue({ confirmed: true }),
        openForm: jest.fn().mockResolvedValue({}),
        openUrl: jest.fn(),
        openWebResource: jest.fn(),
    },
    Utility: {
        getGlobalContext: jest.fn().mockReturnValue({
            getClientUrl: jest.fn().mockReturnValue('https://org.crm.dynamics.com'),
            getUserId: jest.fn().mockReturnValue('00000000-0000-0000-0000-000000000002'),
            getUserName: jest.fn().mockReturnValue('Test User'),
            userSettings: { languageId: 1033 },
        }),
    },
};
"@
    Set-Content -Path (Join-Path $projectDir "tests\setup\xrm-mock.js") -Value $xrmMock -Encoding UTF8

    # Form context mock helper
    $formMock = @"
function createFormContextMock(attributes) {
    attributes = attributes || {};
    const attrMocks = {};

    for (const [name, config] of Object.entries(attributes)) {
        attrMocks[name] = {
            getValue: jest.fn().mockReturnValue(config.value),
            setValue: jest.fn(),
            setRequiredLevel: jest.fn(),
            setSubmitMode: jest.fn(),
            addOnChange: jest.fn(),
            removeOnChange: jest.fn(),
            getIsDirty: jest.fn().mockReturnValue(false),
            controls: {
                forEach: jest.fn(),
                get: jest.fn().mockReturnValue({
                    setVisible: jest.fn(),
                    setDisabled: jest.fn(),
                    setLabel: jest.fn(),
                    setNotification: jest.fn(),
                    clearNotification: jest.fn(),
                }),
            },
        };
    }

    return {
        getAttribute: jest.fn((name) => attrMocks[name] || null),
        getControl: jest.fn(() => ({
            setVisible: jest.fn(),
            setDisabled: jest.fn(),
            setLabel: jest.fn(),
        })),
        data: {
            entity: {
                getId: jest.fn().mockReturnValue('{00000000-0000-0000-0000-000000000001}'),
                getEntityName: jest.fn().mockReturnValue('account'),
                save: jest.fn().mockResolvedValue({}),
            },
            refresh: jest.fn().mockResolvedValue({}),
        },
        ui: {
            setFormNotification: jest.fn(),
            clearFormNotification: jest.fn(),
            refreshRibbon: jest.fn(),
            tabs: { forEach: jest.fn() },
            controls: { forEach: jest.fn() },
        },
    };
}

module.exports = { createFormContextMock };
"@
    Set-Content -Path (Join-Path $projectDir "tests\setup\form-context-mock.js") -Value $formMock -Encoding UTF8

    # Example test
    $exampleTest = @"
const { createFormContextMock } = require('./setup/form-context-mock');

describe('Example Web Resource Tests', () => {
    let formContext;

    beforeEach(() => {
        jest.clearAllMocks();
        formContext = createFormContextMock({
            name: { value: 'Test Account' },
            revenue: { value: 1000000 },
        });
    });

    it('should create a form context mock successfully', () => {
        expect(formContext).toBeDefined();
        expect(formContext.getAttribute('name').getValue()).toBe('Test Account');
    });

    it('should mock Xrm.WebApi.createRecord', async () => {
        const result = await Xrm.WebApi.createRecord('account', { name: 'Test' });
        expect(result.id).toBeDefined();
        expect(Xrm.WebApi.createRecord).toHaveBeenCalledTimes(1);
    });
});
"@
    Set-Content -Path (Join-Path $projectDir "tests\example.test.js") -Value $exampleTest -Encoding UTF8

    # Install dependencies
    Set-Location $projectDir
    Write-Info "Running npm install..."
    npm install --quiet 2>&1 | Out-Null
    Write-Step "JavaScript test project created at: $projectDir"
}

# ─── TypeScript PCF Test Project ──────────────────────────────────────────────

function New-TypeScriptPCFTestProject {
    param([string]$Name, [string]$OutDir, [string]$SourcePath)

    $targetDir = $SourcePath
    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        $targetDir = Join-Path $OutDir $Name
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $testsDir = Join-Path $targetDir "__tests__"
    $mocksDir = Join-Path $targetDir "__mocks__"
    New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $mocksDir -Force | Out-Null

    Set-Location $targetDir

    # Install test dependencies
    Write-Info "Installing Jest + ts-jest + React Testing Library..."
    npm install --save-dev jest ts-jest @types/jest @testing-library/react @testing-library/jest-dom --quiet 2>&1 | Out-Null

    # jest.config.ts
    $jestConfig = @"
import type { Config } from 'jest';

const config: Config = {
    preset: 'ts-jest',
    testEnvironment: 'jsdom',
    roots: ['<rootDir>'],
    testMatch: ['**/__tests__/**/*.test.(ts|tsx)', '**/*.test.(ts|tsx)'],
    moduleNameMapper: {
        '\\\\.(css|less|scss)$': '<rootDir>/__mocks__/styleMock.js',
    },
};

export default config;
"@
    Set-Content -Path (Join-Path $targetDir "jest.config.ts") -Value $jestConfig -Encoding UTF8

    # Style mock
    Set-Content -Path (Join-Path $mocksDir "styleMock.js") -Value "module.exports = {};" -Encoding UTF8

    # ComponentFramework context mock
    $cfMock = @"
export function createMockContext<TInputs>(
    parameters: Partial<TInputs> = {},
    overrides: Record<string, any> = {}
): any {
    return {
        parameters: parameters as TInputs,
        mode: {
            isControlDisabled: false,
            isVisible: true,
            label: 'Test Control',
            allocatedWidth: 300,
            allocatedHeight: 200,
            isHighContrastEnabled: false,
            setControlState: jest.fn(),
            trackContainerResize: jest.fn(),
            setFullScreen: jest.fn(),
        },
        webAPI: {
            createRecord: jest.fn().mockResolvedValue({ id: 'mock-id' }),
            retrieveRecord: jest.fn().mockResolvedValue({}),
            updateRecord: jest.fn().mockResolvedValue({}),
            deleteRecord: jest.fn().mockResolvedValue({}),
            retrieveMultipleRecords: jest.fn().mockResolvedValue({ entities: [] }),
        },
        navigation: {
            openForm: jest.fn().mockResolvedValue({}),
            openAlertDialog: jest.fn().mockResolvedValue({}),
            openConfirmDialog: jest.fn().mockResolvedValue({ confirmed: true }),
            openUrl: jest.fn(),
        },
        resources: {
            getString: jest.fn((key: string) => key),
            getResource: jest.fn(),
        },
        formatting: {
            formatCurrency: jest.fn((val: number) => '$' + val),
            formatDecimal: jest.fn((val: number) => val.toString()),
            formatInteger: jest.fn((val: number) => val.toString()),
        },
        updatedProperties: [],
        ...overrides,
    };
}

export function createMockProperty<T>(raw: T, formatted?: string) {
    return {
        raw,
        formatted: formatted ?? String(raw),
        error: false,
        errorMessage: '',
        security: undefined,
        type: typeof raw,
    };
}
"@
    Set-Content -Path (Join-Path $mocksDir "ComponentFramework.mock.ts") -Value $cfMock -Encoding UTF8

    # Example test
    $exampleTest = @"
import { createMockContext, createMockProperty } from '../__mocks__/ComponentFramework.mock';

describe('PCF Component Tests', () => {
    let container: HTMLDivElement;
    let notifyOutputChanged: jest.Mock;

    beforeEach(() => {
        container = document.createElement('div');
        notifyOutputChanged = jest.fn();
    });

    it('should create a mock context', () => {
        const context = createMockContext({
            testProperty: createMockProperty('hello'),
        });

        expect(context.parameters.testProperty.raw).toBe('hello');
    });

    it('should mock webAPI calls', async () => {
        const context = createMockContext();
        const result = await context.webAPI.createRecord('account', { name: 'Test' });
        expect(result.id).toBe('mock-id');
    });
});
"@
    Set-Content -Path (Join-Path $testsDir "example.test.ts") -Value $exampleTest -Encoding UTF8
    Write-Step "TypeScript PCF test infrastructure created at: $targetDir"
}

# ─── Main Execution ───────────────────────────────────────────────────────────

Write-Host "`nScaffolding $ProjectType test project: $ProjectName" -ForegroundColor Cyan
Write-Host "Output: $OutputPath" -ForegroundColor Cyan

switch ($ProjectType) {
    'CSharpPlugin' {
        New-CSharpPluginTestProject -Name $ProjectName -OutDir $OutputPath -SourcePath $SourceProjectPath
    }
    'JavaScript' {
        New-JavaScriptTestProject -Name $ProjectName -OutDir $OutputPath -SourcePath $SourceProjectPath
    }
    'TypeScriptPCF' {
        New-TypeScriptPCFTestProject -Name $ProjectName -OutDir $OutputPath -SourcePath $SourceProjectPath
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host "`n" -NoNewline
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Test project '$ProjectName' scaffolded successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Type: $ProjectType" -ForegroundColor White
Write-Host ""

switch ($ProjectType) {
    'CSharpPlugin' {
        Write-Host "  Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Add project reference to your plugin project" -ForegroundColor White
        Write-Host "  2. Create test classes inheriting from PluginTestBase" -ForegroundColor White
        Write-Host "  3. Run: dotnet test" -ForegroundColor White
    }
    'JavaScript' {
        Write-Host "  Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Add module.exports to your web resource source files" -ForegroundColor White
        Write-Host "  2. Create test files in tests/ (*.test.js)" -ForegroundColor White
        Write-Host "  3. Run: npm test" -ForegroundColor White
    }
    'TypeScriptPCF' {
        Write-Host "  Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Import your components in __tests__/*.test.ts" -ForegroundColor White
        Write-Host "  2. Use createMockContext() and createMockProperty()" -ForegroundColor White
        Write-Host "  3. Run: npx jest" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
