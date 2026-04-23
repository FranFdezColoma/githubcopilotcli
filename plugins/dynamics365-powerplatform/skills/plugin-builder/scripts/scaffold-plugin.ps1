<#
.SYNOPSIS
    Scaffolds a Dataverse plugin project for Dynamics 365 CE.

.DESCRIPTION
    Creates a .NET Framework 4.7.1 Class Library project with the CrmSdk NuGet
    reference, generates a plugin class from a template, and creates a matching
    MSTest + Moq test project with a base test class.

.PARAMETER PluginName
    Name of the plugin class (PascalCase, e.g., SetDefaultPriceOnCreate).

.PARAMETER Namespace
    Root namespace for the plugin (e.g., Contoso.Crm.Plugins).

.PARAMETER EntityName
    Dataverse entity logical name the plugin targets (e.g., account, contact).

.PARAMETER Message
    The SDK message that triggers the plugin.

.PARAMETER Stage
    The pipeline stage for plugin execution.

.PARAMETER OutputPath
    Directory where the projects will be created. Defaults to current directory.

.EXAMPLE
    .\scaffold-plugin.ps1 -PluginName "ValidateAccountOnCreate" -Namespace "Contoso.Crm.Plugins" -EntityName "account" -Message Create -Stage PreValidation

.EXAMPLE
    .\scaffold-plugin.ps1 -PluginName "AuditContactUpdate" -Namespace "Contoso.Crm.Plugins" -EntityName "contact" -Message Update -Stage PostOperation -OutputPath "C:\Dev\Plugins"

.NOTES
    Requires: .NET Framework 4.7.1 targeting pack, MSBuild or Visual Studio.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Plugin class name (PascalCase).")]
    [ValidatePattern('^[A-Z][a-zA-Z0-9]+$')]
    [string]$PluginName,

    [Parameter(Mandatory = $true, HelpMessage = "Root namespace (e.g., Contoso.Crm.Plugins).")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace,

    [Parameter(Mandatory = $true, HelpMessage = "Target entity logical name.")]
    [ValidateNotNullOrEmpty()]
    [string]$EntityName,

    [Parameter(Mandatory = $true, HelpMessage = "SDK message: Create, Update, Delete, Retrieve, RetrieveMultiple.")]
    [ValidateSet('Create', 'Update', 'Delete', 'Retrieve', 'RetrieveMultiple')]
    [string]$Message,

    [Parameter(Mandatory = $true, HelpMessage = "Pipeline stage.")]
    [ValidateSet('PreValidation', 'PreOperation', 'PostOperation')]
    [string]$Stage,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory.")]
    [string]$OutputPath = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Stage Mapping ────────────────────────────────────────────────────────────
$stageMap = @{
    'PreValidation' = 10
    'PreOperation'  = 20
    'PostOperation' = 40
}
$stageNumber = $stageMap[$Stage]

# ─── Helper Functions ─────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Cyan
}

# ─── Create Project Structure ─────────────────────────────────────────────────

$solutionDir = Join-Path $OutputPath $Namespace.Split('.')[-1]
$pluginProjectDir = Join-Path $solutionDir "$Namespace"
$testProjectDir = Join-Path $solutionDir "$Namespace.Tests"

