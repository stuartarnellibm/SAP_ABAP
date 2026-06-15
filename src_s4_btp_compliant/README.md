# S/4HANA and SAP BTP Compliant Implementation

## Overview
This directory contains the **ABAP Cloud compliant** version of the Online Shop integration code, modernized for S/4HANA and SAP BTP deployment.

## Key Changes from Original Implementation

### 1. ABAP Cloud Language Version
- All packages use `ABAP_LANGUAGE_VERSION = 5` (ABAP Cloud)
- Only released APIs are used
- Compatible with SAP BTP ABAP Environment

### 2. Security & Authorization
- **CDS View**: [`zhb_i_product.ddls`](zms2_cloud/zhb_i_product.ddls.asddls) now has `@AccessControl.authorizationCheck: #CHECK`
- **DCL**: [`zhb_i_product.dcls`](zms2_cloud/zhb_i_product.dcls.asdcls) implements proper authorization control
- Inherits authorization from standard `I_Product` view

### 3. Modernized Integration Architecture

#### Replaced: Function Group → ABAP Class
**Old**: `z_online_shop_sdk` function group (incomplete)  
**New**: [`zcl_online_shop_integration`](zms2_cloud/zcl_online_shop_integration.clas.abap) class

**Key Features**:
- Clean object-oriented design
- Proper error handling with custom exception [`zcx_integration_error`](zms2_cloud/zcx_integration_error.clas.abap)
- Released APIs only

#### Replaced: Background Task → Background Processing Framework
**Old**: `CALL FUNCTION...IN BACKGROUND TASK` (not allowed in ABAP Cloud)  
**New**: Background Processing Framework (bgPF)

```abap
" Modern approach using bgPF
DATA(lo_job) = cl_bgmc_process_factory=>get_default( )->create( ).
lo_job->set_name( |ONLINE_SHOP_ORDER_{ iv_order_id }| ).
lo_job->schedule( ).
```

#### Replaced: Custom Azure SDK → SAP Integration Suite
**Old**: Commented-out custom Azure Service Bus SDK  
**New**: HTTP client with Communication Arrangements

**Integration Pattern**:
- Uses `cl_http_client` (released API)
- Connects via Communication Arrangements
- Supports SAP Event Mesh or Integration Suite
- OAuth 2.0 authentication ready

### 4. API Replacements

| Old (Non-Released) | New (Released) | Location |
|-------------------|----------------|----------|
| `CALL FUNCTION...IN BACKGROUND TASK` | `cl_bgmc_process_factory` | [`zcl_online_shop_integration`](zms2_cloud/zcl_online_shop_integration.clas.abap:91) |
| `SCMS_STRING_TO_XSTRING` | `cl_abap_conv_codepage` | Documented in code comments |
| `cl_gui_frontend_services` | HTTP APIs / Object Storage | N/A (removed) |
| Custom Azure SDK | `cl_http_client` + Comm. Arrangement | [`zcl_online_shop_integration`](zms2_cloud/zcl_online_shop_integration.clas.abap:137) |

## Package Structure

```
src_s4_btp_compliant/
├── package.devc.xml                    # Root package (ABAP Cloud)
└── zms2_cloud/
    ├── package.devc.xml                # Sub-package
    ├── zhb_i_product.ddls.asddls       # CDS View (with auth check)
    ├── zhb_i_product.ddls.xml          # CDS metadata
    ├── zhb_i_product.dcls.asdcls       # DCL (authorization)
    ├── zhb_i_product.dcls.xml          # DCL metadata
    ├── zcl_online_shop_integration.clas.abap  # Integration class
    ├── zcl_online_shop_integration.clas.xml   # Class metadata
    ├── zcx_integration_error.clas.abap        # Exception class
    └── zcx_integration_error.clas.xml         # Exception metadata
```

## Prerequisites

### SAP System Requirements
- SAP S/4HANA 2021 or later (for ABAP Cloud support)
- OR SAP BTP ABAP Environment
- ABAP Cloud language version enabled

### Required Configuration
1. **Communication Arrangement** for cloud integration
   - Destination: `AZURE_EVENT_MESH` (or your cloud platform)
   - Authentication: OAuth 2.0 or API Key
   
