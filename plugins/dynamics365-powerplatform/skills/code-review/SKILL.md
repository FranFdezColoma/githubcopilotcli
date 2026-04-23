---
name: code-review
description: Perform thorough code reviews for Dynamics 365 CE and Power Platform codebases including C# plugins, JavaScript web resources, TypeScript PCF components, and Power Automate flow definitions. Use when reviewing pull requests, auditing code quality, or enforcing coding standards.
---

# Code Review for Dynamics 365 / Power Platform

> **Rule — Language:** Always respond to the user in the same language they use.

## When to Use This Skill

- Reviewing a pull request that contains D365/PP code changes
- Auditing existing plugin, web resource, or PCF code quality
- Enforcing coding standards before merging to main
- Performing security reviews of customizations
- Evaluating Power Automate flow definitions for best practices

## Review Process — Step by Step

### Step 1 — Understand Context

1. Read the PR description, linked work items, and related ADRs
2. Identify the components being changed (plugins, web resources, PCF, flows, solution metadata)
3. Determine the Dataverse tables and messages affected
4. Check if integration endpoints or security roles are modified

### Step 2 — Check Coding Standards

Apply the relevant technology-specific checklist from `references/review-checklist.md`. Run automated analysis if available:

**If SonarQube MCP is available:**

```
Use SonarQube MCP → search_sonar_issues_in_projects to find existing issues in the project.
Use SonarQube MCP → analyze_code_snippet to analyze changed code for new issues.
Filter by severities: HIGH, BLOCKER for critical findings.
Filter by impactSoftwareQualities: SECURITY for security-specific issues.
```

**If GitHub MCP is available:**

```
Use GitHub MCP → pull_request_read (method: get_diff) to get the full diff.
Use GitHub MCP → pull_request_read (method: get_files) to list changed files.
Use GitHub MCP → pull_request_read (method: get_check_runs) for CI status.
```

### Step 3 — Review Business Logic

- Verify the logic matches the functional specification or user story
- Check edge cases and boundary conditions
- Verify idempotency where required (especially for async operations)
- Confirm proper error handling for all failure paths

### Step 4 — Check Security

Run through the Security Review Checklist (see below). This is mandatory for every review.

### Step 5 — Verify Tests

- Confirm unit tests exist for new plugin logic
- Check that test coverage is adequate for the change
- Verify integration tests for new API endpoints or flows

### Step 6 — Produce Review Output

Structure your review as:

```markdown
## Code Review Summary

**PR:** #NNN — Title
**Reviewer:** [name/agent]
**Date:** YYYY-MM-DD
**Verdict:** ✅ Approved | ⚠️ Approved with Comments | ❌ Changes Requested

### Critical Issues (must fix)
- [ ] Issue description with file:line reference

### Warnings (should fix)
- [ ] Warning description with file:line reference

### Suggestions (nice to have)
- [ ] Suggestion description

### Positive Observations
- Good patterns observed
```

---

## C# Plugin Review Checklist

### IPlugin Implementation

- [ ] Class implements `IPlugin` interface correctly
- [ ] `Execute` method is the single entry point
- [ ] Plugin class is **stateless** — no instance fields that hold mutable state
- [ ] Constructor only accepts `string unsecure` and `string secure` configuration parameters

```csharp
// ✅ CORRECT — stateless plugin
public class MyPlugin : IPlugin
{
    private readonly string _config;

    public MyPlugin(string unsecure, string secure)
    {
        _config = unsecure;
    }

    public void Execute(IServiceProvider serviceProvider)
    {
        // all logic here, no shared state
    }
}
```

### Service Usage

- [ ] `IOrganizationService` obtained from service provider per execution — **never cached as a field**
- [ ] `ITracingService` used for diagnostic output
- [ ] `IPluginExecutionContext` used to read input/output parameters, pre/post images
- [ ] No singleton or static service instances

```csharp
// ✅ CORRECT — obtain services per execution
var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
var service = factory.CreateOrganizationService(context.UserId);
var tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
```

### Error Handling

- [ ] `InvalidPluginExecutionException` thrown for user-facing errors with clear messages
- [ ] Internal exceptions are caught, logged via `ITracingService`, then re-thrown as `InvalidPluginExecutionException`
- [ ] No swallowed exceptions (empty catch blocks)
- [ ] `OperationStatus` set correctly for custom API responses

```csharp
// ✅ CORRECT — error handling pattern
try
{
    // business logic
}
catch (InvalidPluginExecutionException)
{
    throw; // re-throw user-facing exceptions as-is
}
catch (Exception ex)
{
    tracingService.Trace($"Unhandled exception: {ex}");
    throw new InvalidPluginExecutionException(
        "An error occurred processing your request. Contact your administrator.",
        ex);
}
```