if (Test-Path $solutionDir) {
    Write-Host "❌ Directory already exists: $solutionDir" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $pluginProjectDir -Force | Out-Null
New-Item -ItemType Directory -Path $testProjectDir -Force | Out-Null
Write-Step "Created solution structure at: $solutionDir"

# ─── Generate Plugin .csproj ──────────────────────────────────────────────────

$pluginCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net471</TargetFramework>
    <RootNamespace>$Namespace</RootNamespace>
    <AssemblyName>$Namespace</AssemblyName>
    <SignAssembly>true</SignAssembly>
    <AssemblyOriginatorKeyFile>$($Namespace).snk</AssemblyOriginatorKeyFile>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.56" />
  </ItemGroup>
</Project>
"@

Set-Content -Path (Join-Path $pluginProjectDir "$Namespace.csproj") -Value $pluginCsproj -Encoding UTF8
Write-Step "Generated plugin .csproj"

# ─── Generate Plugin Class ────────────────────────────────────────────────────

$targetCheck = if ($Message -eq 'RetrieveMultiple') {
    @'
                // Get business entity collection
                if (!context.InputParameters.Contains("Query"))
                    return;
'@
} else {
    @"
                // Get target entity
                if (!context.InputParameters.Contains("Target") ||
                    !(context.InputParameters["Target"] is Entity target))
                    return;

                if (target.LogicalName != "$EntityName")
                    return;
"@
}

$pluginClass = @"
using System;
using Microsoft.Xrm.Sdk;

namespace $Namespace
{
    /// <summary>
    /// Plugin: $PluginName
    /// Entity: $EntityName
    /// Message: $Message
    /// Stage: $Stage ($stageNumber)
    /// </summary>
    public sealed class $PluginName : IPlugin
    {
        private readonly string _unsecureConfig;
        private readonly string _secureConfig;

        public $PluginName(string unsecureConfig, string secureConfig)
        {
            _unsecureConfig = unsecureConfig;
            _secureConfig = secureConfig;
        }

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            try
            {
                tracingService.Trace("$PluginName execution started.");
                tracingService.Trace("Message: {0}, Entity: {1}, Stage: {2}, Depth: {3}",
                    context.MessageName, context.PrimaryEntityName, context.Stage, context.Depth);

                // Depth check to prevent infinite loops
                if (context.Depth > 2)
                {
                    tracingService.Trace("Depth > 2. Exiting to prevent infinite loop.");
                    return;
                }

                // Validate message
                if (context.MessageName != "$Message")
                    return;

$targetCheck

                // ═══ Business logic here ═══

                tracingService.Trace("$PluginName execution completed.");
            }
            catch (InvalidPluginExecutionException)
            {
                throw;
            }
            catch (Exception ex)
            {
                tracingService.Trace("Error: {0}", ex.ToString());
                throw new InvalidPluginExecutionException(
                    "An unexpected error occurred in $PluginName. Please contact your administrator.", ex);
            }
        }
    }
}
"@

Set-Content -Path (Join-Path $pluginProjectDir "$PluginName.cs") -Value $pluginClass -Encoding UTF8
Write-Step "Generated plugin class: $PluginName.cs"

# ─── Generate Test .csproj ────────────────────────────────────────────────────

$testCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net471</TargetFramework>
    <RootNamespace>$Namespace.Tests</RootNamespace>
    <AssemblyName>$Namespace.Tests</AssemblyName>
    <IsPackable>false</IsPackable>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.56" />
    <PackageReference Include="MSTest.TestFramework" Version="2.2.10" />
    <PackageReference Include="MSTest.TestAdapter" Version="2.2.10" />
    <PackageReference Include="Moq" Version="4.20.72" />
    <PackageReference Include="Castle.Core" Version="5.1.1" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.6.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\$Namespace\$Namespace.csproj" />
  </ItemGroup>
</Project>
"@

Set-Content -Path (Join-Path $testProjectDir "$Namespace.Tests.csproj") -Value $testCsproj -Encoding UTF8
Write-Step "Generated test .csproj"

# ─── Generate Test Class ──────────────────────────────────────────────────────

$testClass = @"
using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Moq;

namespace $Namespace.Tests
{
    [TestClass]
    public class ${PluginName}Tests
    {
        private Mock<IOrganizationService> _serviceMock;
        private Mock<IPluginExecutionContext> _contextMock;
        private Mock<ITracingService> _tracingMock;
        private Mock<IOrganizationServiceFactory> _factoryMock;
        private Mock<IServiceProvider> _serviceProviderMock;

        [TestInitialize]
        public void Setup()
        {
            _serviceMock = new Mock<IOrganizationService>();
            _contextMock = new Mock<IPluginExecutionContext>();
            _tracingMock = new Mock<ITracingService>();
            _factoryMock = new Mock<IOrganizationServiceFactory>();
            _serviceProviderMock = new Mock<IServiceProvider>();

            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
                .Returns(_contextMock.Object);
            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(ITracingService)))
                .Returns(_tracingMock.Object);
            _serviceProviderMock
                .Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
                .Returns(_factoryMock.Object);
            _factoryMock
                .Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
                .Returns(_serviceMock.Object);

