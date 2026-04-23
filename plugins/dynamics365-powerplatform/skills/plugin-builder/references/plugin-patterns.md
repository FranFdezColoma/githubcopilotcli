# Plugin Patterns Reference

> **Language Rule:** Always respond to the user in the same language they use.

---

## IPluginExecutionContext Properties Reference

| Property | Type | Description |
|----------|------|-------------|
| `MessageName` | `string` | SDK message (Create, Update, Delete, Retrieve, etc.) |
| `PrimaryEntityName` | `string` | Logical name of the primary entity |
| `PrimaryEntityId` | `Guid` | ID of the primary entity record |
| `Stage` | `int` | Pipeline stage (10, 20, 40) |
| `Mode` | `int` | Execution mode (0=Sync, 1=Async) |
| `Depth` | `int` | Plugin execution depth (1=first call) |
| `UserId` | `Guid` | Calling user's SystemUser ID |
| `InitiatingUserId` | `Guid` | User who started the original operation |
| `BusinessUnitId` | `Guid` | Business unit of the calling user |
| `OrganizationId` | `Guid` | Organization ID |
| `OrganizationName` | `string` | Organization unique name |
| `CorrelationId` | `Guid` | Unique ID for the entire operation chain |
| `OperationId` | `Guid` | Unique ID for the current operation |
| `OperationCreatedOn` | `DateTime` | When the operation was created |
| `IsExecutingOffline` | `bool` | Whether executing in offline mode |
| `IsInTransaction` | `bool` | Whether inside a database transaction |
| `IsOfflinePlayback` | `bool` | Whether replaying offline operations |
| `InputParameters` | `ParameterCollection` | Input parameters for the message |
| `OutputParameters` | `ParameterCollection` | Output parameters (post-operation only) |
| `PreEntityImages` | `EntityImageCollection` | Entity state before the operation |
| `PostEntityImages` | `EntityImageCollection` | Entity state after the operation |
| `SharedVariables` | `ParameterCollection` | Variables shared across the pipeline |
| `ParentContext` | `IPluginExecutionContext` | Parent execution context (null if root) |
| `OwningExtension` | `EntityReference` | Reference to the SdkMessageProcessingStep |

---

## Message Types and Entity Support Matrix

| Message | InputParameters Key | InputParameters Type | Supported Stages |
|---------|-------------------|---------------------|-----------------|
| `Create` | `Target` | `Entity` | 10, 20, 40 |
| `Update` | `Target` | `Entity` | 10, 20, 40 |
| `Delete` | `Target` | `EntityReference` | 10, 20, 40 |
| `Retrieve` | `Target` | `EntityReference` + `ColumnSet` | 10, 20, 40 |
| `RetrieveMultiple` | `Query` | `QueryBase` | 10, 20, 40 |
| `Associate` | `Target`, `Relationship`, `RelatedEntities` | `EntityReference`, `Relationship`, `EntityReferenceCollection` | 10, 20, 40 |
| `Disassociate` | `Target`, `Relationship`, `RelatedEntities` | `EntityReference`, `Relationship`, `EntityReferenceCollection` | 10, 20, 40 |
| `SetState` | `EntityMoniker`, `State`, `Status` | `EntityReference`, `OptionSetValue`, `OptionSetValue` | 10, 20, 40 |
| `Assign` | `Target`, `Assignee` | `EntityReference`, `EntityReference` | 10, 20, 40 |

---

## Stage and Mode Combinations

| Stage | Mode | Transaction | Images Available |
|-------|------|-------------|-----------------|
| Pre-validation (10) | Sync only | Outside | Pre-image only |
| Pre-operation (20) | Sync only | Inside | Pre-image only |
| Post-operation (40) | Sync or Async | Inside (sync) / Outside (async) | Pre-image + Post-image |

### Image Availability by Message and Stage

| Message | Stage | Pre-Image | Post-Image |
|---------|-------|-----------|------------|
| Create | Pre-validation (10) | ❌ | ❌ |
| Create | Pre-operation (20) | ❌ | ❌ |
| Create | Post-operation (40) | ❌ | ✅ |
| Update | Pre-validation (10) | ✅ | ❌ |
| Update | Pre-operation (20) | ✅ | ❌ |
| Update | Post-operation (40) | ✅ | ✅ |
| Delete | Pre-validation (10) | ✅ | ❌ |
| Delete | Pre-operation (20) | ✅ | ❌ |
| Delete | Post-operation (40) | ✅ | ❌ |

---

## Shared Variables Pattern

### Between Pre and Post Plugins (Same Pipeline)

```csharp
// ─── Pre-operation plugin ───
public void Execute(IServiceProvider serviceProvider)
{
    var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
    var target = (Entity)context.InputParameters["Target"];

    // Store original values for post-operation comparison
    context.SharedVariables["OriginalName"] = target.GetAttributeValue<string>("name") ?? "";
    context.SharedVariables["ProcessingTimestamp"] = DateTime.UtcNow.ToString("o");
}

// ─── Post-operation plugin ───
public void Execute(IServiceProvider serviceProvider)
{
    var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

    if (context.SharedVariables.Contains("OriginalName"))
    {
        var originalName = (string)context.SharedVariables["OriginalName"];
        var timestamp = (string)context.SharedVariables["ProcessingTimestamp"];
        // Use shared values...
    }
}
```

