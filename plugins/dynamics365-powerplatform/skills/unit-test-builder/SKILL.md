---
name: unit-test-builder
description: Generate comprehensive unit tests for Dynamics 365 CE and Power Platform code including C# plugin tests (MSTest + Moq), JavaScript web resource tests (Jest), and TypeScript PCF component tests. Use when creating test suites, improving test coverage, or setting up test infrastructure.
---

# Unit Test Builder Skill

> **Language Rule:** Always respond to the user in the same language they use.

## Overview

This skill generates unit tests for three target platforms:

| Platform | Framework | Language |
|----------|-----------|----------|
| Dataverse Plugins | MSTest v2 + Moq | C# (.NET Framework 4.7.1) |
| Web Resources | Jest | JavaScript |
| PCF Components | Jest + React Testing Library | TypeScript / TSX |

---

## C# Plugin Unit Testing

### Project Setup

Target: **.NET Framework 4.7.1**

NuGet packages (exact versions):

| Package | Version |
|---------|---------|
| `Microsoft.CrmSdk.CoreAssemblies` | 9.0.2.56 |
| `MSTest.TestFramework` | 2.2.10 |
| `MSTest.TestAdapter` | 2.2.10 |
| `Microsoft.NET.Test.Sdk` | 17.6.0 |
| `Moq` | 4.20.72 |
| `Castle.Core` | 5.1.1 |

Install via Package Manager Console:

```powershell
Install-Package Microsoft.CrmSdk.CoreAssemblies -Version 9.0.2.56
Install-Package MSTest.TestFramework -Version 2.2.10
Install-Package MSTest.TestAdapter -Version 2.2.10
Install-Package Microsoft.NET.Test.Sdk -Version 17.6.0
Install-Package Moq -Version 4.20.72
Install-Package Castle.Core -Version 5.1.1
```

### Mock Setup Pattern

```csharp
[TestClass]
public class EntityNameMessagePluginTests
{
    private Mock<IOrganizationService> _serviceMock;
    private Mock<IPluginExecutionContext> _contextMock;
    private Mock<ITracingService> _tracingMock;
    private Mock<IOrganizationServiceFactory> _factoryMock;
    private Mock<IServiceProvider> _serviceProviderMock;

    [TestInitialize]
    public void Setup()
    {
        _serviceMock = new Mock<IOrganizationService>();
        _contextMock = new Mock<IPluginExecutionContext>();
        _tracingMock = new Mock<ITracingService>();
        _factoryMock = new Mock<IOrganizationServiceFactory>();
        _serviceProviderMock = new Mock<IServiceProvider>();

        _serviceProviderMock.Setup(sp => sp.GetService(typeof(IPluginExecutionContext)))
            .Returns(_contextMock.Object);
        _serviceProviderMock.Setup(sp => sp.GetService(typeof(ITracingService)))
            .Returns(_tracingMock.Object);
        _serviceProviderMock.Setup(sp => sp.GetService(typeof(IOrganizationServiceFactory)))
            .Returns(_factoryMock.Object);
        _factoryMock.Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>()))
            .Returns(_serviceMock.Object);
    }
}
```

### Test Naming Convention

```
MethodName_Scenario_ExpectedResult
```

Examples:
- `Execute_ValidCreateTarget_ShouldSetDefaultPrice`
- `Execute_DepthExceeded_ShouldReturnEarly`
- `Execute_MissingTarget_ShouldNotThrow`
- `Execute_InvalidMessage_ShouldSkipProcessing`
- `Execute_UnexpectedError_ShouldThrowInvalidPluginException`

### Test Categories

```csharp
[TestCategory("Plugin")]        // Plugin logic tests
[TestCategory("Integration")]   // Tests requiring real service mocks
[TestCategory("Validation")]    // Input validation tests
[TestCategory("ErrorHandling")] // Exception path tests
```

### Common Test Scenarios

