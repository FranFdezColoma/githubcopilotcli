# Flow Patterns Reference

> **Language Rule:** Always respond to the user in the same language they use.

## Expression Cheat Sheet

### Date & Time

| Expression | Description | Example Output |
|---|---|---|
| `utcNow()` | Current UTC timestamp | `2024-06-15T14:30:00Z` |
| `utcNow('yyyy-MM-dd')` | Formatted current date | `2024-06-15` |
| `formatDateTime(utcNow(), 'dd/MM/yyyy HH:mm')` | Custom format | `15/06/2024 14:30` |
| `addDays(utcNow(), 7)` | Add 7 days | `2024-06-22T14:30:00Z` |
| `addHours(utcNow(), -2)` | Subtract 2 hours | `2024-06-15T12:30:00Z` |
| `addMinutes(triggerOutputs()?['body/createdon'], 30)` | Add 30 minutes | |
| `startOfDay(utcNow())` | Start of current day | `2024-06-15T00:00:00Z` |
| `startOfMonth(utcNow())` | Start of current month | `2024-06-01T00:00:00Z` |
| `dayOfWeek(utcNow())` | Day of week (0=Sun) | `6` |
| `ticks(utcNow())` | Ticks (for comparisons) | `638538...` |
| `convertTimeZone(utcNow(), 'UTC', 'Eastern Standard Time')` | Time zone conversion | |

### String Functions

| Expression | Description | Example Output |
|---|---|---|
| `concat('Hello', ' ', 'World')` | Concatenate | `Hello World` |
| `substring('ABCDEF', 2, 3)` | Substring | `CDE` |
| `replace('Hello World', 'World', 'Flow')` | Replace | `Hello Flow` |
| `toLower('HELLO')` | Lowercase | `hello` |
| `toUpper('hello')` | Uppercase | `HELLO` |
| `trim('  hello  ')` | Trim whitespace | `hello` |
| `length('hello')` | String length | `5` |
| `indexOf('hello world', 'world')` | Find position | `6` |
| `split('a;b;c', ';')` | Split to array | `["a","b","c"]` |
| `contains('Hello World', 'World')` | Contains check | `true` |
| `startsWith('Hello', 'He')` | Starts with | `true` |
| `endsWith('Hello', 'lo')` | Ends with | `true` |
| `guid()` | Generate new GUID | `a1b2c3d4-...` |

### Null Handling & Coalesce

| Expression | Description |
|---|---|
| `coalesce(triggerOutputs()?['body/emailaddress1'], 'no-email@contoso.com')` | First non-null value |
| `if(empty(triggerOutputs()?['body/telephone1']), 'N/A', triggerOutputs()?['body/telephone1'])` | Conditional fallback |
| `if(equals(triggerOutputs()?['body/statecode'], 0), 'Active', 'Inactive')` | Conditional text |

### Data Access

| Expression | Description |
|---|---|
| `triggerOutputs()?['body/accountid']` | Trigger output field |
| `triggerBody()?['name']` | Trigger body shorthand |
| `outputs('Get_Account')?['body/name']` | Action output field |
| `body('HTTP_Request')` | Full body of HTTP action |
| `items('Apply_to_each')?['accountid']` | Current item in loop |
| `iterationIndexes('Apply_to_each')` | Current loop iteration index |
| `result('Try_Scope')` | All action results in scope (for error handling) |
| `actions('My_Action')?['status']` | Status of a specific action (`Succeeded`/`Failed`) |
| `workflow()?['run']?['name']` | Current flow run name |
| `workflow()?['tags']?['flowDisplayName']` | Current flow display name |

### Array & Collection

| Expression | Description |
|---|---|
| `length(outputs('List_rows')?['body/value'])` | Count records |
| `first(outputs('List_rows')?['body/value'])` | First item |
| `last(outputs('List_rows')?['body/value'])` | Last item |
| `union(array1, array2)` | Merge arrays (distinct) |
| `intersection(array1, array2)` | Common items |
| `join(variables('myArray'), ', ')` | Join array to string |
| `createArray('a', 'b', 'c')` | Create array literal |

