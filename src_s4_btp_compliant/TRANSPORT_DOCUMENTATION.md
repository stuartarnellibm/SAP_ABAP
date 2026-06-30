# SAP CTS Transport Documentation
## S4/BTP Migration - Online Shop Azure Integration

---

## Transport Overview

| Attribute | Value |
|-----------|-------|
| **Transport Type** | Workbench Transport |
| **Change Category** | Enhancement/Migration |
| **Priority** | High |
| **Risk Level** | Medium |
| **Target Systems** | DEV → QAS → PRD |
| **Estimated Downtime** | None (new package) |

---

## 1. Transport Request Structure

### 1.1 Main Transport Request

```
Transport Request: <DEVK9XXXXX>
Description: S4/BTP Migration - Online Shop Azure Integration to ABAP Cloud
Owner: <Developer Name>
Target: <System Landscape>
```

### 1.2 Transport Tasks

#### Task 1: Package Creation
```
Task: <DEVK9XXXXX>
Description: Create new package ZMS2_CLOUD for S4/BTP compliant objects
Objects:
  - DEVC ZMS2_CLOUD (Package)
```

#### Task 2: Core Integration Classes
```
Task: <DEVK9XXXXX>
Description: Create S4/BTP compliant integration classes
Objects:
  - CLAS ZCL_ONLINE_SHOP_INTEGRATION (Integration Class)
  - CLAS ZCX_INTEGRATION_ERROR (Exception Class)
```

#### Task 3: CDS Views and Service Definition
```
Task: <DEVK9XXXXX>
Description: Create ABAP Cloud compliant CDS views and OData service
Objects:
  - DDLS ZHB_I_PRODUCT (CDS Interface View)
  - DDLS ZHB_C_PRODUCT (CDS Consumption View)
  - DDLX ZHB_C_PRODUCT (Metadata Extension)
  - DCLS ZHB_I_PRODUCT (Access Control)
  - SRVD ZHB_SD_PRODUCT (Service Definition)
  - SRVB ZHB_SB_PRODUCT_O4 (Service Binding)
```

---

## 2. Object List

### 2.1 New Objects (To Be Created)

| Object Type | Object Name | Description | Package |
|-------------|-------------|-------------|---------|
| DEVC | ZMS2_CLOUD | S4/BTP Compliant Package | - |
| CLAS | ZCL_ONLINE_SHOP_INTEGRATION | Main integration class | ZMS2_CLOUD |
| CLAS | ZCX_INTEGRATION_ERROR | Custom exception class | ZMS2_CLOUD |
| DDLS | ZHB_I_PRODUCT | Product interface view | ZMS2_CLOUD |
| DDLS | ZHB_C_PRODUCT | Product consumption view | ZMS2_CLOUD |
| DDLX | ZHB_C_PRODUCT | Metadata extension | ZMS2_CLOUD |
| DCLS | ZHB_I_PRODUCT | Access control definition | ZMS2_CLOUD |
| SRVD | ZHB_SD_PRODUCT | Service definition | ZMS2_CLOUD |
| SRVB | ZHB_SB_PRODUCT_O4 | OData V4 service binding | ZMS2_CLOUD |

### 2.2 Modified Objects (Reference Only)

| Object Type | Object Name | Change Type | Notes |
|-------------|-------------|-------------|-------|
| CLAS | ZCL_MS1 | Reference | Original class remains unchanged |
| FUGR | Z_ONLINE_SHOP_SDK | Reference | Original function group remains |

### 2.3 Deprecated Objects (Not Transported)

| Object Type | Object Name | Status | Reason |
|-------------|-------------|--------|--------|
| Custom SDK | ZCL_ADF_SERVICE_FACTORY | Not used | Replaced by standard HTTP client |
| Custom SDK | ZCL_ADF_SERVICE_SERVICEBUS | Not used | Replaced by Communication Arrangement |
| Custom Exception | ZCX_INTERACE_CONFIG_MISSING | Not used | Replaced by ZCX_INTEGRATION_ERROR |
| Custom Exception | ZCX_HTTP_CLIENT_FAILED | Not used | Replaced by ZCX_INTEGRATION_ERROR |
| Custom Exception | ZCX_ADF_SERVICE | Not used | Replaced by ZCX_INTEGRATION_ERROR |

---

## 3. Pre-Transport Checklist

### 3.1 Development System (DEV)

- [ ] All objects created in package ZMS2_CLOUD
- [ ] Package assigned to transport layer (e.g., ZDEV)
- [ ] All objects syntax-checked successfully
- [ ] Unit tests executed (if applicable)
- [ ] Code review completed
- [ ] ABAP Cloud compliance verified using ATC checks
- [ ] All objects activated
- [ ] Transport request released

### 3.2 Code Quality Checks