#### 1. Happy Path Execution

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_ValidTarget_ShouldProcessSuccessfully()
{
    // Arrange
    var target = new Entity("account", Guid.NewGuid());
    target["name"] = "Contoso Ltd";

    _contextMock.Setup(c => c.MessageName).Returns("Create");
    _contextMock.Setup(c => c.Depth).Returns(1);
    _contextMock.Setup(c => c.InputParameters)
        .Returns(new ParameterCollection { { "Target", target } });

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);

    // Assert
    _tracingMock.Verify(
        t => t.Trace(It.Is<string>(s => s.Contains("completed")), It.IsAny<object[]>()),
        Times.AtLeastOnce);
}
```

#### 2. Missing Target Entity

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_MissingTarget_ShouldReturnWithoutProcessing()
{
    // Arrange
    _contextMock.Setup(c => c.MessageName).Returns("Create");
    _contextMock.Setup(c => c.Depth).Returns(1);
    _contextMock.Setup(c => c.InputParameters)
        .Returns(new ParameterCollection());

    var plugin = new MyPlugin("", "");

    // Act — should not throw
    plugin.Execute(_serviceProviderMock.Object);

    // Assert
    _serviceMock.Verify(s => s.Create(It.IsAny<Entity>()), Times.Never);
}
```

#### 3. Invalid Message Name

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_WrongMessage_ShouldSkipProcessing()
{
    // Arrange
    _contextMock.Setup(c => c.MessageName).Returns("Delete");
    var target = new Entity("account", Guid.NewGuid());
    _contextMock.Setup(c => c.InputParameters)
        .Returns(new ParameterCollection { { "Target", target } });

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);

    // Assert
    _serviceMock.Verify(s => s.Update(It.IsAny<Entity>()), Times.Never);
}
```

#### 4. Depth Exceeded

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_DepthExceeded_ShouldExitEarly()
{
    // Arrange
    _contextMock.Setup(c => c.Depth).Returns(3);

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);

    // Assert
    _serviceMock.Verify(s => s.Create(It.IsAny<Entity>()), Times.Never);
}
```

#### 5. Exception Handling

```csharp
[TestMethod]
[TestCategory("ErrorHandling")]
[ExpectedException(typeof(InvalidPluginExecutionException))]
public void Execute_UnexpectedException_ShouldWrapInInvalidPluginException()
{
    // Arrange
    _contextMock.Setup(c => c.MessageName).Returns("Create");
    _contextMock.Setup(c => c.Depth).Returns(1);
    _contextMock.Setup(c => c.InputParameters)
        .Throws(new NullReferenceException("Simulated failure"));

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);
}
```

