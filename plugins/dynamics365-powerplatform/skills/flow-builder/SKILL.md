---
name: flow-builder
description: Design and build Power Automate cloud flows for Dynamics 365 CE and Dataverse scenarios. Use when creating automated workflows, approval flows, integration flows, or scheduled processes that interact with Dataverse, SharePoint, Teams, or external services.
---

# Flow Builder

> **Language Rule:** Always respond to the user in the same language they use.

## Flow Types

| Type | Trigger | Use Case |
|---|---|---|
| **Automated** | Dataverse trigger (row added/modified/deleted), connector event | React to data changes or events |
| **Scheduled** | Recurrence (hourly, daily, weekly, cron) | Batch processing, reporting, data sync |
| **Instant** | Button press, PowerApps, HTTP request | On-demand operations, user-initiated |
| **Business Process Flow** | Entity form navigation | Guide users through multi-stage processes |

---

## Design Patterns

### 1. Dataverse Connector Patterns

#### List Rows with Filtering

Use OData filter expressions to query Dataverse:

```
Action:      List rows
Table name:  Accounts
Filter rows: statecode eq 0 and revenue gt 1000000
Select columns: accountid,name,revenue
Row count:   5000 (enable pagination)
```

**Common OData filters:**

```
# Equals
statecode eq 0

# Contains
contains(name, 'Contoso')

# Date comparisons
createdon ge 2024-01-01T00:00:00Z
modifiedon ge @{addDays(utcNow(), -7)}

# Lookup references
_parentaccountid_value eq 00000000-0000-0000-0000-000000000001

# Multiple conditions
statecode eq 0 and revenue gt 500000 and contains(name, 'Corp')

# Option set / choice
industrycode eq 100000001

# Null checks
emailaddress1 ne null
```

#### Get Row by ID

```
Action:      Get a row by ID
Table name:  Contacts
Row ID:      @{triggerOutputs()?['body/contactid']}
Select columns: fullname,emailaddress1,telephone1
```

#### Add / Update / Delete Rows

```
# Add a row
Action:      Add a new row
Table name:  Tasks
Subject:     Follow up with @{outputs('Get_Account')?['body/name']}
Due Date:    @{addDays(utcNow(), 7)}
Regarding:   accounts(@{triggerOutputs()?['body/accountid']})

# Update a row
Action:      Update a row
Table name:  Accounts
Row ID:      @{triggerOutputs()?['body/accountid']}
Status:      Active

# Delete a row
Action:      Delete a row
Table name:  Audit Logs
Row ID:      @{items('Apply_to_each')?['auditlogid']}
```

#### Relate / Unrelate Rows

```
Action:      Relate rows
Table name:  Contacts
Row ID:      @{outputs('Create_Contact')?['body/contactid']}
Relationship: contact_customer_accounts
URL:         accounts(@{triggerOutputs()?['body/accountid']})
```

#### Perform Bound / Unbound Actions

```
# Unbound action
Action:      Perform an unbound action
Action name: WinOpportunity
Parameters:  { "Status": 3, "OpportunityClose": { ... } }

# Bound action
Action:      Perform a bound action
Table name:  Accounts
Action name: Microsoft.Dynamics.CRM.contoso_ApproveOrder
Row ID:      @{triggerOutputs()?['body/accountid']}
```

#### Changeset (Batch) Requests

```
Action:      Perform a changeset request
Requests:    Array of create/update/delete operations
             (All succeed or all fail — transactional)
```

---

### 2. Error Handling

#### Try-Catch-Finally Pattern

```
Scope: "Try"
  ├── [Business logic actions]
  
Scope: "Catch" (Configure run after: "Try" has failed, has timed out)
  ├── Compose: Error details → @{result('Try')}
  ├── Send email / Teams notification with error details
  ├── Create error log record in Dataverse
  
Scope: "Finally" (Configure run after: "Catch" has succeeded, has failed, has been skipped)
  ├── Cleanup actions (always execute)
```

**Configure Run After settings:**

| Setting | Meaning |
|---|---|
| `is successful` | Runs only when the previous action succeeds (default) |
| `has failed` | Runs only when the previous action fails |
| `is skipped` | Runs only when the previous action was skipped |
| `has timed out` | Runs only when the previous action times out |

