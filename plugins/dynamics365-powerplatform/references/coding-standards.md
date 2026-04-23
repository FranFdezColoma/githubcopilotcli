# Coding Standards Reference — Dynamics 365 CE / Power Platform

> Mandatory coding standards for every language and framework used in Dynamics 365 CE / Power Platform projects.
> All code produced by developers, agents and skills **must** comply with these standards.

---

## 1. General Principles

These principles apply to **all languages** (C#, JavaScript, TypeScript, Python, PowerShell, etc.).

### 1.1 Readability First

Code is read far more often than it is written. Prefer clarity over cleverness.

- Use descriptive, intention-revealing names for variables, methods and classes.
- Keep functions short — a function should do **one thing**.
- Limit line length to 120 characters where practical.

### 1.2 SOLID Principles

| Principle | Meaning | Practical Guidance |
|---|---|---|
| **S** — Single Responsibility | A class/function has one reason to change | One plugin class = one message + one entity |
| **O** — Open/Closed | Open for extension, closed for modification | Use strategy/template patterns; avoid giant `if/else` trees |
| **L** — Liskov Substitution | Subtypes must be substitutable for their base types | Honour interface contracts |
| **I** — Interface Segregation | Prefer small, focused interfaces | Split `IOrderService` from `IOrderReportService` |
| **D** — Dependency Inversion | Depend on abstractions, not concretions | Inject `IOrganizationService`, not `OrganizationServiceProxy` |

### 1.3 DRY — Don't Repeat Yourself

Extract reusable logic into services, helper methods or shared components.
If the same block of code exists in three or more places, refactor it.

### 1.4 YAGNI — You Aren't Gonna Need It

Do not build speculative abstractions or features that are not part of the current requirement.
Add complexity only when the requirement demands it.

### 1.5 KISS — Keep It Simple

The simplest correct solution is the preferred solution.
Complexity must justify itself with a clear benefit.

### 1.6 Fail Fast

Validate inputs at the boundary of every public method.
Raise descriptive exceptions immediately — do not let invalid data propagate silently.

### 1.7 Self-Documenting Code

- Names explain **what** the code does.
- Comments explain **why** a decision was made (business rule, performance trade-off, workaround).
- Do **not** comment obvious code (`// increment counter` above `i++`).

---

## 2. C# Standards — Dynamics 365 Plugins

### 2.1 Project Setup

| Setting | Value |
|---|---|
| Target Framework | **.NET Framework 4.7.1** (required by Dataverse sandbox) |
| Output Type | Class Library |
| Assembly Signing | **Required** — sign with a strong-name key (.snk) |

### 2.2 Required NuGet Packages

```xml
<PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.*" />
```

> Use the latest `9.0.2.x` patch. Do **not** reference `Microsoft.Xrm.Sdk.Workflow` unless building Custom Workflow Activities.

### 2.3 Plugin Class Structure

```csharp
using System;
using Microsoft.Xrm.Sdk;

namespace Contoso.Crm.Plugins.Sales
{
    /// <summary>
    /// Validates that the Account's credit limit does not exceed the corporate maximum
    /// before the record is saved.
    /// </summary>
    public sealed class ValidateAccountCreditLimit : IPlugin
    {
        private readonly string _unsecureConfig;
        private readonly string _secureConfig;

        public ValidateAccountCreditLimit(string unsecureConfig, string secureConfig)
        {
            _unsecureConfig = unsecureConfig;
            _secureConfig = secureConfig;
        }

        public void Execute(IServiceProvider serviceProvider)
        {
            // 1. Obtain services
            var tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            try
            {
                tracingService.Trace("ValidateAccountCreditLimit started. Depth: {0}", context.Depth);

                // 2. Guard: prevent infinite loops
                if (context.Depth > 2) return;

                // 3. Extract target entity
                if (!context.InputParameters.Contains("Target") ||
                    !(context.InputParameters["Target"] is Entity target))
                    return;

                // 4. Business logic
                ExecuteValidation(target, service, tracingService);

                tracingService.Trace("ValidateAccountCreditLimit completed successfully.");
            }
            catch (InvalidPluginExecutionException)
            {
                throw; // User-friendly message — re-throw as-is
            }
            catch (Exception ex)
            {
                tracingService.Trace("Unhandled error: {0}", ex.ToString());
                throw new InvalidPluginExecutionException(
                    $"An error occurred in ValidateAccountCreditLimit. Correlation: {context.CorrelationId}", ex);
            }
        }

        private void ExecuteValidation(Entity target, IOrganizationService service, ITracingService trace)
        {
            // Implementation here
        }
    }
}
```

#### Key rules

| Rule | Detail |
|---|---|
| `sealed class` | Plugin classes must be `sealed` — Dataverse does not support inheritance chains for plugins |
| Constructor | Accept `(string unsecureConfig, string secureConfig)` even if unused — required signature for registration |
| `IPlugin.Execute` | Single entry point; obtain all services from `IServiceProvider` |
| No static mutable state | Plugins may be cached and reused — never store instance state across executions |

### 2.4 Early-Bound vs Late-Bound Entity Access

| Approach | When to Use | Example |
|---|---|---|
| **Early-bound** | Business logic with many typed attributes; compile-time safety | `var account = target.ToEntity<Account>(); var name = account.Name;` |
| **Late-bound** | Generic/reusable plugins, dynamic attribute access | `var name = target.GetAttributeValue<string>("name");` |

- Generate early-bound classes with `pac modelbuilder build` or `CrmSvcUtil.exe`.
- Store generated files in a dedicated `Entities/` folder. Regenerate as part of the build pipeline.

### 2.5 IOrganizationService Usage Patterns

```csharp
// CREATE
Guid id = service.Create(entity);

// RETRIEVE (only needed columns)
Entity record = service.Retrieve("account", id, new ColumnSet("name", "revenue"));

// UPDATE (include only changed attributes)
var update = new Entity("account", id);
update["name"] = "Updated Name";
service.Update(update);

// DELETE
service.Delete("account", id);

// EXECUTE (for specialised messages)
var response = (AssignResponse)service.Execute(new AssignRequest
{
    Assignee = new EntityReference("systemuser", userId),
    Target = new EntityReference("account", id)
});
```

> **Never** pass `new ColumnSet(true)` in production. Always specify the exact columns needed.

### 2.6 ITracingService for Logging

```csharp
tracingService.Trace("Starting credit limit validation for Account {0}", accountId);
tracingService.Trace("Current credit limit: {0}, Maximum allowed: {1}", currentLimit, maxLimit);
```

- Trace output is available in the **Plugin Trace Log** entity when tracing is enabled in the environment.
- Use structured messages with placeholders (not string concatenation) for readability.
- Trace at entry, exit, and key decision points.

### 2.7 Exception Handling

| Exception Type | Purpose |
|---|---|
| `InvalidPluginExecutionException` | Shows the message to the user in the UI. Use for **business rule violations**. |
| `Exception` (general) | Catch, log via Tracing Service, then wrap in `InvalidPluginExecutionException` with a user-friendly message and the original as inner exception. |

```csharp
throw new InvalidPluginExecutionException(
    "The credit limit cannot exceed $1,000,000. Please contact your manager for approval.");
```

### 2.8 No External HTTP Calls in Sync Plugins

- **Synchronous** plugins run inside the platform transaction. External HTTP calls introduce unpredictable latency and can cause timeouts.
- If external data is required during a sync step, consider caching the data in a Dataverse table updated by an async process.
- If an external call is absolutely necessary, use a **Pre-Validation** step (outside the main transaction) or move to an async step.

### 2.9 Plugin Registration Best Practices

| Aspect | Guidance |
|---|---|
| Filtering Attributes | Register only the attributes the plugin cares about — avoids unnecessary executions |
| Images | Register Pre/Post images with only needed attributes |
| Execution Order | Set explicit order when multiple plugins exist on the same step |
| Isolation Mode | Always **Sandbox** for online deployments |
| Assembly Location | **Database** (not disk or GAC) for Dataverse Online |

---

## 3. C# Test Standards

### 3.1 Project Setup

| Setting | Value |
|---|---|
| Target Framework | **.NET Framework 4.7.1** |
| Test Framework | MSTest v2 |

### 3.2 Required NuGet Packages

```xml
<PackageReference Include="Microsoft.CrmSdk.CoreAssemblies" Version="9.0.2.*" />
<PackageReference Include="MSTest.TestFramework" Version="2.2.10" />
<PackageReference Include="MSTest.TestAdapter" Version="2.2.10" />
<PackageReference Include="Moq" Version="4.20.72" />
<PackageReference Include="Castle.Core" Version="5.1.1" />
```

### 3.3 Test Naming Convention

```
MethodName_Scenario_ExpectedResult
```

Examples:

```csharp
[TestMethod]
public void Execute_CreditLimitExceedsMax_ThrowsInvalidPluginExecutionException() { }

[TestMethod]
public void Execute_CreditLimitWithinRange_CompletesSuccessfully() { }

[TestMethod]
public void Execute_TargetMissing_ReturnsWithoutError() { }
```

### 3.4 Arrange-Act-Assert Pattern

```csharp
[TestMethod]
public void Execute_CreditLimitExceedsMax_ThrowsInvalidPluginExecutionException()
{
    // ── Arrange ─────────────────────────────────────────────────────
    var target = new Entity("account")
    {
        ["creditlimit"] = new Money(2_000_000m)
    };

    var context = CreateMockContext("Create", target);
    var serviceProvider = CreateMockServiceProvider(context);

    var plugin = new ValidateAccountCreditLimit(null, null);

    // ── Act & Assert ────────────────────────────────────────────────
    Assert.ThrowsException<InvalidPluginExecutionException>(
        () => plugin.Execute(serviceProvider));
}
```

### 3.5 Mocking Core Services

```csharp
private IServiceProvider CreateMockServiceProvider(IPluginExecutionContext context)
{
    // Mock IOrganizationService
    var orgService = new Mock<IOrganizationService>();

    // Mock IOrganizationServiceFactory
    var factory = new Mock<IOrganizationServiceFactory>();
    factory.Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
           .Returns(orgService.Object);

    // Mock ITracingService
    var tracingService = new Mock<ITracingService>();

    // Mock IServiceProvider
    var serviceProvider = new Mock<IServiceProvider>();
    serviceProvider.Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
                   .Returns(context);
    serviceProvider.Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
                   .Returns(factory.Object);
    serviceProvider.Setup(sp => sp.GetService(typeof(ITracingService)))
                   .Returns(tracingService.Object);

    return serviceProvider.Object;
}

private IPluginExecutionContext CreateMockContext(string messageName, Entity target)
{
    var context = new Mock<IPluginExecutionContext>();
    context.Setup(c => c.MessageName).Returns(messageName);
    context.Setup(c => c.PrimaryEntityName).Returns(target.LogicalName);
    context.Setup(c => c.Depth).Returns(1);
    context.Setup(c => c.CorrelationId).Returns(Guid.NewGuid());

    var inputParameters = new ParameterCollection { { "Target", target } };
    context.Setup(c => c.InputParameters).Returns(inputParameters);

    return context.Object;
}
```

### 3.6 Test Organisation

```
Contoso.Crm.Plugins.Tests/
├── Sales/
│   ├── ValidateAccountCreditLimitTests.cs
│   └── AssignTerritoryOnCreateTests.cs
├── Service/
│   └── AutoRouteCaseTests.cs
├── Helpers/
│   ├── MockServiceProviderBuilder.cs
│   └── EntityFactory.cs
└── Contoso.Crm.Plugins.Tests.csproj
```

- Mirror the source project namespace structure.
- Extract reusable mock builders into a `Helpers/` folder.
- One test class per plugin class.

---

## 4. JavaScript Standards — Web Resources

### 4.1 Namespace Pattern

```javascript
// Always declare the namespace hierarchy
var Contoso = window.Contoso || {};
Contoso.Account = Contoso.Account || {};
Contoso.Account.FormEvents = Contoso.Account.FormEvents || {};
```

### 4.2 Form Event Handlers

```javascript
/**
 * Called when the Account main form loads.
 * @param {Xrm.Events.EventContext} executionContext
 */
Contoso.Account.FormEvents.onLoad = function (executionContext) {
    var formContext = executionContext.getFormContext();

    // Set field visibility based on account type
    var accountType = formContext.getAttribute("customertypecode").getValue();
    formContext.getControl("creditlimit").setVisible(accountType === 1);
};

/**
 * Called when the Credit Limit field changes.
 * @param {Xrm.Events.EventContext} executionContext
 */
Contoso.Account.FormEvents.onCreditLimitChange = function (executionContext) {
    var formContext = executionContext.getFormContext();
    var creditLimit = formContext.getAttribute("creditlimit").getValue();

    if (creditLimit > 1000000) {
        formContext.getControl("creditlimit").setNotification(
            "Credit limit exceeds $1,000,000. Manager approval required.", "CREDIT_LIMIT_WARNING"
        );
    } else {
        formContext.getControl("creditlimit").clearNotification("CREDIT_LIMIT_WARNING");
    }
};
```

### 4.3 Form Event Registration

Register handlers in **Form Properties** (not inline HTML events):

| Event | Function | Pass Execution Context |
|---|---|---|
| Form `OnLoad` | `Contoso.Account.FormEvents.onLoad` | ✅ Yes |
| `creditlimit` `OnChange` | `Contoso.Account.FormEvents.onCreditLimitChange` | ✅ Yes |
| Form `OnSave` | `Contoso.Account.FormEvents.onSave` | ✅ Yes |

> Always pass execution context. Never use `Xrm.Page` (deprecated) — use `formContext` obtained from `executionContext.getFormContext()`.

### 4.4 Xrm.WebApi Usage Patterns

```javascript
// Retrieve a record
Xrm.WebApi.retrieveRecord("account", accountId, "?$select=name,revenue").then(
    function (result) {
        console.log("Account name: " + result.name);
    },
    function (error) {
        Xrm.Navigation.openAlertDialog({ text: error.message });
    }
);

// Create a record
Xrm.WebApi.createRecord("task", { subject: "Follow up", regardingobjectid_account@odata.bind: "/accounts(" + accountId + ")" }).then(
    function (result) {
        console.log("Task created: " + result.id);
    },
    function (error) {
        Xrm.Navigation.openAlertDialog({ text: error.message });
    }
);

// Update a record
Xrm.WebApi.updateRecord("account", accountId, { name: "Updated Name" }).then(
    function () { /* success */ },
    function (error) {
        Xrm.Navigation.openAlertDialog({ text: error.message });
    }
);
```

### 4.5 Error Handling

```javascript
function handleError(error) {
    console.error("Error: ", error.message);
    Xrm.Navigation.openAlertDialog({
        title: "Error",
        text: error.message || "An unexpected error occurred. Please contact support."
    });
}
```

- Always provide a `.catch()` or error callback on promises.
- Use `Xrm.Navigation.openAlertDialog` for user-facing errors.
- Log to `console.error` for developer diagnostics.
- Never use `alert()` — it is blocked in Unified Interface.

### 4.6 Mandatory Export Block

**Every** JavaScript web resource file **must** end with the following export block to enable unit testing in Node.js:

```javascript
// ── Exports (for unit testing) ──────────────────────────────────────────────
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        /* Insert here the functions to export for testing */
    };
}
```

#### Complete Example

```javascript
var Contoso = window.Contoso || {};
Contoso.Account = Contoso.Account || {};
Contoso.Account.FormEvents = Contoso.Account.FormEvents || {};

Contoso.Account.FormEvents.onLoad = function (executionContext) {
    var formContext = executionContext.getFormContext();
    // ... implementation
};

Contoso.Account.FormEvents.onCreditLimitChange = function (executionContext) {
    var formContext = executionContext.getFormContext();
    // ... implementation
};

// ── Exports (for unit testing) ──────────────────────────────────────────────
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        onLoad: Contoso.Account.FormEvents.onLoad,
        onCreditLimitChange: Contoso.Account.FormEvents.onCreditLimitChange
    };
}
```

---

## 5. TypeScript Standards

### 5.1 Compiler Configuration

```json
{
    "compilerOptions": {
        "strict": true,
        "target": "ES2017",
        "module": "ESNext",
        "moduleResolution": "node",
        "esModuleInterop": true,
        "declaration": true,
        "sourceMap": true,
        "outDir": "./dist",
        "rootDir": "./src",
        "noImplicitAny": true,
        "strictNullChecks": true,
        "noUnusedLocals": true,
        "noUnusedParameters": true
    },
    "include": ["src/**/*"],
    "exclude": ["node_modules", "dist"]
}
```

### 5.2 Interface-First Design

Define interfaces before implementing classes. This enables mocking and decoupling.

```typescript
// interfaces/IAccountService.ts
export interface IAccountService {
    getAccountById(id: string): Promise<Account>;
    validateCreditLimit(account: Account): ValidationResult;
}

// models/Account.ts
export interface Account {
    id: string;
    name: string;
    creditLimit: number;
    customerType: CustomerType;
}

export enum CustomerType {
    Standard = 1,
    Preferred = 2,
    Enterprise = 3,
}

// models/ValidationResult.ts
export interface ValidationResult {
    isValid: boolean;
    errors: string[];
}
```

### 5.3 PCF Component Pattern

```typescript
import { IInputs, IOutputs } from "./generated/ManifestTypes";

export class StarRating implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private container: HTMLDivElement;
    private notifyOutputChanged: () => void;
    private currentValue: number;

    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void,
        state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this.container = container;
        this.notifyOutputChanged = notifyOutputChanged;
        this.currentValue = context.parameters.value.raw ?? 0;

        this.renderControl();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        const newValue = context.parameters.value.raw ?? 0;
        if (newValue !== this.currentValue) {
            this.currentValue = newValue;
            this.renderControl();
        }
    }

    public getOutputs(): IOutputs {
        return {
            value: this.currentValue,
        };
    }

    public destroy(): void {
        // Clean up event listeners and DOM elements
        this.container.innerHTML = "";
    }

    private renderControl(): void {
        // Render implementation
    }
}
```

#### PCF Rules

| Rule | Detail |
|---|---|
| Implement all four lifecycle methods | `init`, `updateView`, `getOutputs`, `destroy` |
| Clean up in `destroy` | Remove event listeners, clear intervals, release DOM references |
| Use `notifyOutputChanged` | Call when the component's output value changes to inform the host |
| Avoid direct DOM manipulation in `updateView` | Minimise re-renders; diff state before updating DOM |
| Use strict TypeScript | Enable all strict compiler flags |

### 5.4 Async / Await for Data Operations

```typescript
async function fetchRelatedContacts(accountId: string): Promise<Contact[]> {
    try {
        const result = await Xrm.WebApi.retrieveMultipleRecords(
            "contact",
            `?$filter=_parentcustomerid_value eq ${accountId}&$select=fullname,emailaddress1`
        );
        return result.entities.map(mapToContact);
    } catch (error: unknown) {
        const message = error instanceof Error ? error.message : "Unknown error";
        console.error(`Failed to fetch contacts for account ${accountId}: ${message}`);
        throw error;
    }
}
```

- Always use `async/await` over raw `.then()` chains for readability.
- Type the return value of every async function.
- Catch and log errors; re-throw or handle gracefully depending on context.
- Use `unknown` for catch clause types and narrow with `instanceof`.

---

## 6. Summary Checklist

Use this checklist during code review:

- [ ] **Naming**: follows naming-conventions.md
- [ ] **Single Responsibility**: each class/function does one thing
- [ ] **No `ColumnSet(true)`**: only required columns are selected
- [ ] **Depth guard**: plugins check `context.Depth`
- [ ] **Exception handling**: try/catch at top level; `InvalidPluginExecutionException` for user messages
- [ ] **Tracing**: entry, exit and key decisions logged via `ITracingService`
- [ ] **No sync external calls**: HTTP calls not made in synchronous plugin steps
- [ ] **Tests exist**: every plugin has corresponding unit tests
- [ ] **Test naming**: `MethodName_Scenario_ExpectedResult`
- [ ] **AAA pattern**: Arrange-Act-Assert clearly separated
- [ ] **JS exports block**: every JS file ends with the mandatory export block
- [ ] **No `Xrm.Page`**: all client code uses `formContext` from execution context
- [ ] **TypeScript strict mode**: `strict: true` in tsconfig.json
- [ ] **PCF lifecycle**: all four methods implemented; `destroy` cleans up