#### 6. Pre/Post Image Validation

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_WithPreImage_ShouldAccessOriginalValues()
{
    // Arrange
    var preImage = new Entity("account", Guid.NewGuid());
    preImage["name"] = "Old Name";
    preImage["revenue"] = new Money(500000m);

    var preImages = new EntityImageCollection { { "PreImage", preImage } };
    _contextMock.Setup(c => c.PreEntityImages).Returns(preImages);

    var target = new Entity("account", preImage.Id);
    target["name"] = "New Name";
    _contextMock.Setup(c => c.MessageName).Returns("Update");
    _contextMock.Setup(c => c.Depth).Returns(1);
    _contextMock.Setup(c => c.InputParameters)
        .Returns(new ParameterCollection { { "Target", target } });

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);

    // Assert — verify the plugin used the pre-image data
    _tracingMock.Verify(
        t => t.Trace(It.IsAny<string>(), It.IsAny<object[]>()),
        Times.AtLeastOnce);
}
```

#### 7. Service Call Verification

```csharp
[TestMethod]
[TestCategory("Plugin")]
public void Execute_ShouldCreateAuditRecord()
{
    // Arrange
    var target = new Entity("account", Guid.NewGuid());
    target["name"] = "Contoso";
    _contextMock.Setup(c => c.MessageName).Returns("Create");
    _contextMock.Setup(c => c.Depth).Returns(1);
    _contextMock.Setup(c => c.InputParameters)
        .Returns(new ParameterCollection { { "Target", target } });

    _serviceMock.Setup(s => s.Create(It.IsAny<Entity>()))
        .Returns(Guid.NewGuid());

    var plugin = new MyPlugin("", "");

    // Act
    plugin.Execute(_serviceProviderMock.Object);

    // Assert
    _serviceMock.Verify(s => s.Create(
        It.Is<Entity>(e =>
            e.LogicalName == "my_auditlog" &&
            e.GetAttributeValue<string>("my_action") == "Create"
        )), Times.Once);
}
```

### Arrange-Act-Assert Pattern (MANDATORY)

Every test **must** follow the AAA structure:

```csharp
[TestMethod]
public void MethodName_Scenario_ExpectedResult()
{
    // ── Arrange ──
    // Set up mocks, create test data, configure context

    // ── Act ──
    // Call the method under test (single call)

    // ── Assert ──
    // Verify outcomes using Assert.* and Mock.Verify()
}
```

---

## JavaScript Web Resource Unit Testing

### Setup

```powershell
npm init -y
npm install --save-dev jest
```

### jest.config.js

```javascript
module.exports = {
    testEnvironment: 'jsdom',
    roots: ['<rootDir>/tests'],
    testMatch: ['**/*.test.js'],
    setupFiles: ['<rootDir>/tests/setup/xrm-mock.js'],
};
```

### Xrm Mock Object

```javascript
// tests/setup/xrm-mock.js
global.Xrm = {
    WebApi: {
        createRecord: jest.fn().mockResolvedValue({ id: '00000000-0000-0000-0000-000000000001' }),
        retrieveRecord: jest.fn().mockResolvedValue({}),
        updateRecord: jest.fn().mockResolvedValue({}),
        deleteRecord: jest.fn().mockResolvedValue({}),
        retrieveMultipleRecords: jest.fn().mockResolvedValue({ entities: [], nextLink: null }),
    },
    Navigation: {
        openAlertDialog: jest.fn().mockResolvedValue({}),
        openConfirmDialog: jest.fn().mockResolvedValue({ confirmed: true }),
        openForm: jest.fn().mockResolvedValue({}),
        openUrl: jest.fn(),
        openWebResource: jest.fn(),
    },
    Utility: {
        getGlobalContext: jest.fn().mockReturnValue({
            getClientUrl: jest.fn().mockReturnValue('https://org.crm.dynamics.com'),
            getUserId: jest.fn().mockReturnValue('00000000-0000-0000-0000-000000000002'),
            getUserName: jest.fn().mockReturnValue('Test User'),
            userSettings: {
                languageId: 1033,
                userId: '00000000-0000-0000-0000-000000000002',
            },
        }),
    },
};
```

### FormContext Mock Factory

```javascript
// tests/setup/form-context-mock.js
function createFormContextMock(attributes = {}) {
    const attributeMocks = {};
    for (const [name, config] of Object.entries(attributes)) {
        attributeMocks[name] = {
            getValue: jest.fn().mockReturnValue(config.value),
            setValue: jest.fn(),
            getIsDirty: jest.fn().mockReturnValue(false),
            setRequiredLevel: jest.fn(),
            setSubmitMode: jest.fn(),
            addOnChange: jest.fn(),
            removeOnChange: jest.fn(),
            fireOnChange: jest.fn(),
            controls: {
                forEach: jest.fn(),
                get: jest.fn().mockReturnValue({
                    setVisible: jest.fn(),
                    setDisabled: jest.fn(),
                    setLabel: jest.fn(),
                    setNotification: jest.fn(),
                    clearNotification: jest.fn(),
                }),
            },
        };
    }

    return {
        getAttribute: jest.fn((name) => attributeMocks[name] || null),
        getControl: jest.fn((name) => ({
            setVisible: jest.fn(),
            setDisabled: jest.fn(),
            setLabel: jest.fn(),
            setNotification: jest.fn(),
            clearNotification: jest.fn(),
        })),
        data: {
            entity: {
                getId: jest.fn().mockReturnValue('{00000000-0000-0000-0000-000000000001}'),
                getEntityName: jest.fn().mockReturnValue('account'),
                save: jest.fn().mockResolvedValue({}),
            },
            refresh: jest.fn().mockResolvedValue({}),
        },
        ui: {
            setFormNotification: jest.fn(),
            clearFormNotification: jest.fn(),
            tabs: { forEach: jest.fn() },
            controls: { forEach: jest.fn() },
            refreshRibbon: jest.fn(),
        },
    };
}

