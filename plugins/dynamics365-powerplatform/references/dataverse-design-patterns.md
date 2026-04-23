# Dataverse Design Patterns Reference — Dynamics 365 CE / Power Platform

> Proven patterns for table design, security, plugin pipeline, integration and performance inside Dataverse.
> Use this reference to make consistent architectural decisions across all projects.

---

## 1. Table Design Patterns

### 1.1 When to Use Custom Tables vs Extend OOB

| Scenario | Recommendation |
|---|---|
| Data maps cleanly to an existing OOB entity (Account, Contact, Case, Opportunity…) | **Extend OOB** — add custom columns; never recreate the entity |
| Data is a new business concept with no OOB equivalent | **Create a custom table** |
| You need the Activity timeline (emails, tasks, phone calls) | **Create an Activity table** (`IsActivity = true`) |
| Data lives in an external system and must be queried on demand | **Virtual table** backed by a Virtual Entity Data Provider or OData |
| High-velocity write workloads (IoT telemetry, logs, event streams) | **Elastic table** (backed by Azure Cosmos DB) |

### 1.2 Activity Tables

- Set `IsActivity = true` at creation time — cannot be changed later.
- Inherits `RegardingObjectId`, subject, dates, owner and participation (From / To / CC / BCC).
- Automatically appears in the Activity timeline on related records.
- Use when the data represents something "that happened" and should be chronologically visible.

### 1.3 Virtual Tables

- Read-only by default; write-back possible with a custom data provider.
- No Dataverse storage consumed — data fetched at query time.
- Supported OData v4 endpoints or custom data providers via plugin.
- Limitations: no audit, no business rules on the server, no real-time workflows.

### 1.4 Elastic Tables

- Backed by Azure Cosmos DB; horizontally scalable.
- Support JSON columns for semi-structured payloads.
- Best for append-heavy, high-throughput data that does not require relational joins.
- Accessible via Dataverse SDK and Web API (with some limitations on query operators).

---

## 2. Relationship Patterns

### 2.1 Self-Referential Lookups

A table with a lookup to itself to model hierarchies.

```
crXXX_Category
  └── crXXX_ParentCategoryId  →  crXXX_Category
```

- Enable **Hierarchy Settings** on the table to get hierarchy visualisations and `Under` / `Above` operators in Advanced Find.
- Set cascade rules carefully to avoid infinite loops on delete.

### 2.2 Polymorphic Lookups (Customer / Regarding)

Dataverse supports lookups that can point to **more than one table type**.

| Polymorphic Type | Points To | Usage |
|---|---|---|
| `Customer` | Account **or** Contact | Built-in on OOB entities; cannot be added to custom tables via UI (SDK only) |
| `Regarding` | Any entity enabled for activities | Links activities to their parent record |
| Custom polymorphic | Multiple specified tables | Create via SDK `LookupAttributeMetadata` with multiple `Targets` |

- At runtime, always check the `LogicalName` of the `EntityReference` to know which table the lookup points to.

### 2.3 Cascade Behaviours

| Behaviour | Meaning |
|---|---|
| `Cascade All` | Action propagates to all related child records |
| `Cascade Active` | Propagates only to active child records |
| `Cascade User-Owned` | Propagates only to children owned by the same user |
| `Cascade None` | No propagation |
| `Remove Link` | Sets the lookup to null on children (for Delete) |
| `Restrict` | Prevents the action if children exist |

**Best practices:**

- Default to `Remove Link` or `Restrict` for delete to prevent accidental data loss.
- Use `Cascade None` for Assign / Share unless business rules explicitly require propagation.
- Avoid `Cascade All` on Delete for tables with large child record counts — triggers serial plugin execution and can cause timeouts.

### 2.4 Connection Roles

- Use when the relationship type between two records is **dynamic or user-defined** (e.g., "Mentor → Mentee", "Vendor → Subcontractor").
- Connection roles do not create schema-level relationships; they are data-level links.
- Good for social / relationship mapping scenarios.

---

## 3. Column Design Patterns

### 3.1 Choice vs Boolean

| Use Case | Column Type |
|---|---|
| Two mutually exclusive options with no chance of expansion | **Boolean** (Yes/No) |
| Two or more options, or a two-option set that may grow | **Choice (OptionSet)** |
| Multi-select values | **Multi-Select Choice** |

