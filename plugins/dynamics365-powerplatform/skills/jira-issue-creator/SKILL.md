---
name: jira-issue-creator
description: Create well-structured Jira issues following established naming conventions and best practices for Dynamics 365 CE and Power Platform projects. Uses the Atlassian MCP to interact with Jira, inspect existing issues for context, and create issues including test cases in Gherkin format.
---

# Jira Issue Creator

> **Language Rule:** Always respond to the user in the same language they use.

## MCP Requirement

This skill **REQUIRES** the Atlassian MCP (`mcp-atlassian`). If the MCP is not available:

1. Instruct the user to install and configure the `mcp-atlassian` MCP server.
2. Verify connectivity by calling `jira_get_all_projects`.
3. Confirm the target project is accessible before proceeding.

---

## Pre-Creation Process

Before creating any issue, always perform these discovery steps:

### Step 1: Inspect Existing Project Issues

```
Tool: jira_search
JQL:  project = {PROJECT_KEY} ORDER BY created DESC
Limit: 20
```

Analyze the results to understand:
- Summary naming patterns (prefixes, casing, format)
- Commonly used labels
- Description formatting style
- How acceptance criteria are written

### Step 2: Identify Project Configuration

```
Tool: jira_get_project_components
Project: {PROJECT_KEY}
```

```
Tool: jira_search_fields
Keyword: "epic"
```

Discover:
- Available components
- Custom fields (Epic Link, Story Points, Sprint, etc.)
- Issue types available in the project

### Step 3: Determine Sprint Context

```
Tool: jira_get_agile_boards
Project: {PROJECT_KEY}
```

```
Tool: jira_get_sprints_from_board
Board ID: {BOARD_ID}
State: active
```

---

## Issue Types and Templates

### Epic

**Summary format:** `[Module] Brief Description`

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Epic
Summary:     [Sales] Order Approval Workflow
Description: |
  ## Overview
  Implement an automated approval workflow for sales orders above a configurable
  threshold. This includes Dataverse Custom API, Power Automate flows, and
  model-driven app customizations.

  ## Scope
  - Custom API for order validation and approval logic
  - Power Automate flow for approval routing
  - Model-driven app command bar integration
  - Email notifications for approvers
  - Audit trail logging

  ## Success Criteria
  - Orders above threshold route to the correct approver
  - Approved/rejected status reflected in real time
  - Full audit trail available in the order timeline
  - Average approval processing time < 5 minutes

  ## Out of Scope
  - Mobile app approval interface (Phase 2)
  - Multi-level approval chains (Phase 2)
```

**Labels:** `dynamics365`, `salesorder`, `workflow`

---

### Story / User Story

**Summary format:** `As a [role], I want [capability] so that [benefit]`

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Story
Summary:     As a Sales Manager, I want to approve orders from the model-driven app so that I can process approvals without leaving CRM
Description: |
  ## User Story
  As a **Sales Manager**, I want to **approve or reject sales orders directly
  from the Sales Order form** so that **I can quickly process approvals without
  switching applications**.

  ## Acceptance Criteria
  - [ ] "Approve" and "Reject" buttons appear on the Sales Order command bar
        when status is "Pending Approval"
  - [ ] Clicking "Approve" triggers the contoso_ApproveOrder Custom API
  - [ ] Clicking "Reject" opens a dialog for rejection reason (required field)
  - [ ] Order status updates immediately after action
  - [ ] Notification email sent to the order creator
  - [ ] Buttons are hidden for users without the "Sales Manager" security role

  ## Technical Notes
  - Use Ribbon Workbench or command designer for command bar buttons
  - Custom API: contoso_ApproveOrder (see Epic for details)
  - JavaScript web resource for button click handlers
  - Connection to Power Automate flow for email notifications

  ## Dependencies
  - Custom API must be registered (PROJ-101)
  - Security role "Sales Manager" must include prvExecute privilege
Additional Fields: {"epicKey": "PROJ-100", "priority": {"name": "High"}, "labels": ["dynamics365", "model-driven-app", "command-bar"]}
```

---

### Task

