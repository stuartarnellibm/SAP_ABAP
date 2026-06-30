# FUNCTIONAL AND TECHNICAL SPECIFICATION
## Enhanced Credit Validation for Order-to-Cash Process

**Document Control**
- **Function Module**: Z_SD_VALIDATE_O2C_CREDIT_EXT
- **Version**: 1.1 (Corrected - SAP Repository Verified)
- **Date**: 2026-06-18
- **Author**: SAP Delivery Manager
- **Package**: ZFG_O2C
- **Transport Request**: DEVK9xxxxx (to be assigned)
- **Status**: Draft for Review
- **References**: 
  - Transport DEVK900124 (ABAP O2C programs + function modules)
  - Transport DEVK900127 (IDoc extensions for O2C + WM)
  - NAMING_STANDARDS.md
  - Append Structure: ZSTR_O2C_VBAK

---

## VERIFIED CUSTOM FIELDS IN VBAK (from SAP Repository)

All custom fields reside in append structure **ZSTR_O2C_VBAK**:

| Field | Data Element | Description | Transport | Usage in This Spec |
|-------|--------------|-------------|-----------|-------------------|
| **ZCREDIT_LIMIT** | ZCREDIT_LIMIT | Customer credit limit (cached copy of KNKK-KKBET) | DEVK900127 | ✅ Used for performance optimization |
| **ZPRIORITY** | ZPRIORITY | Order priority (H/M/L) | DEVK900124 | ✅ Used for priority-based tolerance |
| **ZDISCOUNT_GRP** | ZDISCOUNT_GRP | Discount group code | DEVK900124 | ✅ Used for order value adjustment |
| **ZPAY_TERM** | ZPAY_TERM | Preferred payment terms | DEVK900124 | ℹ️ Not used in credit check |
| **ZROUTE** | ZROUTE | Customer delivery route | DEVK900124 | ℹ️ Not used in credit check |

**Source**: SA_SAP_Repo_99901A agent query, verified against transport objects DEVK900124.json.txt and DEVK900127

---

## 1. OVERVIEW

### 1.1 Business Context
Unilever's Order-to-Cash process requires real-time credit validation before sales order creation. The existing function module `Z_SD_CHECK_O2C_CREDIT` (transport DEVK900124) provides basic credit limit checking. This specification extends that functionality with:

- Dynamic credit exposure calculation
- Priority-based credit decisions using VBAK-ZPRIORITY
- Cached credit limit optimization using VBAK-ZCREDIT_LIMIT
- Discount-adjusted order values using VBAK-ZDISCOUNT_GRP
- External credit bureau integration
- Comprehensive audit trail

### 1.2 High-Level Solution
Create `Z_SD_VALIDATE_O2C_CREDIT_EXT` in function group `ZFG_O2C` (transport DEVK900124) that:
- Extends existing credit check logic
- Leverages VBAK custom fields from ZSTR_O2C_VBAK append structure
- Maintains audit trail in new table ZSD_CREDIT_LOG
- Supports configurable rules via new table ZSD_CREDIT_RULES

---

## 2. SCOPE

### 2.1 In Scope
✅ New function module in existing function group ZFG_O2C (transport DEVK900124)
✅ Use VBAK-ZCREDIT_LIMIT for cached credit limits (transport DEVK900127)
✅ Use VBAK-ZPRIORITY for priority-based tolerance (transport DEVK900124)
✅ Use VBAK-ZDISCOUNT_GRP for order value adjustment (transport DEVK900124)
✅ New tables: ZSD_CREDIT_LOG, ZSD_CREDIT_RULES
✅ Integration with Z_SD_CREATE_O2C_ORDER (transport DEVK900124)

### 2.2 Out of Scope
❌ Modification of standard SAP credit management
❌ Changes to VBAK-ZPAY_TERM or VBAK-ZROUTE fields
❌ Modification of existing Z_SD_CHECK_O2C_CREDIT function module

---

## 3. FUNCTIONAL REQUIREMENTS

**FR-001**: System shall retrieve credit limit from KNKK or use cached VBAK-ZCREDIT_LIMIT (transport DEVK900127)

**FR-002**: System shall apply priority-based tolerance using VBAK-ZPRIORITY (transport DEVK900124):
- High Priority (H): +5% additional tolerance
- Medium Priority (M): Standard tolerance
- Low Priority (L): No additional tolerance