- Prefer **global choices** for values reused across tables (e.g., Priority, Country).
- Prefer **local choices** for values unique to one column on one table.

### 3.2 Calculated vs Rollup Fields

| Feature | Calculated Field | Rollup Field |
|---|---|---|
| Evaluated | Real-time on read | Asynchronously on a schedule (every 1 hour by default) + on-demand |
| Source | Columns on the same record or direct parent (via lookup) | Aggregate of child records (SUM, COUNT, MIN, MAX, AVG) |
| Performance impact | Minimal (computed at retrieval) | Low (async job); stale for up to 1 hour |
| Use when | Deriving a value from the current record | Aggregating child data (e.g., total amount, count of related tasks) |

### 3.3 File and Image Columns

- **File column**: up to 10 GB per file. Stored in Azure Blob (managed by the platform).
- **Image column**: primary image shown in views and forms. 144×144 px thumbnail auto-generated.
- Use `RetrieveMultiple` with `$select` to avoid downloading large binaries unnecessarily.
- For bulk document management, consider SharePoint integration instead of file columns.

### 3.4 Auto-Number Columns

- Defined with a format string: `{SEQNUM:6}`, `{DATETIMEUTC:yyyyMMdd}`, `{RANDSTRING:4}`.
- Sequence guaranteed unique per environment; not guaranteed sequential after deletes.
- Example: `TKT-{SEQNUM:6}` → `TKT-000001`, `TKT-000002`.
- Seed value can be reset via the SDK.

---

## 4. Security Model Patterns

### 4.1 Business Unit Hierarchy

```
Root BU (Org)
├── Region North
│   ├── Office A
│   └── Office B
└── Region South
    └── Office C
```

- Every user belongs to exactly one Business Unit.
- Record ownership determines base access; BU hierarchy controls "roll-up" visibility.
- Use the fewest BUs necessary — deeply nested hierarchies complicate administration.

### 4.2 Team-Based Security

| Team Type | Use Case |
|---|---|
| **Owner team** | Owns records; has security roles assigned directly. Used when records belong to a group rather than an individual. |
| **Access team** | Does not own records; grants ad-hoc access to individual records via access team templates. |
| **Azure AD Group team** | Membership synced from Azure AD; can act as owner or access team. Ideal for large, dynamic groups. |

### 4.3 Field-Level Security (FLS)

- Protects individual columns (e.g., salary, SSN) regardless of entity-level permissions.
- Requires a **Field Security Profile** assigned to users or teams.
- Secured fields return `null` for users without Read permission — plan UI accordingly.
- Performance: FLS adds a small overhead per query; apply selectively.

### 4.4 Sharing Rules

- Use `GrantAccessRequest` / `RevokeAccessRequest` to share individual records.
- Excessive sharing creates entries in the `PrincipalObjectAccess` (POA) table and can degrade performance.
- Prefer team-based ownership or BU restructuring over mass sharing when possible.

### 4.5 Access Team Templates

- Configure on the table definition (enable Access Teams).
- Users are added to the auto-created team record via a sub-grid on the form.
- Access Team members receive the privileges defined in the template (Read, Write, Append, etc.).
- Ideal for record-by-record collaboration (e.g., case team, deal team).

---

## 5. Plugin Pipeline Patterns

### 5.1 Stage Selection Guide

| Stage | Pipeline Event | Transaction | Best For |
|---|---|---|---|
| **Pre-Validation (10)** | Before platform validation | Outside main DB transaction | Lightweight validation, cancel operation early |
| **Pre-Operation (20)** | After validation, before DB write | Inside main DB transaction | Modify data before save, enrich fields |
| **Post-Operation (40)** | After DB write | Inside main DB transaction (sync) / Outside (async) | Create related records, send notifications, audit logging |

### 5.2 Sync vs Async Execution

| Mode | Transaction | User Experience | Use When |
|---|---|---|---|
| **Synchronous** | Shares the platform transaction | Blocks the user until completion | Validations, field enrichment, must-succeed operations |
| **Asynchronous** | Runs in a separate System Job | User is not blocked | Notifications, integrations, heavy processing |

### 5.3 Plugin Images (Pre-Image / Post-Image)