**Summary format:** `[Component] Action Description`

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Task
Summary:     [Plugin] Implement contoso_ApproveOrder Custom API backing plugin
Description: |
  ## Objective
  Implement the C# plugin that backs the `contoso_ApproveOrder` Custom API.

  ## Implementation Steps
  1. Scaffold the plugin project using `scaffold-custom-api.ps1`
  2. Implement approval validation logic:
     - Verify order is in "Pending Approval" status
     - Verify calling user has approval privilege
     - Validate order total against threshold
  3. Implement approval execution:
     - Update order status to "Approved"
     - Set approved by/date fields
     - Create audit log record
  4. Write unit tests (>80% coverage)
  5. Register assembly via PAC CLI
  6. Create Custom API record with parameters

  ## Acceptance Criteria
  - [ ] Plugin compiles without warnings
  - [ ] Unit test coverage ≥ 80%
  - [ ] Custom API callable via Web API
  - [ ] Proper error messages for invalid states
  - [ ] Tracing logs written for all execution paths

  ## Technical Details
  - Namespace: `Contoso.Plugins.CustomApis`
  - Target framework: .NET 4.7.1
  - Dependencies: Microsoft.CrmSdk.CoreAssemblies 9.0.2.x
Additional Fields: {"parent": "PROJ-101", "priority": {"name": "High"}, "labels": ["plugin", "custom-api", "csharp"]}
```

---

### Bug

**Summary format:** `[Component] Brief defect description`

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Bug
Summary:     [Plugin] ApproveOrder API returns generic error for inactive orders instead of specific message
Description: |
  ## Bug Description
  When calling `contoso_ApproveOrder` on an inactive sales order, the API
  returns a generic "An error occurred" message instead of the expected
  "Only active orders can be approved" business error.

  ## Steps to Reproduce
  1. Navigate to a sales order with Status = Inactive
  2. Call the API: `POST /api/data/v9.2/contoso_ApproveOrder`
     with body: `{"OrderId": {"salesorderid": "<inactive-order-id>"}}`
  3. Observe the error response

  ## Expected Result
  ```json
  {
      "error": {
          "code": "0x80040265",
          "message": "Only active orders can be approved."
      }
  }
  ```

  ## Actual Result
  ```json
  {
      "error": {
          "code": "0x80044150",
          "message": "An error occurred in ApproveOrder."
      }
  }
  ```

  ## Environment
  - Environment: DEV (contoso-dev.crm.dynamics.com)
  - Plugin assembly version: 1.0.0.3
  - Browser: N/A (API call)

  ## Root Cause Analysis
  The catch block in `ApproveOrderApi.cs` line 42 catches the
  `InvalidPluginExecutionException` and wraps it in a new generic exception
  instead of re-throwing.

  ## Severity
  **Medium** — Affects developer experience and debugging, not end-user functionality.
Additional Fields: {"priority": {"name": "Medium"}, "labels": ["plugin", "custom-api", "bug"]}
```

---

### Sub-task

**Summary format:** `[Parent-Key] Sub-task description`

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Subtask
Summary:     Write unit tests for ApproveOrder validation logic
Additional Fields: {"parent": "PROJ-102"}
Description: |
  ## Objective
  Write comprehensive unit tests for the validation logic in `ApproveOrderApi.cs`.

  ## Test Cases
  - Valid active order → returns approved
  - Inactive order → throws InvalidPluginExecutionException
  - Missing OrderId parameter → throws InvalidPluginExecutionException
  - Null OrderId → throws InvalidPluginExecutionException
  - Order with zero total → succeeds (no minimum threshold)
  - Order above threshold → succeeds with approval

  ## Requirements
  - Framework: MSTest
  - Mocking: Moq
  - Coverage target: ≥ 90% for validation methods