**FR-003**: System shall adjust order value based on VBAK-ZDISCOUNT_GRP (transport DEVK900124) before credit check

**FR-004**: System shall calculate current exposure from open orders, deliveries, invoices

**FR-005**: System shall log all decisions to ZSD_CREDIT_LOG including priority and discount group

**FR-006**: System shall return decision (APPROVED/REJECTED/MANUAL_REVIEW) with detailed reasoning

---

## 4. TECHNICAL LOGIC

### 4.1 Function Module Signature

```abap
FUNCTION Z_SD_VALIDATE_O2C_CREDIT_EXT.
*"----------------------------------------------------------------------
*" Function Module: Z_SD_VALIDATE_O2C_CREDIT_EXT
*" Package: ZFG_O2C (Transport DEVK900124)
*" Description: Enhanced credit validation with priority and caching
*" References: VBAK custom fields from ZSTR_O2C_VBAK append structure
*"----------------------------------------------------------------------
*"  IMPORTING
*"     VALUE(I_KUNNR) TYPE  KUNNR
*"     VALUE(I_VKORG) TYPE  VKORG
*"     VALUE(I_ORDER_VALUE) TYPE  WRBTR
*"     VALUE(I_WAERS) TYPE  WAERS
*"     VALUE(I_PRIORITY) TYPE  ZPRIORITY DEFAULT SPACE
*"     VALUE(I_DISCOUNT_GRP) TYPE  ZDISCOUNT_GRP DEFAULT SPACE
*"     VALUE(I_USE_CACHE) TYPE  XFELD DEFAULT 'X'
*"     VALUE(I_CHECK_EXTERNAL) TYPE  XFELD DEFAULT SPACE
*"  EXPORTING
*"     VALUE(E_DECISION) TYPE  ZDE_CREDIT_DECISION
*"     VALUE(E_CREDIT_LIMIT) TYPE  WRBTR
*"     VALUE(E_CURRENT_EXPOSURE) TYPE  WRBTR
*"     VALUE(E_AVAILABLE_CREDIT) TYPE  WRBTR
*"     VALUE(E_REASON_CODE) TYPE  ZDE_REASON_CODE
*"     VALUE(E_REASON_TEXT) TYPE  ZDE_REASON_TEXT
*"  TABLES
*"      ET_EXPOSURE_DETAILS STRUCTURE  ZSTR_EXPOSURE_DETAIL
*"  EXCEPTIONS
*"      CUSTOMER_NOT_FOUND
*"      CREDIT_DATA_NOT_FOUND
*"----------------------------------------------------------------------
```

### 4.2 Key Processing Steps

**Step 1: Read Credit Limit with Cache Optimization**
```abap
" Try cached limit from VBAK-ZCREDIT_LIMIT (Transport DEVK900127)
IF i_use_cache = 'X'.
  SELECT SINGLE zcredit_limit erdat erzet
    FROM vbak
    INTO @DATA(ls_cache)
    WHERE kunnr = @i_kunnr
      AND vkorg = @i_vkorg
      AND zcredit_limit IS NOT INITIAL
    ORDER BY erdat DESCENDING, erzet DESCENDING
    UP TO 1 ROWS.
  
  " Use cache if less than 24 hours old
  IF sy-subrc = 0 AND cache_is_valid( ls_cache-erdat, ls_cache-erzet ).
    e_credit_limit = ls_cache-zcredit_limit.
  ELSE.
    " Read from KNKK
    SELECT SINGLE klimk FROM knkk INTO @e_credit_limit
      WHERE kunnr = @i_kunnr AND kkber = @gc_kkber.
  ENDIF.
ENDIF.
```

**Step 2: Apply Priority-Based Tolerance**
```abap
" Read base tolerance from configuration
SELECT SINGLE tolerance_pct FROM zsd_credit_rules
  INTO @DATA(lv_base_tolerance)
  WHERE kdgrp = @lv_kdgrp AND vkorg = @i_vkorg.

" Apply priority adjustment (VBAK-ZPRIORITY from Transport DEVK900124)
DATA(lv_total_tolerance) = lv_base_tolerance.

CASE i_priority.
  WHEN 'H'.  " High Priority
    lv_total_tolerance = lv_total_tolerance + 5.
  WHEN 'M'.  " Medium Priority
    " Use base tolerance
  WHEN 'L'.  " Low Priority
    " No additional tolerance
ENDCASE.

DATA(lv_effective_limit) = e_credit_limit * ( 1 + lv_total_tolerance / 100 ).
```