| Image | Available In | Contains | Use When |
|---|---|---|---|
| **Pre-Image** | Pre-Operation, Post-Operation | Field values **before** the change | Comparing old vs new values (change detection) |
| **Post-Image** | Post-Operation only | Field values **after** the change | Reading the final state of the record after save |

- Register only the attributes you need in the image to minimise overhead.
- Images are snapshots; modifying them has no effect on the database.

### 5.4 Execution Context Depth

- Every plugin invocation has a `Depth` property starting at 1.
- Child plugins triggered by the same transaction increment the depth.
- **Guard against infinite loops:** check `context.Depth` and exit if it exceeds a safe threshold (commonly 2 or 3).

```csharp
if (context.Depth > 2)
    return; // prevent cascading re-entry
```

### 5.5 Transaction Handling

- Pre-Operation and synchronous Post-Operation share the platform transaction — an unhandled exception rolls back the entire operation.
- **Never open your own `TransactionScope`** inside a plugin; it conflicts with the platform transaction.
- For operations that must not roll back the main record, move them to an async Post-Operation step.

---

## 6. Custom API Patterns

### 6.1 When to Use What

| Mechanism | Bound to Entity | Supports Plugins | Available via Web API | Use When |
|---|---|---|---|---|
| **Custom API** | Optional (bound or global) | Yes | Yes (`/api/data/v9.x/…`) | Preferred for new development; full SDK support |
| **Custom Action (Process)** | Optional | Yes | Yes | Legacy; still valid but Custom APIs are recommended |
| **Custom Process Action** | Always bound | Through workflow | Yes | Simple automation tied to a single entity |

### 6.2 Bound vs Global

- **Bound**: scoped to an entity — appears as an action on that entity's Web API endpoint. Use when the operation is inherently about one record or entity type.
- **Global**: not tied to any entity — appears under `/api/data/v9.x/<MessageName>`. Use for cross-entity or system-level operations.

### 6.3 Request / Response Parameters

- Define parameters with clear names and types in the Custom API definition.
- Use `Entity`, `EntityCollection`, `String`, `Boolean`, `DateTime`, `Decimal`, `Float`, `Guid`, `Integer`, `Money`, `Picklist`, `StringArray`, `EntityReference`.
- Always validate input parameters in the plugin implementation.

---

## 7. Integration Patterns

### 7.1 Pattern Selection Matrix

| Pattern | Direction | Latency | Best For |
|---|---|---|---|
| **Sync Plugin** | Outbound (within transaction) | < 2 s required | Enrichment from external system before save |
| **Async Plugin** | Outbound (after transaction) | Seconds to minutes | Fire-and-forget notifications, logging |
| **Webhook** | Outbound push | Near real-time | Lightweight HTTP POST to external endpoints |
| **Azure Service Bus** | Outbound pub/sub | Near real-time | Decoupled messaging, multiple subscribers |
| **Azure Functions** | Either | Variable | Complex transformations, orchestrations |
| **Power Automate** | Either | Seconds to minutes | Citizen-developer integrations, approval flows |
| **Logic Apps** | Either | Seconds to minutes | Enterprise connectors (SAP, Salesforce, etc.) |
| **Virtual Tables** | Inbound (query) | On-demand | Read/write against external REST/OData sources |

### 7.2 Webhooks

- Registered on a plugin step; Dataverse POSTs the execution context JSON to the URL.
- Supports authentication headers (HttpHeader, WebhookKey, HttpQueryString).
- Synchronous delivery — endpoint must respond within 60 seconds.
- Failed webhooks retry automatically with exponential backoff.

### 7.3 Azure Service Bus

- Supports **Queues**, **Topics / Subscriptions**, and **Event Hubs** (via Relay).
- Message format: `RemoteExecutionContext` serialised as JSON or XML.
- Use **Topics** when multiple consumers need the same event.
- Pair with Azure Functions or Logic Apps as subscribers.

### 7.4 Azure Functions Integration

- Use as webhook listeners or Service Bus subscribers.
- Can call back into Dataverse via the SDK (`ServiceClient`) or Web API.
- For complex multi-step processing, combine with Durable Functions orchestrations.
- Secure credentials with Azure Key Vault; reference via App Settings.

### 7.5 Virtual Tables for External Data

- Map external OData v4 feeds to Dataverse tables without data copy.
- Custom data providers (via plugin) enable non-OData backends.
- Virtual tables participate in views, dashboards, model-driven apps, and security.
- Avoid for high-frequency queries against slow external endpoints — cache externally if needed.

