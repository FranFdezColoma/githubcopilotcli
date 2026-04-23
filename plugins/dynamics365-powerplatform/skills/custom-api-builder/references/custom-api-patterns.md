# Custom API Patterns Reference

> **Language Rule:** Always respond to the user in the same language they use.

## Custom API Metadata Schema

A Custom API is defined by a record in the `customapi` table with the following properties:

| Property | Type | Required | Description |
|---|---|---|---|
| `uniquename` | String | ✅ | Unique name with publisher prefix (e.g., `contoso_ApproveOrder`) |
| `displayname` | String | ✅ | Display name shown in tools and documentation |
| `description` | String | ✅ | Detailed description of the API purpose |
| `bindingtype` | OptionSet | ✅ | `0` = Global, `1` = Entity, `2` = EntityCollection |
| `boundentitylogicalname` | String | If bound | Logical name of the bound entity |
| `isfunction` | Boolean | ✅ | `true` = Function (GET, read-only), `false` = Action (POST, side effects) |
| `isprivate` | Boolean | ✅ | `true` = Not visible in Web API metadata |
| `allowedcustomprocessingsteptype` | OptionSet | ✅ | `0` = None, `1` = AsyncOnly, `2` = SyncAndAsync |
| `executeprivilegename` | String | No | Custom privilege required to execute |
| `plugintypeid` | Lookup | No | Reference to the backing plugin type |
| `iscustomizable` | ManagedProperty | No | Whether it can be customized in downstream solutions |
| `workflowsdkstepenabled` | Boolean | No | Whether a custom processing step is allowed |

---

## Supported Parameter Types

Custom API request parameters and response properties support these types:

| Type Value | Type Name | C# Type | Notes |
|---|---|---|---|
| `0` | Boolean | `bool` | |
| `1` | DateTime | `DateTime` | |
| `2` | Decimal | `decimal` | |
| `3` | Entity | `Entity` | Full entity with all attributes |
| `4` | EntityCollection | `EntityCollection` | Collection of entities |
| `5` | EntityReference | `EntityReference` | Reference to a specific record |
| `6` | Float | `double` | |
| `7` | Integer | `int` | |
| `8` | Money | `Money` | Wraps a decimal value |
| `9` | Picklist | `OptionSetValue` | Single option set value |
| `10` | String | `string` | Max 4000 characters by default |
| `11` | StringArray | `string[]` | Array of strings (JSON serialized) |
| `12` | Guid | `Guid` | Unique identifier |

### Parameter Definition Schema (CustomAPIRequestParameter / CustomAPIResponseProperty)

| Property | Type | Required | Description |
|---|---|---|---|
| `uniquename` | String | ✅ | Parameter name (with publisher prefix) |
| `displayname` | String | ✅ | Display name |
| `description` | String | ✅ | Purpose of the parameter |
| `type` | OptionSet | ✅ | One of the types above (0-12) |
| `isoptional` | Boolean | ✅ | Whether the parameter is optional (request only) |
| `logicalentityname` | String | Conditional | Required when type is Entity, EntityCollection, or EntityReference |

---

## Binding Types

### Global (Unbound) — `BindingType = 0`

- Called without an entity context.
- Endpoint: `POST/GET [OrgUri]/api/data/v9.2/<uniquename>`
- Use for: Cross-entity operations, utility functions, integration endpoints.

```http
POST https://org.crm.dynamics.com/api/data/v9.2/contoso_CalculateTax
Content-Type: application/json

{
    "Amount": 1500.00,
    "Region": "US-CA"
}
```

### Entity Bound — `BindingType = 1`

- Called in the context of a specific entity record.
- Endpoint: `POST/GET [OrgUri]/api/data/v9.2/<entityset>(<id>)/Microsoft.Dynamics.CRM.<uniquename>`
- The `Target` EntityReference is automatically available in `InputParameters`.
- Use for: Operations specific to a single record.

```http
POST https://org.crm.dynamics.com/api/data/v9.2/salesorders(00000000-0000-0000-0000-000000000001)/Microsoft.Dynamics.CRM.contoso_ApproveOrder
Content-Type: application/json

{}
```

