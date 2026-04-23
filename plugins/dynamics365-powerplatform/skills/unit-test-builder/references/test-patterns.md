# Test Patterns Reference

> **Language Rule:** Always respond to the user in the same language they use.

---

## C# MSTest Attributes Reference

| Attribute | Scope | Description |
|-----------|-------|-------------|
| `[TestClass]` | Class | Marks a class as containing test methods |
| `[TestMethod]` | Method | Marks a method as a test |
| `[TestInitialize]` | Method | Runs before each test method |
| `[TestCleanup]` | Method | Runs after each test method |
| `[ClassInitialize]` | Static method | Runs once before all tests in the class |
| `[ClassCleanup]` | Static method | Runs once after all tests in the class |
| `[DataTestMethod]` | Method | Data-driven test method (use with `[DataRow]`) |
| `[DataRow(...)]` | Method | Provides inline data for a `[DataTestMethod]` |
| `[TestCategory("name")]` | Method/Class | Categorizes tests for selective execution |
| `[ExpectedException(typeof(T))]` | Method | Test passes if the specified exception is thrown |
| `[Timeout(ms)]` | Method | Fails the test if it exceeds the specified duration |
| `[Ignore("reason")]` | Method | Skips the test with a reason |
| `[Priority(n)]` | Method | Sets execution priority (lower = first) |

### Assert Methods

```csharp
Assert.AreEqual(expected, actual);
Assert.AreEqual(expected, actual, "Message");
Assert.AreNotEqual(unexpected, actual);
Assert.IsTrue(condition);
Assert.IsFalse(condition);
Assert.IsNull(obj);
Assert.IsNotNull(obj);
Assert.IsInstanceOfType(obj, typeof(T));
Assert.ThrowsException<T>(() => action());
await Assert.ThrowsExceptionAsync<T>(async () => await action());
CollectionAssert.Contains(collection, element);
CollectionAssert.AreEqual(expected, actual);
CollectionAssert.AllItemsAreNotNull(collection);
StringAssert.Contains(actual, substring);
StringAssert.StartsWith(actual, prefix);
StringAssert.Matches(actual, regex);
```

### DataRow Example

```csharp
[DataTestMethod]
[DataRow("Create", true)]
[DataRow("Update", true)]
[DataRow("Delete", false)]
[DataRow("Retrieve", false)]
[TestCategory("Plugin")]
public void Execute_MessageFilter_ShouldProcessOnlyCreateAndUpdate(string message, bool shouldProcess)
{
    // Arrange
    _contextMock.Setup(c => c.MessageName).Returns(message);

    // Act & Assert
    if (shouldProcess)
        Assert.IsTrue(ProcessMessage(message));
    else
        Assert.IsFalse(ProcessMessage(message));
}
```

---

## Moq API Cheat Sheet

### Setup

```csharp
// Basic setup with return value
mock.Setup(x => x.Method(It.IsAny<string>())).Returns("result");

// Async setup
mock.Setup(x => x.MethodAsync(It.IsAny<int>())).ReturnsAsync("result");

// Setup with callback
mock.Setup(x => x.Method(It.IsAny<string>()))
    .Callback<string>(arg => capturedArg = arg)
    .Returns("result");

// Setup property
mock.Setup(x => x.PropertyName).Returns("value");
mock.SetupGet(x => x.PropertyName).Returns("value");
mock.SetupSet(x => x.PropertyName = It.IsAny<string>());

// Setup sequence (different results per call)
mock.SetupSequence(x => x.Method())
    .Returns("first")
    .Returns("second")
    .Throws<InvalidOperationException>();

// Throw exception
mock.Setup(x => x.Method()).Throws<InvalidOperationException>();
mock.Setup(x => x.Method()).Throws(new Exception("message"));
```

### Argument Matchers (It.*)

