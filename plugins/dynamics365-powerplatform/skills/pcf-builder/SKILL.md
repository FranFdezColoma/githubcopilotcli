---
name: pcf-builder
description: Scaffold, develop, and deploy PowerApps Component Framework (PCF) controls for Dynamics 365 CE and Power Platform. Use when building custom field or dataset components, including TypeScript implementation, CSS styling, testing, and packaging for deployment.
---

# PCF Builder Skill

> **Language Rule:** Always respond to the user in the same language they use.

## Prerequisites

| Tool | Required Version | Install Command |
|------|-----------------|-----------------|
| Node.js | LTS (18.x or 20.x) | [Download](https://nodejs.org) |
| npm | Bundled with Node | — |
| Power Platform CLI (`pac`) | Latest | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| .NET Build Tools | 6.0+ SDK | [Download](https://dotnet.microsoft.com) |
| pcf-scripts | Latest | Installed automatically by `pac pcf init` |

Verify prerequisites:

```powershell
node --version          # v18.x or v20.x
npm --version           # 9.x+
pac --version           # 1.30+
dotnet --version        # 6.0+
```

---

## Component Types

### Field Components
Bound to a **single column** (text, number, date, lookup, optionset, etc.). Use when you need a custom editor/renderer for one field.

### Dataset Components
Bound to a **view or subgrid**. Use when building grids, galleries, charts, or any multi-record experience.

---

## Scaffolding Process

### Using PAC CLI

```powershell
# Create project directory
mkdir MyComponent && cd MyComponent

# Scaffold a field component (vanilla TypeScript)
pac pcf init --namespace Contoso --name RatingControl --template field --framework none

# Scaffold a dataset component (React)
pac pcf init --namespace Contoso --name DataGrid --template dataset --framework react

# Install dependencies
npm install
```

### Using the Scaffold Script

```powershell
.\scripts\scaffold-pcf.ps1 `
    -ComponentName "RatingControl" `
    -Namespace "Contoso" `
    -Template field `
    -Framework none `
    -OutputPath "C:\Dev\PCF\RatingControl"
```

See: [`scripts/scaffold-pcf.ps1`](scripts/scaffold-pcf.ps1)

---

## Development Workflow

### Step 1 — Define the Manifest

Edit `ControlManifest.Input.xml` to declare properties, bound properties, and resources.

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest>
  <control namespace="Contoso" constructor="RatingControl" version="1.0.0"
           display-name-key="RatingControl" description-key="A star rating control"
           control-type="standard"
           api-version="1.3.0">
    <property name="ratingValue" display-name-key="Rating Value"
              of-type="Whole.None" usage="bound" required="true" />
    <property name="maxStars" display-name-key="Max Stars"
              of-type="Whole.None" usage="input" required="false"
              default-value="5" />
    <resources>
      <code path="index.ts" order="1" />
      <css path="css/RatingControl.css" order="1" />
      <resx path="strings/RatingControl.1033.resx" order="1" />
    </resources>
    <feature-usage>
      <uses-feature name="Utility" required="true" />
    </feature-usage>
  </control>
</manifest>
```

### Step 2 — Implement `index.ts`

Implement the four lifecycle methods of `ComponentFramework.StandardControl<TInputs, TOutputs>`:

1. **`init(context, notifyOutputChanged, state, container)`** — One-time setup. Attach DOM, initialize state.
2. **`updateView(context)`** — Called whenever bound properties change. Re-render UI.
3. **`getOutputs()`** — Return current output values back to the host.
4. **`destroy()`** — Clean up listeners, timers, React roots.

### Step 3 — Add CSS Styling

Create `css/RatingControl.css` next to your manifest. Keep styles scoped to avoid conflicts with the host form.

### Step 4 — Test Locally

```powershell
npm start watch          # Opens test harness at https://localhost:8181
```

The test harness provides a mock container where you can set property values and see the control render.

### Step 5 — Build

```powershell
npm run build            # Compiles and bundles for production
```

### Step 6 — Package & Deploy

**Option A — Quick push (dev/test only):**

```powershell
pac pcf push --publisher-prefix contoso
```

**Option B — Solution packaging (production):**

```powershell
cd ..
mkdir RatingControlSolution && cd RatingControlSolution
pac solution init --publisher-name Contoso --publisher-prefix contoso
pac solution add-reference --path ..\MyComponent
msbuild /t:build /restore /p:Configuration=Release
```

Import the resulting `.zip` via `pac solution import` or the Power Platform admin portal.

---

## Code Patterns

### React-Based Component Pattern

```typescript
import * as React from "react";
import * as ReactDOM from "react-dom";
import { RatingApp } from "./RatingApp";

export class RatingControl implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private _container: HTMLDivElement;
    private _notifyOutputChanged: () => void;
    private _currentValue: number;

    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void,
        state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this._container = container;
        this._notifyOutputChanged = notifyOutputChanged;
        this._currentValue = context.parameters.ratingValue.raw ?? 0;
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        const value = context.parameters.ratingValue.raw ?? 0;
        ReactDOM.render(
            React.createElement(RatingApp, {
                value,
                maxStars: context.parameters.maxStars.raw ?? 5,
                onChange: (newVal: number) => {
                    this._currentValue = newVal;
                    this._notifyOutputChanged();
                },
                disabled: context.mode.isControlDisabled,
            }),
            this._container
        );
    }

    public getOutputs(): IOutputs {
        return { ratingValue: this._currentValue };
    }

    public destroy(): void {
        ReactDOM.unmountComponentAtNode(this._container);
    }
}
```

### Vanilla TypeScript Component Pattern

```typescript
export class SimpleToggle implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private _container: HTMLDivElement;
    private _button: HTMLButtonElement;
    private _value: boolean;
    private _notifyOutputChanged: () => void;

    public init(context: ComponentFramework.Context<IInputs>,
                notifyOutputChanged: () => void,
                state: ComponentFramework.Dictionary,
                container: HTMLDivElement): void {
        this._container = container;
        this._notifyOutputChanged = notifyOutputChanged;
        this._value = context.parameters.toggleValue.raw ?? false;

        this._button = document.createElement("button");
        this._button.textContent = this._value ? "ON" : "OFF";
        this._button.addEventListener("click", this._onClick.bind(this));
        this._container.appendChild(this._button);
    }

    private _onClick(): void {
        this._value = !this._value;
        this._button.textContent = this._value ? "ON" : "OFF";
        this._notifyOutputChanged();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this._value = context.parameters.toggleValue.raw ?? false;
        this._button.textContent = this._value ? "ON" : "OFF";
        if (context.mode.isControlDisabled) {
            this._button.setAttribute("disabled", "disabled");
        } else {
            this._button.removeAttribute("disabled");
        }
    }

    public getOutputs(): IOutputs {
        return { toggleValue: this._value };
    }

    public destroy(): void {
        this._button.removeEventListener("click", this._onClick.bind(this));
    }
}
```

### Dataset Component with Sorting/Filtering/Paging

```typescript
public updateView(context: ComponentFramework.Context<IInputs>): void {
    const dataset = context.parameters.datasetGrid;

    // Access columns
    const columns = dataset.columns;

    // Access sorted/filtered records
    const records = dataset.sortedRecordIds.map(id => dataset.records[id]);

    // Paging
    if (dataset.paging.hasNextPage) {
        dataset.paging.loadNextPage();
    }

    // Sorting
    dataset.sorting = [{ name: "name", sortDirection: 0 }]; // 0=Asc, 1=Desc
    dataset.refresh();

    // Filtering
    dataset.filtering.setFilter({
        conditions: [{ attributeName: "statuscode", conditionOperator: 0, value: "1" }],
        filterOperator: 0,
    });
    dataset.refresh();
}
```

### Web API Calls from PCF

```typescript
// Retrieve a record
const record = await context.webAPI.retrieveRecord(
    "account", recordId, "?$select=name,revenue"
);

// Create a record
const newRecord: ComponentFramework.WebApi.Entity = {
    "name": "Contoso Ltd",
    "revenue": 1000000
};
const result = await context.webAPI.createRecord("account", newRecord);

// Update a record
await context.webAPI.updateRecord("account", recordId, { "revenue": 2000000 });

// Delete a record
await context.webAPI.deleteRecord("account", recordId);
```

### Navigation API

```typescript
// Open a form
context.navigation.openForm({
    entityName: "account",
    entityId: recordId,
    openInNewWindow: false,
});

// Open alert dialog
context.navigation.openAlertDialog({
    text: "Record saved successfully.",
    confirmButtonLabel: "OK",
});

// Open URL
context.navigation.openUrl("https://contoso.com", { height: 600, width: 800 });
```

### Localization (resx files)

Place `.resx` files in a `strings/` folder referenced in the manifest:

```xml
<resx path="strings/RatingControl.1033.resx" order="1" />
```

Access in code:

```typescript
const label = context.resources.getString("Rating_Label");
```

---

## Best Practices

### Memory Management
- **Always** clean up event listeners in `destroy()`.
- Unmount React component trees with `ReactDOM.unmountComponentAtNode()`.
- Clear intervals/timeouts.
- Remove references to DOM elements.

### Performance
- Minimize DOM updates; diff before writing.
- Use virtual scrolling for dataset components with 500+ records.
- Debounce user input events (300ms is a good default).
- Avoid synchronous heavy computation in `updateView()`.

### Accessibility
- Add `role`, `aria-label`, `aria-valuenow`, `aria-valuemin`, `aria-valuemax` attributes.
- Support keyboard navigation (`Tab`, `Enter`, `Arrow` keys).
- Respect high-contrast mode via `context.mode.isHighContrastEnabled`.

### Responsive Design
- Use `context.mode.allocatedWidth` and `context.mode.allocatedHeight`.
- Use CSS `max-width: 100%` and flexbox for fluid layouts.

### Error Boundaries
- Wrap React trees with an error boundary component.
- Catch and log errors in lifecycle methods; never let errors crash the host form.

---

## Testing

### Unit Testing with Jest

```powershell
npm install --save-dev jest ts-jest @types/jest
```

### Component Testing (React)

```powershell
npm install --save-dev @testing-library/react @testing-library/jest-dom
```

### Manual Testing

```powershell
npm start watch    # Test harness at https://localhost:8181
```

---

## Deployment

| Method | Use Case | Command |
|--------|----------|---------|
| `pac pcf push` | Dev/test quick deploy | `pac pcf push --publisher-prefix contoso` |
| Solution packaging | Production deployment | `msbuild /t:build /restore` |
| Managed solution | Customer delivery | Build with `/p:Configuration=Release` |
| Unmanaged solution | Development/customization | Build with `/p:Configuration=Debug` |

---

## References

- Scaffold script: [`scripts/scaffold-pcf.ps1`](scripts/scaffold-pcf.ps1)
- Pattern reference: [`references/pcf-patterns.md`](references/pcf-patterns.md)
- [Official PCF documentation](https://learn.microsoft.com/en-us/power-apps/developer/component-framework/overview)
