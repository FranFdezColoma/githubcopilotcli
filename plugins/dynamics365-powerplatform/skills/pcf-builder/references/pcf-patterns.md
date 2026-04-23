# PCF Patterns Reference

> **Language Rule:** Always respond to the user in the same language they use.

---

## ControlManifest.Input.xml Schema Reference

### Root Structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest>
  <control namespace="YourNamespace"
           constructor="YourControl"
           version="1.0.0"
           display-name-key="YourControl_DisplayName"
           description-key="YourControl_Description"
           control-type="standard|virtual"
           api-version="1.3.0">

    <!-- Properties -->
    <!-- Resources -->
    <!-- Feature Usage -->

  </control>
</manifest>
```

### Property Types

| of-type | Description | C# Equivalent |
|---------|-------------|---------------|
| `SingleLine.Text` | Single line of text | `string` |
| `SingleLine.Email` | Email address | `string` |
| `SingleLine.Phone` | Phone number | `string` |
| `SingleLine.URL` | URL | `string` |
| `SingleLine.TextArea` | Multi-line (control hint) | `string` |
| `Multiple` | Multi-line text | `string` |
| `Whole.None` | Whole number | `number` |
| `Currency` | Currency value | `number` |
| `Decimal` | Decimal number | `number` |
| `FP` | Floating point | `number` |
| `DateAndTime.DateOnly` | Date only | `Date` |
| `DateAndTime.DateAndTime` | Date and time | `Date` |
| `TwoOptions` | Boolean | `boolean` |
| `OptionSet` | Choice (option set) | `number` |
| `MultiSelectOptionSet` | Multi-select choice | `number[]` |
| `Lookup.Simple` | Lookup | `EntityReference` |
| `Enum` | Enum (Security, Duration, Language, TimeZone) | `number` |
| `DataSet` | Dataset (views, subgrids) | `DataSet` |

### Property Usage Modes

| Usage | Description |
|-------|-------------|
| `bound` | Two-way binding — reads from and writes back to the column |
| `input` | Read-only configuration property set in form designer |

### Property Element

```xml
<property name="propertyName"
          display-name-key="PropertyDisplayName"
          description-key="PropertyDescription"
          of-type="SingleLine.Text"
          usage="bound|input"
          required="true|false"
          default-value="optional default" />
```

### Dataset Element

```xml
<data-set name="datasetGrid"
          display-name-key="DataSet"
          description-key="The dataset for the grid"
          cds-data-set-options="displayCommandBar:true;displayViewSelector:true">
  <property-set name="columnName"
                display-name-key="Column"
                description-key="A dataset column"
                of-type="SingleLine.Text"
                usage="bound"
                required="true" />
</data-set>
```

### Resources Element

```xml
<resources>
  <code path="index.ts" order="1" />
  <css path="css/MyControl.css" order="1" />
  <resx path="strings/MyControl.1033.resx" order="1" />
  <img path="img/icon.png" />
  <platform-library name="React" version="16.8.6" />
  <platform-library name="Fluent" version="9.46.2" />
</resources>
```

### Feature Usage Flags

```xml
<feature-usage>
  <uses-feature name="Utility" required="true" />
  <uses-feature name="WebAPI" required="true" />