---

## 8. Data Migration Patterns

### 8.1 Import Maps / Data Import Wizard

- Best for one-time or periodic CSV / XML imports by power users.
- Supports basic field mapping and lookup resolution.
- Limited to ~100 K rows per import file; split larger files.

### 8.2 SDK-Based Migration

- Use `ExecuteMultipleRequest` or `CreateMultipleRequest` (bulk API) for large volumes.
- Process in batches of 1,000 records (Dataverse recommended maximum per batch).
- Run from an external console app or Azure Function; authenticate with Application User (client credentials).
- Log errors per record for retry / remediation.

### 8.3 Alternate Keys for Upsert

- Define an **alternate key** on the target table (e.g., external system ID).
- Use `UpsertRequest` — Dataverse creates or updates based on key match.
- Avoids the "retrieve then decide" anti-pattern; single round-trip per record.

```csharp
var entity = new Entity("crXXX_projecttask");
entity.KeyAttributes["crXXX_externalid"] = "EXT-00042";
entity["crXXX_name"] = "Updated Task Name";

var upsert = new UpsertRequest { Target = entity };
var response = (UpsertResponse)service.Execute(upsert);
bool wasCreated = response.RecordCreated;
```

### 8.4 Migration Sequence

1. **Reference / Configuration data** (Choices, Business Units, Teams, Security Roles)
2. **Master data** (Accounts, Contacts, Products)
3. **Transactional data** (Opportunities, Cases, Activities)
4. **Relationship links** (Connections, N:N intersect records)

Always disable plugins and flows on target tables during bulk migration to avoid side-effects and improve throughput.

---

## 9. Performance Patterns

### 9.1 Index Management

- Dataverse auto-indexes primary key, lookup columns, and status/state.
- Request custom indexes through a **Microsoft support ticket** for heavily queried custom columns.
- Avoid queries with leading wildcards (`LIKE '%value'`) — they cannot use indexes.

### 9.2 Query Optimisation

#### QueryExpression

```csharp
var query = new QueryExpression("account")
{
    ColumnSet = new ColumnSet("name", "revenue"), // Only select needed columns
    Criteria = new FilterExpression(LogicalOperator.And)
    {
        Conditions =
        {
            new ConditionExpression("statecode", ConditionOperator.Equal, 0),
            new ConditionExpression("revenue", ConditionOperator.GreaterThan, 1_000_000)
        }
    },
    TopCount = 50 // Limit result set
};
```

#### FetchXML

```xml
<fetch top="50">
  <entity name="account">
    <attribute name="name" />
    <attribute name="revenue" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="revenue" operator="gt" value="1000000" />
    </filter>
  </entity>
</fetch>
```

**Rules of thumb:**

- Always specify a `ColumnSet` — never use `new ColumnSet(true)` (all columns) in production code.
- Use `TopCount` or `fetch top` to limit rows.
- Filter early — push conditions into the query rather than filtering in code.
- Avoid `RetrieveMultiple` in a loop; use a single query with `In` condition or use `FetchXML` with link-entity joins.

### 9.3 Batch Operations

| API | Records / Batch | Transactional | Use When |
|---|---|---|---|
| `ExecuteMultipleRequest` | Up to 1,000 | Optional (`ContinueOnError`) | Mixed message types in one batch |
| `CreateMultipleRequest` | Up to 1,000 | Yes (all or nothing) | Bulk create of a single entity type |
| `UpdateMultipleRequest` | Up to 1,000 | Yes | Bulk update of a single entity type |
| `UpsertMultipleRequest` | Up to 1,000 | Yes | Bulk upsert with alternate keys |

- Set `ContinueOnError = true` on `ExecuteMultiple` to avoid one bad record aborting the entire batch.
- Process batches in parallel (3-5 concurrent threads is a safe starting point) with the recommended `ServiceClient`.

### 9.4 Async Processing

- Offload non-critical work to **async plugin steps** or **Power Automate flows**.
- For heavy compute, push messages to **Azure Service Bus** and process with Azure Functions.
- Use **Elastic tables** for append-heavy workloads that exceed standard table throughput.
- Monitor async system jobs in **Settings → System Jobs** for failures and backlogs.