module.exports = { createFormContextMock };
```

### Example Test File

```javascript
// tests/account-form.test.js
const { createFormContextMock } = require('./setup/form-context-mock');
const { onLoad, onNameChange } = require('../src/account-form');

describe('Account Form', () => {
    let formContext;

    beforeEach(() => {
        jest.clearAllMocks();
        formContext = createFormContextMock({
            name: { value: 'Contoso Ltd' },
            revenue: { value: 1000000 },
            statuscode: { value: 1 },
        });
    });

    describe('onLoad', () => {
        it('should set revenue field as required', () => {
            onLoad({ getFormContext: () => formContext });

            const revenueAttr = formContext.getAttribute('revenue');
            expect(revenueAttr.setRequiredLevel).toHaveBeenCalledWith('required');
        });
    });

    describe('onNameChange', () => {
        it('should show notification when name is empty', () => {
            formContext.getAttribute('name').getValue.mockReturnValue('');

            onNameChange({ getFormContext: () => formContext });

            expect(formContext.ui.setFormNotification)
                .toHaveBeenCalledWith(
                    expect.any(String),
                    'WARNING',
                    'name_required'
                );
        });
    });
});
```

> **IMPORTANT:** Tests rely on the `module.exports` block being present in source files. Ensure your web resource files export their functions:
> ```javascript
> if (typeof module !== 'undefined') {
>     module.exports = { onLoad, onNameChange };
> }
> ```

---

## TypeScript PCF Component Testing

### Setup (Add to Existing PCF Project)

```powershell
npm install --save-dev jest ts-jest @types/jest
npm install --save-dev @testing-library/react @testing-library/jest-dom  # If React-based
```

### jest.config.ts

```typescript
import type { Config } from 'jest';

const config: Config = {
    preset: 'ts-jest',
    testEnvironment: 'jsdom',
    roots: ['<rootDir>'],
    testMatch: ['**/__tests__/**/*.test.(ts|tsx)', '**/*.test.(ts|tsx)'],
    moduleNameMapper: {
        '\\.(css|less|scss)$': '<rootDir>/__mocks__/styleMock.js',
    },
};

export default config;
```

### ComponentFramework Context Mock

```typescript
// __mocks__/ComponentFramework.mock.ts
export function createMockContext<TInputs>(
    parameters: Partial<TInputs> = {},
    overrides: Partial<ComponentFramework.Context<TInputs>> = {}
): ComponentFramework.Context<TInputs> {
    return {
        parameters: parameters as TInputs,
        mode: {
            isControlDisabled: false,
            isVisible: true,
            label: 'Test Control',
            allocatedWidth: 300,
            allocatedHeight: 200,
            isHighContrastEnabled: false,
            setControlState: jest.fn(),
            trackContainerResize: jest.fn(),
            setFullScreen: jest.fn(),
        } as any,
        webAPI: {
            createRecord: jest.fn().mockResolvedValue({ id: 'mock-id' }),
            retrieveRecord: jest.fn().mockResolvedValue({}),
            updateRecord: jest.fn().mockResolvedValue({}),
            deleteRecord: jest.fn().mockResolvedValue({}),
            retrieveMultipleRecords: jest.fn().mockResolvedValue({ entities: [] }),
        } as any,
        navigation: {
            openForm: jest.fn().mockResolvedValue({}),
            openAlertDialog: jest.fn().mockResolvedValue({}),
            openConfirmDialog: jest.fn().mockResolvedValue({ confirmed: true }),
            openUrl: jest.fn(),
        } as any,
        resources: {
            getString: jest.fn((key: string) => key),
            getResource: jest.fn(),
        } as any,
        formatting: {
            formatCurrency: jest.fn((val: number) => `$${val}`),
            formatDecimal: jest.fn((val: number) => val.toString()),
            formatInteger: jest.fn((val: number) => val.toString()),
        } as any,
        updatedProperties: [],
        ...overrides,
    } as ComponentFramework.Context<TInputs>;
}