            // Default context setup
            _contextMock.Setup(c => c.MessageName).Returns("$Message");
            _contextMock.Setup(c => c.PrimaryEntityName).Returns("$EntityName");
            _contextMock.Setup(c => c.Stage).Returns($stageNumber);
            _contextMock.Setup(c => c.Depth).Returns(1);
            _contextMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
        }

        private $PluginName CreatePlugin(string unsecure = "", string secure = "")
        {
            return new $PluginName(unsecure, secure);
        }

        private ParameterCollection CreateInputParametersWithTarget(Entity target)
        {
            return new ParameterCollection { { "Target", target } };
        }

        [TestMethod]
        [TestCategory("Plugin")]
        public void Execute_ValidTarget_ShouldSucceed()
        {
            // Arrange
            var target = new Entity("$EntityName", Guid.NewGuid());
            _contextMock.Setup(c => c.InputParameters)
                .Returns(CreateInputParametersWithTarget(target));

            var plugin = CreatePlugin();

            // Act
            plugin.Execute(_serviceProviderMock.Object);

            // Assert
            _tracingMock.Verify(
                t => t.Trace(It.Is<string>(s => s.Contains("completed")), It.IsAny<object[]>()),
                Times.AtLeastOnce);
        }

        [TestMethod]
        [TestCategory("Plugin")]
        public void Execute_DepthExceeded_ShouldReturn()
        {
            // Arrange
            _contextMock.Setup(c => c.Depth).Returns(3);
            var target = new Entity("$EntityName", Guid.NewGuid());
            _contextMock.Setup(c => c.InputParameters)
                .Returns(CreateInputParametersWithTarget(target));

            var plugin = CreatePlugin();

            // Act
            plugin.Execute(_serviceProviderMock.Object);

            // Assert — plugin should exit early; no service calls
            _serviceMock.Verify(
                s => s.Create(It.IsAny<Entity>()), Times.Never);
        }

        [TestMethod]
        [TestCategory("Plugin")]
        public void Execute_MissingTarget_ShouldReturn()
        {
            // Arrange
            _contextMock.Setup(c => c.InputParameters)
                .Returns(new ParameterCollection());

            var plugin = CreatePlugin();

            // Act
            plugin.Execute(_serviceProviderMock.Object);

            // Assert — no exception thrown, plugin exits gracefully
            _serviceMock.Verify(
                s => s.Create(It.IsAny<Entity>()), Times.Never);
        }

        [TestMethod]
        [TestCategory("Plugin")]
        public void Execute_WrongMessage_ShouldReturn()
        {
            // Arrange
            _contextMock.Setup(c => c.MessageName).Returns("Delete");
            var target = new Entity("$EntityName", Guid.NewGuid());
            _contextMock.Setup(c => c.InputParameters)
                .Returns(CreateInputParametersWithTarget(target));

            var plugin = CreatePlugin();

            // Act
            plugin.Execute(_serviceProviderMock.Object);

            // Assert
            _serviceMock.Verify(
                s => s.Create(It.IsAny<Entity>()), Times.Never);
        }

        [TestMethod]
        [TestCategory("Plugin")]
        [ExpectedException(typeof(InvalidPluginExecutionException))]
        public void Execute_UnexpectedException_ShouldThrowInvalidPluginExecution()
        {
            // Arrange
            var target = new Entity("$EntityName", Guid.NewGuid());
            _contextMock.Setup(c => c.InputParameters)
                .Returns(CreateInputParametersWithTarget(target));

            // Simulate an unexpected error
            _contextMock.Setup(c => c.InputParameters)
                .Throws(new NullReferenceException("Simulated error"));

            var plugin = CreatePlugin();

            // Act
            plugin.Execute(_serviceProviderMock.Object);
        }
    }
}
"@

Set-Content -Path (Join-Path $testProjectDir "${PluginName}Tests.cs") -Value $testClass -Encoding UTF8
Write-Step "Generated test class: ${PluginName}Tests.cs"

# ─── Strong Name Key Instructions ────────────────────────────────────────────

$snkNote = @"
# Strong Name Key

A strong-name key (.snk) is REQUIRED for Dataverse plugin assemblies.

## Generate the key:

    sn -k $Namespace.snk

Place the generated file in the plugin project directory:
    $pluginProjectDir\$Namespace.snk

The .csproj is already configured to reference this file.
"@

Set-Content -Path (Join-Path $pluginProjectDir "SNK_README.md") -Value $snkNote -Encoding UTF8

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Plugin '$PluginName' scaffolded successfully!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📁 Plugin project:  $pluginProjectDir" -ForegroundColor White
Write-Host "  🧪 Test project:    $testProjectDir" -ForegroundColor White
Write-Host "  📋 Entity:          $EntityName" -ForegroundColor White
Write-Host "  📨 Message:         $Message" -ForegroundColor White
Write-Host "  ⚡ Stage:           $Stage ($stageNumber)" -ForegroundColor White
Write-Host ""
Write-Host "  Next Steps:" -ForegroundColor Yellow
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  1. Generate strong-name key:  sn -k $Namespace.snk" -ForegroundColor White
Write-Host "  2. Implement business logic in $PluginName.cs" -ForegroundColor White
Write-Host "  3. Build:  msbuild /t:build /restore" -ForegroundColor White
Write-Host "  4. Run tests:  dotnet test $testProjectDir" -ForegroundColor White
Write-Host "  5. Register with Plugin Registration Tool or pac plugin push" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
