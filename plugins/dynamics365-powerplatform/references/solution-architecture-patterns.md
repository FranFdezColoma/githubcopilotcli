# Solution Architecture Patterns Reference — Dynamics 365 CE / Power Platform

> Decision frameworks, ALM strategy, integration architecture and governance patterns for Dynamics 365 CE / Power Platform projects.
> Use this reference when making architectural decisions about how to implement, deploy and operate solutions.

---

## 1. Solution Priority Decision Matrix

Always evaluate options in order: **OOB → Low-Code → Pro-Code**.
Choose the lowest-complexity option that fully satisfies the requirement.

### 1.1 Decision Tree

```
┌─────────────────────────────────────────────────────────┐
│  Can the requirement be met with OOB configuration?     │
│  (No code, no flows, just settings and rules)           │
├─────── YES ──────────────────── NO ─────────────────────┤
│  ✅ Use OOB                     │                       │
│                                 ▼                       │
│                   Can it be met with Low-Code?          │
│                   (Power Automate, Canvas App,          │
│                    Model-Driven customisation,          │
│                    Power Pages)                         │
│                   ├── YES ──────── NO ──────────────────┤
│                   │  ✅ Use Low-Code                    │
│                   │                 ▼                   │
│                   │    Use Pro-Code (Plugins,           │
│                   │    Custom APIs, PCF, Azure,         │
│                   │    Web Resources)                   │
│                   │    ✅ Pro-Code                      │
└─────────────────────────────────────────────────────────┘
```

### 1.2 OOB Configuration (Level 1)

Use when the platform provides the capability natively with no code.

| Capability | Examples |
|---|---|
| Business Rules | Field visibility, required/optional, default values, simple validation |
| Calculated / Rollup Fields | Derived values from the same record or aggregated from children |
| Workflows (Real-Time) | Simple field updates on record create/update |
| Classic Workflows (Background) | Scheduled or condition-based automation for simple scenarios |
| Dashboards & Charts | OOB system dashboards, interactive dashboards |
| Forms & Views | Custom forms, filtered views, quick view forms, card forms |
| Security Configuration | Roles, field security profiles, BU hierarchy |

### 1.3 Low-Code (Level 2)

Use when OOB cannot meet the requirement but no compiled code is needed.

| Technology | Best For |
|---|---|
| **Power Automate (Cloud Flows)** | Multi-step automation, approvals, integration with 600+ connectors, scheduled jobs |
| **Canvas Apps** | Custom UIs for mobile or task-specific scenarios not served by model-driven forms |
| **Model-Driven App Customisation** | Custom commands (ribbons), business process flows, site maps, custom pages |
| **Power Pages** | External-facing portals with Dataverse data, self-service scenarios |
| **AI Builder** | Document processing, prediction, text classification |
| **Power BI Embedded** | Advanced analytics and reporting inside model-driven apps |

### 1.4 Pro-Code (Level 3)

Use when low-code lacks the performance, precision, or capability required.