export function createMockProperty<T>(raw: T, formatted?: string) {
    return {
        raw,
        formatted: formatted ?? String(raw),
        error: false,
        errorMessage: '',
        security: undefined,
        type: typeof raw,
    };
}
```

### Example PCF Component Test

```typescript
// __tests__/RatingControl.test.ts
import { RatingControl } from '../RatingControl';
import { createMockContext, createMockProperty } from '../../__mocks__/ComponentFramework.mock';

describe('RatingControl', () => {
    let control: RatingControl;
    let container: HTMLDivElement;
    let notifyOutputChanged: jest.Mock;

    beforeEach(() => {
        control = new RatingControl();
        container = document.createElement('div');
        notifyOutputChanged = jest.fn();
    });

    afterEach(() => {
        control.destroy();
    });

    describe('init', () => {
        it('should initialize without errors', () => {
            const context = createMockContext({
                ratingValue: createMockProperty(3),
                maxStars: createMockProperty(5),
            });

            expect(() => {
                control.init(context, notifyOutputChanged, {}, container);
            }).not.toThrow();
        });
    });

    describe('updateView', () => {
        it('should render stars in the container', () => {
            const context = createMockContext({
                ratingValue: createMockProperty(3),
                maxStars: createMockProperty(5),
            });

            control.init(context, notifyOutputChanged, {}, container);
            control.updateView(context);

            expect(container.innerHTML).not.toBe('');
        });
    });

    describe('getOutputs', () => {
        it('should return current rating value', () => {
            const context = createMockContext({
                ratingValue: createMockProperty(4),
                maxStars: createMockProperty(5),
            });

            control.init(context, notifyOutputChanged, {}, container);
            const outputs = control.getOutputs();

            expect(outputs).toHaveProperty('ratingValue');
        });
    });

    describe('destroy', () => {
        it('should clean up without errors', () => {
            const context = createMockContext({
                ratingValue: createMockProperty(3),
                maxStars: createMockProperty(5),
            });

            control.init(context, notifyOutputChanged, {}, container);

            expect(() => {
                control.destroy();
            }).not.toThrow();
        });
    });
});
```

---

## Test Generation Workflow

Follow these steps when generating tests for existing code:

### Step 1 — Analyze Source Code
- Read the source file(s) thoroughly
- Identify all public methods, event handlers, and lifecycle methods
- Map out logic branches (if/else, switch, try/catch)

### Step 2 — Identify Testable Units
- Each public method → at least one test
- Each conditional branch → positive and negative tests
- Each catch block → error scenario test
- Each external call → mock verification test

### Step 3 — Generate Test File
- Create proper test file structure with setup/teardown
- Follow naming conventions (`MethodName_Scenario_ExpectedResult`)
- Use AAA pattern for every test

### Step 4 — Cover Edge Cases
- Null/undefined inputs
- Empty strings and collections
- Boundary values (0, -1, max int)
- Concurrent scenarios (if applicable)

### Step 5 — Verify Compilation/Execution

```powershell
# C# Plugin Tests
dotnet test --verbosity normal

# JavaScript Web Resource Tests
npx jest --verbose

# TypeScript PCF Tests
npx jest --verbose
```

---

## Scaffold Script

```powershell
.\scripts\scaffold-test-project.ps1 `
    -ProjectType CSharpPlugin `
    -ProjectName "Contoso.Crm.Plugins.Tests" `
    -SourceProjectPath "C:\Dev\Contoso.Crm.Plugins" `
    -OutputPath "C:\Dev\Tests"
```

See: [`scripts/scaffold-test-project.ps1`](scripts/scaffold-test-project.ps1)

---

## References

- Scaffold script: [`scripts/scaffold-test-project.ps1`](scripts/scaffold-test-project.ps1)
- Pattern reference: [`references/test-patterns.md`](references/test-patterns.md)
- [MSTest documentation](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-mstest)
- [Jest documentation](https://jestjs.io/docs/getting-started)
- [Moq documentation](https://github.com/moq/moq4)