#### Retry Policies

Configure on HTTP actions and connectors:

```json
{
    "retryPolicy": {
        "type": "exponential",
        "count": 4,
        "interval": "PT7S",
        "minimumInterval": "PT5S",
        "maximumInterval": "PT1H"
    }
}
```

| Policy | Behavior |
|---|---|
| `none` | No retries |
| `fixed` | Retry at fixed intervals |
| `exponential` | Exponential backoff (recommended for external APIs) |

#### Dead Letter / Notification Pattern

When retries are exhausted:

1. Log the failed message to a Dataverse "Dead Letter" table.
2. Send a notification to a Teams channel or email distribution list.
3. Include: Flow run URL, error message, input data, timestamp.
4. Create a scheduled flow to periodically retry dead letters.

---

### 3. Pagination

#### Enable Pagination

On the **List rows** action:

1. Open action **Settings**.
2. Enable **Pagination**.
3. Set **Threshold** (e.g., 100,000).
4. Flow will automatically page through all records.

#### Skip Token for >100K Records

For very large datasets:

1. Use a **Do Until** loop.
2. Call the Dataverse Web API via **HTTP** action with `$skiptoken`.
3. Process each page inside the loop.
4. Exit when `@odata.nextLink` is null.

---

### 4. Concurrency Control

#### Apply to Each — Degree of Parallelism

1. Open **Apply to Each** → **Settings**.
2. **Concurrency Control**: On.
3. **Degree of Parallelism**: 1–50 (default: 20).

| Setting | Use Case |
|---|---|
| `1` | Sequential processing, order matters |
| `5-10` | Moderate parallelism, external API rate limits |
| `20` | Default, good for Dataverse operations |
| `50` | Maximum, use for lightweight operations |

#### Singleton Flow Pattern

Prevent concurrent executions of the same flow:

1. Open **Trigger Settings** (⋯ on the trigger).
2. **Concurrency Control**: On.
3. **Degree of Parallelism**: `1`.
4. This ensures only one instance runs at a time.

---

### 5. Performance Best Practices

#### Reduce Payload with Select

After **List rows**, use a **Select** action to extract only needed fields:

```
From:   @{outputs('List_Accounts')?['body/value']}
Map:
  id    → @{item()?['accountid']}
  name  → @{item()?['name']}
  email → @{item()?['emailaddress1']}
```

#### Use Compose for Transformations

```
Compose: Formatted Name
Input:   @{toUpper(outputs('Get_Contact')?['body/lastname'])}, @{outputs('Get_Contact')?['body/firstname']}
```

#### Avoid Unnecessary API Calls in Loops

❌ **Bad:** Getting related records inside a loop (N+1 problem):

```
Apply to Each (Accounts)
  └── List rows: Contacts where _parentcustomerid_value eq [current account]
```

✅ **Good:** Get all contacts first, then filter in-memory:

```
List rows: All Contacts (with expand or pre-filter)
Apply to Each (Accounts)
  └── Filter array: Contacts where _parentcustomerid_value eq [current account]
```

#### Batch Operations

Use **Perform a changeset request** for transactional batches, or **Perform an unbound action** calling `ExecuteMultiple` for bulk operations.

---

### 6. Integration Patterns

#### HTTP Connector — External APIs

```
Action:   HTTP
Method:   POST
URI:      https://api.external-system.com/v2/records
Headers:
  Authorization: Bearer @{body('Get_Token')?['access_token']}
  Content-Type:  application/json
Body:     @{outputs('Compose_Payload')}
```

#### Custom Connector

1. Create a custom connector in the Power Platform environment.
2. Define the API specification (OpenAPI/Swagger).
3. Configure authentication (OAuth 2.0, API Key, etc.).
4. Use **Connection References** in solutions (not embedded connections).

#### Azure Service Bus

```
# Send
Action:   Send message (Service Bus)
Queue:    dataverse-events
Content:  @{triggerOutputs()?['body']}

# Receive (trigger)
Trigger:  When a message is received in a queue (peek-lock)
Queue:    external-responses
```

#### SharePoint File Operations

```
# Create file
Action:   Create file (SharePoint)
Site:     https://contoso.sharepoint.com/sites/CRM
Library:  Documents
File name: @{outputs('Get_Account')?['body/name']}_Report.pdf
Content:  @{body('Generate_PDF')}
```

