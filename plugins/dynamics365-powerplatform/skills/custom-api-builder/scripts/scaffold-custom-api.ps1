<#
.SYNOPSIS
    Scaffolds a Dataverse Custom API plugin project with C# implementation and unit tests.

.DESCRIPTION
    Creates a complete project structure for a Dataverse Custom API including:
    - C# plugin class implementing IPlugin
    - .csproj targeting .NET Framework 4.7.1 with Microsoft.CrmSdk.CoreAssemblies
    - Unit test project with MSTest and Moq
    - Solution file linking both projects

.PARAMETER ApiName
    The name of the Custom API (without publisher prefix).
    Example: "ApproveOrder"

.PARAMETER PluginNamespace
    The root C# namespace for the plugin project.
    Example: "Contoso.Plugins"

.PARAMETER OutputPath
    The directory where the project structure will be created.
    Defaults to the current directory.

.PARAMETER BoundEntity
    Optional. The logical name of the entity this API is bound to.
    If omitted, the API is created as a Global (unbound) API.
    Example: "salesorder"

.EXAMPLE
    .\scaffold-custom-api.ps1 -ApiName "ApproveOrder" -PluginNamespace "Contoso.Plugins" -OutputPath ".\src"

.EXAMPLE
    .\scaffold-custom-api.ps1 -ApiName "CalculateDiscount" -PluginNamespace "Contoso.Plugins" -OutputPath ".\src" -BoundEntity "salesorder"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Custom API (e.g., 'ApproveOrder')")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$', ErrorMessage = "ApiName must start with a letter and contain only alphanumeric characters.")]
    [string]$ApiName,

    [Parameter(Mandatory = $true, HelpMessage = "Root C# namespace (e.g., 'Contoso.Plugins')")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$', ErrorMessage = "PluginNamespace must be a valid C# namespace.")]
    [string]$PluginNamespace,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for generated files")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Bound entity logical name (omit for Global API)")]
    [ValidatePattern('^[a-z][a-z0-9_]*$', ErrorMessage = "BoundEntity must be a valid Dataverse logical name.")]
    [string]$BoundEntity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helper: Write-Step
# ---------------------------------------------------------------------------
function Write-Step {
    param([string]$Message)
    Write-Host "  [+] $Message" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$OutputPath = Resolve-Path -Path $OutputPath -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path
if (-not $OutputPath) {
    $OutputPath = $PSScriptRoot
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
}

$pluginProjectName = "$PluginNamespace.CustomApis"
$testProjectName   = "$PluginNamespace.CustomApis.Tests"
$solutionName      = "$PluginNamespace.CustomApis"

$pluginDir = Join-Path $OutputPath $pluginProjectName
$testDir   = Join-Path $OutputPath $testProjectName

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Custom API Scaffold: $ApiName" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# Create directories
# ---------------------------------------------------------------------------
Write-Step "Creating project directories..."
@($pluginDir, $testDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Determine binding context
# ---------------------------------------------------------------------------
$isGlobal = [string]::IsNullOrWhiteSpace($BoundEntity)
$bindingComment = if ($isGlobal) { "Global (unbound) Custom API" } else { "Bound to entity: $BoundEntity" }

# ---------------------------------------------------------------------------
# Generate .csproj (Plugin)
# ---------------------------------------------------------------------------
Write-Step "Generating plugin .csproj..."

$csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net471</TargetFramework>
    <RootNamespace>$PluginNamespace.CustomApis</RootNamespace>
    <AssemblyName>$PluginNamespace.CustomApis</AssemblyName>
    <SignAssembly>true</SignAssembly>
    <AssemblyOriginatorKeyFile>Key.snk</AssemblyOriginatorKeyFile>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.56" />
  </ItemGroup>

</Project>
"@

Set-Content -Path (Join-Path $pluginDir "$pluginProjectName.csproj") -Value $csprojContent -Encoding UTF8

# ---------------------------------------------------------------------------
# Generate strong-name key placeholder instructions
# ---------------------------------------------------------------------------
Write-Step "Note: Generate a strong-name key with: sn -k Key.snk"

# ---------------------------------------------------------------------------
# Generate Plugin class
# ---------------------------------------------------------------------------
Write-Step "Generating plugin class: ${ApiName}Api.cs..."

$boundEntityParam = if (-not $isGlobal) {
    @"

                // For bound APIs the Target is available in InputParameters
                // var target = (EntityReference)context.InputParameters["Target"];
"@
} else { "" }

$pluginClass = @"
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace $PluginNamespace.CustomApis
{
    /// <summary>
    /// Backing plugin for the $ApiName Custom API.
    /// $bindingComment
    /// </summary>
    public class ${ApiName}Api : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            // Obtain services
            var context = (IPluginExecutionContext)serviceProvider
                .GetService(typeof(IPluginExecutionContext));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider
                .GetService(typeof(IOrganizationServiceFactory));
            var tracingService = (ITracingService)serviceProvider
                .GetService(typeof(ITracingService));
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            try
            {
                tracingService.Trace("${ApiName}Api: Execution started.");
$boundEntityParam
                // ----------------------------------------------------------
                // TODO: Read InputParameters
                //   Example:
                //   var myParam = (string)context.InputParameters["MyParam"];
                // ----------------------------------------------------------

                // ----------------------------------------------------------
                // TODO: Implement business logic using IOrganizationService
                // ----------------------------------------------------------

                // ----------------------------------------------------------
                // TODO: Set OutputParameters
                //   Example:
                //   context.OutputParameters["Result"] = true;
                // ----------------------------------------------------------

                tracingService.Trace("${ApiName}Api: Execution completed.");
            }
            catch (InvalidPluginExecutionException)
            {
                throw; // Re-throw business exceptions
            }
            catch (Exception ex)
            {
                tracingService.Trace("${ApiName}Api Error: {0}", ex.ToString());
                throw new InvalidPluginExecutionException(
                    "An error occurred in ${ApiName}: " + ex.Message, ex);
            }
        }
    }
}
"@

