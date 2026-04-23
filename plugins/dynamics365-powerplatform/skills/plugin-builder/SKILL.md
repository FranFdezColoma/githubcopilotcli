---
name: plugin-builder
description: Scaffold, develop, and register Dataverse plugins for Dynamics 365 CE. Use when building server-side business logic including pre/post operation plugins, Custom Workflow Activities, and plugin registration using .NET Framework 4.7.1 and CrmSdk.
---

# Plugin Builder Skill

> **Language Rule:** Always respond to the user in the same language they use.

## Prerequisites

| Tool | Required Version | Install / Notes |
|------|-----------------|-----------------|
| Visual Studio 2022 or VS Code | Latest | With .NET / C# workload |
| .NET Framework | 4.7.1 (targeting pack) | [Download](https://dotnet.microsoft.com/download/dotnet-framework) |
| Plugin Registration Tool | Latest | NuGet: `Microsoft.CrmSdk.XrmTooling.PluginRegistrationTool` or XrmToolBox |
| Power Platform CLI (`pac`) | Latest (optional) | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |

Verify prerequisites:

```powershell
dotnet --version                         # 6.0+ (host SDK)
msbuild -version                         # 17.x+
pac --version                            # 1.30+ (optional)
```

---

## Plugin Types

| Stage | Value | Timing | Use Case |
|-------|-------|--------|----------|
| Pre-validation | 10 | Before main transaction | Input validation, cancellation |
| Pre-operation | 20 | Inside transaction, before DB write | Modify target entity, set defaults |
| Post-operation | 40 | Inside transaction, after DB write | Trigger follow-up logic, external calls |

### Execution Mode

| Mode | Value | Description |
|------|-------|-------------|
| Synchronous | 0 | Blocks the user until complete |
| Asynchronous | 1 | Queued for background processing (post-operation only) |

---

## Scaffolding Process

### Manual Setup

1. Create a **Class Library** project targeting **.NET Framework 4.7.1**
2. Install NuGet package:
   ```powershell
   Install-Package Microsoft.CrmSdk.CoreAssemblies -Version 9.0.2.56
   ```
3. **Sign the assembly** with a strong-name key (`.snk`):
   ```powershell
   sn -k MyPlugins.snk
   ```
   Then reference it in the `.csproj`:
   ```xml
   <SignAssembly>true</SignAssembly>
   <AssemblyOriginatorKeyFile>MyPlugins.snk</AssemblyOriginatorKeyFile>
   ```
4. Implement `IPlugin`

### Using the Scaffold Script

```powershell
.\scripts\scaffold-plugin.ps1 `
    -PluginName "SetDefaultPriceOnCreate" `
    -Namespace "Contoso.Crm.Plugins" `
    -EntityName "product" `
    -Message Create `
    -Stage PreOperation `
    -OutputPath "C:\Dev\Plugins"
```

See: [`scripts/scaffold-plugin.ps1`](scripts/scaffold-plugin.ps1)

---

## Plugin Class Template

```csharp
using System;
using Microsoft.Xrm.Sdk;

namespace CompanyName.Crm.Plugins
{
    public sealed class EntityNameMessagePlugin : IPlugin
    {
        private readonly string _unsecureConfig;
        private readonly string _secureConfig;

        public EntityNameMessagePlugin(string unsecureConfig, string secureConfig)
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
                tracingService.Trace("Plugin execution started.");

                // Depth check to prevent infinite loops
                if (context.Depth > 2)
                {
                    tracingService.Trace("Depth > 2. Exiting to prevent infinite loop.");
                    return;
                }

                // Validate message and entity
                if (context.MessageName != "Create" && context.MessageName != "Update")
                    return;

                // Get target entity
                if (!context.InputParameters.Contains("Target") ||
                    !(context.InputParameters["Target"] is Entity target))
                    return;

                // ─── Business logic here ───

                tracingService.Trace("Plugin execution completed.");
            }
            catch (InvalidPluginExecutionException)
            {
                throw;
            }
            catch (Exception ex)
            {
                tracingService.Trace("Error: {0}", ex.ToString());
                throw new InvalidPluginExecutionException(
                    "An unexpected error occurred. Please contact your administrator.", ex);
            }
        }
    }
}
```

---

## Development Patterns

### Pre-Image / Post-Image Usage

```csharp
// Pre-image: entity values BEFORE the operation
Entity preImage = context.PreEntityImages.Contains("PreImage")
    ? context.PreEntityImages["PreImage"]
    : null;

// Post-image: entity values AFTER the operation (post-operation only)
Entity postImage = context.PostEntityImages.Contains("PostImage")
    ? context.PostEntityImages["PostImage"]
    : null;

// Merge target + pre-image to get full record
var mergedEntity = new Entity(target.LogicalName, target.Id);
if (preImage != null)
{
    foreach (var attr in preImage.Attributes)
        mergedEntity[attr.Key] = attr.Value;
}
foreach (var attr in target.Attributes)
    mergedEntity[attr.Key] = attr.Value;
```

### Shared Variables Between Pre and Post Plugins

```csharp
// In pre-operation plugin:
context.SharedVariables.Add("OriginalPrice", oldPrice);

// In post-operation plugin (same pipeline):
if (context.SharedVariables.Contains("OriginalPrice"))
{
    var originalPrice = (Money)context.SharedVariables["OriginalPrice"];
}
```

### Entity Alias for Linked Entity Attributes

```csharp
// When registering on RetrieveMultiple with a linked entity
if (entity.Contains("alias.attributename"))
{
    var aliasedValue = entity.GetAttributeValue<AliasedValue>("alias.attributename");
    var actualValue = aliasedValue.Value;
}
```

### Alternate Keys for Upsert

```csharp
var upsertTarget = new Entity("account");
upsertTarget.KeyAttributes.Add("accountnumber", "ACC-001");
upsertTarget["name"] = "Contoso Ltd";

var request = new UpsertRequest { Target = upsertTarget };
var response = (UpsertResponse)service.Execute(request);
bool wasCreated = response.RecordCreated;
```

### Plugin Context Hierarchy

```csharp
// Access parent context (when plugin is triggered by another plugin)
IPluginExecutionContext parentContext = context.ParentContext;
while (parentContext != null)
{
    tracingService.Trace("Parent: {0} on {1}",
        parentContext.MessageName, parentContext.PrimaryEntityName);
    parentContext = parentContext.ParentContext;
}
```

---

## Registration

### Plugin Registration Tool (PRT)

1. **Register Assembly** → browse to your built `.dll`
2. **Register Step**:
   - Message: `Create`, `Update`, `Delete`, etc.
   - Primary Entity: e.g., `account`
   - Stage: Pre-validation (10), Pre-operation (20), Post-operation (40)
   - Execution Mode: Synchronous / Asynchronous
   - Filtering Attributes: select specific columns (Update only)
3. **Add Images** (optional):
   - Pre-image: attributes you need before the operation
   - Post-image: attributes you need after the operation

### PAC CLI Plugin Push

```powershell
pac plugin push --solution-unique-name MySolution
```

### Solution-Aware Registration
Register steps through solutions for ALM (export/import across environments).

---

## Debugging

### Plugin Profiler (via PRT)

1. In PRT, select the step → **Start Profiling**
2. Execute the action in D365 that triggers the plugin
3. Download the profiler log
4. In PRT, **Debug** → attach Visual Studio → replay execution
5. Step through code with breakpoints

### ITracingService Best Practices

```csharp
tracingService.Trace("=== {0} START ===", nameof(MyPlugin));
tracingService.Trace("Message: {0}, Entity: {1}, Stage: {2}",
    context.MessageName, context.PrimaryEntityName, context.Stage);
tracingService.Trace("User: {0}, Depth: {1}", context.UserId, context.Depth);
tracingService.Trace("Target attributes: {0}",
    string.Join(", ", target.Attributes.Keys));
```

### Plugin Trace Log
- Enable in **System Settings → Customization → Plugin Trace Log**: `All` or `Exception`
- View logs in **Settings → Plugin Trace Log** entity
- Logs auto-purge after 24 hours by default

---

## Performance Best Practices

| Practice | Why |
|----------|-----|
| Use `ColumnSet` with specific columns | Avoid `new ColumnSet(true)` — loads ALL columns |
| Minimize Retrieve operations | Combine queries; use images instead of re-retrieving |
| Batch with `ExecuteMultipleRequest` | Reduces round-trips for bulk operations |
| Avoid synchronous HTTP calls | Use async plugins (post-operation) for external APIs |
| Keep plugins under 2 minutes | Sandbox timeout is 2 min; aim for < 10 seconds |
| Use early-bound types sparingly | Late-bound avoids assembly coupling; use early-bound only when type safety is critical |

### ExecuteMultipleRequest Example

```csharp
var requests = new ExecuteMultipleRequest
{
    Requests = new OrganizationRequestCollection(),
    Settings = new ExecuteMultipleSettings
    {
        ContinueOnError = true,
        ReturnResponses = true
    }
};

foreach (var record in recordsToUpdate)
{
    requests.Requests.Add(new UpdateRequest { Target = record });
}

var responses = (ExecuteMultipleResponse)service.Execute(requests);
foreach (var responseItem in responses.Responses)
{
    if (responseItem.Fault != null)
        tracingService.Trace("Error on index {0}: {1}",
            responseItem.RequestIndex, responseItem.Fault.Message);
}
```

---

## References

- Scaffold script: [`scripts/scaffold-plugin.ps1`](scripts/scaffold-plugin.ps1)
- Pattern reference: [`references/plugin-patterns.md`](references/plugin-patterns.md)
- [Official Plugin documentation](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/plug-ins)