</feature-usage>
```

| Feature | Description |
|---------|-------------|
| `Utility` | Access to `context.utils` (lookupObjects, hasEntityPrivilege) |
| `WebAPI` | Access to `context.webAPI` for CRUD operations |

---

## StandardControl Interface Methods

```typescript
interface StandardControl<TInputs, TOutputs> {
    /**
     * Called once when the component is loaded.
     * Use for initial DOM setup, event listeners, state initialization.
     */
    init(
        context: ComponentFramework.Context<TInputs>,
        notifyOutputChanged: () => void,
        state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void;

    /**
     * Called whenever the framework detects a change in bound/input properties
     * or the component needs to re-render.
     */
    updateView(context: ComponentFramework.Context<TInputs>): void;

    /**
     * Called by the framework to retrieve the current output values.
     * Only called after notifyOutputChanged() is invoked.
     */
    getOutputs(): TOutputs;

    /**
     * Called when the component is removed from the DOM.
     * Clean up all event listeners, timers, React mounts.
     */
    destroy(): void;
}
```

---

## Context Object API Reference

### context.parameters
Access input/bound properties defined in the manifest.

```typescript
const value = context.parameters.propertyName.raw;     // Typed value
const formatted = context.parameters.propertyName.formatted; // Display string
const error = context.parameters.propertyName.error;    // boolean
const type = context.parameters.propertyName.type;      // string
```

### context.mode
Runtime mode information.

```typescript
context.mode.isControlDisabled   // boolean — field is read-only
context.mode.isVisible           // boolean — control is visible
context.mode.label               // string — field label
context.mode.allocatedWidth      // number — available width in px (-1 if unknown)
context.mode.allocatedHeight     // number — available height in px (-1 if unknown)
context.mode.isHighContrastEnabled // boolean — high contrast mode active
context.mode.setControlState(state) // persist state across navigation
context.mode.trackContainerResize(true) // receive resize events
```

### context.webAPI
CRUD operations on Dataverse tables (requires `WebAPI` feature-usage).

```typescript
// Create
const result = await context.webAPI.createRecord(entityName, data);
// result.id — GUID of new record

// Retrieve
const record = await context.webAPI.retrieveRecord(entityName, id, options);
// options: "?$select=name,revenue&$expand=primarycontactid"

// Retrieve Multiple
const results = await context.webAPI.retrieveMultipleRecords(entityName, options, maxPageSize);
// results.entities — array of records
// results.nextLink — pagination URL

// Update
await context.webAPI.updateRecord(entityName, id, data);

// Delete
await context.webAPI.deleteRecord(entityName, id);
```

### context.navigation

```typescript
// Open a record form
context.navigation.openForm(entityFormOptions, formParameters);

// Open alert dialog
context.navigation.openAlertDialog(alertStrings, alertOptions);

// Open confirm dialog
const result = await context.navigation.openConfirmDialog(confirmStrings, confirmOptions);
// result.confirmed — boolean

// Open URL
context.navigation.openUrl(url, openUrlOptions);

// Open web resource
context.navigation.openWebResource(name, windowOptions, data);
```

### context.resources

```typescript
const label = context.resources.getString("key"); // Localized string from resx
const imgUrl = context.resources.getResource("img/icon.png", // Resource URL
    (data) => { /* base64 callback */ },
    () => { /* error callback */ }
);
```

### context.formatting

```typescript
context.formatting.formatCurrency(value);
context.formatting.formatDecimal(value, precision);
context.formatting.formatInteger(value);
context.formatting.formatDateAsFilterStringInUTC(date);
context.formatting.formatDateLong(date);
context.formatting.formatDateShort(date);
context.formatting.formatDateLongAbbreviated(date);
context.formatting.formatLanguage(lcid);
context.formatting.getWeekOfYear(date);
```

### context.updatedProperties
Array of property names that changed since last `updateView()`. Use to optimize rendering.

```typescript
public updateView(context: ComponentFramework.Context<IInputs>): void {
    if (context.updatedProperties.includes("ratingValue")) {
        // Only re-render when ratingValue changed
        this.renderRating(context.parameters.ratingValue.raw);
    }
}
```

---

## React Integration Pattern (Full Example with Hooks)

### index.ts (Control class)

```typescript
import * as React from "react";
import * as ReactDOM from "react-dom";
import { RatingApp, IRatingAppProps } from "./RatingApp";

export class RatingControl implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private _container: HTMLDivElement;
    private _notifyOutputChanged: () => void;
    private _currentValue: number;

    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void,
        _state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this._container = container;
        this._notifyOutputChanged = notifyOutputChanged;
        this._currentValue = context.parameters.ratingValue.raw ?? 0;
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        const props: IRatingAppProps = {
            value: context.parameters.ratingValue.raw ?? 0,
            maxStars: context.parameters.maxStars.raw ?? 5,
            disabled: context.mode.isControlDisabled,
            onChange: (newValue: number) => {
                this._currentValue = newValue;
                this._notifyOutputChanged();
            },
        };
        ReactDOM.render(React.createElement(RatingApp, props), this._container);
    }

    public getOutputs(): IOutputs {
        return { ratingValue: this._currentValue };
    }

    public destroy(): void {
        ReactDOM.unmountComponentAtNode(this._container);
    }
}
```

### RatingApp.tsx (React component with hooks)

```tsx
import * as React from "react";
const { useState, useEffect, useCallback } = React;