Set-Content -Path (Join-Path $pluginDir "${ApiName}Api.cs") -Value $pluginClass -Encoding UTF8

# ---------------------------------------------------------------------------
# Generate .csproj (Test)
# ---------------------------------------------------------------------------
Write-Step "Generating test .csproj..."

$testCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net471</TargetFramework>
    <RootNamespace>$PluginNamespace.CustomApis.Tests</RootNamespace>
    <AssemblyName>$PluginNamespace.CustomApis.Tests</AssemblyName>
    <IsPackable>false</IsPackable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="MSTest.TestAdapter" Version="3.1.1" />
    <PackageReference Include="MSTest.TestFramework" Version="3.1.1" />
    <PackageReference Include="Moq" Version="4.20.70" />
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.56" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\$pluginProjectName\$pluginProjectName.csproj" />
  </ItemGroup>

</Project>
"@

Set-Content -Path (Join-Path $testDir "$testProjectName.csproj") -Value $testCsproj -Encoding UTF8

# ---------------------------------------------------------------------------
# Generate Unit Test class
# ---------------------------------------------------------------------------
Write-Step "Generating unit test class: ${ApiName}ApiTests.cs..."

$testClass = @"
using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using Moq;
using $PluginNamespace.CustomApis;

namespace $PluginNamespace.CustomApis.Tests
{
    [TestClass]
    public class ${ApiName}ApiTests
    {
        private Mock<IPluginExecutionContext> _contextMock;
        private Mock<IOrganizationServiceFactory> _factoryMock;
        private Mock<IOrganizationService> _serviceMock;
        private Mock<ITracingService> _tracingMock;
        private Mock<IServiceProvider> _serviceProviderMock;

        [TestInitialize]
        public void Setup()
        {
            _contextMock = new Mock<IPluginExecutionContext>();
            _factoryMock = new Mock<IOrganizationServiceFactory>();
            _serviceMock = new Mock<IOrganizationService>();
            _tracingMock = new Mock<ITracingService>();
            _serviceProviderMock = new Mock<IServiceProvider>();

            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
                .Returns(_contextMock.Object);
            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
                .Returns(_factoryMock.Object);
            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(ITracingService)))
                .Returns(_tracingMock.Object);

            _contextMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
            _factoryMock
                .Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
                .Returns(_serviceMock.Object);
        }

        [TestMethod]
        public void Execute_ShouldCompleteWithoutErrors()
        {
            // Arrange
            var inputParams = new ParameterCollection();
            var outputParams = new ParameterCollection();

            // TODO: Add your input parameters here
            // inputParams["MyParam"] = "value";

            _contextMock.Setup(c => c.InputParameters).Returns(inputParams);
            _contextMock.Setup(c => c.OutputParameters).Returns(outputParams);

            var plugin = new ${ApiName}Api();

            // Act
            plugin.Execute(_serviceProviderMock.Object);

            // Assert
            // TODO: Verify output parameters and service calls
            // Assert.IsTrue((bool)outputParams["Result"]);
            _tracingMock.Verify(
                t => t.Trace(It.IsAny<string>(), It.IsAny<object[]>()),
                Times.AtLeastOnce);
        }

        [TestMethod]
        [ExpectedException(typeof(InvalidPluginExecutionException))]
        public void Execute_InvalidInput_ShouldThrowBusinessException()
        {
            // Arrange
            var inputParams = new ParameterCollection();
            var outputParams = new ParameterCollection();

            // TODO: Set up invalid input to trigger a business exception

            _contextMock.Setup(c => c.InputParameters).Returns(inputParams);
            _contextMock.Setup(c => c.OutputParameters).Returns(outputParams);

            var plugin = new ${ApiName}Api();

            // Act — should throw InvalidPluginExecutionException
            plugin.Execute(_serviceProviderMock.Object);
        }
    }
}
"@

Set-Content -Path (Join-Path $testDir "${ApiName}ApiTests.cs") -Value $testClass -Encoding UTF8

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Scaffold Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Project:  $pluginDir" -ForegroundColor White
Write-Host "  Tests:    $testDir" -ForegroundColor White
Write-Host ""
Write-Host "  Generated files:" -ForegroundColor Yellow
Write-Host "    Plugin:  $pluginProjectName\${ApiName}Api.cs"
Write-Host "    csproj:  $pluginProjectName\$pluginProjectName.csproj"
Write-Host "    Test:    $testProjectName\${ApiName}ApiTests.cs"
Write-Host "    csproj:  $testProjectName\$testProjectName.csproj"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Generate a strong-name key:  sn -k Key.snk  (place in plugin project)"
Write-Host "    2. Implement your business logic in ${ApiName}Api.cs"
Write-Host "    3. Add InputParameter / OutputParameter handling"
Write-Host "    4. Write unit tests in ${ApiName}ApiTests.cs"
Write-Host "    5. Build:  dotnet build"
Write-Host "    6. Register assembly via Plugin Registration Tool or PAC CLI"
Write-Host "    7. Create Custom API record in Dataverse and link to plugin type"
Write-Host "    8. Test via Web API:  POST /api/data/v9.2/<publisher>_$ApiName"
Write-Host ""