```csharp
It.IsAny<T>()                          // Matches any value of type T
It.Is<T>(x => x > 5)                   // Matches values satisfying predicate
It.IsIn("a", "b", "c")                 // Matches if value is in set
It.IsNotIn("x", "y")                   // Matches if value is not in set
It.IsInRange(1, 10, Moq.Range.Inclusive) // Matches values in range
It.IsRegex(@"^\d+$")                   // Matches strings by regex
It.IsNotNull<T>()                      // Matches non-null values
```

### Verify

```csharp
// Verify method was called
mock.Verify(x => x.Method(), Times.Once);
mock.Verify(x => x.Method(), Times.Never);
mock.Verify(x => x.Method(), Times.Exactly(3));
mock.Verify(x => x.Method(), Times.AtLeastOnce);
mock.Verify(x => x.Method(), Times.AtMost(5));
mock.Verify(x => x.Method(), Times.Between(1, 3, Moq.Range.Inclusive));

// Verify with argument matching
mock.Verify(x => x.Method(It.Is<string>(s => s.Contains("test"))), Times.Once);

// Verify property was accessed
mock.VerifyGet(x => x.PropertyName, Times.Once);

// Verify no other calls were made
mock.VerifyNoOtherCalls();
```

---

## Common Mock Setups for Dataverse Services

### IOrganizationService — All Methods

```csharp
// Create
_serviceMock.Setup(s => s.Create(It.IsAny<Entity>()))
    .Returns(Guid.NewGuid());

// Retrieve
_serviceMock.Setup(s => s.Retrieve(
    It.IsAny<string>(),
    It.IsAny<Guid>(),
    It.IsAny<ColumnSet>()))
    .Returns(new Entity("account") { ["name"] = "Mock Account" });

// Update
_serviceMock.Setup(s => s.Update(It.IsAny<Entity>()));

// Delete
_serviceMock.Setup(s => s.Delete(It.IsAny<string>(), It.IsAny<Guid>()));

// RetrieveMultiple
_serviceMock.Setup(s => s.RetrieveMultiple(It.IsAny<QueryBase>()))
    .Returns(new EntityCollection(new List<Entity>
    {
        new Entity("account") { Id = Guid.NewGuid(), ["name"] = "Account 1" },
        new Entity("account") { Id = Guid.NewGuid(), ["name"] = "Account 2" },
    }));

// Execute (generic)
_serviceMock.Setup(s => s.Execute(It.IsAny<OrganizationRequest>()))
    .Returns(new OrganizationResponse());

// Execute (specific request type)
_serviceMock.Setup(s => s.Execute(It.IsAny<RetrieveRequest>()))
    .Returns(new RetrieveResponse
    {
        Results = new ParameterCollection
        {
            { "Entity", new Entity("account") { ["name"] = "Retrieved" } }
        }
    });

// Associate / Disassociate
_serviceMock.Setup(s => s.Associate(
    It.IsAny<string>(), It.IsAny<Guid>(),
    It.IsAny<Relationship>(), It.IsAny<EntityReferenceCollection>()));
_serviceMock.Setup(s => s.Disassociate(
    It.IsAny<string>(), It.IsAny<Guid>(),
    It.IsAny<Relationship>(), It.IsAny<EntityReferenceCollection>()));
```

### Context Properties