### Type Conversion

| Expression | Description |
|---|---|
| `int('42')` | String to integer |
| `float('3.14')` | String to float |
| `string(42)` | Number to string |
| `bool('true')` | String to boolean |
| `json('{"key":"value"}')` | String to JSON object |
| `base64('hello')` | Base64 encode |
| `base64ToString('aGVsbG8=')` | Base64 decode |
| `decodeUriComponent('%20')` | URL decode |
| `encodeUriComponent('hello world')` | URL encode |

---

## Dataverse Connector Action Reference

| Action | Description | Key Parameters |
|---|---|---|
| **List rows** | Query multiple records | Table, Filter, Select, Expand, Order By, Row Count |
| **Get a row by ID** | Retrieve single record | Table, Row ID, Select, Expand |
| **Add a new row** | Create a record | Table, field values |
| **Update a row** | Update existing record | Table, Row ID, field values |
| **Delete a row** | Delete a record | Table, Row ID |
| **Relate rows** | Associate records (N:N or N:1) | Table, Row ID, Relationship, URL |
| **Unrelate rows** | Disassociate records | Table, Row ID, Relationship, URL |
| **Perform a bound action** | Call entity-bound Custom API/Action | Table, Row ID, Action Name, Parameters |
| **Perform an unbound action** | Call global Custom API/Action | Action Name, Parameters |
| **Perform a changeset request** | Transactional batch | Array of operations |
| **Upload file or image** | Upload file/image column content | Table, Row ID, Column Name, Content |
| **Download file or image** | Download file/image column content | Table, Row ID, Column Name |

---

## Common OData Filter Examples

### Status and State

```
# Active records
statecode eq 0

# Inactive records
statecode eq 1

# Specific status reason
statuscode eq 100000001

# Active AND specific status reason
statecode eq 0 and statuscode eq 1
```

### Date Filters

```
# Created today
createdon ge @{startOfDay(utcNow())}

# Created in last 7 days
createdon ge @{addDays(utcNow(), -7)}

# Created this month
createdon ge @{startOfMonth(utcNow())}

# Modified in last hour
modifiedon ge @{addHours(utcNow(), -1)}

# Between dates
createdon ge 2024-01-01T00:00:00Z and createdon lt 2024-02-01T00:00:00Z

# Due date is today or past
duedate le @{utcNow()}
```

### Lookup / Relationship Filters

```
# By parent account
_parentaccountid_value eq 00000000-0000-0000-0000-000000000001

# By owner (specific user)
_ownerid_value eq 00000000-0000-0000-0000-000000000002

# By owner (current user — use in context)
_ownerid_value eq @{outputs('Get_CurrentUser')?['body/systemuserid']}

# By team
_owningteam_value eq 00000000-0000-0000-0000-000000000003

# By business unit
_owningbusinessunit_value eq 00000000-0000-0000-0000-000000000004
```

### Text Filters

```
# Exact match
name eq 'Contoso Ltd'

# Contains
contains(name, 'Contoso')

# Starts with
startswith(name, 'Cont')

# Ends with
endswith(emailaddress1, '@contoso.com')

# Not equal
name ne 'Test Account'

# Null check
emailaddress1 ne null
telephone1 eq null
```

### Numeric / Money Filters

```
# Greater than
revenue gt 1000000

# Between
revenue ge 100000 and revenue le 500000

# Not zero
revenue ne 0 and revenue ne null
```

### Choice / OptionSet Filters

```
# Specific choice value
industrycode eq 100000001

# Multiple choices (OR)
(industrycode eq 100000001 or industrycode eq 100000002)

# Exclude specific choice
industrycode ne 100000003
```

### Combined Filters

```
# Active high-value accounts in a specific industry
statecode eq 0 and revenue gt 1000000 and industrycode eq 100000001

# Contacts with email, modified this week, owned by a specific team
emailaddress1 ne null and modifiedon ge @{addDays(utcNow(), -7)} and _owningteam_value eq 00000000-0000-0000-0000-000000000003
```

