# Jira Conventions Reference for D365/Power Platform Projects

> **Language Rule:** Always respond to the user in the same language they use.

## Issue Naming Patterns

### Epic

```
[Module] Brief Description
```

| Example | Module |
|---|---|
| `[Sales] Order Approval Workflow` | Sales module |
| `[Service] Case SLA Automation` | Customer Service |
| `[Marketing] Lead Scoring Integration` | Marketing module |
| `[Platform] Environment Governance` | Platform/DevOps |
| `[Integration] ERP Financial Sync` | Integration |
| `[PCF] Interactive Timeline Control` | PCF components |

### Story / User Story

```
As a [role], I want [capability] so that [benefit]
```

| Example |
|---|
| `As a Sales Rep, I want to see related opportunities on the account form so that I can assess account value quickly` |
| `As a Service Agent, I want to auto-populate case fields from the customer record so that I can reduce data entry time` |
| `As an Admin, I want to configure SLA escalation rules without code so that I can respond to changing business needs` |

### Task

```
[Component] Action Description
```

| Example | Component |
|---|---|
| `[Plugin] Implement post-create validation for Order entity` | Plugin development |
| `[Flow] Build approval routing flow for purchase requests` | Power Automate |
| `[PCF] Create searchable dropdown component` | PCF component |
| `[WebResource] Add ribbon button for quote generation` | JavaScript |
| `[Config] Configure security roles for Sales module` | Configuration |
| `[Data] Migrate historical accounts from legacy CRM` | Data migration |
| `[DevOps] Set up CI/CD pipeline for plugin deployment` | DevOps |

### Bug

```
[Component] Brief defect description
```

| Example |
|---|
| `[Plugin] Pre-validation plugin throws null reference on Contact create without parent account` |
| `[Flow] Approval flow fails silently when approver is a disabled user` |
| `[PCF] Timeline control renders duplicate entries on form refresh` |
| `[Config] Business rule hides required field causing save failure` |
| `[Integration] Duplicate records created during ERP sync batch` |

### Sub-task

```
Sub-task description (linked to parent)
```

| Example |
|---|
| `Write unit tests for Order validation plugin` |
| `Configure connection references for approval flow` |
| `Create test data for SLA escalation scenarios` |
| `Document API contract for external integration` |

---

## Label Taxonomy

### Technology Labels

| Label | Use When |
|---|---|
| `dynamics365` | Any D365 CE customization |
| `power-automate` | Power Automate flows |
| `power-apps` | Canvas or model-driven apps |
| `pcf` | PowerApps Component Framework |
| `plugin` | C# plugin development |
| `custom-api` | Custom API development |
| `workflow-activity` | Custom workflow activities |
| `web-resource` | JavaScript/HTML web resources |
| `dataverse` | Dataverse data model or config |
| `azure` | Azure services integration |
| `power-bi` | Power BI reports/dashboards |
| `ai-builder` | AI Builder models |

### Area Labels

| Label | Use When |
|---|---|
| `sales` | Sales module features |
| `service` | Customer Service features |
| `marketing` | Marketing module features |
| `field-service` | Field Service features |
| `platform` | Platform/cross-cutting concerns |
| `integration` | External system integrations |
| `security` | Security roles, privileges |
| `data-migration` | Data migration tasks |
| `devops` | CI/CD, ALM, deployment |

### Process Labels

| Label | Use When |
|---|---|
| `test-case` | Test case issues |
| `gherkin` | Gherkin-formatted test cases |
| `spike` | Research/investigation tasks |
| `tech-debt` | Technical debt items |
| `documentation` | Documentation tasks |
| `hotfix` | Urgent production fixes |
| `regression` | Regression bugs |

---

## Component Taxonomy

Suggested components for D365/Power Platform projects:

| Component | Description |
|---|---|
| `Plugins` | C# plugins and custom workflow activities |
| `Custom APIs` | Dataverse Custom API definitions and implementations |
| `Flows` | Power Automate cloud and desktop flows |
| `Model-Driven App` | Model-driven app customizations (forms, views, dashboards) |
| `Canvas App` | Canvas app development |
| `PCF Controls` | PowerApps Component Framework controls |
| `Web Resources` | JavaScript, HTML, CSS web resources |
| `Security` | Security roles, field-level security, teams |
| `Data Model` | Tables, columns, relationships, option sets |
| `Integration` | External system connectors and integrations |
| `Data Migration` | Data import, migration, and transformation |
| `DevOps` | CI/CD pipelines, solution management, ALM |
| `Configuration` | Business rules, calculated fields, environment settings |
| `Reporting` | Power BI dashboards, SSRS, FetchXML reports |
| `Documentation` | Technical and user documentation |