```csharp
// Message and entity
_contextMock.Setup(c => c.MessageName).Returns("Create");
_contextMock.Setup(c => c.PrimaryEntityName).Returns("account");
_contextMock.Setup(c => c.PrimaryEntityId).Returns(Guid.NewGuid());

// Stage and mode
_contextMock.Setup(c => c.Stage).Returns(20); // Pre-operation
_contextMock.Setup(c => c.Mode).Returns(0);   // Synchronous

// User context
_contextMock.Setup(c => c.UserId).Returns(Guid.NewGuid());
_contextMock.Setup(c => c.InitiatingUserId).Returns(Guid.NewGuid());
_contextMock.Setup(c => c.BusinessUnitId).Returns(Guid.NewGuid());
_contextMock.Setup(c => c.OrganizationId).Returns(Guid.NewGuid());

// Depth
_contextMock.Setup(c => c.Depth).Returns(1);

// Input/Output parameters
var inputParams = new ParameterCollection { { "Target", targetEntity } };
_contextMock.Setup(c => c.InputParameters).Returns(inputParams);

var outputParams = new ParameterCollection { { "id", Guid.NewGuid() } };
_contextMock.Setup(c => c.OutputParameters).Returns(outputParams);

// Images
var preImages = new EntityImageCollection { { "PreImage", preImageEntity } };
_contextMock.Setup(c => c.PreEntityImages).Returns(preImages);

var postImages = new EntityImageCollection { { "PostImage", postImageEntity } };
_contextMock.Setup(c => c.PostEntityImages).Returns(postImages);

// Shared variables
var sharedVars = new ParameterCollection();
_contextMock.Setup(c => c.SharedVariables).Returns(sharedVars);

// Parent context
_contextMock.Setup(c => c.ParentContext).Returns((IPluginExecutionContext)null);

// Transaction state
_contextMock.Setup(c => c.IsInTransaction).Returns(true);
_contextMock.Setup(c => c.IsExecutingOffline).Returns(false);
```

---

## Jest API Cheat Sheet

### Test Structure

```javascript
describe('GroupName', () => {
    beforeAll(() => { /* once before all tests */ });
    afterAll(() => { /* once after all tests */ });
    beforeEach(() => { /* before each test */ });
    afterEach(() => { /* after each test */ });

    it('should do something', () => { /* test */ });
    test('does something', () => { /* alternative syntax */ });

    it.only('focuses on this test', () => { /* skips all others */ });
    it.skip('skips this test', () => { /* not executed */ });
    it.todo('needs implementation');

    describe('nested group', () => {
        it('can nest describes', () => { });
    });
});
```

### Expect Matchers

```javascript
// Equality
expect(value).toBe(exact);                    // === comparison
expect(value).toEqual(deepEqual);             // Deep equality
expect(value).toStrictEqual(strictDeep);      // Deep + type checking

// Truthiness
expect(value).toBeTruthy();
expect(value).toBeFalsy();
expect(value).toBeNull();
expect(value).toBeUndefined();
expect(value).toBeDefined();
expect(value).toBeNaN();

// Numbers
expect(value).toBeGreaterThan(3);
expect(value).toBeGreaterThanOrEqual(3);
expect(value).toBeLessThan(10);
expect(value).toBeCloseTo(0.3, 5);           // Floating point

// Strings
expect(str).toMatch(/regex/);
expect(str).toContain('substring');
expect(str).toHaveLength(5);

// Arrays / Iterables
expect(arr).toContain(item);
expect(arr).toContainEqual({ a: 1 });
expect(arr).toHaveLength(3);
expect(arr).toEqual(expect.arrayContaining([1, 2]));

// Objects
expect(obj).toHaveProperty('key');
expect(obj).toHaveProperty('key', 'value');
expect(obj).toMatchObject({ key: 'value' });
expect(obj).toEqual(expect.objectContaining({ key: 'value' }));

// Exceptions
expect(() => fn()).toThrow();
expect(() => fn()).toThrow('message');
expect(() => fn()).toThrow(ErrorType);
expect(async () => await fn()).rejects.toThrow();

// Negation
expect(value).not.toBe(other);
```

### Mock Functions

```javascript
// Create mock
const fn = jest.fn();
const fn = jest.fn().mockReturnValue(42);
const fn = jest.fn().mockResolvedValue('async result');
const fn = jest.fn().mockRejectedValue(new Error('fail'));
const fn = jest.fn().mockImplementation((x) => x * 2);

// Mock return values per call
fn.mockReturnValueOnce(1).mockReturnValueOnce(2).mockReturnValue(99);

// Verify calls
expect(fn).toHaveBeenCalled();
expect(fn).toHaveBeenCalledTimes(3);
expect(fn).toHaveBeenCalledWith('arg1', 'arg2');
expect(fn).toHaveBeenLastCalledWith('lastArg');
expect(fn).toHaveBeenNthCalledWith(2, 'secondCallArg');
expect(fn).toHaveReturned();
expect(fn).toHaveReturnedWith(42);

// Access call data
fn.mock.calls          // [[arg1, arg2], [arg1, arg2], ...]
fn.mock.results         // [{ type: 'return', value: 42 }, ...]
fn.mock.calls.length    // Number of times called

// Module mocking
jest.mock('./module');
jest.mock('./module', () => ({ fn: jest.fn().mockReturnValue('mocked') }));

// Clear / Reset
jest.clearAllMocks();   // Clear call history (keeps implementation)
jest.resetAllMocks();   // Reset to jest.fn() (removes implementation)
jest.restoreAllMocks(); // Restore original (for spyOn)
```