| Technology | Best For |
|---|---|
| **Plugins (C#)** | Synchronous transaction logic, complex validation, field enrichment within DB transaction |
| **Custom APIs** | Reusable server-side operations exposed via Web API |
| **PCF Controls** | Rich UI components not possible with standard form controls |
| **Azure Functions** | Heavy or long-running compute, external API orchestration |
| **Custom Web Resources (JS/HTML)** | Client-side form logic that exceeds Business Rule capability |
| **Azure Logic Apps** | Enterprise integration requiring B2B connectors (SAP, Oracle, EDI) |

### 1.5 Decision Criteria Summary

| Criterion | OOB | Low-Code | Pro-Code |
|---|---|---|---|
| Development speed | ★★★★★ | ★★★★ | ★★★ |
| Maintainability (citizen dev) | ★★★★★ | ★★★★ | ★★ |
| Flexibility | ★★ | ★★★ | ★★★★★ |
| Performance ceiling | ★★★ | ★★★ | ★★★★★ |
| Transactional integrity | ★★★★ | ★★ | ★★★★★ |
| ALM complexity | ★ | ★★ | ★★★★ |
| Requires professional developer | No | Rarely | Yes |

---

## 2. ALM (Application Lifecycle Management) Patterns

### 2.1 Solution Layering

Dataverse resolves component definitions by **merging layers** from bottom to top:

```
┌──────────────────────────────────┐  ← Active / unmanaged layer (dev only)
├──────────────────────────────────┤
│  Managed Solution C (top)        │  ← Highest priority
├──────────────────────────────────┤
│  Managed Solution B              │
├──────────────────────────────────┤
│  Managed Solution A              │
├──────────────────────────────────┤
│  System (OOB) Layer              │  ← Base platform
└──────────────────────────────────┘
```

- Higher layers override lower layers for the same component.
- When a managed solution is removed, the next layer down is re-exposed.
- **Never** have unmanaged customisations (active layer) in production — all changes should arrive via managed solutions.

### 2.2 Managed vs Unmanaged Strategy

| Environment | Solution Type | Rationale |
|---|---|---|
| Development | **Unmanaged** | Allows editing of components |
| Build / CI | Export as **Managed** | Lock components for downstream environments |
| Test / QA | **Managed** | Immutable; testing reflects production behaviour |
| UAT | **Managed** | Stakeholder acceptance on production-like environment |
| Production | **Managed** | Immutable; only updatable via solution upgrade |

### 2.3 Solution Segmentation

Split by domain or layer to reduce merge conflicts and enable independent release cadences.

```
Publisher: contso

contso_CoreModel          → Tables, columns, relationships
contso_CoreSecurity       → Security roles, field security profiles
contso_CorePlugins        → Plugin assemblies and step registrations
contso_SalesUI            → Model-driven app, forms, views, site map
contso_SalesAutomation    → Flows, business process flows, custom APIs
contso_SalesIntegration   → Webhooks, Service Bus registrations, env variables
contso_SalesReporting     → Dashboards, charts, Power BI embedded
```

### 2.4 Patch Solutions

- Use for **minor, incremental** changes to a parent solution.
- Patches reduce deployment size — only changed components are included.
- Patches are applied on top of the parent solution; they must be cloned back into the parent before the next major release.
- **Limitation:** patches cannot remove components; only add or modify.

### 2.5 CI/CD with Azure DevOps and Power Platform CLI

#### Pipeline Stages

```
┌─────────┐    ┌──────────┐    ┌─────────┐    ┌──────────┐    ┌─────────────┐
│   Dev   │───▶│  Build   │───▶│  Test   │───▶│   UAT    │───▶│ Production  │
│  (unm.) │    │ (export  │    │ (import  │    │ (import  │    │ (import     │
│         │    │  as mgd) │    │  managed)│    │  managed)│    │  managed)   │
└─────────┘    └──────────┘    └─────────┘    └──────────┘    └─────────────┘
```

#### Key CLI Commands

```bash
# Export unmanaged solution from Dev
pac solution export --path ./solutions/SalesCore.zip --name contso_SalesCore

# Unpack for source control
pac solution unpack --zipfile ./solutions/SalesCore.zip --folder ./src/SalesCore --processCanvasApps

# Pack as managed for deployment
pac solution pack --folder ./src/SalesCore --zipfile ./build/SalesCore_managed.zip --packagetype Managed

# Import managed into target
pac solution import --path ./build/SalesCore_managed.zip --activate-plugins
```

#### Solution Checker Integration

```bash
# Run solution checker before deployment
pac solution check --path ./build/SalesCore_managed.zip --outputDirectory ./reports
```

- Fail the pipeline on **Critical** or **High** severity findings.
- Store solution source (unpacked) in Git — enables diff, PR review and branch strategy.

---

## 3. Integration Architecture

### 3.1 Pattern Selection Guide

| Requirement | Recommended Pattern |
|---|---|
| Validation or enrichment **within** the save transaction | **Sync Plugin** |
| Fire-and-forget notification after save | **Async Plugin** or **Webhook** |
| Near-real-time push to an external HTTP endpoint | **Webhook** |
| Decoupled pub/sub with multiple consumers | **Azure Service Bus** + subscribers |
| Complex orchestration, retries, fan-out | **Azure Durable Functions** |
| Citizen-developer integration with SaaS connectors | **Power Automate** |
| Enterprise B2B integration (SAP, EDI, Oracle) | **Azure Logic Apps** |
| Query external data on demand without copying | **Virtual Tables** |
| Scheduled batch sync | **Azure Functions** on timer trigger or **Power Automate** scheduled flow |

### 3.2 Sync Plugin Integration (Within Transaction)

```
User saves record
  → Pre-Operation plugin fires
  → Plugin calls external API (< 2 sec)
  → Enriches entity attributes
  → Platform writes to DB
```

**Constraints:**

- External call must complete within the 2-minute plugin timeout (aim for < 2 seconds).
- Network failures block the user and roll back the transaction.
- Use only when the data is essential before save (e.g., tax calculation, address validation).

### 3.3 Async Plugin + Azure Service Bus

```
User saves record
  → Platform writes to DB
  → Post-Operation Async plugin fires
  → Plugin posts message to Service Bus Topic
  → Subscriber A (Azure Function) processes message
  → Subscriber B (Logic App) processes message
```

**Benefits:**

- Non-blocking; user experience unaffected.
- Multiple consumers; add/remove subscribers without changing Dataverse.
- Built-in retry, dead-letter queue, message ordering.

### 3.4 Webhook Pattern

```
User saves record
  → Platform writes to DB
  → Dataverse POSTs execution context to registered URL
  → External service processes payload and responds 2xx
```

- Synchronous delivery (blocks async system job until response).
- Max 60-second response timeout.
- Authenticate via `HttpHeader` or `WebhookKey`.

### 3.5 Power Automate Integration

```
Dataverse trigger (When a row is added, modified or deleted)
  → Flow executes actions
  → Connectors talk to external systems
```

- Easiest to build; no compiled code.
- Throttling limits apply (100,000 actions/day on per-flow basis varies by licence).
- Use for citizen-developer-maintainable integrations; avoid for performance-critical paths.

---

## 4. Multi-Environment Strategy

### 4.1 Environment Topology

```
┌─────────────────────────────────────────────────────────────┐
│  Developer sandboxes (per-developer or shared)              │
├──────────────────────┬──────────────────────────────────────┤
│  Development (shared)│  Integration (optional)              │
├──────────────────────┴──────────────────────────────────────┤
│  Test / QA                                                  │
├─────────────────────────────────────────────────────────────┤
│  UAT / Staging                                              │
├─────────────────────────────────────────────────────────────┤
│  Production                                                 │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Environment Variables

- Store environment-specific configuration (URLs, feature flags, keys) as **Dataverse Environment Variables**.
- Define the variable in the solution; set the **Current Value** per environment.
- In plugins: retrieve via `EnvironmentVariableDefinition` + `EnvironmentVariableValue` entities.
- In Power Automate: use the **Environment Variable** dynamic content.

### 4.3 Connection References

- Define **Connection References** inside the solution for every connector used by flows.
- During managed solution import, the administrator maps each reference to an existing connection.
- Avoids hard-coded user credentials per environment.

### 4.4 Promotion Flow

```
Dev  ──export unmanaged──▶  Build Pipeline  ──pack managed──▶  Test
                                                                │
                                                         run automated tests
                                                                │
                                                                ▼
                                                              UAT
                                                                │
                                                         stakeholder sign-off
                                                                │
                                                                ▼
                                                           Production
```

---

## 5. Scalability Patterns

### 5.1 Async Processing

- Move non-essential logic from sync plugins to async steps or Power Automate.
- Async system jobs are processed by the Async Service with configurable concurrency.

### 5.2 Batch Operations

- Use `CreateMultiple`, `UpdateMultiple`, `UpsertMultiple` for bulk data operations.
- Process in batches of 1,000 records; parallelise with 3-5 concurrent threads.
- Prefer **Application User** (S2S) authentication for server-to-server batch jobs.

### 5.3 Elastic Tables

- Use for IoT telemetry, event logs, sensor data, or any scenario exceeding ~100 writes/second.
- Backed by Cosmos DB; auto-scales horizontally.
- Supports partitioning by a custom partition key.

### 5.4 Azure Offloading

- Offload heavy compute (PDF generation, ML inference, complex transformations) to Azure Functions.
- Use Service Bus or Event Grid as the trigger mechanism.
- Return results to Dataverse via SDK callback or webhook.

---

## 6. Error Handling Architecture

### 6.1 Plugin Error Handling

#### Layered Pattern

```csharp
public void Execute(IServiceProvider serviceProvider)
{
    var tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
    var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

    try
    {
        tracingService.Trace("Plugin started. Entity: {0}, Message: {1}", context.PrimaryEntityName, context.MessageName);
        // --- Business logic ---
        ExecuteBusinessLogic(serviceProvider);
    }
    catch (InvalidPluginExecutionException)
    {
        throw; // Already a user-friendly error — re-throw as-is
    }
    catch (Exception ex)
    {
        tracingService.Trace("Unhandled exception: {0}", ex.ToString());
        throw new InvalidPluginExecutionException(
            $"An unexpected error occurred in {GetType().Name}. Correlation: {context.CorrelationId}",
            ex);
    }
}
```

**Rules:**

- Always wrap in try/catch at the top level.
- Use `InvalidPluginExecutionException` for user-facing messages.
- Log the full exception (including stack trace) to the Tracing Service.
- Include the correlation ID in error messages for supportability.

### 6.2 Power Automate Error Handling (Try-Catch-Finally)

```
Scope: Try
  ├── Action 1
  ├── Action 2
  └── Action 3

Scope: Catch (Configure Run After: has failed, has timed out)
  ├── Log error details (compose Run() outputs)
  ├── Send notification email
  └── Update record status to "Error"

Scope: Finally (Configure Run After: is successful, has failed, is skipped, has timed out)
  └── Clean-up actions
```

- Wrap main logic in a **Try** scope.
- Add a **Catch** scope that runs after failure/timeout of the Try scope.
- Add a **Finally** scope that always runs (configure all "Run After" options).
- Log the error object: `outputs('Failing_Action_Name')?['body']` and `actions('Failing_Action_Name')?['error']`.

### 6.3 Structured Logging Patterns

| Platform | Logging Target | Pattern |
|---|---|---|
| Plugin (C#) | ITracingService | `tracingService.Trace("Step {0}: {1}", stepName, detail)` |
| Plugin (C#) | Custom Log Table | Create `crXXX_PluginLog` record for persistent audit |
| Power Automate | Flow Run History | Built-in; add Compose actions for debug data |
| Power Automate | Custom Log Table | Create a row in `crXXX_IntegrationLog` on failure |
| Azure Functions | Application Insights | `ILogger.LogInformation(...)`, `ILogger.LogError(...)` |
| Web Resources (JS) | Console + Custom API | `console.error(...)` + POST to a Custom API for server-side logging |

---

## 7. Governance

### 7.1 Center of Excellence (CoE) Toolkit

Microsoft's CoE Starter Kit provides:

- **Inventory dashboards** — all apps, flows, connectors, makers across the tenant.
- **Compliance flows** — auto-notify makers of policy violations.
- **Nurture components** — training, community hub, app catalogues.
- **Audit logs** — Power Platform audit events pushed to a Dataverse table.

Install the CoE Kit in a dedicated **admin environment** separate from project environments.

### 7.2 Data Loss Prevention (DLP) Policies

| Group | Description | Example Connectors |
|---|---|---|
| **Business** | Connectors allowed to share data with each other | Dataverse, SharePoint, Office 365, Outlook |
| **Non-Business** | Connectors allowed to share data with each other but NOT with Business group | Twitter, Dropbox, custom connectors |
| **Blocked** | Connectors that cannot be used at all | As defined by policy |

**Rules:**

- Apply DLP at the **tenant** level for baseline protection.
- Create **environment-level** DLP overrides for project-specific needs.
- Review custom connectors — they are unclassified by default and fall into Non-Business.

### 7.3 Solution Checker Rules

Run the Solution Checker on every build. Key rule categories:

| Category | Examples |
|---|---|
| **Performance** | Avoid `RetrieveMultiple` inside loops, avoid `ColumnSet(true)` |
| **Security** | Do not hard-code credentials, use environment variables |
| **Maintainability** | Remove unused web resources, avoid deprecated APIs |
| **Supportability** | Plugin assemblies must be signed, workflows should not have infinite loops |
| **Online Migration Readiness** | No unsupported customisations for online deployment |

- **Critical / High** findings block deployment.
- **Medium / Low** findings are tracked as technical debt in the backlog.

### 7.4 Branching Strategy for Solutions

```
main (protected)
  │
  ├── release/1.0   ← stabilisation branch for release 1.0
  │
  ├── feature/PROJ-123-new-entity
  │     └── developer works, exports solution, unpacks, commits
  │
  └── feature/PROJ-456-plugin-update
        └── developer works, exports solution, unpacks, commits

PR from feature → main triggers:
  1. Solution pack (managed)
  2. Solution Checker
  3. Automated tests
  4. Deploy to Test environment
```

- Store the **unpacked solution** in Git (output of `pac solution unpack`).
- Each feature branch corresponds to a user story / work item.
- Pull Requests require Solution Checker pass and at least one reviewer.