```abap
" Run ATC checks with ABAP Cloud profile
" Transaction: ATC
" Check Variant: ABAP_CLOUD_DEVELOPMENT
```

**Expected Results:**
- ✅ No errors for released API usage
- ✅ No warnings for deprecated function modules
- ✅ All CDS views use released data sources
- ✅ HTTP client uses Communication Arrangements

### 3.3 Dependencies Verification

**Required Standard Objects (Must exist in target):**
- `I_Product` (Standard CDS view)
- `CL_HTTP_CLIENT` (Released HTTP client class)
- `/UI2/CL_JSON` (Released JSON serializer)
- `CL_BGMC_PROCESS_FACTORY` (Background Processing Framework)

**Custom Dependencies:**
- None (fully self-contained in ZMS2_CLOUD package)

---

## 4. Transport Instructions

### 4.1 Export from DEV

```bash
# Transaction: SE09 / SE10
# 1. Select transport request <DEVK9XXXXX>
# 2. Release all tasks
# 3. Release transport request
# 4. Verify export log for errors
```

**Export Verification:**
```
Check export log: /usr/sap/trans/log/DEVK9XXXXX.<SID>
Expected: Return code 0000 (Success)
```

### 4.2 Import to QAS

```bash
# Transaction: STMS (Transport Management System)
# 1. Navigate to Import Queue for QAS
# 2. Locate transport <DEVK9XXXXX>
# 3. Import with option: "Import transport request"
# 4. Monitor import log
```

**Import Options:**
- Import Mode: Standard
- Table Import: Overwrite originals
- Ignore Invalid Component Version: No

### 4.3 Import to PRD

```bash
# Same process as QAS
# Additional: Schedule during maintenance window
# Recommended: Off-peak hours
```

---

## 5. Post-Transport Activities

### 5.1 Quality Assurance System (QAS)

#### Step 1: Verify Object Activation
```abap
" Transaction: SE80
" Package: ZMS2_CLOUD
" Verify all objects are active (green light)
```

#### Step 2: Configure Communication Arrangement
```
Transaction: /IWFND/V4_ADMIN or Fiori App "Communication Arrangements"

1. Create Communication System:
   - System ID: AZURE_EVENT_MESH_QAS
   - Host: <Azure Event Mesh endpoint for QAS>
   - Port: 443
   - SSL: Active

2. Create Communication Arrangement:
   - Scenario: Custom HTTP scenario
   - Arrangement Name: AZURE_EVENT_MESH
   - Communication System: AZURE_EVENT_MESH_QAS
   - Authentication: OAuth 2.0 or API Key
   - Credentials: <From Azure portal>
```

#### Step 3: Activate OData Service
```
Transaction: /IWFND/V4_ADMIN

1. Register Service:
   - Service Binding: ZHB_SB_PRODUCT_O4
   - Service Name: ZHB_SD_PRODUCT
   - Version: 0001

2. Test Service:
   - URL: /sap/opu/odata4/sap/zhb_sd_product/srvd/sap/zhb_sd_product/0001/
   - Method: GET
   - Expected: 200 OK with product metadata
```

#### Step 4: Test Integration
```abap
" Create test program or use SE37
DATA(lo_integration) = NEW zcl_online_shop_integration( ).

TRY.
    zcl_online_shop_integration=>send_order_to_cloud(
      iv_order_id   = '00000001'
      iv_created_by = sy-uname
    ).
    WRITE: / 'Integration test successful'.
  CATCH zcx_integration_error INTO DATA(lx_error).
    WRITE: / 'Error:', lx_error->get_text( ).
ENDTRY.
```

#### Step 5: Verify Background Processing
```abap
" Test background job creation
zcl_online_shop_integration=>process_order_background(
  iv_order_id   = '00000001'
  iv_created_by = sy-uname
).

" Verify in SM37 (Job Overview)
" Job name pattern: ONLINE_SHOP_ORDER_*
```

### 5.2 Production System (PRD)

**Repeat all QAS steps with production-specific configuration:**

1. Communication System: `AZURE_EVENT_MESH_PRD`
2. Azure endpoint: Production Event Mesh URL
3. Credentials: Production Azure credentials
4. Monitoring: Enable application logging

---

## 6. Rollback Plan

### 6.1 Immediate Rollback (If Import Fails)

```bash
# Transaction: STMS
# 1. Navigate to import queue
# 2. Select failed transport
# 3. Choose "Delete from Queue"
# 4. System returns to previous state
```

### 6.2 Post-Import Rollback (If Issues Found)

**Option A: Deactivate Service Binding**
```
Transaction: /IWFND/V4_ADMIN
1. Locate service ZHB_SD_PRODUCT
2. Deactivate service binding
3. System falls back to original integration (if still active)
```

