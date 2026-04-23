---
name: custom-api-builder
description: Scaffold, build, and register Dataverse Custom APIs with backing plugin code. Use when creating new Custom APIs, Custom Actions, or Custom Process Actions in Dynamics 365 CE, including request/response parameter definition, plugin implementation, and registration.
---

# Custom API Builder

> **Language Rule:** Always respond to the user in the same language they use.

## Decision Tree: Which API Type to Use

| Criteria | Custom API | Custom Action | Custom Process Action |
|---|---|---|---|
| **Backing logic** | C# Plugin (recommended) | C# Plugin or Workflow Activity | Workflow (no code) |
| **Supports Functions (GET)** | ✅ Yes (`IsFunction = true`) | ❌ No | ❌ No |
| **Solution-aware** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Supports request/response params** | ✅ Full type system | ✅ Full type system | ⚠️ Limited types |
| **Supports binding** | ✅ Global, Entity, EntityCollection | ✅ Global, Entity | ⚠️ Entity only |
| **Requires Dynamics 365 license** | ❌ Dataverse license sufficient | ❌ Dataverse license sufficient | ❌ Dataverse license sufficient |
| **Deprecation risk** | ✅ Current & recommended | ⚠️ Older pattern | ⚠️ Older pattern |

**Recommendation:** Always prefer **Custom API** for new development. Use Custom Action only when extending existing Action-based architectures.

---

## Scaffolding Process

### Step 1: Define API Metadata

Determine the following properties before coding:

| Property | Required | Example |
|---|---|---|
| `UniqueName` | ✅ | `contoso_ApproveOrder` |
| `DisplayName` | ✅ | `Approve Order` |
| `Description` | ✅ | `Validates and approves a sales order` |
| `BindingType` | ✅ | `Global` / `Entity` / `EntityCollection` |
| `BoundEntityLogicalName` | If bound | `salesorder` |
| `IsFunction` | ✅ | `false` (Action) / `true` (Function) |
| `IsPrivate` | ✅ | `false` |
| `AllowedCustomProcessingStepType` | ✅ | `None` / `AsyncOnly` / `SyncAndAsync` |
| `PluginTypeId` | After registration | GUID of the backing plugin type |

### Step 2: Define Request Parameters

For each input parameter:

```
Name:        contoso_OrderId
Type:        EntityReference (or String, Integer, etc.)
Required:    true
Description: The ID of the order to approve
```

### Step 3: Define Response Properties

For each output property:

```
Name:        contoso_IsApproved
Type:        Boolean
Description: Whether the order was successfully approved
```

### Step 4: Generate C# Plugin Class

Use the scaffold script to generate the project structure:

```powershell
.\skills\custom-api-builder\scripts\scaffold-custom-api.ps1 `
    -ApiName "ApproveOrder" `
    -PluginNamespace "Contoso.Plugins" `
    -OutputPath ".\src\Contoso.Plugins"
```

For a bound API:

```powershell
.\skills\custom-api-builder\scripts\scaffold-custom-api.ps1 `
    -ApiName "ApproveOrder" `
    -PluginNamespace "Contoso.Plugins" `
    -OutputPath ".\src\Contoso.Plugins" `
    -BoundEntity "salesorder"
```

### Step 5: Register the Custom API

Choose one of these registration methods (see Registration Options below).

---

## C# Implementation Pattern

### Plugin Class Structure

```csharp
using System;
using Microsoft.Xrm.Sdk;

namespace Contoso.Plugins.CustomApis
{
    /// <summary>
    /// Backing plugin for the contoso_ApproveOrder Custom API.
    /// </summary>
    public class ApproveOrderApi : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            // 1. Obtain execution context
            var context = (IPluginExecutionContext)serviceProvider
                .GetService(typeof(IPluginExecutionContext));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider
                .GetService(typeof(IOrganizationServiceFactory));
            var tracingService = (ITracingService)serviceProvider
                .GetService(typeof(ITracingService));
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            try
            {
                // 2. Read request parameters from InputParameters
                var orderId = context.InputParameters.Contains("OrderId")
                    ? (EntityReference)context.InputParameters["OrderId"]
                    : throw new InvalidPluginExecutionException(
                        "OrderId is a required parameter.");

                tracingService.Trace("Processing order: {0}", orderId.Id);

                // 3. Execute business logic
                bool approved = ProcessApproval(service, orderId, tracingService);

                // 4. Set response in OutputParameters
                context.OutputParameters["IsApproved"] = approved;
            }
            catch (InvalidPluginExecutionException)
            {
                throw; // Re-throw business exceptions as-is
            }
            catch (Exception ex)
            {
                tracingService.Trace("Error: {0}", ex.ToString());
                throw new InvalidPluginExecutionException(
                    $"An error occurred in ApproveOrder: {ex.Message}", ex);
            }
        }

        private bool ProcessApproval(
            IOrganizationService service,
            EntityReference orderId,
            ITracingService tracingService)
        {
            // Retrieve the order
            var order = service.Retrieve(
                orderId.LogicalName,
                orderId.Id,
                new Microsoft.Xrm.Sdk.Query.ColumnSet("statecode", "totalamount"));

            // Business validation
            var state = order.GetAttributeValue<OptionSetValue>("statecode");
            if (state?.Value != 0) // 0 = Active
            {
                throw new InvalidPluginExecutionException(
                    "Only active orders can be approved.");
            }

            // Update order status
            var updateOrder = new Entity(orderId.LogicalName, orderId.Id);
            updateOrder["statuscode"] = new OptionSetValue(100000001); // Approved
            service.Update(updateOrder);

            tracingService.Trace("Order {0} approved successfully.", orderId.Id);
            return true;
        }
    }
}
```

### Key Implementation Rules

1. **Always use `ITracingService`** for logging — `Console.WriteLine` does not work in plugins.
2. **Wrap all logic in try-catch** — unhandled exceptions crash silently.
3. **Throw `InvalidPluginExecutionException`** for business errors — this is the only exception type that surfaces to the caller with a clean message.
4. **Use `context.UserId`** when creating `IOrganizationService` to run as the calling user (respects security roles).
5. **Never store state in class fields** — plugin classes are cached and reused across requests.
6. **Access parameters by the `Name` defined in the Custom API metadata** (without the publisher prefix in `InputParameters`/`OutputParameters` keys).

---

## Registration Options

### Option A: Solution-Aware Registration (Recommended)

Include the Custom API definition in a managed/unmanaged solution:

1. Create the Custom API record in the target environment (via maker portal or programmatically).
2. Add request parameters and response properties.
3. Build and register the plugin assembly.
4. Link the `PluginTypeId` on the Custom API record to the registered plugin type.
5. Export the solution containing the Custom API, parameters, and plugin step.

### Option B: Plugin Registration Tool

```
1. Open Plugin Registration Tool
2. Register New Assembly → Select your .dll
3. In Dataverse, create the Custom API record:
   - UniqueName: contoso_ApproveOrder
   - Plugin Type: Select the registered type
