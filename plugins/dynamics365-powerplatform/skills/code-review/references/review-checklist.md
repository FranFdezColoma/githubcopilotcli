# Code Review Checklist — Dynamics 365 / Power Platform

> Use this checklist during pull request reviews. Check each item that passes; flag items that fail.

---

## General — All Technologies

- [ ] Code compiles / builds without errors
- [ ] No new compiler warnings introduced
- [ ] Coding standards followed (naming, formatting, structure)
- [ ] No hardcoded credentials, API keys, or connection strings
- [ ] No TODO/HACK/FIXME left without a linked work item
- [ ] Changes match the linked user story or work item requirements
- [ ] Unit tests added or updated for changed logic
- [ ] No unnecessary commented-out code

---

## C# Plugin Review

### Structure and Implementation

- [ ] Implements `IPlugin` interface
- [ ] Plugin class is stateless (no mutable instance fields)
- [ ] Constructor accepts only `(string unsecure, string secure)`
- [ ] Single `Execute(IServiceProvider)` entry point

### Service Provider Usage

- [ ] `IOrganizationService` obtained per execution (not cached as field)
- [ ] `ITracingService` obtained and used for logging
- [ ] `IPluginExecutionContext` used for input/output parameters
- [ ] No static or singleton `IOrganizationService` instances

### Error Handling

- [ ] `InvalidPluginExecutionException` for user-facing errors
- [ ] Internal exceptions caught → logged via tracing → re-thrown as `InvalidPluginExecutionException`
- [ ] No empty catch blocks (swallowed exceptions)

### Pipeline Awareness

- [ ] Depth check present (`context.Depth > N`)
- [ ] Correct stage (PreValidation / PreOperation / PostOperation)
- [ ] Correct message (Create / Update / Delete / etc.)
- [ ] Pre/Post images used correctly
- [ ] `target.Contains("field")` checked before accessing attributes
- [ ] Transaction scope understood (sync plugins share DB transaction)

### Performance

- [ ] No external HTTP calls in synchronous plugins
- [ ] `ColumnSet` specifies only needed columns (no `new ColumnSet(true)`)
- [ ] `ExecuteMultipleRequest` used for bulk operations
- [ ] Query results paginated for large datasets
- [ ] Filtering done server-side (not client-side)

### Code Quality

- [ ] Early-bound or late-bound used consistently
- [ ] SOLID principles followed
- [ ] No magic strings — constants or enums used
- [ ] Null checks on entity attributes and parameters

---

## JavaScript Web Resource Review

### Structure

- [ ] Namespace pattern used (no global function pollution)
- [ ] `module.exports` block present for testability

### Form Context

- [ ] `executionContext.getFormContext()` used (not `Xrm.Page`)
- [ ] `formContext` passed to all helper functions
- [ ] Null checks on `getAttribute()` and `getControl()` results

### API Usage

- [ ] `Xrm.WebApi` methods used for data access
- [ ] Both `.then()` and `.catch()` handlers present on promises
- [ ] `$select` limits returned fields
- [ ] `$filter` applied server-side

### Error Handling

- [ ] All async operations have error handlers
- [ ] `Xrm.Navigation.openAlertDialog` used (not `alert()`)
- [ ] No `console.log` in production hot paths

### Performance

- [ ] No synchronous `XMLHttpRequest`
- [ ] Event handlers registered only for necessary fields
- [ ] Bundle size reasonable (< 100KB per resource)

---

## TypeScript / PCF Control Review

### TypeScript

- [ ] `strict: true` in `tsconfig.json`
- [ ] No `any` type usage (or documented exception)
- [ ] Interfaces defined for data structures
- [ ] No `@ts-ignore` without justification comment

### Lifecycle Methods

- [ ] `init()` — one-time setup only
- [ ] `updateView()` — checks for actual data changes before re-rendering
- [ ] `destroy()` — all resources cleaned up

### Memory and Performance

- [ ] Event listeners removed in `destroy()`
- [ ] React components unmounted in `destroy()` (if applicable)
- [ ] `React.memo` or `shouldComponentUpdate` used for optimization
- [ ] `notifyOutputChanged()` called only when values actually change

### Build

- [ ] `ControlManifest.Input.xml` valid
- [ ] Bundle size optimized (tree-shaking, no unnecessary deps)
- [ ] External libraries license-compatible
- [ ] API version matches target environment

---

## Power Automate Flow Review

### Error Handling

- [ ] Try-Catch-Finally scope pattern for critical actions
- [ ] "Configure run after" includes `has failed` and `has timed out`
- [ ] Error notifications configured (email / Teams / adaptive card)
- [ ] Error details captured (`actions('X')?['error']`, `workflow()['run']['name']`)

### Data Handling

- [ ] Pagination enabled on "List rows" actions
- [ ] `$select` used to limit columns
- [ ] `$filter` used server-side (no "Filter array" on full datasets)
- [ ] Large datasets handled with batching

### Concurrency

- [ ] Trigger concurrency control configured
- [ ] `Apply to each` concurrency degree set appropriately
- [ ] No unnecessary sequential actions

### Solution Awareness

- [ ] Connection References used (not hardcoded connections)
- [ ] Environment Variables used for configuration
- [ ] Flow is solution-aware (in managed solution)
- [ ] Trigger conditions filter unnecessary runs

### Naming and Documentation

- [ ] Actions have descriptive names
- [ ] Complex expressions commented or wrapped in `Compose`
- [ ] Flow description documents purpose and trigger
- [ ] Scope actions group related steps

---

## Security Review (Mandatory for All)

### Credentials

- [ ] No hardcoded passwords, API keys, or secrets
- [ ] Secrets in Azure Key Vault or secure configuration
- [ ] Environment variable type "Secret" for flow secrets

### Input Validation

- [ ] User inputs validated before processing
- [ ] No FetchXML injection (user input not concatenated into XML)
- [ ] QueryExpression uses parameterized conditions
- [ ] Web resource inputs sanitized (XSS prevention)

### XSS Prevention (Web Resources)

- [ ] `textContent` used instead of `innerHTML` for user data
- [ ] No `eval()` or `new Function()` with dynamic content
- [ ] Content Security Policy set for HTML web resources

### Data Access

- [ ] Security roles follow least-privilege
- [ ] Application users have minimal permissions
- [ ] Impersonation documented and justified
- [ ] Plugin runs in sandbox isolation mode

---

## Review Verdict

| Verdict | Criteria |
|---------|---------|
| ✅ **Approved** | All critical items pass, no warnings |
| ⚠️ **Approved with Comments** | No critical issues; minor items to address |
| ❌ **Changes Requested** | One or more critical items fail |

**Reviewer:** ____________________
**Date:** ____________________
**PR:** ____________________
**Verdict:** ____________________

### Critical Issues Found

1. <!-- issue description — file:line -->

### Warnings

1. <!-- warning description — file:line -->

### Suggestions

1. <!-- suggestion -->