**Option B: Delete Communication Arrangement**
```
Fiori App: Communication Arrangements
1. Delete arrangement AZURE_EVENT_MESH
2. Integration calls will fail gracefully with exception
```

**Option C: Full Package Deletion** (Last Resort)
```
Transaction: SE80
1. Delete package ZMS2_CLOUD
2. Transport deletion to target systems
3. Restore from backup if needed
```

---

## 7. Testing Strategy

### 7.1 Unit Testing

```abap
CLASS ltc_integration_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      test_json_conversion FOR TESTING,
      test_http_request_mock FOR TESTING,
      test_background_processing FOR TESTING.
ENDCLASS.

CLASS ltc_integration_test IMPLEMENTATION.
  METHOD test_json_conversion.
    " Test JSON serialization
    DATA(lv_json) = zcl_online_shop_integration=>convert_order_to_json(
      iv_order_id   = '00000001'
      iv_created_by = 'TESTUSER'
    ).
    
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_json
      msg = 'JSON should not be empty'
    ).
  ENDMETHOD.
ENDCLASS.
```

### 7.2 Integration Testing

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| TC-001 | Send valid order to Azure | HTTP 200/201, success message |
| TC-002 | Send with invalid order ID | Exception raised, error logged |
| TC-003 | Azure endpoint unavailable | Exception raised, retry logic triggered |
| TC-004 | Background job creation | Job created in SM37 |
| TC-005 | OData service query | Product list returned |

### 7.3 Performance Testing

```abap
" Test with volume data
DO 100 TIMES.
  zcl_online_shop_integration=>send_order_to_cloud(
    iv_order_id   = sy-index
    iv_created_by = sy-uname
  ).
ENDDO.

" Monitor:
" - Response times (should be < 2 seconds)
" - Memory consumption
" - Azure Service Bus queue depth
```

---

## 8. Monitoring and Support

### 8.1 Application Logging

```abap
" TODO: Implement using Application Log (BAL)
" Transaction: SLG1
" Object: ZMS2_CLOUD
" Subobject: INTEGRATION
```

### 8.2 Key Metrics to Monitor

| Metric | Tool | Threshold |
|--------|------|-----------|
| HTTP Response Time | ST05 | < 2 seconds |
| Background Job Success Rate | SM37 | > 95% |
| Exception Rate | SLG1 | < 5% |
| Azure Queue Depth | Azure Portal | < 1000 messages |

### 8.3 Support Contacts

| Role | Contact | Responsibility |
|------|---------|----------------|
| ABAP Developer | <Name> | Code issues, bug fixes |
| Basis Administrator | <Name> | Transport, system issues |
| Azure Administrator | <Name> | Azure connectivity, credentials |
| Functional Owner | <Name> | Business requirements |

---

## 9. Documentation References

### 9.1 Technical Documentation

- [README.md](README.md) - Migration overview and architecture
- [zcl_online_shop_integration.clas.abap](zms2_cloud/zcl_online_shop_integration.clas.abap) - Main integration class
- [zcx_integration_error.clas.abap](zms2_cloud/zcx_integration_error.clas.abap) - Exception handling

### 9.2 SAP Documentation

- SAP Help: ABAP Cloud Development
- SAP Help: Communication Management
- SAP Help: Background Processing Framework (bgPF)
- SAP Help: OData V4 Service Development

### 9.3 Azure Documentation

- Azure Event Mesh Documentation
- Azure Service Bus REST API
- Azure Authentication (OAuth 2.0)

---

## 10. Sign-Off

### 10.1 Development Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| Technical Lead | | | |
| Code Reviewer | | | |

### 10.2 Quality Assurance Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| QA Tester | | | |
| QA Manager | | | |

### 10.3 Production Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Change Manager | | | |
| Production Manager | | | |
| Business Owner | | | |

---

## 11. Transport History

| Date | System | Transport | Status | Notes |
|------|--------|-----------|--------|-------|
| YYYY-MM-DD | DEV | DEVK9XXXXX | Released | Initial development |
| YYYY-MM-DD | QAS | DEVK9XXXXX | Imported | QA testing |
| YYYY-MM-DD | PRD | DEVK9XXXXX | Imported | Production deployment |

---

## 12. Lessons Learned

### 12.1 What Went Well
- [ ] Clean separation of concerns (new package)
- [ ] ABAP Cloud compliance achieved
- [ ] No impact on existing functionality

### 12.2 Challenges Encountered
- [ ] Communication Arrangement configuration complexity
- [ ] Azure credential management
- [ ] Background Processing Framework learning curve

### 12.3 Recommendations for Future
- [ ] Automate Communication Arrangement setup
- [ ] Create reusable HTTP client wrapper
- [ ] Implement comprehensive logging from day one

---

**Document Version:** 1.0  
**Last Updated:** 2026-06-15  
**Next Review Date:** 2026-09-15