```

---

### Test Case (Gherkin Format)

**Summary format:** `[Test] Feature - Scenario description`

**MUST** follow Gherkin (Cucumber) nomenclature:

```
Tool: jira_create_issue
Project:     {PROJECT_KEY}
Issue Type:  Task
Summary:     [Test] Order Approval - Approve active order successfully
Description: |
  ## Test Case

  ```gherkin
  Feature: Order Approval Custom API

    Scenario: Successfully approve an active sales order
      Given a sales order exists with status "Pending Approval"
      And the order total is $15,000
      And the calling user has the "Sales Manager" security role
      When the user calls the contoso_ApproveOrder API with the order ID
      Then the API should return IsApproved = true
      And the order status should be updated to "Approved"
      And the order "Approved By" field should contain the calling user
      And the order "Approved Date" field should contain the current timestamp
      And an audit log record should be created

    Scenario: Reject approval for inactive order
      Given a sales order exists with status "Inactive"
      When the user calls the contoso_ApproveOrder API with the order ID
      Then the API should return an error
      And the error message should be "Only active orders can be approved."
      And the order status should remain "Inactive"

    Scenario: Reject approval for unauthorized user
      Given a sales order exists with status "Pending Approval"
      And the calling user does NOT have the "Sales Manager" security role
      When the user calls the contoso_ApproveOrder API with the order ID
      Then the API should return a privilege error
      And the order status should remain "Pending Approval"
  ```

  ## Automation Notes
  - Integration test via Web API HTTP calls
  - Requires test data setup (order records, test users)
  - Cleanup: Reset order status after each test
Additional Fields: {"labels": ["test-case", "gherkin", "custom-api", "integration-test"]}
```

---

## Fields Mapping

| Field | Source | Notes |
|---|---|---|
| **Summary** | Naming convention per issue type | See templates above |
| **Description** | Markdown formatted | Structured sections: Objective, Steps, Acceptance Criteria |
| **Priority** | Business impact assessment | See [priority matrix](references/jira-conventions.md#priority-matrix) |
| **Labels** | Technology-based | `dynamics365`, `power-automate`, `pcf`, `plugin`, `custom-api` |
| **Components** | Discovered from `jira_get_project_components` | Project-specific |
| **Epic Link** | If applicable | Use `additional_fields: {"epicKey": "PROJ-100"}` |
| **Assignee** | If known | Use email or account ID |
| **Story Points** | If estimation is available | Use `additional_fields: {"customfield_XXXXX": 5}` |

---

## Batch Creation Workflow

For creating multiple related issues (e.g., an Epic with Stories and Tasks):

### Step 1: Create the Epic First

```
Tool: jira_create_issue
→ Returns Epic key (e.g., PROJ-100)
```

### Step 2: Create Stories Linked to Epic

```
Tool: jira_batch_create_issues
Issues: [
  {
    "project_key": "PROJ",
    "summary": "As a Sales Manager, I want to approve orders...",
    "issue_type": "Story",
    "description": "...",
    "additional_fields": {"epicKey": "PROJ-100"}
  },
  {
    "project_key": "PROJ",
    "summary": "As an Admin, I want to configure approval thresholds...",
    "issue_type": "Story",
    "description": "...",
    "additional_fields": {"epicKey": "PROJ-100"}
  }
]
```

### Step 3: Create Tasks as Sub-tasks of Stories

```
Tool: jira_create_issue (for each task)
Additional Fields: {"parent": "PROJ-101"}
```

### Step 4: Link Related Issues

```
Tool: jira_create_issue_link
Link Type:      "Blocks"
Inward Issue:   PROJ-102 (Plugin task)
Outward Issue:  PROJ-103 (Flow task — depends on plugin)
```

---

## MCP Tools Reference

| Tool | Purpose | When to Use |
|---|---|---|
| `jira_search` | Discover patterns, check duplicates | Before creating issues |
| `jira_get_project_issues` | Understand project context | Initial project discovery |
| `jira_get_project_components` | Get available components | Map components to issues |
| `jira_search_fields` | Find custom field IDs | Map Story Points, Sprint, etc. |
| `jira_get_agile_boards` | Find board for sprint context | Sprint planning |
| `jira_get_sprints_from_board` | Get active/future sprints | Assign to sprint |
| `jira_create_issue` | Create individual issues | Single issue creation |
| `jira_batch_create_issues` | Create multiple issues | Batch creation |
| `jira_link_to_epic` | Link issues to epics | After creating stories/tasks |
| `jira_create_issue_link` | Link related issues | Blocking/dependency relationships |
| `jira_add_issues_to_sprint` | Assign issues to sprint | Sprint planning |
| `jira_add_comment` | Add context to issues | Post-creation notes |

---

## References

- [Jira Conventions Reference](references/jira-conventions.md) — naming patterns, label taxonomy, Gherkin examples, priority matrix
- [Atlassian: Jira Cloud documentation](https://support.atlassian.com/jira-cloud/)
- [Cucumber: Gherkin Reference](https://cucumber.io/docs/gherkin/reference/)