---

## Gherkin Test Case Examples

### Plugin Execution Test Cases

```gherkin
Feature: Order Validation Plugin (Pre-Operation)

  Scenario: Validate order with valid data
    Given a new sales order is being created
    And the order has a valid customer reference
    And the order has at least one line item
    And the order total is greater than $0
    When the pre-operation plugin executes
    Then the order should be created successfully
    And the "Order Number" field should be auto-populated

  Scenario: Reject order without customer
    Given a new sales order is being created
    And the customer field is empty
    When the pre-operation plugin executes
    Then the plugin should throw an InvalidPluginExecutionException
    And the error message should be "Customer is required for sales orders."
    And the order should NOT be created

  Scenario: Reject order with negative total
    Given a new sales order is being created
    And the order total is -$100
    When the pre-operation plugin executes
    Then the plugin should throw an InvalidPluginExecutionException
    And the error message should contain "Order total must be positive"
```

### Form Behavior Test Cases

```gherkin
Feature: Account Form Business Rules

  Scenario: Show credit limit field for corporate accounts
    Given the user opens an Account form
    And the Account Category is set to "Corporate"
    When the form loads
    Then the "Credit Limit" field should be visible
    And the "Credit Limit" field should be required

  Scenario: Hide credit limit field for individual accounts
    Given the user opens an Account form
    And the Account Category is set to "Individual"
    When the form loads
    Then the "Credit Limit" field should be hidden
    And the "Credit Limit" field should NOT be required

  Scenario: Auto-populate address from parent account
    Given the user opens a new Account form
    When the user selects a Parent Account
    Then the Address fields should auto-populate from the Parent Account
    And the user should see a notification "Address copied from parent account"
```

### Flow Execution Test Cases

```gherkin
Feature: Order Approval Flow

  Scenario: Route order above threshold to manager
    Given an order is created with total $15,000
    And the approval threshold is configured as $10,000
    And the order creator's manager is "Jane Smith"
    When the "Order Approval" flow triggers
    Then an approval request should be sent to "Jane Smith"
    And the order status should change to "Pending Approval"
    And the order should be locked for editing

  Scenario: Auto-approve order below threshold
    Given an order is created with total $5,000
    And the approval threshold is configured as $10,000
    When the "Order Approval" flow triggers
    Then NO approval request should be sent
    And the order status should change to "Approved"

  Scenario: Handle approval timeout
    Given an approval request has been pending for 72 hours
    When the approval timeout is reached
    Then an escalation email should be sent to the approver's manager
    And a reminder should be sent to the original approver
    And the order status should remain "Pending Approval"
```

### PCF Component Test Cases

```gherkin
Feature: Searchable Dropdown PCF Control

  Scenario: Search and select a value
    Given the searchable dropdown control is rendered on the form
    And the control is bound to the "Industry" option set
    When the user types "Tech" in the search box
    Then the dropdown should show filtered options containing "Tech"
    And "Technology" should appear in the results
    When the user selects "Technology"
    Then the field value should be set to "Technology"
    And the dropdown should close

  Scenario: Clear selection
    Given the searchable dropdown has "Technology" selected
    When the user clicks the clear button
    Then the field value should be cleared
    And the search box should be empty and focused

  Scenario: Handle no results
    Given the searchable dropdown control is rendered on the form
    When the user types "XYZNOTFOUND" in the search box
    Then the dropdown should show "No results found"
    And the previous selection should remain unchanged
```

### Integration Test Cases