---

## Xrm Mock Object Patterns (Complete Namespace)

```javascript
global.Xrm = {
    // ─── WebApi ───
    WebApi: {
        createRecord: jest.fn((entityName, data) =>
            Promise.resolve({ id: 'mock-guid-001' })),
        retrieveRecord: jest.fn((entityName, id, options) =>
            Promise.resolve({ name: 'Mock Record', [`${entityName}id`]: id })),
        updateRecord: jest.fn((entityName, id, data) =>
            Promise.resolve({ entityType: entityName, id })),
        deleteRecord: jest.fn((entityName, id) =>
            Promise.resolve({ entityType: entityName, id })),
        retrieveMultipleRecords: jest.fn((entityName, options, maxPageSize) =>
            Promise.resolve({ entities: [], nextLink: null })),
        online: {
            execute: jest.fn().mockResolvedValue({ ok: true }),
            executeMultiple: jest.fn().mockResolvedValue([]),
        },
    },

    // ─── Navigation ───
    Navigation: {
        openAlertDialog: jest.fn(() => Promise.resolve()),
        openConfirmDialog: jest.fn(() => Promise.resolve({ confirmed: true })),
        openForm: jest.fn(() => Promise.resolve({ savedEntityReference: [] })),
        openUrl: jest.fn(),
        openWebResource: jest.fn(),
        openErrorDialog: jest.fn(() => Promise.resolve()),
    },

    // ─── Utility ───
    Utility: {
        getGlobalContext: jest.fn(() => ({
            getClientUrl: jest.fn(() => 'https://org.crm.dynamics.com'),
            getVersion: jest.fn(() => '9.2.0.0'),
            getUserId: jest.fn(() => '{00000000-0000-0000-0000-000000000001}'),
            getUserName: jest.fn(() => 'Test User'),
            getOrgUniqueName: jest.fn(() => 'testorg'),
            getOrgLcid: jest.fn(() => 1033),
            getUserLcid: jest.fn(() => 1033),
            isOnPremises: jest.fn(() => false),
            client: {
                getClient: jest.fn(() => 'Web'),
                getClientState: jest.fn(() => 'Online'),
            },
            userSettings: {
                languageId: 1033,
                userId: '{00000000-0000-0000-0000-000000000001}',
                userName: 'Test User',
                securityRoles: ['00000000-0000-0000-0000-000000000099'],
                isGuidedHelpEnabled: false,
                dateFormattingInfo: { },
            },
        })),
        getEntityMetadata: jest.fn(() => Promise.resolve({
            LogicalName: 'account',
            DisplayName: 'Account',
        })),
        showProgressIndicator: jest.fn(),
        closeProgressIndicator: jest.fn(),
        getResourceString: jest.fn((webResourceName, key) => key),
        lookupObjects: jest.fn(() => Promise.resolve([])),
        refreshParentGrid: jest.fn(),
    },

    // ─── App ───
    App: {
        addGlobalNotification: jest.fn(() => Promise.resolve('notification-id')),
        clearGlobalNotification: jest.fn(() => Promise.resolve()),
        sidePanes: {
            createPane: jest.fn(() => ({ navigate: jest.fn(), close: jest.fn() })),
        },
    },

    // ─── Panel ───
    Panel: {
        loadPanel: jest.fn(),
    },

    // ─── Device ───
    Device: {
        captureImage: jest.fn(() => Promise.resolve({ fileContent: '', mimeType: 'image/png' })),
        pickFile: jest.fn(() => Promise.resolve([])),
        getBarcodeValue: jest.fn(() => Promise.resolve('')),
        getCurrentPosition: jest.fn(() => Promise.resolve({ coords: {} })),
    },

    // ─── Encoding ───
    Encoding: {
        htmlAttributeEncode: jest.fn((s) => s),
        htmlDecode: jest.fn((s) => s),
        htmlEncode: jest.fn((s) => s),
        xmlAttributeEncode: jest.fn((s) => s),
        xmlEncode: jest.fn((s) => s),
    },
};
```

