# ZMS2 Package Documentation

## Package Overview

**Package Name**: `ZMS2`  
**Description**: Call auf MS Azure SDK (Azure SDK Integration)  
**Purpose**: Integration layer between SAP and Microsoft Azure services for online shop functionality

## Package Contents

### 1. CDS Views
- [`zhb_i_product.ddls`](#zhb_i_product) - Product master data interface view

### 2. ABAP Classes
- [`zcl_ms1`](#zcl_ms1) - Azure Service Bus integration class
- [`zhb_i_prodcut_sql`](#zhb_i_prodcut_sql) - CDS view test class

### 3. Function Groups
- [`z_online_shop_sdk`](#z_online_shop_sdk) - RFC function module pool

---

## Component Details

### zhb_i_product

**Type**: CDS Interface View  
**Base View**: `I_Product` (Standard SAP Product Master)  
**File**: `zhb_i_product.ddls.asddls`

#### Purpose
Provides a simplified, consumption-ready view of product master data for online shop integration scenarios.

#### Key Characteristics
- **Access Control**: `#NOT_REQUIRED` - No authorization checks
- **Usage Type**: Service quality with mixed data class
- **Size Category**: Small (`#S`)

#### Selected Fields

**Core Product Information**:
- `Product` (Key) - Product number
- `ProductGroup` - Product group classification
- `BaseUnit` - Base unit of measure
- `ItemCategoryGroup` - Item category grouping

**Hierarchy & Organization**:
- `ProductHierarchy` - Product hierarchy assignment
- `Division` - Division assignment
- `ProductCategory` - Product category

**Sales & Distribution**:
- `SalesStatus` - Sales status indicator
- `SalesStatusValidityDate` - Valid from date for sales status
- `TransportationGroup` - Transportation grouping

**Warehouse & Logistics**:
- `WarehouseProductGroup` - Warehouse product group
- `WarehouseStorageCondition` - Storage condition requirements
- `HandlingIndicator` - Handling indicator
- `HandlingUnitType` - Handling unit type
- `StandardHandlingUnitType` - Standard handling unit

**Quality & Compliance**:
- `QualityInspectionGroup` - Quality inspection grouping
- `IsRelevantForHzdsSubstances` - Hazardous substances flag
- `QltyMgmtInProcmtIsActive` - Quality management in procurement

**Custom Fields**:
- `ZZ1_CustomFieldRiskMit_PRD` - Risk mitigation field
- `ZZ1_CustomFieldHighRis_PRD` - High risk indicator
- `ZZ1_CustomFieldRiskRea_PRD` - Risk reason field

#### Associations
Maintains all standard associations from `I_Product` including:
- Text associations (`_MaterialText`, `_ProductGroupText`)
- Unit of measure associations (`_BaseUnitOfMeasure`, `_ContentUnit`)
- Hierarchy associations (`_ProductHierarchy`, `_MDProductHierarchyNode`)
- Related entity associations (`_ProductSales`, `_ProductProcurement`)

#### Usage Example
```abap
SELECT Product, ProductGroup, BaseUnit, SalesStatus
  FROM zhb_i_product
  WHERE ProductGroup = 'L003'
  INTO TABLE @DATA(lt_products).
```

---

### zcl_ms1

**Type**: Public Final Class  
**File**: `zcl_ms1.clas.abap`

#### Purpose
Handles integration between SAP online shop events and Microsoft Azure Service Bus for asynchronous event processing.

#### Class Definition
```abap
CLASS zcl_ms1 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.
```

#### Public Methods

##### abap_sdk_read
Initiates asynchronous processing of online shop order events.

**Signature**:
```abap
CLASS-METHODS abap_sdk_read 
  IMPORTING 
    orderid   TYPE numc08
    createdby TYPE zaonlineshop_ms1-created_by.
```

**Parameters**:
- `orderid` - Order identifier (8-digit numeric)
- `createdby` - User ID who created the order

**Implementation**:
```abap
CALL FUNCTION 'Z_ONLINESHOP_SDK_BUS' IN BACKGROUND TASK
  EXPORTING
    im_order     = orderid
    im_createdby = createdby.
```

**Processing Flow**:
1. Receives order creation event data
2. Delegates to RFC function module in background task
3. Enables asynchronous, non-blocking processing

#### Legacy Implementation (Commented)

The class contains ~140 lines of commented code representing the original direct Azure Service Bus integration:

**Original Architecture**:
1. **Event Structure Creation**
   - Business object: `BUS2015` (Purchase Requisition)
   - Event type: `CREATED`
   - Captures timestamp and object key

2. **JSON Serialization**
   ```abap
   lv_json_output = /ui2/cl_json=>serialize( 
     data        = lv_event
     compress    = abap_true
     pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
   ```

3. **Azure SDK Factory Pattern**
   ```abap
   oref = zcl_adf_service_factory=>create( 
     iv_interface_id        = p_asdkid
     iv_business_identifier = filter ).
   oref_servicebus ?= oref.
   ```

4. **SAS Token Configuration**
   - Expiry time: 15 minutes
   - Token type: Shared Access Signature

5. **Message Transmission**
   - Converts JSON to XSTRING
   - Adds broker properties header: `{"Label":"OnlineShopEvent"}`
   - Sends to Azure Service Bus
   - Validates HTTP status (200/201)

6. **Exception Handling**
   - `zcx_interace_config_missing` - Configuration errors
   - `zcx_http_client_failed` - HTTP failures
   - `zcx_adf_service` - Azure service errors

**Migration Rationale**:
The refactoring from direct Azure SDK calls to RFC-based processing likely addresses:
- Performance optimization (non-blocking operations)
- Error recovery and retry mechanisms
- Separation of concerns
- Scalability for high-volume scenarios

#### Usage Example
```abap
" Trigger Azure Service Bus integration for new order
zcl_ms1=>abap_sdk_read(
  orderid   = '00000123'
  createdby = sy-uname ).
```

---

### zhb_i_prodcut_sql

**Type**: Test/Demo Class  
**File**: `zhb_i_prodcut_sql.clas.abap`  
**Interface**: `if_oo_adt_classrun`

#### Purpose
Provides a simple test harness for validating CDS view `zhb_i_product` accessibility and data retrieval.

#### Class Definition
```abap
CLASS zhb_i_prodcut_sql DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.
  
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
```

#### Implementation
```abap
METHOD if_oo_adt_classrun~main.
  SELECT * FROM zhb_i_product 
    INTO TABLE @DATA(lt_product).
  DATA(a) = 1.
ENDMETHOD.
```

#### ABAP Features Used
- **Modern SQL**: `@` host variable syntax (ABAP 7.40 SP05+)
- **Inline Declaration**: `DATA(lt_product)` (ABAP 7.40+)
- **ADT Integration**: `if_oo_adt_classrun` for F9 execution in Eclipse

#### Execution
Run in ABAP Development Tools (ADT):
1. Open class in Eclipse
2. Press F9 to execute
3. View results in console

#### Notes
- Contains unused variable `DATA(a) = 1` - likely debugging artifact
- No output statements - data loaded but not displayed
- Suitable for quick CDS view validation

#### Enhancement Suggestions
```abap
METHOD if_oo_adt_classrun~main.
  SELECT Product, ProductGroup, BaseUnit
    FROM zhb_i_product
    WHERE ProductGroup = 'L003'
    INTO TABLE @DATA(lt_product)
    UP TO 10 ROWS.
    
  out->write( |Found { lines( lt_product ) } products| ).
  
  LOOP AT lt_product INTO DATA(ls_product).
    out->write( |Product: { ls_product-product }, | &&
                |Group: { ls_product-productgroup }| ).
  ENDLOOP.
ENDMETHOD.
```

---

### z_online_shop_sdk

**Type**: Function Group (Function Pool)  
**Files**: 
- `z_online_shop_sdk.fugr.saplz_online_shop_sdk.abap` (Main pool)
- `z_online_shop_sdk.fugr.lz_online_shop_sdktop.abap` (TOP include)

#### Purpose
Contains RFC-enabled function modules for background processing of online shop Azure integration.

#### Structure

**Main Pool** (`saplz_online_shop_sdk.abap`):
```abap
*******************************************************************
*   System-defined Include-files.
*******************************************************************
INCLUDE LZ_ONLINE_SHOP_SDKTOP.             " Global Declarations
INCLUDE LZ_ONLINE_SHOP_SDKUXX.             " Function Modules
```

**TOP Include** (`lz_online_shop_sdktop.abap`):
```abap
FUNCTION-POOL Z_ONLINE_SHOP_SDK.
```

#### Standard Include Structure
- `LXXTOP` - Global data declarations
- `LXXUXX` - Function module implementations
- `LXXF**` - Subroutines (optional)
- `LXXO**` - PBO modules (optional)
- `LXXI**` - PAI modules (optional)
- `LXXE**` - Events (optional)
- `LXXP**` - Local class implementations (optional)
- `LXXT99` - ABAP Unit tests (optional)

#### Expected Function Module

**Name**: `Z_ONLINESHOP_SDK_BUS` (referenced in `zcl_ms1`)

**Expected Signature**:
```abap
FUNCTION Z_ONLINESHOP_SDK_BUS.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IM_ORDER) TYPE  NUMC08
*"     VALUE(IM_CREATEDBY) TYPE  ZAONLINESHOP_MS1-CREATED_BY
*"----------------------------------------------------------------------

  " Implementation:
  " 1. Validate input parameters
  " 2. Create Azure Service Bus event structure
  " 3. Serialize to JSON
  " 4. Send to Azure Service Bus
  " 5. Log results
  " 6. Handle exceptions

ENDFUNCTION.
```

**RFC Properties**:
- Processing Type: RFC-enabled
- Start Type: Can be started immediately
- Update Task: Background processing

#### Usage Pattern
```abap
" Synchronous call (blocks until completion)
CALL FUNCTION 'Z_ONLINESHOP_SDK_BUS'
  EXPORTING
    im_order     = lv_order_id
    im_createdby = sy-uname.

" Asynchronous call (non-blocking)
CALL FUNCTION 'Z_ONLINESHOP_SDK_BUS' IN BACKGROUND TASK
  EXPORTING
    im_order     = lv_order_id
    im_createdby = sy-uname.

" Commit work to trigger background RFC
COMMIT WORK.
```

---

## Architecture Overview

### Integration Flow

```
┌─────────────────┐
│  Online Shop    │
│  Application    │
└────────┬────────┘
         │ Order Created Event
         ▼
┌─────────────────┐
│   zcl_ms1       │
│ ::abap_sdk_read │
└────────┬────────┘
         │ Background RFC
         ▼
┌─────────────────────────┐
│ Z_ONLINESHOP_SDK_BUS    │
│ (Function Module)       │
└────────┬────────────────┘
         │ HTTP/REST
         ▼
┌─────────────────────────┐
│ Azure Service Bus       │
│ (Queue/Topic)           │
└─────────────────────────┘
```

### Data Flow

```
┌──────────────┐
│ SAP Product  │
│ Master Data  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ I_Product    │
│ (Standard)   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│zhb_i_product │
│ (Custom CDS) │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Online Shop  │
│ Application  │
└──────────────┘
```

### Design Patterns

1. **Factory Pattern**: Azure SDK service instantiation (legacy code)
2. **Asynchronous Processing**: Background RFC for non-blocking operations
3. **Separation of Concerns**: CDS for data, classes for logic, function modules for RFC
4. **Exception Handling**: Structured exception classes for error management

---

## Technical Requirements

### ABAP Version Compatibility

| Feature | Minimum Release | Used In |
|---------|----------------|---------|
| Inline declarations (`DATA(...)`) | 7.40 SP08 | All classes |
| `@` host variables in SQL | 7.40 SP05 | Test class |
| CDS views | 7.40 SP05 | zhb_i_product |
| Constructor expressions | 7.40 SP08 | Legacy code |
| `if_oo_adt_classrun` | 7.40 | Test class |

**Recommended**: ABAP 7.50+ or S/4HANA 1809+

### Required Components

- SAP NetWeaver 7.40 SP05 or higher
- CDS view support
- RFC/aRFC capability
- HTTP client for Azure connectivity (if using direct integration)

### Custom Objects Referenced

- `zaonlineshop_ms1` - Database table/structure
- `zcl_adf_service_factory` - Azure SDK factory class (legacy)
- `zcl_adf_service_servicebus` - Service Bus client (legacy)
- `zcx_interace_config_missing` - Exception class
- `zcx_http_client_failed` - Exception class
- `zcx_adf_service` - Exception class

---

## Configuration

### Azure Service Bus Setup (Legacy)

1. **Interface Configuration**
   - Interface ID: Stored in configuration table
   - Business identifier: Filter criteria

2. **Authentication**
   - SAS (Shared Access Signature) token
   - Expiry: 15 minutes (configurable)

3. **Message Properties**
   - Broker Properties: `{"Label":"OnlineShopEvent"}`
   - Content Type: JSON
   - Encoding: UTF-8 (via XSTRING)

### RFC Configuration (Current)

1. **Function Module**: `Z_ONLINESHOP_SDK_BUS`
2. **Processing**: Background task (asynchronous)
3. **Commit**: Required after CALL FUNCTION to trigger execution

---

## Error Handling

### Exception Classes

1. **zcx_interace_config_missing**
   - Trigger: Missing or invalid interface configuration
   - Action: Check configuration tables

2. **zcx_http_client_failed**
   - Trigger: HTTP communication failure
   - Action: Verify network connectivity, Azure endpoint

3. **zcx_adf_service**
   - Trigger: Azure service-specific errors
   - Action: Check Azure Service Bus status, credentials

### HTTP Status Codes

- `200` - OK (Success)
- `201` - Created (Success)
- Other codes - Error condition

---

## Testing

### Unit Testing

**Test Class**: `zhb_i_prodcut_sql`
```abap
" Execute in ADT with F9
" Validates CDS view accessibility
```

### Integration Testing

```abap
" Test Azure integration
DATA(lv_order_id) = '00000001'.
DATA(lv_user) = 'TESTUSER'.

TRY.
    zcl_ms1=>abap_sdk_read(
      orderid   = lv_order_id
      createdby = lv_user ).
    COMMIT WORK.
    WRITE: / 'Integration test successful'.
  CATCH cx_root INTO DATA(lx_error).
    WRITE: / 'Error:', lx_error->get_text( ).
ENDTRY.
```

### CDS View Testing

```abap
" Test product data retrieval
SELECT Product, ProductGroup, SalesStatus
  FROM zhb_i_product
  WHERE ProductGroup = 'L003'
  INTO TABLE @DATA(lt_test_products)
  UP TO 5 ROWS.

LOOP AT lt_test_products INTO DATA(ls_product).
  WRITE: / ls_product-product, ls_product-productgroup.
ENDLOOP.
```

---

## Maintenance & Support

### Known Issues

1. **Typo in Class Name**: `zhb_i_prodcut_sql` should be `zhb_i_product_sql`
2. **Commented Code**: 140+ lines of legacy Azure SDK code should be removed or documented
3. **Unused Variable**: `DATA(a) = 1` in test class serves no purpose

### Recommendations

1. **Code Cleanup**
   - Remove or archive commented legacy code
   - Document migration rationale
   - Fix class name typo

2. **Documentation**
   - Add method-level documentation
   - Document custom fields purpose
   - Create sequence diagrams

3. **Enhancement**
   - Add error logging
   - Implement retry mechanism
   - Add monitoring/alerting

4. **Testing**
   - Create comprehensive unit tests
   - Add integration test suite
   - Implement mock Azure Service Bus for testing

---

## Related Documentation

- [Azure Service Bus Documentation](https://docs.microsoft.com/azure/service-bus-messaging/)
- [SAP CDS Views Guide](https://help.sap.com/docs/ABAP_PLATFORM/cc0c305d2fab47bd808adcad3ca7ee9d/4ed1f2e06e391014adc9fffe4e204223.html)
- [ABAP RFC Programming](https://help.sap.com/docs/ABAP_PLATFORM/753088fc00704d0a80e7fbd6803c8adb/4888e7e86e391014adc9fffe4e204223.html)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | - | - | Initial implementation with direct Azure SDK |
| 2.0 | - | - | Refactored to RFC-based background processing |

---

## Contact & Support

For questions or issues related to this package, contact the development team or refer to the project's issue tracking system.