export interface IRatingAppProps {
    value: number;
    maxStars: number;
    disabled: boolean;
    onChange: (value: number) => void;
}

export const RatingApp: React.FC<IRatingAppProps> = ({ value, maxStars, disabled, onChange }) => {
    const [hoveredStar, setHoveredStar] = useState<number | null>(null);
    const [selectedValue, setSelectedValue] = useState(value);

    useEffect(() => {
        setSelectedValue(value);
    }, [value]);

    const handleClick = useCallback(
        (starIndex: number) => {
            if (disabled) return;
            setSelectedValue(starIndex);
            onChange(starIndex);
        },
        [disabled, onChange]
    );

    const handleKeyDown = useCallback(
        (e: React.KeyboardEvent, starIndex: number) => {
            if (disabled) return;
            if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                handleClick(starIndex);
            }
        },
        [disabled, handleClick]
    );

    return (
        <div
            className="rating-container"
            role="radiogroup"
            aria-label={`Rating: ${selectedValue} of ${maxStars}`}
        >
            {Array.from({ length: maxStars }, (_, i) => i + 1).map((star) => (
                <span
                    key={star}
                    role="radio"
                    aria-checked={star <= selectedValue}
                    aria-label={`${star} star${star > 1 ? "s" : ""}`}
                    tabIndex={disabled ? -1 : 0}
                    className={`star ${star <= (hoveredStar ?? selectedValue) ? "filled" : "empty"}`}
                    onClick={() => handleClick(star)}
                    onMouseEnter={() => !disabled && setHoveredStar(star)}
                    onMouseLeave={() => setHoveredStar(null)}
                    onKeyDown={(e) => handleKeyDown(e, star)}
                    style={{ cursor: disabled ? "default" : "pointer", fontSize: "24px" }}
                >
                    {star <= (hoveredStar ?? selectedValue) ? "★" : "☆"}
                </span>
            ))}
        </div>
    );
};
```

---

## Dataset API Reference

### DataSet Object

```typescript
interface DataSet {
    // Columns metadata
    columns: DataSetColumn[];

    // Record IDs in current sort/filter order
    sortedRecordIds: string[];

    // Records keyed by ID
    records: { [id: string]: DataSetRecord };

    // Paging
    paging: DataSetPaging;

    // Sorting
    sorting: SortStatus[];

    // Filtering
    filtering: DataSetFiltering;

    // Loading state
    loading: boolean;

    // Error info
    error: boolean;
    errorMessage: string;

    // Refresh data
    refresh(): void;

    // Open record
    openDatasetItem(entityReference: EntityReference): void;

    // Get title
    getTitle(): string;