---

## ComponentFramework Context Mock Patterns

```typescript
// Full context mock factory
function createMockContext<TInputs>(params: Partial<TInputs>): any {
    return {
        parameters: params as TInputs,
        mode: {
            isControlDisabled: false,
            isVisible: true,
            label: 'Test',
            allocatedWidth: 300,
            allocatedHeight: 200,
            isHighContrastEnabled: false,
            setControlState: jest.fn(),
            trackContainerResize: jest.fn(),
            setFullScreen: jest.fn(),
        },
        webAPI: {
            createRecord: jest.fn().mockResolvedValue({ id: 'new-id' }),
            retrieveRecord: jest.fn().mockResolvedValue({}),
            updateRecord: jest.fn().mockResolvedValue({}),
            deleteRecord: jest.fn().mockResolvedValue({}),
            retrieveMultipleRecords: jest.fn().mockResolvedValue({
                entities: [], nextLink: null,
            }),
        },
        navigation: {
            openForm: jest.fn().mockResolvedValue({}),
            openAlertDialog: jest.fn().mockResolvedValue({}),
            openConfirmDialog: jest.fn().mockResolvedValue({ confirmed: true }),
            openUrl: jest.fn(),
            openWebResource: jest.fn(),
        },
        resources: {
            getString: jest.fn((key: string) => `[${key}]`),
            getResource: jest.fn(),
        },
        formatting: {
            formatCurrency: jest.fn((v: number) => `$${v.toFixed(2)}`),
            formatDecimal: jest.fn((v: number, p: number) => v.toFixed(p)),
            formatInteger: jest.fn((v: number) => v.toString()),
            formatDateAsFilterStringInUTC: jest.fn((d: Date) => d.toISOString()),
            formatDateLong: jest.fn((d: Date) => d.toLocaleDateString()),
            formatDateShort: jest.fn((d: Date) => d.toLocaleDateString()),
        },
        updatedProperties: [],
        utils: {
            hasEntityPrivilege: jest.fn().mockReturnValue(true),
            lookupObjects: jest.fn().mockResolvedValue([]),
        },
    };
}

// Dataset mock factory
function createMockDataset(records: any[] = []): any {
    const recordMap: Record<string, any> = {};
    const ids = records.map((r, i) => {
        const id = r.id || `record-${i}`;
        recordMap[id] = {
            getRecordId: () => id,
            getNamedReference: () => ({ id, name: r.name || '' }),
            getValue: (col: string) => r[col],
            getFormattedValue: (col: string) => String(r[col] ?? ''),
        };
        return id;
    });

    return {
        sortedRecordIds: ids,
        records: recordMap,
        columns: Object.keys(records[0] || {}).map((name, order) => ({
            name,
            displayName: name,
            dataType: 'string',
            alias: name,
            order,
            visualSizeFactor: 1,
            isHidden: false,
            isPrimary: order === 0,
            disableSorting: false,
        })),
        paging: {
            totalResultCount: records.length,
            pageSize: 50,
            hasNextPage: false,
            hasPreviousPage: false,
            loadNextPage: jest.fn(),
            loadPreviousPage: jest.fn(),
            loadExactPage: jest.fn(),
            setPageSize: jest.fn(),
            reset: jest.fn(),
        },
        sorting: [],
        filtering: {
            getFilter: jest.fn().mockReturnValue({ conditions: [], filterOperator: 0 }),
            setFilter: jest.fn(),
            clearFilter: jest.fn(),
        },
        loading: false,
        error: false,
        errorMessage: '',
        refresh: jest.fn(),
        openDatasetItem: jest.fn(),
        getTitle: jest.fn().mockReturnValue('Mock Dataset'),
        getViewId: jest.fn().mockReturnValue('mock-view-id'),
    };
}
```