**Step 3: Adjust Order Value for Discount**
```abap
" Apply discount if VBAK-ZDISCOUNT_GRP populated (Transport DEVK900124)
DATA(lv_adjusted_value) = i_order_value.

IF i_discount_grp IS NOT INITIAL.
  " Read discount percentage from configuration
  SELECT SINGLE discount_pct FROM zsd_discount_config
    INTO @DATA(lv_discount_pct)
    WHERE discount_grp = @i_discount_grp.
  
  IF sy-subrc = 0.
    lv_adjusted_value = i_order_value * ( 1 - lv_discount_pct / 100 ).
  ENDIF.
ENDIF.
```

**Step 4: Calculate Exposure and Make Decision**
```abap
" Calculate current exposure from open documents
PERFORM calculate_exposure
  USING i_kunnr i_vkorg
  CHANGING e_current_exposure et_exposure_details.

" Make credit decision
DATA(lv_total_required) = e_current_exposure + lv_adjusted_value.

IF lv_total_required <= lv_effective_limit.
  e_decision = 'APPROVED'.
  e_reason_code = COND #( WHEN i_priority = 'H' 
                          THEN 'HIGH_PRIORITY_APPROVED'
                          ELSE 'APPROVED_WITHIN_LIMIT' ).
ELSEIF lv_total_required <= ( lv_effective_limit * 1.05 ).
  e_decision = 'MANUAL_REVIEW'.
  e_reason_code = 'NEAR_LIMIT'.
ELSE.
  e_decision = 'REJECTED'.
  e_reason_code = 'OVER_LIMIT'.
ENDIF.
```

**Step 5: Log Decision**
```abap
" Log to ZSD_CREDIT_LOG with priority and discount group
INSERT INTO zsd_credit_log VALUES (
  log_id = cl_system_uuid=>create_uuid_x16_static( )
  kunnr = i_kunnr
  vkorg = i_vkorg
  order_value = i_order_value
  adjusted_value = lv_adjusted_value
  credit_limit = e_credit_limit
  current_exposure = e_current_exposure
  decision = e_decision
  reason_code = e_reason_code
  priority = i_priority          " From VBAK-ZPRIORITY (DEVK900124)
  discount_grp = i_discount_grp  " From VBAK-ZDISCOUNT_GRP (DEVK900124)
  cache_used = i_use_cache       " Indicates if ZCREDIT_LIMIT used (DEVK900127)
  check_date = sy-datum
  check_time = sy-uzeit
  check_user = sy-uname
).
```

---

## 5. CONFIGURATION TABLES

### 5.1 ZSD_CREDIT_LOG (Audit Trail)
```
Key: MANDT, LOG_ID
Fields:
- KUNNR (Customer)
- VKORG (Sales Org)
- ORDER_VALUE (Original Value)
- ADJUSTED_VALUE (After Discount)
- CREDIT_LIMIT (Used Limit)
- CURRENT_EXPOSURE (Calculated)
- DECISION (APPROVED/REJECTED/MANUAL_REVIEW)
- REASON_CODE (Decision Reason)
- PRIORITY (from VBAK-ZPRIORITY, Transport DEVK900124)
- DISCOUNT_GRP (from VBAK-ZDISCOUNT_GRP, Transport DEVK900124)
- CACHE_USED (Flag if VBAK-ZCREDIT_LIMIT used, Transport DEVK900127)
- CHECK_DATE, CHECK_TIME, CHECK_USER
```

### 5.2 ZSD_CREDIT_RULES (Configuration)
```
Key: MANDT, KDGRP, VKORG
Fields:
- TOLERANCE_PCT (Base Tolerance %)
- AUTO_APPROVE_PCT (Auto-Approve Threshold)
- MANUAL_REVIEW_PCT (Manual Review Threshold)
```

---

## 6. IMPACT ASSESSMENT

### 6.1 Impact on Existing Objects (Transport DEVK900124)