### Plugin Pipeline Awareness

- [ ] **Depth check** to prevent infinite loops when plugin triggers itself

```csharp
if (context.Depth > 3)
{
    tracingService.Trace($"Exiting due to depth {context.Depth}");
    return;
}
```

- [ ] Correct stage registered (PreValidation=10, PreOperation=20, MainOperation=30, PostOperation=40)
- [ ] Correct message registered (Create, Update, Delete, Retrieve, RetrieveMultiple, Associate, etc.)
- [ ] **Pre-images and post-images** used correctly — pre-image for original values, post-image for final values
- [ ] **Target entity** checked for attribute presence before accessing (`target.Contains("fieldname")`)
- [ ] Transaction awareness — sync plugins in PreOp/PostOp share the database transaction

### Performance

- [ ] **No external HTTP calls in synchronous plugins** — use async registration or move to Azure Functions
- [ ] Bulk operations use `ExecuteMultipleRequest` with proper batch sizing
- [ ] `ColumnSet` specifies only required columns — never `new ColumnSet(true)` in production
- [ ] QueryExpression/FetchXML uses proper filtering, not client-side filtering of large result sets
- [ ] Paging implemented for queries that may return > 5,000 records

### Code Quality

- [ ] Early-bound types used consistently (or late-bound with documented reason)
- [ ] SOLID principles followed — single responsibility per plugin class
- [ ] Magic strings avoided — constants or enums for field names, option set values
- [ ] Proper null checks on all entity attributes and context parameters

---

## JavaScript Web Resource Review Checklist

### Namespace and Structure

- [ ] Code follows namespace pattern to prevent global scope pollution

```javascript
// ✅ CORRECT — namespace pattern
var Contoso = Contoso || {};
Contoso.Account = Contoso.Account || {};

Contoso.Account.onLoad = function (executionContext) {
    var formContext = executionContext.getFormContext();
    // logic here
};
```

- [ ] Functions exported for testing via `module.exports` block

```javascript
// at end of file
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        onLoad: Contoso.Account.onLoad,
        onSave: Contoso.Account.onSave
    };
}
```

### Form Context Usage

- [ ] `executionContext.getFormContext()` used — **never** `Xrm.Page` (deprecated)
- [ ] Form context passed explicitly to all helper functions
- [ ] `formContext.getAttribute("fieldname")` with null check before `.getValue()`
- [ ] `formContext.getControl("fieldname")` with null check before UI operations

### Xrm.WebApi Usage

- [ ] `Xrm.WebApi.retrieveRecord` / `retrieveMultipleRecords` used for data operations
- [ ] Promise `.then()` and `.catch()` handlers both present
- [ ] `$select` parameter limits fields returned
- [ ] `$filter` applied server-side, not client-side filtering

```javascript
// ✅ CORRECT — proper WebApi usage
Xrm.WebApi.retrieveMultipleRecords(
    "account",
    "?$select=name,revenue&$filter=revenue gt 1000000"
).then(
    function (results) { /* handle */ },
    function (error) { Xrm.Navigation.openAlertDialog({ text: error.message }); }
);
```

### Error Handling

- [ ] All async operations have error handlers
- [ ] User-facing errors use `Xrm.Navigation.openAlertDialog` or `openErrorDialog`
- [ ] Errors logged to console in development; no `console.log` in production hot paths
- [ ] No `alert()` calls — use Xrm.Navigation dialogs

### Performance

- [ ] No synchronous `XMLHttpRequest` calls
- [ ] Event handlers registered for specific fields, not on every form load unnecessarily
- [ ] Web resource bundle size reasonable (< 100KB uncompressed for single resources)

---

## TypeScript / PCF Control Review Checklist

### TypeScript Standards

- [ ] `strict: true` enabled in `tsconfig.json`
- [ ] No use of `any` type — specific types or generics used
- [ ] Interfaces defined for all data structures
- [ ] No `@ts-ignore` without documented justification

### PCF Lifecycle Methods

- [ ] `init()` performs one-time setup — event listeners, initial data load
- [ ] `updateView()` efficiently re-renders — checks if data actually changed before DOM manipulation
- [ ] `destroy()` cleans up all resources — event listeners removed, timers cleared, subscriptions unsubscribed

```typescript
// ✅ CORRECT — proper cleanup
public destroy(): void {
    if (this._resizeObserver) {
        this._resizeObserver.disconnect();
    }
    if (this._eventHandler) {
        window.removeEventListener("resize", this._eventHandler);
    }
    // Remove React component if used
    ReactDOM.unmountComponentAtNode(this._container);
}
```

### Memory and Performance