2. **Message Class** `ZONLINE_SHOP` with messages:
   - 001: "Failed to send order to cloud platform"
   - 002: "HTTP communication error"
   - 003: "JSON conversion error"

3. **Background Processing Framework** (bgPF) configured

## Installation

### Using abapGit
1. Pull this repository using abapGit
2. Create package `ZS4_BTP_COMPLIANT` with ABAP Cloud language version
3. Import objects from `src_s4_btp_compliant/` directory
4. Activate all objects

### Manual Installation
1. Create packages with ABAP Cloud language version:
   - Root package: `ZS4_BTP_COMPLIANT`
   - Sub-package: `ZMS2_CLOUD`
2. Create objects in order:
   - CDS View + DCL
   - Exception class
   - Integration class
3. Configure Communication Arrangement

## Usage

### Send Order to Cloud Platform
```abap
TRY.
    zcl_online_shop_integration=>send_order_to_cloud(
      iv_order_id   = '12345678'
      iv_created_by = sy-uname
    ).
  CATCH zcx_integration_error INTO DATA(lx_error).
    " Handle error
    MESSAGE lx_error TYPE 'E'.
ENDTRY.
```

### Process Order in Background
```abap
zcl_online_shop_integration=>process_order_background(
  iv_order_id   = '12345678'
  iv_created_by = sy-uname
).
```

### Query Products
```abap
SELECT * FROM zhb_i_product
  WHERE productgroup = 'L003'
  INTO TABLE @DATA(lt_products).
```

## Testing

### Unit Tests
TODO: Implement ABAP Unit tests for:
- JSON conversion
- HTTP client mocking
- Background job scheduling
- Authorization checks

### Integration Tests
1. Configure test Communication Arrangement
2. Test order submission
3. Verify background job creation
4. Check authorization with different users

## Migration from Original Code

### What Was Removed
- Function group `z_online_shop_sdk` (replaced with class)
- Commented-out Azure SDK code (replaced with standard HTTP client)
- Non-released API calls
- GUI-dependent code (`cl_gui_frontend_services`)

### What Was Added
- ABAP Cloud package definitions
- DCL for authorization
- Custom exception class
- Background Processing Framework integration
- Communication Arrangement support
- Comprehensive error handling
- Documentation

### Breaking Changes
- Function module calls must be replaced with class method calls
- Background task processing requires bgPF configuration
- Authorization now enforced (was disabled in original)

## Known Limitations

1. **Communication Arrangement** must be manually configured
2. **Message Class** `ZONLINE_SHOP` must be created manually
3. **Background Processing Framework** requires system configuration
4. **RAP Business Object** for OData services not yet implemented (see roadmap)

## Roadmap

### Phase 1: Foundation ✅ (Current)
- [x] ABAP Cloud packages
- [x] CDS View with DCL
- [x] Integration class with released APIs
- [x] Background Processing Framework
- [x] Exception handling

### Phase 2: Service Layer (Planned)
- [ ] RAP Business Object for Product
- [ ] OData V4 service definition
- [ ] Service binding
- [ ] Replace SEGW extension report

### Phase 3: Advanced Features (Future)
- [ ] ABAP Unit tests
- [ ] Application logging
- [ ] Monitoring dashboard
- [ ] Performance optimization

## Support

For issues related to:
- **ABAP Cloud**: Check SAP Help Portal for released APIs
- **Background Processing**: See bgPF documentation
- **Communication Arrangements**: Refer to SAP Integration Suite docs
- **This Implementation**: Create GitHub issue

## License
Apache 2.0 - See [LICENSE](../LICENSE) file

## Related Documentation
- [Original Implementation](../src/zms2/) - Standard ABAP version
- [GitHub Issue #1](https://github.com/stuartarnellibm/SAP_ABAP/issues/1) - S/4HANA conversion request
- [SAP Help: ABAP Cloud](https://help.sap.com/docs/abap-cloud)
- [SAP Help: Background Processing Framework](https://help.sap.com/docs/btp/sap-business-technology-platform/background-processing-framework)