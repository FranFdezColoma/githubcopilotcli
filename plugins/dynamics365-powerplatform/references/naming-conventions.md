# Naming Conventions Reference — Dynamics 365 CE / Power Platform

> Canonical guide for every nameable artefact in a Dynamics 365 CE / Power Platform project.
> All teams, skills and agents **must** follow these conventions to keep the platform consistent and supportable.

---

## 1. Publisher Prefix

| Aspect | Convention |
|---|---|
| Format | 2-5 lowercase letters assigned by the publisher (e.g. `cr123`, `contso`, `fab`) |
| Schema prefix | `crXXX_` — appended automatically to every custom component created inside a solution owned by that publisher |
| Default publisher | **Never** use the default `new_` publisher for production work; it signals uncategorised customisations and makes ALM painful |
| Choosing a prefix | Pick an abbreviation of the company or product that is globally unique within the tenant. Check existing publishers in **Settings → Solutions → Publishers** before committing. |

### When to use a custom publisher

- **Always** for project-specific or customer-specific solutions.
- Use a single publisher per logical product/vendor so all its components share the same prefix.
- ISV / reusable components should have their own publisher distinct from customer prefixes.

---

## 2. Solutions

| Aspect | Convention |
|---|---|
| Unique Name | `PublisherPrefix_SolutionName` — PascalCase, no spaces. Example: `contso_SalesAccelerator` |
| Display Name | Human-readable with spaces. Example: "Contoso Sales Accelerator" |
| Versioning | `Major.Minor.Build.Revision` (e.g. `1.4.0.0`). Increment **Major** for breaking changes, **Minor** for features, **Build** for patches, **Revision** for hotfixes. |
| Managed solutions | Suffix `-managed` only in build-pipeline artefact names, never in the solution's unique name. |
| Unmanaged solutions | Used exclusively in development environments; never import unmanaged into Test / UAT / Production. |
| Segmentation | Split large solutions by domain: `contso_SalesCore`, `contso_SalesIntegration`, `contso_SalesReports`. |

---

## 3. Tables (Entities)

| Aspect | Convention |
|---|---|
| Schema name | `crXXX_TableName` — **PascalCase**, **singular** noun. Example: `crXXX_ProjectTask` |
| Display name | Singular: "Project Task", Plural: "Project Tasks" |
| Reserved names | Avoid names that collide with OOB entities or system tables (e.g. `Account`, `Contact`, `Lead`, `Task`). |
| Activity tables | If the table extends Activity: `crXXX_CustomActivity`. Set `IsActivity = true` at creation time. |
| Intersection (N:N) tables | Automatically named by the platform; do not override unless creating a custom intersect entity. |

### Examples

```
crXXX_ProjectTask
crXXX_InspectionResult
crXXX_AssetLocation
crXXX_TimesheetEntry
```

---

## 4. Columns (Attributes)

| Aspect | Convention |
|---|---|
| Schema name | `crXXX_columnname` — **lowercase** with no separators, or `crXXX_column_name` with underscores for readability. Both are accepted; choose one per project and stick with it. |
| Display name | Title Case with spaces: "Estimated Duration" |
| Lookup columns | End with `Id` → `crXXX_parentaccountid`. The display name should read "Parent Account". |
| Choice / OptionSet | End with `code` or `type` where meaningful → `crXXX_statuscode`, `crXXX_prioritytype` |
| Boolean | Prefix or include a verb: `crXXX_isactive`, `crXXX_hasapproval` |
| Date / DateTime | End with `date` or `on` → `crXXX_duedate`, `crXXX_submittedon` |
| Currency / Money | End with `amount` → `crXXX_estimatedamount` |
| Calculated / Rollup | Suffix `_calc` or `_rollup` in internal docs is optional; schema name follows normal rules. |
| Auto-number | Clearly prefix or suffix: `crXXX_ticketnumber` with format `TKT-{SEQNUM:6}` |

---

## 5. Relationships

### N:1 (Many-to-One / Lookup)

```
crXXX_ChildTable_ParentTable
```

Example: `crXXX_ProjectTask_Project` — many Project Tasks belong to one Project.

### 1:N (One-to-Many)

The inverse of the above; the platform names it automatically. Display name follows:

```
crXXX_ParentTable_ChildTable (plural)
```

### N:N (Many-to-Many)

```
crXXX_TableA_TableB
```

Example: `crXXX_Contact_Skill` — Contacts can have many Skills, and Skills can belong to many Contacts.

> **Tip:** Put the "owning" or more prominent entity first in the name.

---

## 6. Web Resources

### Path-based naming

```
crXXX_/scripts/<entity>/<FileName>.js
crXXX_/styles/<FileName>.css
crXXX_/html/<FileName>.html
crXXX_/images/<FileName>.png
```

### Folder structure examples

```
crXXX_/scripts/account/AccountForm.js
crXXX_/scripts/account/AccountRibbon.js
crXXX_/scripts/contact/ContactForm.js
crXXX_/scripts/shared/Utility.js
crXXX_/styles/shared/Global.css
crXXX_/html/account/AccountQuickView.html
crXXX_/images/icons/StatusActive.svg
```

### Rules

- Always use forward slashes inside the logical name (Dataverse convention).
- Use **PascalCase** for file names.
- Group by entity first, then by purpose.
- Place shared/cross-entity files in a `shared` folder.

---