4. Create CustomAPIRequestParameter records
5. Create CustomAPIResponseProperty records
```

### Option C: PAC CLI

```powershell
# Authenticate
pac auth create --url https://yourorg.crm.dynamics.com

# Push plugin assembly
pac plugin push --assemblyPath .\bin\Release\Contoso.Plugins.dll

# Import solution containing Custom API metadata
pac solution import --path .\Solutions\CustomApis_1_0_0_0.zip --activate-plugins
```

---

## Testing Strategy

### Unit Testing (Plugin Logic)

```csharp
[TestClass]
public class ApproveOrderApiTests
{
    [TestMethod]
    public void Execute_ValidActiveOrder_ReturnsApproved()
    {
        // Arrange
        var context = new Mock<IPluginExecutionContext>();
        var serviceFactory = new Mock<IOrganizationServiceFactory>();
        var service = new Mock<IOrganizationService>();
        var tracingService = new Mock<ITracingService>();
        var serviceProvider = new Mock<IServiceProvider>();

        var orderId = new EntityReference("salesorder", Guid.NewGuid());
        var inputParams = new ParameterCollection { { "OrderId", orderId } };
        var outputParams = new ParameterCollection();

        context.Setup(c => c.InputParameters).Returns(inputParams);
        context.Setup(c => c.OutputParameters).Returns(outputParams);
        context.Setup(c => c.UserId).Returns(Guid.NewGuid());

        serviceProvider.Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
            .Returns(context.Object);
        serviceProvider.Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
            .Returns(serviceFactory.Object);
        serviceProvider.Setup(sp => sp.GetService(typeof(ITracingService)))
            .Returns(tracingService.Object);
        serviceFactory.Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
            .Returns(service.Object);

        var orderEntity = new Entity("salesorder", orderId.Id);
        orderEntity["statecode"] = new OptionSetValue(0);
        orderEntity["totalamount"] = new Money(100m);
        service.Setup(s => s.Retrieve(
            It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<ColumnSet>()))
            .Returns(orderEntity);

        // Act
        var plugin = new ApproveOrderApi();
        plugin.Execute(serviceProvider.Object);

        // Assert
        Assert.IsTrue((bool)outputParams["IsApproved"]);
        service.Verify(s => s.Update(It.IsAny<Entity>()), Times.Once);
    }
}
```

### Integration Testing via Web API

```http
POST [Organization URI]/api/data/v9.2/contoso_ApproveOrder
Content-Type: application/json
Authorization: Bearer {token}

{
    "OrderId": {
        "@odata.type": "Microsoft.Dynamics.CRM.salesorder",
        "salesorderid": "00000000-0000-0000-0000-000000000001"
    }
}
```

**Expected Response:**

```json
{
    "@odata.context": "[Organization URI]/api/data/v9.2/$metadata#Microsoft.Dynamics.CRM.contoso_ApproveOrderResponse",
    "IsApproved": true
}
```

### Postman Collection Template

Create a Postman collection with:

1. **Environment variables:** `orgUrl`, `clientId`, `clientSecret`, `tenantId`
2. **Pre-request script:** OAuth 2.0 token acquisition
3. **Request:** `POST {{orgUrl}}/api/data/v9.2/contoso_ApproveOrder`
4. **Test assertions:**
   ```javascript
   pm.test("Status is 200", () => pm.response.to.have.status(200));
   pm.test("IsApproved is true", () => {
       var json = pm.response.json();
       pm.expect(json.IsApproved).to.eql(true);
   });
   ```

---

## Scaffold Script

Generate the full project structure with:

```powershell
.\skills\custom-api-builder\scripts\scaffold-custom-api.ps1 `
    -ApiName "ApproveOrder" `
    -PluginNamespace "Contoso.Plugins" `
    -OutputPath ".\src"
```

See [`scripts/scaffold-custom-api.ps1`](scripts/scaffold-custom-api.ps1) for the full scaffold script.

---

## References

- [Custom API Patterns Reference](references/custom-api-patterns.md) — metadata schema, parameter types, binding types, best practices
- [Microsoft Docs: Custom API](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/custom-api)
- [Microsoft Docs: Write a plug-in](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/write-plug-in)