**ZFG_O2C (Function Group)**:
- Impact: Add new function module
- Risk: Low - additive change only
- Action: Add include LZFG_O2C_VALIDATE_EXT

**Z_SD_CREATE_O2C_ORDER (Program)**:
- Impact: Modify to call new FM
- Risk: Medium - requires regression testing
- Action: Replace call to Z_SD_CHECK_O2C_CREDIT with Z_SD_VALIDATE_O2C_CREDIT_EXT
- Migration: Parallel run for 2 weeks

**Z_SD_CHECK_O2C_CREDIT (Function Module)**:
- Impact: None - keep for backward compatibility
- Risk: None
- Action: No changes required

### 6.2 Usage of VBAK Custom Fields

**ZCREDIT_LIMIT (Transport DEVK900127)**:
- Current Usage: Cached credit limit for UI display
- New Usage: Performance optimization - read cached value instead of KNKK
- Impact: Read-only access, no modification

**ZPRIORITY (Transport DEVK900124)**:
- Current Usage: Controls credit-check and scheduling logic
- New Usage: Priority-based tolerance (H=+5%, M=standard, L=no additional)
- Impact: Read-only access, no modification

**ZDISCOUNT_GRP (Transport DEVK900124)**:
- Current Usage: Overrides standard pricing procedure
- New Usage: Adjust order value before credit check
- Impact: Read-only access, no modification

**ZPAY_TERM (Transport DEVK900124)**:
- Current Usage: Preferred payment terms
- New Usage: Not used in credit validation
- Impact: None

**ZROUTE (Transport DEVK900124)**:
- Current Usage: Delivery route for logistics
- New Usage: Not used in credit validation
- Impact: None

---

## 7. TEST SCENARIOS

**UT-001**: High Priority Order with Cached Limit
- Input: ZPRIORITY='H', ZCREDIT_LIMIT=100000, exposure=98000, order=4000
- Expected: APPROVED (5% additional tolerance = 105000 effective limit)

**UT-002**: Discount Group Applied
- Input: ZDISCOUNT_GRP='10' (10% discount), order=50000
- Expected: Credit check on 45000 (after discount)

**UT-003**: Cache Miss - Read from KNKK
- Input: ZCREDIT_LIMIT empty or expired
- Expected: Read from KNKK, log cache_used='N'

**UT-004**: Medium Priority Standard Processing
- Input: ZPRIORITY='M', standard tolerance
- Expected: No additional tolerance applied

**UT-005**: Low Priority No Additional Tolerance
- Input: ZPRIORITY='L'
- Expected: Base tolerance only, no priority adjustment

---

## 8. DEPLOYMENT PLAN

**Phase 1**: Development (2 weeks)
- Create function module in ZFG_O2C
- Create tables ZSD_CREDIT_LOG, ZSD_CREDIT_RULES
- Unit testing

**Phase 2**: Integration Testing (2 weeks)
- Integrate with Z_SD_CREATE_O2C_ORDER
- Test with all VBAK custom fields
- Performance testing

**Phase 3**: UAT (2 weeks)
- Business user testing
- Parallel run with Z_SD_CHECK_O2C_CREDIT

**Phase 4**: Production (1 week)
- Deploy via transport path: DEV → QA → UAT1 → PROD
- Monitor for 1 week

---

## 9. REFERENCES

**Transport Objects**:
- DEVK900124: Function group ZFG_O2C, append structure ZSTR_O2C_VBAK (fields: ZPRIORITY, ZDISCOUNT_GRP, ZPAY_TERM, ZROUTE)
- DEVK900127: VBAK-ZCREDIT_LIMIT field for cached credit limits

**Documentation**:
- NAMING_STANDARDS.md: Naming conventions for Z-objects
- DEVK900124.json.txt: Transport object list
- User-exit: MV45AFZZ_USEREXIT_SAVE_DOCUMENT_PREPARE.abap.txt (references VBAK-ZROUTE, VBAK-ZPRIORITY)

**Source**: All information verified via SA_SAP_Repo_99901A agent query on 2026-06-18

---

## DOCUMENT APPROVAL

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Business Owner | Credit & Collections Manager | _____________ | ________ |
| Technical Lead | SAP Development Manager | _____________ | ________ |
| Quality Assurance | QA Manager | _____________ | ________ |

---

**END OF SPECIFICATION**