#### Teams Notifications

```
Action:   Post message in a chat or channel (Teams)
Team:     CRM Operations
Channel:  #alerts
Message:  🔔 New high-value opportunity: @{triggerOutputs()?['body/name']} ($@{triggerOutputs()?['body/estimatedvalue']})
```

---

### 7. Security Best Practices

#### Connection References (NOT Embedded Connections)

Always use connection references in solution-aware flows:

```
Connection Reference:  contoso_DataverseConnection
Type:                  Microsoft Dataverse
Description:           Service account for CRM automation flows
```

This allows different credentials per environment without editing flows.

#### Environment Variables for Configuration

Store configuration values as environment variables:

```
Name:    contoso_ExternalApiUrl
Type:    String
Value:   https://api.production.external-system.com/v2

Name:    contoso_NotificationEmail
Type:    String
Value:   crm-alerts@contoso.com

Name:    contoso_BatchSize
Type:    Integer
Value:   500
```

Access in flow expressions: `@{parameters('contoso_ExternalApiUrl')}`

#### Service Principal Connections

For server-to-server flows:

1. Register an Azure AD App Registration.
2. Create an Application User in Dataverse.
3. Assign appropriate security roles.
4. Use client credentials flow for authentication.

#### Secure Inputs/Outputs

On sensitive actions (e.g., HTTP with auth headers):

1. Open action **Settings**.
2. Enable **Secure Inputs** and/or **Secure Outputs**.
3. This hides data from flow run history.

---

## Naming Conventions

Follow this pattern for flow names:

```
[Process]-[Entity]-[Trigger]-[Action]
```

**Examples:**

| Flow Name | Description |
|---|---|
| `Approval-SalesOrder-OnCreate-SendForApproval` | Triggers approval when a sales order is created |
| `Sync-Contact-OnUpdate-PushToMailchimp` | Syncs contact changes to Mailchimp |
| `Batch-Invoice-Scheduled-GenerateMonthlyReport` | Monthly invoice report generation |
| `Notify-Case-OnCreate-PostToTeams` | Posts a Teams message for new cases |
| `Cleanup-AuditLog-Scheduled-ArchiveOldRecords` | Archives old audit log records on schedule |

---

## Documentation Requirements

For every flow, document:

1. **Purpose:** What business process does this flow automate?
2. **Trigger:** What starts the flow and under what conditions?
3. **Inputs/Outputs:** What data flows in and out?
4. **Error Handling:** How are failures handled and reported?
5. **Dependencies:** Connection references, environment variables, custom connectors, other flows.
6. **Performance:** Expected volume, pagination settings, concurrency.
7. **Owner:** Who is responsible for maintaining this flow?

---

## Testing Strategy

### Manual Testing

1. **Trigger the flow** manually or create/modify the triggering record.
2. **Check flow run history:** Power Automate → Flow → Run History.
3. **Inspect each action:** Verify inputs, outputs, and status.
4. **Test error paths:** Intentionally cause failures to verify Try-Catch-Finally works.

### Automated Testing

1. Use **Power Automate Test Framework** (preview) for automated flow testing.
2. Create a **test flow** that calls the main flow and validates results.
3. Use **Solution Checker** to detect common flow anti-patterns.

### Checklist

- [ ] Happy path succeeds end-to-end.
- [ ] Error handling catches and reports failures correctly.
- [ ] Pagination works for large datasets.
- [ ] Concurrency settings are appropriate.
- [ ] Connection references resolve correctly in all environments.
- [ ] Environment variables are populated in all environments.
- [ ] Secure inputs/outputs hide sensitive data.
- [ ] Flow owner is a service account (not a personal account).
- [ ] Flow is solution-aware and included in the deployment solution.

---

## References

- [Flow Patterns Reference](references/flow-patterns.md) — JSON snippets, expression cheat sheet, connector reference
- [Microsoft: Power Automate documentation](https://learn.microsoft.com/en-us/power-automate/)
- [Microsoft: Dataverse connector](https://learn.microsoft.com/en-us/connectors/commondataserviceforapps/)
- [Microsoft: Best practices for flows](https://learn.microsoft.com/en-us/power-automate/guidance/planning/introduction)