- [ ] No memory leaks — DOM references cleaned up in `destroy()`
- [ ] React components unmounted properly in `destroy()` if using React
- [ ] Virtual DOM / React `shouldComponentUpdate` or `React.memo` used for optimization
- [ ] `getOutputs()` returns only changed values
- [ ] No unnecessary re-renders triggered by `notifyOutputChanged()`

### Bundle and Build

- [ ] `pcfproj` file and `ControlManifest.Input.xml` are valid
- [ ] Bundle size optimized — tree-shaking enabled, no unnecessary dependencies
- [ ] External libraries approved and license-compatible
- [ ] Feature API version matches target environment capabilities

---

## Power Automate Flow Review Checklist

### Error Handling

- [ ] **Try-Catch-Finally scope** pattern used for all critical actions
- [ ] "Configure run after" set to `has failed` and `has timed out` on error-handling actions
- [ ] Error notifications sent (email, Teams, or adaptive card) for unrecoverable failures
- [ ] Error details captured: `actions('ActionName')?['error']`, `workflow()['run']['name']`

### Data Handling

- [ ] **Pagination enabled** on "List rows" actions when results may exceed page size
- [ ] `$select` used on Dataverse actions to limit columns retrieved
- [ ] `$filter` applied on Dataverse queries — no "Filter array" after fetching all records
- [ ] Large datasets handled with batching, not single Apply-to-each

### Concurrency and Performance

- [ ] **Concurrency control** configured on triggers (degree of parallelism set appropriately)
- [ ] `Apply to each` loops have concurrency degree set (not default sequential if parallelizable)
- [ ] No unnecessary sequential actions that could run in parallel
- [ ] `Compose` actions used for complex expressions instead of inline repetition

### Solution Awareness

- [ ] Flow uses **Connection References** (not hardcoded connections)
- [ ] Configuration values read from **Environment Variables** (not hardcoded)
- [ ] Flow is **solution-aware** (part of a managed solution for ALM transport)
- [ ] Trigger conditions use filter expressions to minimize unnecessary runs

### Naming and Documentation

- [ ] Actions have descriptive names (not "Apply_to_each" or "Condition")
- [ ] Complex expressions have comments or are wrapped in named `Compose` actions
- [ ] Flow description documents purpose, trigger, and expected behavior
- [ ] Scope actions used to group logically related steps

---

## Security Review Checklist (All Technologies)

### Credential Security

- [ ] **No hardcoded credentials** — passwords, API keys, client secrets, connection strings
- [ ] Secrets stored in Azure Key Vault or Dataverse secure configuration
- [ ] Plugin secure configuration used for sensitive plugin settings
- [ ] Environment variables of type "Secret" used for flow configuration

### Input Validation

- [ ] All user inputs validated before processing
- [ ] **FetchXML injection** prevented — user inputs never concatenated into FetchXML strings
- [ ] QueryExpression values parameterized using `ConditionExpression`
- [ ] Web resource inputs sanitized before DOM insertion (XSS prevention)

```csharp
// ❌ WRONG — FetchXML injection risk
var fetchXml = $"<fetch><entity name='account'><filter><condition attribute='name' operator='eq' value='{userInput}'/></filter></entity></fetch>";

// ✅ CORRECT — use QueryExpression with parameterized conditions
var query = new QueryExpression("account");
query.Criteria.AddCondition("name", ConditionOperator.Equal, userInput);
```

### XSS Prevention in Web Resources

- [ ] User-supplied data escaped before rendering in HTML
- [ ] `textContent` used instead of `innerHTML` for text display
- [ ] No `eval()`, `new Function()`, or inline event handlers with dynamic content
- [ ] Content Security Policy headers set if using HTML web resources

### Data Access

- [ ] Security roles follow least-privilege principle
- [ ] Application users have minimal required permissions
- [ ] Impersonation (`CallerObjectId`) used only when justified and documented
- [ ] Plugin runs in sandbox isolation mode (not none)

---

## Integration with Automated Tools

### SonarQube Analysis (if SonarQube MCP available)

```
1. Search project: search_my_sonarqube_projects with project name
2. Get issues: search_sonar_issues_in_projects filtered to changed files
3. Check quality gate: get_project_quality_gate_status
4. For specific snippets: analyze_code_snippet with the changed code
5. Report HIGH and BLOCKER issues as Critical in code review
```

### GitHub Actions CI Check (if GitHub MCP available)

```
1. Get PR status: pull_request_read (method: get_check_runs)
2. If checks failed: get_job_logs for failed jobs
3. Include CI failures in review output
```

---

## References

- See `references/review-checklist.md` for a compact, printable checklist
- [Microsoft Plugin Development Best Practices](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/best-practices/business-logic/)
- [PCF Best Practices](https://learn.microsoft.com/en-us/power-apps/developer/component-framework/code-components-best-practices)