---

## Test Data Generation Patterns for D365 Entities

### C# — Entity Factory

```csharp
public static class TestEntityFactory
{
    private static readonly Random _random = new Random();

    public static Entity CreateAccount(
        Guid? id = null,
        string name = null,
        decimal? revenue = null,
        Guid? primaryContactId = null)
    {
        var entity = new Entity("account", id ?? Guid.NewGuid());
        entity["name"] = name ?? $"Test Account {_random.Next(1000)}";
        entity["revenue"] = new Money(revenue ?? _random.Next(10000, 10000000));
        entity["statecode"] = new OptionSetValue(0); // Active
        entity["statuscode"] = new OptionSetValue(1);
        if (primaryContactId.HasValue)
            entity["primarycontactid"] = new EntityReference("contact", primaryContactId.Value);
        return entity;
    }

    public static Entity CreateContact(
        Guid? id = null,
        string firstName = null,
        string lastName = null,
        string email = null)
    {
        var entity = new Entity("contact", id ?? Guid.NewGuid());
        entity["firstname"] = firstName ?? "Test";
        entity["lastname"] = lastName ?? $"Contact {_random.Next(1000)}";
        entity["emailaddress1"] = email ?? $"test{_random.Next(10000)}@example.com";
        entity["statecode"] = new OptionSetValue(0);
        entity["statuscode"] = new OptionSetValue(1);
        return entity;
    }

    public static EntityReference CreateEntityRef(string entityName, Guid? id = null, string name = null)
    {
        return new EntityReference(entityName, id ?? Guid.NewGuid()) { Name = name ?? entityName };
    }
}
```

### JavaScript — Test Data Helper

```javascript
const TestData = {
    guid: () => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0;
        return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
    }),

    account: (overrides = {}) => ({
        accountid: TestData.guid(),
        name: `Test Account ${Math.floor(Math.random() * 1000)}`,
        revenue: Math.floor(Math.random() * 10000000),
        statecode: 0,
        statuscode: 1,
        ...overrides,
    }),

    contact: (overrides = {}) => ({
        contactid: TestData.guid(),
        firstname: 'Test',
        lastname: `Contact ${Math.floor(Math.random() * 1000)}`,
        emailaddress1: `test${Math.floor(Math.random() * 10000)}@example.com`,
        statecode: 0,
        statuscode: 1,
        ...overrides,
    }),

    entityReference: (entityName, id, name) => ({
        entityType: entityName,
        id: id || TestData.guid(),
        name: name || entityName,
    }),
};

module.exports = { TestData };
```

---

## Code Coverage Configuration

### C# — Coverlet

Add to test `.csproj`:

```xml
<PackageReference Include="coverlet.collector" Version="6.0.0">
  <PrivateAssets>all</PrivateAssets>
  <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
</PackageReference>
```

Run:

```powershell
dotnet test --collect:"XPlat Code Coverage"
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura
```

Generate report:

```powershell
dotnet tool install --global dotnet-reportgenerator-globaltool
reportgenerator -reports:coverage.cobertura.xml -targetdir:coveragereport -reporttypes:Html
```

### JavaScript / TypeScript — Jest Coverage

```powershell
npx jest --coverage
```

Configure in `jest.config.js`:

```javascript
module.exports = {
    collectCoverage: true,
    collectCoverageFrom: [
        'src/**/*.{js,ts,tsx}',
        '!src/**/*.d.ts',
        '!src/**/index.ts',
    ],
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'text-summary', 'lcov', 'clover'],
    coverageThresholds: {
        global: {
            branches: 80,
            functions: 80,
            lines: 80,
            statements: 80,
        },
    },
};
```