> **Note:** SharedVariables support serializable types only: `string`, `int`, `Guid`, `DateTime`, `Entity`, `EntityReference`, etc.

---

## Early-Bound vs Late-Bound Access Patterns

### Late-Bound (Recommended for Plugins)

```csharp
// Create
var entity = new Entity("account");
entity["name"] = "Contoso Ltd";
entity["revenue"] = new Money(1000000m);
entity["primarycontactid"] = new EntityReference("contact", contactId);
entity["industrycode"] = new OptionSetValue(1); // Accounting
var id = service.Create(entity);

// Retrieve
var account = service.Retrieve("account", id, new ColumnSet("name", "revenue"));
string name = account.GetAttributeValue<string>("name");
Money revenue = account.GetAttributeValue<Money>("revenue");
EntityReference contact = account.GetAttributeValue<EntityReference>("primarycontactid");

// Update
var update = new Entity("account", id);
update["name"] = "Contoso Corporation";
service.Update(update);

// Null-safe access
string phone = entity.GetAttributeValue<string>("telephone1") ?? "N/A";
int? statusCode = entity.GetAttributeValue<OptionSetValue>("statuscode")?.Value;
Guid? lookupId = entity.GetAttributeValue<EntityReference>("parentaccountid")?.Id;
```

### Early-Bound (When Type Safety Is Critical)

```csharp
// Requires generated entity classes via CrmSvcUtil or pac modelbuilder
var account = new Account
{
    Name = "Contoso Ltd",
    Revenue = new Money(1000000m),
    PrimaryContactId = new EntityReference("contact", contactId),
    IndustryCode = new OptionSetValue((int)Account_IndustryCode.Accounting)
};
var id = service.Create(account);

// Retrieve with early-bound
var retrieved = service.Retrieve("account", id, new ColumnSet("name")).ToEntity<Account>();
string name = retrieved.Name;
```

---

## Common OrganizationRequest Types

### CreateRequest / UpdateRequest / DeleteRequest

```csharp
var createRequest = new CreateRequest { Target = entity };
var createResponse = (CreateResponse)service.Execute(createRequest);
Guid newId = createResponse.id;

var updateRequest = new UpdateRequest { Target = entity };
service.Execute(updateRequest);

var deleteRequest = new DeleteRequest
{
    Target = new EntityReference("account", accountId)
};
service.Execute(deleteRequest);
```

### RetrieveRequest

```csharp
var request = new RetrieveRequest
{
    Target = new EntityReference("account", accountId),
    ColumnSet = new ColumnSet("name", "revenue"),
    RelatedEntitiesQuery = new RelationshipQueryCollection
    {
        {
            new Relationship("contact_customer_accounts"),
            new QueryExpression("contact")
            {
                ColumnSet = new ColumnSet("fullname", "emailaddress1")
            }
        }
    }
};
var response = (RetrieveResponse)service.Execute(request);
Entity account = response.Entity;
EntityCollection contacts = account.RelatedEntities[new Relationship("contact_customer_accounts")];
```

### UpsertRequest

```csharp
var target = new Entity("account");
target.KeyAttributes.Add("accountnumber", "ACC-001");
target["name"] = "Contoso Ltd";
target["revenue"] = new Money(500000m);

var response = (UpsertResponse)service.Execute(new UpsertRequest { Target = target });
bool wasCreated = response.RecordCreated;
```

### SetStateRequest

```csharp
var request = new SetStateRequest
{
    EntityMoniker = new EntityReference("account", accountId),
    State = new OptionSetValue(1),   // Inactive
    Status = new OptionSetValue(2)   // Inactive status reason
};
service.Execute(request);
```

---

## ExecuteMultipleRequest Pattern

```csharp
var batch = new ExecuteMultipleRequest
{
    Requests = new OrganizationRequestCollection(),
    Settings = new ExecuteMultipleSettings
    {
        ContinueOnError = true,
        ReturnResponses = true
    }
};

// Add up to 1000 requests per batch
foreach (var record in recordsToProcess)
{
    batch.Requests.Add(new UpdateRequest { Target = record });
}

var batchResponse = (ExecuteMultipleResponse)service.Execute(batch);

// Process results
int successCount = 0;
int errorCount = 0;
foreach (var item in batchResponse.Responses)
{
    if (item.Fault != null)
    {
        tracingService.Trace("Error at index {0}: {1}",
            item.RequestIndex, item.Fault.Message);
        errorCount++;
    }
    else
    {
        successCount++;
    }
}
tracingService.Trace("Batch complete: {0} succeeded, {1} failed.", successCount, errorCount);
```

> **Limits:** Max 1000 requests per ExecuteMultipleRequest. For larger sets, split into batches.

---

## Transaction Behavior in Plugin Pipeline