---

## Error Handling JSON Structure

### Extracting Error Details from a Failed Scope

```json
// Expression to get error details from a scope:
// result('Try_Scope')

// Returns array of action results:
[
    {
        "name": "Get_Account",
        "status": "Succeeded",
        "outputs": { "body": { "name": "Contoso" } }
    },
    {
        "name": "Update_Account",
        "status": "Failed",
        "error": {
            "code": "0x80040265",
            "message": "The record is read-only."
        }
    }
]
```

### Expression to Extract Error Message

```
// Get all failed actions
@{join(
    map(
        filter(result('Try_Scope'), item => equals(item?['status'], 'Failed')),
        item => concat(item?['name'], ': ', item?['error']?['message'])
    ),
    '; '
)}
```

### Teams Error Notification Template

```
🚨 **Flow Error Alert**

**Flow:** @{workflow()?['tags']?['flowDisplayName']}
**Run:** @{workflow()?['run']?['name']}
**Time:** @{utcNow('yyyy-MM-dd HH:mm:ss')} UTC
**Error:** @{outputs('Compose_ErrorMessage')}

[View Run](https://make.powerautomate.com/environments/@{workflow()?['tags']?['environmentName']}/flows/@{workflow()?['name']}/runs/@{workflow()?['run']?['name']})
```

---

## Environment Variable Expression Syntax

### Accessing Environment Variables in Expressions

```
// String variable
@{parameters('contoso_ExternalApiUrl')}

// Integer variable
@{parameters('contoso_BatchSize')}

// Boolean variable
@{parameters('contoso_FeatureFlagEnabled')}

// JSON variable (parse before use)
@{json(parameters('contoso_ConfigJson'))}

// Using in OData filter
statecode eq 0 and industrycode eq @{parameters('contoso_TargetIndustryCode')}
```

### Defining Environment Variables in Solution

```xml
<!-- Environment Variable Definition -->
<environmentvariabledefinition>
  <uniquename>contoso_ExternalApiUrl</uniquename>
  <displayname>External API URL</displayname>
  <description>Base URL for the external CRM API</description>
  <type>String</type>
  <isrequired>true</isrequired>
  <defaultvalue>https://api.staging.external-system.com/v2</defaultvalue>
</environmentvariabledefinition>

<!-- Environment Variable Value (per-environment) -->
<environmentvariablevalue>
  <schemaname>contoso_ExternalApiUrl</schemaname>
  <value>https://api.production.external-system.com/v2</value>
</environmentvariablevalue>
```

---

## Connection Reference Usage Pattern

### In Solution XML

```xml
<connectionreference>
  <connectionreferencelogicalname>contoso_DataverseConnection</connectionreferencelogicalname>
  <connectionreferencedisplayname>Dataverse - CRM Service Account</connectionreferencedisplayname>
  <connectorid>/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps</connectorid>
  <description>Service account connection for CRM automation flows</description>
</connectionreference>
```

### In Flow Definition (JSON)

```json
{
    "connectionReferences": {
        "shared_commondataserviceforapps": {
            "connectionName": "",
            "source": "Invoker",
            "id": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
            "connectionReferenceLogicalName": "contoso_DataverseConnection",
            "connectionProperties": {
                "authentication": "ManagedServiceIdentity"
            }
        }
    }
}
```

### Best Practices for Connection References

1. **One connection reference per connector type per solution.**
2. **Name descriptively:** `contoso_DataverseServiceAccount`, `contoso_SharePointCRMSite`.
3. **Use service accounts** — never individual user accounts.
4. **Document the required permissions** for each connection reference.
5. **Configure during deployment** — connection references prompt during solution import.

---

## Further Reading

- [Microsoft: Power Automate expression reference](https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference)
- [Microsoft: Dataverse connector reference](https://learn.microsoft.com/en-us/connectors/commondataserviceforapps/)
- [Microsoft: Solution connection references](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/create-connection-reference)
- [Microsoft: Environment variables](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/environmentvariables)