### EntityCollection Bound — `BindingType = 2`

- Called in the context of an entity collection.
- Endpoint: `POST/GET [OrgUri]/api/data/v9.2/<entityset>/Microsoft.Dynamics.CRM.<uniquename>`
- Use for: Batch operations on a collection of entities.

```http
POST https://org.crm.dynamics.com/api/data/v9.2/salesorders/Microsoft.Dynamics.CRM.contoso_BulkApproveOrders
Content-Type: application/json

{
    "OrderIds": ["id1", "id2", "id3"]
}
```

---

## IsFunction vs IsAction

| Aspect | Function (`IsFunction = true`) | Action (`IsFunction = false`) |
|---|---|---|
| **HTTP Method** | `GET` | `POST` |
| **Side Effects** | ❌ Must NOT modify data | ✅ Can modify data |
| **Idempotent** | ✅ Yes | ❌ Not guaranteed |
| **Composable** | ✅ Can be used in `$filter`, `$orderby` (OData v4) | ❌ No |
| **Use When** | Read-only calculations, validations, lookups | Creating/updating records, triggering processes |

### Function Example

```http
GET https://org.crm.dynamics.com/api/data/v9.2/contoso_GetTaxRate(Region=@p1)?@p1='US-CA'
```

### Action Example

```http
POST https://org.crm.dynamics.com/api/data/v9.2/contoso_ApproveOrder
Content-Type: application/json

{ "OrderId": { "salesorderid": "..." } }
```

---

## Security

### AllowedCustomProcessingStepType

| Value | Meaning |
|---|---|
| `0` — None | No custom processing steps allowed. Only the main plugin runs. |
| `1` — Async Only | Other plugins can register async steps on this message. |
| `2` — Sync and Async | Other plugins can register both sync and async steps. |

**Recommendation:** Use `None` (0) unless you explicitly want to allow ISV extensibility on your API.

### Privilege Requirements

- By default, any user with the `prvExecute` privilege can call Custom APIs.
- Use `ExecutePrivilegeName` to require a specific security role privilege.
- For entity-bound APIs, the caller also needs standard CRUD privileges on the bound entity.

### Service Principal Access

Custom APIs support application (S2S) authentication. Ensure the application user has the required security roles.

---

## Best Practices

1. **Naming Convention:** `<publisher>_<Verb><Noun>` — e.g., `contoso_ApproveOrder`, `contoso_CalculateTax`.
2. **Prefix Parameters:** Always prefix parameter names with the publisher prefix — `contoso_OrderId`, not `OrderId`.
3. **Keep APIs Focused:** One API = one well-defined operation. Avoid "god" APIs.
4. **Use Functions for Read-Only:** If the API doesn't modify data, make it a Function.
5. **Document Thoroughly:** Include clear descriptions on the API, each parameter, and each response property.
6. **Version Via New APIs:** Don't modify existing API contracts. Create `contoso_ApproveOrderV2` instead.
7. **Handle Nulls:** Always check for parameter existence before casting.
8. **Return Meaningful Errors:** Throw `InvalidPluginExecutionException` with clear messages.
9. **Limit Parameter Count:** Prefer Entity/EntityCollection parameters over many individual parameters for complex inputs.
10. **Test with Both SDK and Web API:** Behavior can differ subtly between the two.

---

## Examples

### Example 1: Simple CRUD Custom API

**API:** `contoso_CloneRecord` — Clones a Dataverse record by ID.

```
Binding:      Global
IsFunction:   false
Parameters:
  - contoso_SourceRecordId  (EntityReference, required)
  - contoso_OverrideValues  (Entity, optional)
Response:
  - contoso_ClonedRecordId  (EntityReference)
```