| Scenario | Behavior |
|----------|----------|
| Pre-operation (sync) throws | Entire transaction rolls back |
| Post-operation (sync) throws | Entire transaction rolls back |
| Post-operation (async) throws | Only async work fails; original operation already committed |
| Pre-validation throws | Operation cancelled before transaction starts |

### Rollback Implications

```csharp
// In Pre-operation: this update is part of the same transaction
// If the plugin or the triggering operation fails, this update is rolled back
service.Update(relatedEntity);

// In Post-operation (sync): same transaction behavior
// In Post-operation (async): SEPARATE transaction — not rolled back with the original
```

---

## Plugin Depth and Re-Entrant Scenarios

```
User creates Account
  → AccountCreate plugin fires (depth 1)
    → Plugin creates related Contact
      → ContactCreate plugin fires (depth 2)
        → Plugin updates Account
          → AccountUpdate plugin fires (depth 3)  ← GUARD HERE
```

### Recommended Guard

```csharp
if (context.Depth > 2)
{
    tracingService.Trace("Exiting: depth {0} exceeds limit.", context.Depth);
    return;
}
```

### Alternative: Check Initiating Entity

```csharp
// Only run if directly triggered (not as a side-effect)
if (context.ParentContext != null &&
    context.ParentContext.PrimaryEntityName == context.PrimaryEntityName)
{
    tracingService.Trace("Skipping: triggered by same entity in parent context.");
    return;
}
```

---

## Common Exceptions and Handling

| Exception Type | When Thrown | How to Handle |
|----------------|------------|---------------|
| `InvalidPluginExecutionException` | Business rule violation | Throw with user-friendly message |
| `FaultException<OrganizationServiceFault>` | SDK call failure | Log and wrap in `InvalidPluginExecutionException` |
| `TimeoutException` | External call timeout | Retry or fail gracefully |
| `NullReferenceException` | Missing expected data | Validate inputs before accessing |

### Error Handling Pattern

```csharp
try
{
    // Business logic
}
catch (InvalidPluginExecutionException)
{
    // Already a user-facing error — re-throw as-is
    throw;
}
catch (FaultException<OrganizationServiceFault> ex)
{
    tracingService.Trace("SDK Fault: {0}", ex.Detail.Message);
    tracingService.Trace("Error Code: {0}", ex.Detail.ErrorCode);
    tracingService.Trace("Trace: {0}", ex.Detail.TraceText);
    throw new InvalidPluginExecutionException(
        $"A Dataverse error occurred: {ex.Detail.Message}", ex);
}
catch (Exception ex)
{
    tracingService.Trace("Unexpected error: {0}", ex.ToString());
    throw new InvalidPluginExecutionException(
        "An unexpected error occurred. Contact your administrator.", ex);
}
```

---

## Registration XML Schema (Solution-Aware)

For ALM scenarios, plugin steps can be defined in solution XML:

```xml
<SdkMessageProcessingStep>
  <SdkMessageId>{SDK_MESSAGE_GUID}</SdkMessageId>
  <SdkMessageFilterId>{FILTER_GUID}</SdkMessageFilterId>
  <Name>CompanyName.Plugins.MyPlugin: Create of account</Name>
  <Description>Triggers on account create</Description>
  <Stage>20</Stage>                    <!-- Pre-operation -->
  <Mode>0</Mode>                       <!-- Synchronous -->
  <Rank>1</Rank>                       <!-- Execution order -->
  <SupportedDeployment>0</SupportedDeployment>  <!-- Server only -->
  <FilteringAttributes>name,revenue</FilteringAttributes>  <!-- Update only -->
  <AsyncAutoDelete>false</AsyncAutoDelete>
  <PluginTypeId>{PLUGIN_TYPE_GUID}</PluginTypeId>
  <Configuration></Configuration>
  <SdkMessageProcessingStepImages>
    <SdkMessageProcessingStepImage>
      <ImageType>0</ImageType>         <!-- 0=Pre, 1=Post, 2=Both -->
      <Name>PreImage</Name>
      <EntityAlias>PreImage</EntityAlias>
      <Attributes>name,revenue,statuscode</Attributes>
    </SdkMessageProcessingStepImage>
  </SdkMessageProcessingStepImages>
</SdkMessageProcessingStep>
```

### PRT Registration Quick Reference

| PRT Field | Description | Values |
|-----------|-------------|--------|
| Message | SDK message name | Create, Update, Delete, Retrieve, etc. |
| Primary Entity | Target entity | e.g., account, contact |
| Secondary Entity | Related entity (Associate/Disassociate) | e.g., contact |
| Filtering Attributes | Columns that trigger Update | Comma-separated logical names |
| Stage | Pipeline stage | 10, 20, 40 |
| Execution Mode | Sync or Async | Synchronous, Asynchronous |
| Execution Order | Rank among same-stage plugins | Integer (lower = first) |
| Unsecure Configuration | Plain-text config string | Visible to all users |
| Secure Configuration | Encrypted config string | Visible to System Admins only |
| Image Type | Pre, Post, or Both | Pre-Image, Post-Image |
| Image Name / Alias | Name to retrieve in code | e.g., "PreImage" |
| Image Attributes | Columns included in image | Comma-separated logical names |