```gherkin
Feature: ERP Financial Data Sync

  Scenario: Sync new invoice to ERP
    Given a new invoice is created in Dynamics 365
    And the invoice status is "Active"
    And the ERP system is available
    When the integration flow triggers
    Then the invoice data should be sent to the ERP endpoint
    And the ERP should return a confirmation with external ID
    And the external ID should be stored on the D365 invoice record
    And the sync status field should be set to "Synced"

  Scenario: Handle ERP system unavailable
    Given a new invoice is created in Dynamics 365
    And the ERP system is unavailable (HTTP 503)
    When the integration flow triggers
    Then the flow should retry 3 times with exponential backoff
    And after all retries fail, the sync status should be set to "Failed"
    And a dead letter record should be created
    And a notification should be sent to the integration team

  Scenario: Handle duplicate sync attempt
    Given an invoice has already been synced to the ERP
    And the sync status is "Synced"
    And the external ID is populated
    When the integration flow triggers again (e.g., due to retry)
    Then the flow should detect the existing external ID
    And should perform an UPDATE instead of CREATE in the ERP
    And the sync status should remain "Synced"
```

---

## Priority Matrix

| Priority | Business Impact | Response Time | Examples |
|---|---|---|---|
| **Critical** | Production system down, data loss, security breach | Immediate (< 1 hour) | Plugin causing system crash, data corruption in sync, security role misconfiguration exposing data |
| **High** | Major feature broken, significant user impact, blocking deployment | Same day (< 8 hours) | Approval flow not triggering, form not loading for all users, CI/CD pipeline blocked |
| **Medium** | Feature partially broken, workaround available, cosmetic issues affecting usability | Within sprint (1-5 days) | PCF control rendering issue, non-critical validation missing, slow query performance |
| **Low** | Minor cosmetic issue, nice-to-have improvement, documentation gap | Backlog (next available sprint) | Tooltip text incorrect, minor UI alignment, documentation update needed |

### D365/PP-Specific Priority Guidelines

- **Always Critical:** Plugin exceptions causing transaction rollbacks in production, security privilege escalation
- **Always High:** Flow failures affecting business SLAs, data sync errors causing downstream issues
- **Typically Medium:** Form customization bugs with workarounds, PCF component edge cases
- **Typically Low:** Code quality improvements (tech debt), naming convention alignment, documentation

---

## Definition of Ready (DoR)

An issue is **Ready** when:

- [ ] Summary follows the naming convention for its issue type
- [ ] Description is complete with all required sections
- [ ] Acceptance criteria are defined (for Stories) or steps to reproduce are documented (for Bugs)
- [ ] Priority is set based on the priority matrix
- [ ] Labels are applied (at least one technology label)
- [ ] Component is assigned
- [ ] Epic link is set (if applicable)
- [ ] Dependencies are identified and linked
- [ ] Estimation is provided (Story Points for Stories, hours for Tasks)
- [ ] Technical approach is agreed (for complex items)

---

## Definition of Done (DoD)

An issue is **Done** when:

### For Plugin/Custom API Tasks

- [ ] Code compiles without warnings
- [ ] Unit test coverage ≥ 80%
- [ ] Code reviewed and approved (PR merged)
- [ ] Plugin registered in target environment
- [ ] Integration test passed via Web API
- [ ] Tracing/logging verified in Plugin Trace Log

### For Power Automate Flow Tasks

- [ ] Flow runs successfully end-to-end (happy path)
- [ ] Error handling tested (error paths)
- [ ] Connection references configured (not embedded)
- [ ] Environment variables used for configuration
- [ ] Flow is solution-aware
- [ ] Documentation updated

### For PCF Component Tasks

- [ ] Component builds without errors (`npm run build`)
- [ ] Component tested in harness (`npm start watch`)
- [ ] Component deployed and tested on form
- [ ] Responsive behavior verified
- [ ] Accessibility checked (keyboard nav, screen reader)

### For Configuration Tasks

- [ ] Configuration applied in target environment
- [ ] Solution exported and verified
- [ ] Configuration documented
- [ ] User acceptance testing completed

### For All Issue Types

- [ ] All acceptance criteria met
- [ ] No open blockers
- [ ] Documentation updated (if applicable)
- [ ] Deployed to at least DEV environment
- [ ] Peer reviewed

---

## Further Reading

- [Atlassian: Jira best practices](https://www.atlassian.com/software/jira/guides)
- [Cucumber: Gherkin reference](https://cucumber.io/docs/gherkin/reference/)
- [Microsoft: ALM for Power Platform](https://learn.microsoft.com/en-us/power-platform/alm/)