```csharp
public class CloneRecordApi : IPlugin
{
    public void Execute(IServiceProvider serviceProvider)
    {
        var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
        var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
        var service = factory.CreateOrganizationService(context.UserId);

        var sourceRef = (EntityReference)context.InputParameters["SourceRecordId"];
        var source = service.Retrieve(sourceRef.LogicalName, sourceRef.Id, new ColumnSet(true));

        source.Id = Guid.Empty;
        source.Attributes.Remove(sourceRef.LogicalName + "id");

        // Apply overrides if provided
        if (context.InputParameters.Contains("OverrideValues"))
        {
            var overrides = (Entity)context.InputParameters["OverrideValues"];
            foreach (var attr in overrides.Attributes)
            {
                source[attr.Key] = attr.Value;
            }
        }

        var newId = service.Create(source);
        context.OutputParameters["ClonedRecordId"] =
            new EntityReference(sourceRef.LogicalName, newId);
    }
}
```

### Example 2: Batch Operation Custom API

**API:** `contoso_BulkUpdateStatus` — Updates status on multiple records.

```
Binding:      Global
IsFunction:   false
Parameters:
  - contoso_EntityLogicalName  (String, required)
  - contoso_RecordIds          (StringArray, required)
  - contoso_NewStatusCode      (Integer, required)
Response:
  - contoso_SuccessCount       (Integer)
  - contoso_FailureCount       (Integer)
```

```csharp
public class BulkUpdateStatusApi : IPlugin
{
    public void Execute(IServiceProvider serviceProvider)
    {
        var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
        var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
        var tracing = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
        var service = factory.CreateOrganizationService(context.UserId);

        var entityName = (string)context.InputParameters["EntityLogicalName"];
        var recordIds = (string[])context.InputParameters["RecordIds"];
        var statusCode = (int)context.InputParameters["NewStatusCode"];

        int success = 0, failure = 0;

        foreach (var idStr in recordIds)
        {
            try
            {
                var update = new Entity(entityName, Guid.Parse(idStr));
                update["statuscode"] = new OptionSetValue(statusCode);
                service.Update(update);
                success++;
            }
            catch (Exception ex)
            {
                tracing.Trace("Failed to update {0}: {1}", idStr, ex.Message);
                failure++;
            }
        }

        context.OutputParameters["SuccessCount"] = success;
        context.OutputParameters["FailureCount"] = failure;
    }
}
```

### Example 3: Integration Custom API

**API:** `contoso_SyncToExternalCRM` — Pushes a contact record to an external system.

```
Binding:      Entity (contact)
IsFunction:   false
Parameters:
  - (Target is implicit from binding)
  - contoso_ExternalSystemUrl  (String, required)
Response:
  - contoso_ExternalId         (String)
  - contoso_SyncSuccess        (Boolean)
```

```csharp
public class SyncToExternalCrmApi : IPlugin
{
    public void Execute(IServiceProvider serviceProvider)
    {
        var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
        var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
        var tracing = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
        var service = factory.CreateOrganizationService(context.UserId);

        var target = (EntityReference)context.InputParameters["Target"];
        var externalUrl = (string)context.InputParameters["ExternalSystemUrl"];

        var contact = service.Retrieve("contact", target.Id,
            new ColumnSet("fullname", "emailaddress1", "telephone1"));

        // Build payload (in production, use a dedicated HTTP helper)
        var payload = new
        {
            name = contact.GetAttributeValue<string>("fullname"),
            email = contact.GetAttributeValue<string>("emailaddress1"),
            phone = contact.GetAttributeValue<string>("telephone1")
        };

        // NOTE: Use IHttpClientFactory patterns or a Secure/Unsecure config
        // for external HTTP calls in production plugins.
        // External HTTP calls from sandbox plugins require the external endpoint
        // to be accessible and HTTPS.

        tracing.Trace("Would sync contact {0} to {1}", target.Id, externalUrl);

        // Simulate response
        context.OutputParameters["ExternalId"] = Guid.NewGuid().ToString();
        context.OutputParameters["SyncSuccess"] = true;
    }
}
```

---

## Further Reading

- [Microsoft: Create and use Custom APIs](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/custom-api)
- [Microsoft: Custom API tables](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/custom-api-tables)
- [Microsoft: Write a plug-in](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/write-plug-in)