    // Get view ID
    getViewId(): string;
}
```

### DataSetColumn

```typescript
interface DataSetColumn {
    name: string;            // Logical name
    displayName: string;     // Display label
    dataType: string;        // Column data type
    alias: string;           // Alias name
    order: number;           // Column order
    visualSizeFactor: number; // Relative width
    isHidden: boolean;
    isPrimary: boolean;
    disableSorting: boolean;
}
```

### DataSetRecord

```typescript
interface DataSetRecord {
    getRecordId(): string;
    getNamedReference(): EntityReference;
    getValue(columnName: string): string | Date | number | number[] | boolean | EntityReference | EntityReference[];
    getFormattedValue(columnName: string): string;
}
```

### DataSetPaging

```typescript
interface DataSetPaging {
    totalResultCount: number;
    pageSize: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
    loadNextPage(): void;
    loadPreviousPage(): void;
    loadExactPage(pageNumber: number): void;
    setPageSize(pageSize: number): void;
    reset(): void;
}
```

### DataSetFiltering

```typescript
interface DataSetFiltering {
    getFilter(): FilterExpression;
    setFilter(expression: FilterExpression): void;
    clearFilter(): void;
}

interface FilterExpression {
    conditions: ConditionExpression[];
    filterOperator: 0 | 1; // 0=And, 1=Or
    filters?: FilterExpression[]; // nested
}

interface ConditionExpression {
    attributeName: string;
    conditionOperator: number; // 0=Equal, 1=NotEqual, 2=GreaterThan, etc.
    value: string;
    entityAliasName?: string;
}
```

### SortStatus

```typescript
interface SortStatus {
    name: string;           // Column logical name
    sortDirection: 0 | 1;   // 0=Ascending, 1=Descending
}
```

---

## Fluent UI v9 Integration Pattern

### Setup

```powershell
npm install @fluentui/react-components
```

### Manifest

```xml
<platform-library name="Fluent" version="9.46.2" />
```

### Usage in React Component

```tsx
import * as React from "react";
import {
    FluentProvider,
    webLightTheme,
    Button,
    Input,
    Spinner,
} from "@fluentui/react-components";

export const MyFluentComponent: React.FC<IProps> = (props) => {
    return (
        <FluentProvider theme={webLightTheme}>
            <div className="container">
                <Input
                    placeholder="Enter value..."
                    value={props.value}
                    onChange={(_, data) => props.onChange(data.value)}
                    disabled={props.disabled}
                />
                <Button appearance="primary" onClick={props.onSave}>
                    Save
                </Button>
            </div>
        </FluentProvider>
    );
};
```

---

## Localization Pattern with Resx Files

### File Structure

```
strings/
├── MyControl.1033.resx   (English - default)
├── MyControl.1036.resx   (French)
├── MyControl.3082.resx   (Spanish)
└── MyControl.1031.resx   (German)
```

### Resx File Format

```xml
<?xml version="1.0" encoding="utf-8"?>
<root>
  <data name="MyControl_DisplayName" xml:space="preserve">
    <value>My Control</value>
  </data>
  <data name="Save_Button_Label" xml:space="preserve">
    <value>Save</value>
  </data>
  <data name="Error_Required_Field" xml:space="preserve">
    <value>This field is required.</value>
  </data>
</root>
```

### Manifest Reference

```xml
<resources>
  <resx path="strings/MyControl.1033.resx" order="1" />
</resources>
```

### Code Usage

```typescript
const displayName = context.resources.getString("MyControl_DisplayName");
const saveLabel = context.resources.getString("Save_Button_Label");
const errorMsg = context.resources.getString("Error_Required_Field");
```

### Common LCID Codes

| LCID | Language |
|------|----------|
| 1033 | English (US) |
| 1036 | French |
| 3082 | Spanish |
| 1031 | German |
| 1040 | Italian |
| 1046 | Portuguese (Brazil) |
| 1041 | Japanese |
| 2052 | Chinese (Simplified) |

---

## FeatureUsage Flags

| Flag | API Enabled | When to Use |
|------|-------------|-------------|
| `Utility` | `context.utils.lookupObjects()`, `context.utils.hasEntityPrivilege()` | Lookup dialogs, privilege checks |
| `WebAPI` | `context.webAPI.*` | CRUD operations on Dataverse tables |

Both are declared in the manifest:

```xml
<feature-usage>
  <uses-feature name="Utility" required="true" />
  <uses-feature name="WebAPI" required="true" />
</feature-usage>
```