## 7. Plugin Steps

### Format

```
EntityName.MessageName.Stage.Mode
```

| Token | Values |
|---|---|
| EntityName | Logical name or friendly name of the primary entity |
| MessageName | `Create`, `Update`, `Delete`, `Retrieve`, `RetrieveMultiple`, `Associate`, `Disassociate`, custom messages |
| Stage | `PreValidation`, `PreOperation`, `PostOperation` |
| Mode | `Sync`, `Async` |

### Examples

```
Account.Create.PreOperation.Sync
Contact.Update.PostOperation.Async
crXXX_ProjectTask.Delete.PreValidation.Sync
none.crXXX_ApproveTimesheet.PostOperation.Sync
```

> Use `none` as the entity token for entity-agnostic Custom API / Custom Action steps.

---

## 8. Plugin Assemblies & Classes

| Artefact | Convention | Example |
|---|---|---|
| Assembly (DLL) | `CompanyName.Crm.Plugins` | `Contoso.Crm.Plugins` |
| Workflow assembly | `CompanyName.Crm.Workflows` | `Contoso.Crm.Workflows` |
| Plugin class | `<Verb><Entity>` or `<Entity><Message>` | `ValidateProjectTask`, `ProjectTaskOnCreate` |
| Namespace | `CompanyName.Crm.Plugins.<DomainArea>` | `Contoso.Crm.Plugins.Sales` |
| Custom API assembly | `CompanyName.Crm.CustomApis` | `Contoso.Crm.CustomApis` |

---

## 9. Power Automate Flows

### Format

```
[Process]-[Entity]-[Trigger]-[Action]
```

### Examples

```
Notify-Account-OnCreate-SendEmail
Sync-Contact-OnUpdate-PushToSAP
Approve-Timesheet-OnSubmit-RouteToManager
Schedule-Report-Daily-GeneratePDF
```

### Rules

- Use hyphens as separators.
- Start with the business process verb.
- Keep names under 80 characters.
- Prefix environment-specific flows with the environment name when testing: `DEV-Notify-Account-OnCreate-SendEmail`.

---

## 10. Environment Variables

| Aspect | Convention |
|---|---|
| Schema name | `crXXX_EnvironmentVariableName` — PascalCase |
| Display name | Human-readable: "SAP Base URL" |
| Types | `String`, `Number`, `Boolean`, `JSON`, `Data Source` |

### Examples

```
crXXX_SAPBaseUrl          → String
crXXX_MaxRetryCount       → Number
crXXX_FeatureFlagNewUI    → Boolean
crXXX_IntegrationConfig   → JSON
```

> Store connection strings, feature flags, and external URLs here — **never** hard-code them in plugins or web resources.

---

## 11. PCF (PowerApps Component Framework) Components

| Artefact | Convention | Example |
|---|---|---|
| Namespace | `CompanyName.Components` | `Contoso.Components` |
| Control name | PascalCase descriptive | `EditableGrid`, `StarRating`, `AddressPicker` |
| Solution component name | `crXXX_CompanyName.Components.ControlName` | `crXXX_Contoso.Components.StarRating` |
| Manifest namespace attribute | Must match namespace above | `Contoso.Components` |
| Property names | camelCase | `inputValue`, `maxStars`, `isReadOnly` |

### Folder structure (inside a PCF project)

```
StarRating/
├── StarRating/
│   ├── index.ts
│   ├── ControlManifest.Input.xml
│   ├── css/
│   │   └── StarRating.css
│   └── components/
│       └── Star.tsx
├── package.json
└── pcfproj
```

---

## 12. Security Roles

| Aspect | Convention |
|---|---|
| Format | `<Prefix> - <Role Name>` | 
| Prefix | Company abbreviation or project code |
| Examples | `CTSO - Sales Manager`, `CTSO - Field Technician`, `CTSO - System Administrator` |

### Rules

- Always create **custom** security roles; never edit OOB roles directly.
- Copy from an OOB role as the starting baseline, then rename with the prefix.
- Use descriptive role names that map to business personas.
- Document each role's privileges in a security matrix spreadsheet.

---

## Quick-Reference Cheat Sheet

| Artefact | Pattern | Example |
|---|---|---|
| Publisher prefix | `crXXX_` | `contso_` |
| Solution | `prefix_SolutionName` | `contso_SalesCore` |
| Table | `crXXX_PascalSingular` | `crXXX_ProjectTask` |
| Column | `crXXX_lowercasename` | `crXXX_estimatedamount` |
| Lookup column | `crXXX_parententityid` | `crXXX_parentaccountid` |
| Relationship N:1 | `crXXX_Child_Parent` | `crXXX_ProjectTask_Project` |
| Web resource | `crXXX_/scripts/entity/File.js` | `crXXX_/scripts/account/AccountForm.js` |
| Plugin step | `Entity.Message.Stage.Mode` | `Account.Create.PreOperation.Sync` |
| Plugin assembly | `Company.Crm.Plugins` | `Contoso.Crm.Plugins` |
| Flow | `[Process]-[Entity]-[Trigger]-[Action]` | `Notify-Account-OnCreate-SendEmail` |
| Env variable | `crXXX_PascalName` | `crXXX_SAPBaseUrl` |
| PCF control | `Company.Components.Control` | `Contoso.Components.StarRating` |
| Security role | `PREFIX - Role Name` | `CTSO - Sales Manager` |
