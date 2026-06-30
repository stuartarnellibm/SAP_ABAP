#!/usr/bin/env bash

set -e

ROOT="Z_O2C_WM_FULL_REPOSITORY"

echo "Creating repository at: $ROOT"

mkdir -p "$ROOT"/{docs,abap/programs,abap/function_groups/ZFG_O2C,abap/function_groups/ZFG_WM_TO,cds,enhancements/user_exits,ddic/tables,idoc/types,idoc/segments,wm,auth,jobs,rfc,transports}

########################################
# manifest.yaml
########################################
cat > "$ROOT/manifest.yaml" << 'EOF'
repository: Z_O2C_WM_FULL_REPOSITORY
version: 1.0.0
exported_on: 2026-06-17
exported_by: JSMITH
system: D10
client: 100
sap_basis: 620
kernel: 6.20
description: >
  Complete fictional SAP R/3 repository for O2C + WM processes,
  including DDIC, ABAP, CDS, IDocs, enhancements, and transports.
EOF

########################################
# README.md
########################################
cat > "$ROOT/README.md" << 'EOF'
# Z_O2C_WM_FULL_REPOSITORY

Fictional SAP R/3 O2C + WM repository:
- Z DDIC objects
- ABAP programs and function groups
- CDS views
- IDoc extensions
- Enhancements, exits, BADIs
- DB2-oriented design notes
- 3-tier landscape (D10 → Q10 → P10)

See `docs/` for standards, landscape, DB2 notes, and exit strategy.
EOF

########################################
# docs/NAMING_STANDARDS.md
########################################
cat > "$ROOT/docs/NAMING_STANDARDS.md" << 'EOF'
# Naming Standards (Z Namespace)

## General Rules
- All custom objects must begin with `Z` (global) or `Y` (local).
- Use uppercase only.
- Names must be descriptive, not cryptic.
- Avoid abbreviations unless SAP-standard (VBELN, LGNUM).

## Object-Specific Naming

- Tables: `Z` + module + `_` (e.g. `ZSD_SALES_HDR`)
- Structures: `ZSTR_` (e.g. `ZSTR_O2C_ORDER`)
- Data Elements: `Z` + field (e.g. `ZROUTE`)
- Domains: `Z` + field (e.g. `ZPRIORITY`)
- Programs: `Z` + module + `_` (e.g. `ZSD_O2C_MONITOR`)
- Function Groups: `ZFG_` (e.g. `ZFG_O2C`)
- Function Modules: `Z_` + module + `_` (e.g. `Z_SD_CREATE_O2C_ORDER`)
- Classes: `ZCL_` (e.g. `ZCL_O2C_SERVICE`)
- Interfaces: `ZIF_` (e.g. `ZIF_WM_API`)
- IDoc Types: `Z` + name + version (e.g. `ZDELVRY01`)
- Segments: `ZE1` + name (e.g. `ZE1ZDLV1`)
- CDS Views: `Z_CDS_` (e.g. `Z_CDS_O2C_HEADER`)
EOF

########################################
# docs/LANDSCAPE.md
########################################
cat > "$ROOT/docs/LANDSCAPE.md" << 'EOF'
# System Landscape and Path to Production

## Systems

- Development: D10 / Client 100
- Quality:    Q10 / Client 200
- Production: P10 / Client 300

## Transport Path

D10 → Q10 → P10

## Governance

- All changes originate in D10.
- No direct changes in Q10 or P10.
- Emergency fixes require CAB approval.
- Transports must be sequenced to avoid dependency issues.
EOF

########################################
# docs/DB2_NOTES.md
########################################
cat > "$ROOT/docs/DB2_NOTES.md" << 'EOF'
# DB2 Platform Notes

## Indexing

- Primary index on key fields for all Z-tables.
- Secondary indexes for frequent WHERE clauses and joins.

## Tablespaces

- Use SAP standard tablespaces:
  - PSAPBTABD for tables
  - PSAPBTABI for indexes
- Large tables (> 2M rows) should have compression and regular reorgs.

## Performance

- Avoid `SELECT *` in ABAP.
- Use `FOR ALL ENTRIES` carefully.
- CDS views push down to DB2 SQL; avoid nested selects and non-deterministic functions.
EOF

########################################
# docs/EXITS_AND_ENHANCEMENTS.md
########################################
cat > "$ROOT/docs/EXITS_AND_ENHANCEMENTS.md" << 'EOF'
# Exits and Enhancements

## User Exits

- USEREXIT_SAVE_DOCUMENT_PREPARE (MV45AFZZ)
  - Purpose: Validate ZROUTE and ZPRIORITY on sales orders.

## Enhancements

- ZXM06U43 (MM06E005)
  - Purpose: Warehouse capacity check before PO release.

## BADIs

- LE_WM_TO_CREATE / Z_IM_WM_TO_CREATE
  - Purpose: Pre-TO creation validation.

## Governance

- No COMMIT WORK inside exits.
- Use message classes, not hard-coded text.
- Document each exit in functional and technical specs.
EOF

########################################
# docs/REPOSITORY_COMMENTARY.md
########################################
cat > "$ROOT/docs/REPOSITORY_COMMENTARY.md" << 'EOF'
# Repository Commentary

## O2C Design

- ZSD_SALES_HDR extends standard sales header without modifying SAP tables.
- Z_SD_CREATE_O2C_ORDER wraps BAPI_SALESORDER_CREATEFROMDAT2 for validation and routing.

## WM Design

- ZWM_BIN_MAPPING provides bin metadata (zone, temperature).
- Z_WM_CREATE_TO wraps L_TO_CREATE_MULTIPLE to enforce movement type Z999 and temperature rules.

## IDoc Design

- ZDELVRY01 extends delivery IDoc with custom delivery number, route, and priority.
- ZWM_BINMAP01 supports external WMS integration.

## CDS Design

- CDS views provide reporting and OData exposure with DB2 pushdown.
EOF

########################################
# ABAP: ZSD_O2C_MONITOR
########################################
cat > "$ROOT/abap/programs/ZSD_O2C_MONITOR.abap" << 'EOF'
REPORT ZSD_O2C_MONITOR.

TABLES: VBAK, VBAP.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
PARAMETERS: p_vkorg TYPE vkorg DEFAULT '1000'.
SELECT-OPTIONS: s_audat FOR vbak-audat.
SELECTION-SCREEN END OF BLOCK b1.

DATA: gt_orders TYPE TABLE OF vbak,
      gs_order  TYPE vbak.

START-OF-SELECTION.

  SELECT * FROM vbak
    INTO TABLE @gt_orders
    WHERE vkorg = @p_vkorg
      AND audat IN @s_audat.

  LOOP AT gt_orders INTO gs_order.
    WRITE: / gs_order-vbeln,
             gs_order-kunnr,
             gs_order-audat.
  ENDLOOP.
EOF

########################################
# ABAP: ZWM_BIN_HEALTHCHECK
########################################
cat > "$ROOT/abap/programs/ZWM_BIN_HEALTHCHECK.abap" << 'EOF'
REPORT ZWM_BIN_HEALTHCHECK.

TABLES: ZWM_BIN_MAPPING.

SELECT * FROM zwm_bin_mapping INTO @DATA(ls_bin).

  IF ls_bin-ztemp > '25.00'.
    MESSAGE w010(zwm_msg) WITH ls_bin-lgpla.
  ENDIF.

ENDSELECT.
EOF

########################################
# Function group ZFG_O2C - TOP
########################################
cat > "$ROOT/abap/function_groups/ZFG_O2C/LZFG_O2CTOP.abap" << 'EOF'
*---------------------------------------------------------------------*
*  Function Group ZFG_O2C - TOP Include                               *
*---------------------------------------------------------------------*

FUNCTION-POOL ZFG_O2C.

TABLES: VBAK, VBAP, KNA1, MARA.

CONSTANTS:
  gc_default_vkorg TYPE vkorg VALUE '1000'.
EOF

########################################
# FM: Z_SD_CREATE_O2C_ORDER
########################################
cat > "$ROOT/abap/function_groups/ZFG_O2C/Z_SD_CREATE_O2C_ORDER.fm.abap" << 'EOF'
FUNCTION Z_SD_CREATE_O2C_ORDER.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_KUNNR) TYPE KUNNR
*"     VALUE(I_MATNR) TYPE MATNR
*"     VALUE(I_QTY)   TYPE KWMENG
*"  EXPORTING
*"     VALUE(E_VBELN) TYPE VBELN
*"  EXCEPTIONS
*"     INVALID_CUSTOMER
*"     MATERIAL_BLOCKED
*"     QUANTITY_ERROR
*"----------------------------------------------------------------------

  DATA: ls_vbak TYPE vbak,
        ls_vbap TYPE vbap.

* Validate customer
  SELECT SINGLE * FROM kna1 INTO @DATA(ls_kna1)
    WHERE kunnr = @i_kunnr.
  IF sy-subrc <> 0.
    RAISE invalid_customer.
  ENDIF.

* Validate material
  SELECT SINGLE * FROM mara INTO @DATA(ls_mara)
    WHERE matnr = @i_matnr.
  IF sy-subrc <> 0 OR ls_mara-mstae = '01'. "blocked
    RAISE material_blocked.
  ENDIF.

* Validate quantity
  IF i_qty IS INITIAL OR i_qty <= 0.
    RAISE quantity_error.
  ENDIF.

* Prepare header
  CLEAR ls_vbak.
  ls_vbak-kunnr = i_kunnr.
  ls_vbak-vkorg = gc_default_vkorg.
  ls_vbak-auart = 'OR'.
  ls_vbak-audat = sy-datum.

* Prepare item
  CLEAR ls_vbap.
  ls_vbap-posnr = '000010'.
  ls_vbap-matnr = i_matnr.
  ls_vbap-kwmeng = i_qty.
  ls_vbap-meins  = ls_mara-meins.

* Call standard BAPI
  DATA: lt_return TYPE TABLE OF bapiret2.

  CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
    EXPORTING
      order_header_in   = ls_vbak
    TABLES
      order_items_in    = VALUE #( ( ls_vbap ) )
      return            = lt_return.

  READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    RAISE quantity_error.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

* Get created document
  SELECT SINGLE vbeln FROM vbak INTO @e_vbeln
    WHERE kunnr = @i_kunnr
      AND audat = @sy-datum
    ORDER BY vbeln DESC.

ENDFUNCTION.
EOF

########################################
# Function group ZFG_WM_TO - TOP
########################################
cat > "$ROOT/abap/function_groups/ZFG_WM_TO/LZFG_WM_TOTOP.abap" << 'EOF'
*---------------------------------------------------------------------*
*  Function Group ZFG_WM_TO - TOP Include                             *
*---------------------------------------------------------------------*

FUNCTION-POOL ZFG_WM_TO.

TABLES: LAGP, LQUA.
EOF

########################################
# FM: Z_WM_CREATE_TO
########################################
cat > "$ROOT/abap/function_groups/ZFG_WM_TO/Z_WM_CREATE_TO.fm.abap" << 'EOF'
FUNCTION Z_WM_CREATE_TO.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_LGNUM) TYPE LGNUM
*"     VALUE(I_VBELN) TYPE VBELN
*"  TABLES
*"     T_ITEMS        TYPE ZSTR_WM_TO_ITEM
*"  EXPORTING
*"     VALUE(E_TONUM) TYPE TANUM
*"----------------------------------------------------------------------

  DATA: ls_to_header TYPE ltap,
        lt_to_items  TYPE TABLE OF ltap,
        ls_item      TYPE zstr_wm_to_item.

* Build TO header
  CLEAR ls_to_header.
  ls_to_header-lgnum = i_lgnum.
  ls_to_header-bwlvs = '999'. "custom movement
  ls_to_header-refnr = i_vbeln.

* Build TO items
  LOOP AT t_items INTO ls_item.
    APPEND VALUE ltap(
      lgnum = i_lgnum
      matnr = ls_item-matnr
      lgpla = ls_item-lgpla
      menge = ls_item-menge
      meins = ls_item-meins
    ) TO lt_to_items.
  ENDLOOP.

* Call standard WM function (fictional wrapper)
  CALL FUNCTION 'L_TO_CREATE_MULTIPLE'
    EXPORTING
      i_lgnum   = i_lgnum
      i_bwlvs   = ls_to_header-bwlvs
    TABLES
      t_ltap    = lt_to_items
    EXCEPTIONS
      no_to_created = 1
      OTHERS        = 2.

  IF sy-subrc <> 0.
    MESSAGE e010(zwm_msg) WITH 'TO not created'.
  ENDIF.

* Get last TO number
  SELECT SINGLE tanum FROM ltak INTO @e_tonum
    WHERE lgnum = @i_lgnum
    ORDER BY tanum DESC.

ENDFUNCTION.
EOF

########################################
# Enhancement: USEREXIT_SAVE_DOCUMENT_PREPARE
########################################
cat > "$ROOT/enhancements/user_exits/MV45AFZZ_USEREXIT_SAVE_DOCUMENT_PREPARE.abap" << 'EOF'
FORM USEREXIT_SAVE_DOCUMENT_PREPARE.

  DATA: lv_route    TYPE zroute,
        lv_priority TYPE zpriority.

* Assume custom fields are in VBAK-ZROUTE / VBAK-ZPRIORITY
  lv_route    = vbak-zroute.
  lv_priority = vbak-zpriority.

  IF lv_route IS INITIAL.
    MESSAGE e001(zsd_msg) WITH lv_route.
  ENDIF.

  IF lv_priority = 'H' AND vbak-kunnr IS INITIAL.
    MESSAGE e002(zsd_msg) WITH vbak-kunnr.
  ENDIF.

ENDFORM.
EOF

########################################
# CDS: Z_CDS_O2C_Header
########################################
cat > "$ROOT/cds/Z_CDS_O2C_Header.cds" << 'EOF'
@AbapCatalog.sqlViewName: 'ZV_O2C_HDR'
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'O2C Sales Header with Delivery Extension'
define view Z_CDS_O2C_Header as
  select from zsd_sales_hdr as hdr
    left outer join zsd_delivery_ext as dlv
      on dlv.vbeln = hdr.vbeln
{
  key hdr.vbeln        as SalesDocument,
      hdr.kunnr        as SoldToParty,
      hdr.audat        as DocumentDate,
      hdr.zpriority    as Priority,
      hdr.zroute       as Route,
      dlv.zdlv_no      as CustomDeliveryNumber,
      dlv.zflag        as SpecialHandlingFlag
}
EOF

########################################
# CDS: Z_CDS_WM_BinMap
########################################
cat > "$ROOT/cds/Z_CDS_WM_BinMap.cds" << 'EOF'
@AbapCatalog.sqlViewName: 'ZV_WM_BINMAP'
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'WM Bin Mapping'
define view Z_CDS_WM_BinMap as
  select from zwm_bin_mapping
{
  key lgnum   as Warehouse,
  key lgtyp   as StorageType,
  key lgpla   as Bin,
      zzone   as Zone,
      ztemp   as Temperature
}
EOF

########################################
# DDIC TABLE: ZSD_SALES_HDR
########################################
cat > "$ROOT/ddic/tables/ZSD_SALES_HDR.xml" << 'EOF'
<ddicTable name="ZSD_SALES_HDR" deliveryClass="A" dataBrowser="allowed">
  <fields>
    <field name="VBELN" type="VBELN" key="true" notNull="true"/>
    <field name="KUNNR" type="KUNNR" notNull="true"/>
    <field name="AUDAT" type="DATS" notNull="true"/>
    <field name="ZROUTE" type="ZROUTE"/>
    <field name="ZPRIORITY" type="ZPRIORITY"/>
  </fields>
  <technicalSettings buffering="none" logging="false" enhancementCategory="not_classified"/>
  <indexes>
    <index name="Z01" unique="false">
      <field name="KUNNR"/>
      <field name="AUDAT"/>
    </index>
  </indexes>
</ddicTable>
EOF

########################################
# DDIC TABLE: ZSD_DELIVERY_EXT
########################################
cat > "$ROOT/ddic/tables/ZSD_DELIVERY_EXT.xml" << 'EOF'
<ddicTable name="ZSD_DELIVERY_EXT" deliveryClass="A" dataBrowser="allowed">
  <fields>
    <field name="VBELN" type="VBELN" key="true" notNull="true"/>
    <field name="ZDLV_NO" type="CHAR20"/>
    <field name="ZFLAG" type="CHAR1"/>
  </fields>
  <technicalSettings buffering="none" logging="false" enhancementCategory="not_classified"/>
  <indexes>
    <index name="Z01" unique="false">
      <field name="ZDLV_NO"/>
    </index>
  </indexes>
</ddicTable>
EOF

########################################
# DDIC TABLE: ZWM_BIN_MAPPING
########################################
cat > "$ROOT/ddic/tables/ZWM_BIN_MAPPING.xml" << 'EOF'
<ddicTable name="ZWM_BIN_MAPPING" deliveryClass="A" dataBrowser="allowed">
  <fields>
    <field name="LGNUM" type="LGNUM" key="true" notNull="true"/>
    <field name="LGTYP" type="LGTYP" key="true" notNull="true"/>
    <field name="LGPLA" type="LGPLA" key="true" notNull="true"/>
    <field name="ZZONE" type="CHAR10"/>
    <field name="ZTEMP" type="DEC5_2"/>
  </fields>
  <technicalSettings buffering="single" logging="false" enhancementCategory="not_classified"/>
  <indexes>
    <index name="Z01" unique="false">
      <field name="ZZONE"/>
    </index>
  </indexes>
</ddicTable>
EOF

########################################
# DDIC TABLE: ZWM_TO_ITEMS
########################################
cat > "$ROOT/ddic/tables/ZWM_TO_ITEMS.xml" << 'EOF'
<ddicTable name="ZWM_TO_ITEMS" deliveryClass="A" dataBrowser="allowed">
  <fields>
    <field name="LGNUM" type="LGNUM" key="true" notNull="true"/>
    <field name="TANUM" type="TANUM" key="true" notNull="true"/>
    <field name="POSNR" type="NUMC6" key="true" notNull="true"/>
    <field name="MATNR" type="MATNR"/>
    <field name="MENGE" type="MENGE_D"/>
    <field name="MEINS" type="MEINS"/>
    <field name="LGPLA" type="LGPLA"/>
  </fields>
  <technicalSettings buffering="none" logging="false" enhancementCategory="not_classified"/>
  <indexes>
    <index name="Z01" unique="false">
      <field name="MATNR"/>
    </index>
  </indexes>
</ddicTable>
EOF

########################################
# IDOC SEGMENT: ZE1ZDLV1
########################################
cat > "$ROOT/idoc/segments/ZE1ZDLV1.xml" << 'EOF'
<idocSegment name="ZE1ZDLV1" type="Z" hierarchy="1" description="Extended Delivery Header Segment">
  <fields>
    <field name="VBELN" type="VBELN" description="Delivery Number"/>
    <field name="ZROUTE" type="ZROUTE" description="Route"/>
    <field name="ZPRIORITY" type="ZPRIORITY" description="Priority"/>
    <field name="ZDLV_NO" type="CHAR20" description="Custom Delivery Number"/>
    <field name="ZFLAG" type="CHAR1" description="Special Handling Flag"/>
  </fields>
</idocSegment>
EOF

########################################
# IDOC SEGMENT: ZE1ZWM01
########################################
cat > "$ROOT/idoc/segments/ZE1ZWM01.xml" << 'EOF'
<idocSegment name="ZE1ZWM01" type="Z" hierarchy="1" description="WM Bin Mapping Segment">
  <fields>
    <field name="LGNUM" type="LGNUM" description="Warehouse Number"/>
    <field name="LGTYP" type="LGTYP" description="Storage Type"/>
    <field name="LGPLA" type="LGPLA" description="Storage Bin"/>
    <field name="ZZONE" type="CHAR10" description="Zone"/>
    <field name="ZTEMP" type="DEC5_2" description="Temperature"/>
  </fields>
</idocSegment>
EOF

########################################
# IDOC TYPE: ZDELVRY01
########################################
cat > "$ROOT/idoc/types/ZDELVRY01.xml" << 'EOF'
<idocType name="ZDELVRY01" baseType="DELVRY01" description="Extended Delivery IDoc">
  <segments>
    <segment name="E1EDL20" mandatory="true" multiple="false"/>
    <segment name="ZE1ZDLV1" mandatory="false" multiple="false"/>
    <segment name="E1EDL24" mandatory="true" multiple="true"/>
  </segments>
  <notes>
    <note>Extends standard delivery IDoc with custom delivery number, route, and priority.</note>
  </notes>
</idocType>
EOF

########################################
# IDOC TYPE: ZWM_BINMAP01
########################################
cat > "$ROOT/idoc/types/ZWM_BINMAP01.xml" << 'EOF'
<idocType name="ZWM_BINMAP01" description="WM Bin Mapping IDoc for External WMS">
  <segments>
    <segment name="ZE1ZWM01" mandatory="true" multiple="true"/>
  </segments>
  <notes>
    <note>Used for synchronizing bin metadata with external WMS systems.</note>
  </notes>
</idocType>
EOF

########################################
# WM METADATA: Movement Type Z999
########################################
cat > "$ROOT/wm/movement_type_Z999.json" << 'EOF'
{
  "movement_type": "Z999",
  "description": "Custom O2C/WM Transfer Order Movement",
  "posting_change": false,
  "inventory_mgmt": {
    "requires_batch": false,
    "allows_negative_stock": false
  },
  "wm_settings": {
    "generate_to": true,
    "auto_confirm": false,
    "print_to": true
  }
}
EOF

########################################
# WM METADATA: Putaway Strategy ZPUT01
########################################
cat > "$ROOT/wm/strategy_ZPUT01.json" << 'EOF'
{
  "strategy": "ZPUT01",
  "description": "Temperature‑controlled Putaway Strategy",
  "rules": [
    {
      "condition": "material.temperature_class == 'COLD'",
      "action": "assign_zone('COLD_ZONE')"
    },
    {
      "condition": "material.temperature_class == 'AMBIENT'",
      "action": "assign_zone('AMBIENT_ZONE')"
    }
  ],
  "bin_selection": {
    "sort_by": ["ZZONE", "ZTEMP"],
    "max_results": 10
  }
}
EOF

########################################
# WM METADATA: Picking Strategy ZPICK02
########################################
cat > "$ROOT/wm/strategy_ZPICK02.json" << 'EOF'
{
  "strategy": "ZPICK02",
  "description": "FIFO Picking Strategy with Zone Priority",
  "rules": [
    {
      "condition": "stock.batch_expiry ascending",
      "action": "select_oldest_batch()"
    },
    {
      "condition": "bin.zone_priority ascending",
      "action": "prefer_high_priority_zones()"
    }
  ],
  "bin_selection": {
    "sort_by": ["batch_expiry", "zone_priority"],
    "max_results": 20
  }
}
EOF

########################################
# WM METADATA: Queue ZWM_Q_INBOUND
########################################
cat > "$ROOT/wm/queue_ZWM_Q_INBOUND.json" << 'EOF'
{
  "queue": "ZWM_Q_INBOUND",
  "description": "Inbound Delivery Processing Queue",
  "processing": {
    "parallel_workers": 4,
    "retry_limit": 3,
    "dead_letter_queue": "ZWM_Q_INBOUND_DLQ"
  },
  "filters": {
    "movement_types": ["101", "Z999"],
    "document_types": ["INBOUND_DELIVERY"]
  }
}
EOF

########################################
# WM METADATA: Print Profile ZPICK01
########################################
cat > "$ROOT/wm/print_profile_ZPICK01.json" << 'EOF'
{
  "print_profile": "ZPICK01",
  "description": "Picking Label Print Profile",
  "label_format": "ZLBL_PICK",
  "trigger": {
    "event": "TO_CONFIRMATION",
    "movement_types": ["Z999", "601"]
  },
  "output_device": "LP01"
}
EOF

########################################
# RFC DESTINATION: ZEXT_APO
########################################
cat > "$ROOT/rfc/ZEXT_APO.json" << 'EOF'
{
  "rfc_destination": "ZEXT_APO",
  "description": "External APO Planning System",
  "connection": {
    "type": "3",
    "ashost": "apo-ext.company.com",
    "sysnr": "00",
    "client": "200",
    "user": "RFC_APO",
    "lang": "EN"
  },
  "technical": {
    "max_connections": 5,
    "timeout_seconds": 60,
    "use_snc": false
  },
  "monitoring": {
    "ping_interval_seconds": 300,
    "alert_on_failure": true
  }
}
EOF

########################################
# RFC DESTINATION: ZEXT_WMS
########################################
cat > "$ROOT/rfc/ZEXT_WMS.json" << 'EOF'
{
  "rfc_destination": "ZEXT_WMS",
  "description": "External Warehouse Management System",
  "connection": {
    "type": "T",
    "tpname": "WMS_INBOUND",
    "tptype": "R",
    "gwhost": "sapgw00.company.com",
    "gwserv": "sapgw00"
  },
  "technical": {
    "max_connections": 10,
    "timeout_seconds": 120,
    "use_snc": true,
    "snc_partnername": "p:CN=WMS, O=COMPANY"
  },
  "monitoring": {
    "ping_interval_seconds": 120,
    "alert_on_failure": true
  }
}
EOF

########################################
# RFC DESTINATION: ZEXT_LABELSYS
########################################
cat > "$ROOT/rfc/ZEXT_LABELSYS.json" << 'EOF'
{
  "rfc_destination": "ZEXT_LABELSYS",
  "description": "External Label Printing System (Zebra Server)",
  "connection": {
    "type": "G",
    "http_destination": "http://labels.company.com:8080/api/print",
    "method": "POST"
  },
  "technical": {
    "timeout_seconds": 30,
    "retry_attempts": 2
  },
  "monitoring": {
    "ping_interval_seconds": 600,
    "alert_on_failure": false
  }
}
EOF

########################################
# BATCH JOB: ZJOB_O2C_MONITOR
########################################
cat > "$ROOT/jobs/ZJOB_O2C_MONITOR.json" << 'EOF'
{
  "job_name": "ZJOB_O2C_MONITOR",
  "description": "Daily O2C Sales Order Monitoring",
  "schedule": {
    "frequency": "daily",
    "time": "02:00",
    "days": ["MON", "TUE", "WED", "THU", "FRI"]
  },
  "steps": [
    {
      "program": "ZSD_O2C_MONITOR",
      "variant": "DAILY",
      "language": "EN"
    }
  ],
  "monitoring": {
    "alert_on_failure": true,
    "email_recipients": ["sd-support@company.com"],
    "max_runtime_minutes": 30
  }
}
EOF

########################################
# BATCH JOB: ZJOB_WM_BIN_SYNC
########################################
cat > "$ROOT/jobs/ZJOB_WM_BIN_SYNC.json" << 'EOF'
{
  "job_name": "ZJOB_WM_BIN_SYNC",
  "description": "WM Bin Mapping Synchronisation with External WMS",
  "schedule": {
    "frequency": "hourly",
    "interval_minutes": 60
  },
  "steps": [
    {
      "program": "ZWM_BIN_HEALTHCHECK",
      "variant": "SYNC",
      "language": "EN"
    }
  ],
  "monitoring": {
    "alert_on_failure": true,
    "email_recipients": ["wm-support@company.com"],
    "max_runtime_minutes": 10
  }
}
EOF

########################################
# TRANSPORT: DEVK900123
########################################
cat > "$ROOT/transports/DEVK900123.json" << 'EOF'
{
  "transport": "DEVK900123",
  "owner": "JSMITH",
  "description": "DDIC + CDS foundation objects",
  "created_on": "2026-06-10",
  "objects": [
    { "type": "TABL", "name": "ZSD_SALES_HDR" },
    { "type": "TABL", "name": "ZSD_DELIVERY_EXT" },
    { "type": "TABL", "name": "ZWM_BIN_MAPPING" },
    { "type": "TABL", "name": "ZWM_TO_ITEMS" },
    { "type": "VIEW", "name": "ZV_O2C_HDR" },
    { "type": "VIEW", "name": "ZV_WM_BINMAP" }
  ],
  "dependencies": []
}
EOF

########################################
# TRANSPORT: DEVK900124
########################################
cat > "$ROOT/transports/DEVK900124.json" << 'EOF'
{
  "transport": "DEVK900124",
  "owner": "JSMITH",
  "description": "ABAP O2C programs + function modules",
  "created_on": "2026-06-11",
  "objects": [
    { "type": "PROG", "name": "ZSD_O2C_MONITOR" },
    { "type": "FUGR", "name": "ZFG_O2C" },
    { "type": "FUNC", "name": "Z_SD_CREATE_O2C_ORDER" }
  ],
  "dependencies": ["DEVK900123"]
}
EOF

########################################
# TRANSPORT: DEVK900125
########################################
cat > "$ROOT/transports/DEVK900125.json" << 'EOF'
{
  "transport": "DEVK900125",
  "owner": "JSMITH",
  "description": "ABAP WM programs + TO creation",
  "created_on": "2026-06-12",
  "objects": [
    { "type": "PROG", "name": "ZWM_BIN_HEALTHCHECK" },
    { "type": "FUGR", "name": "ZFG_WM_TO" },
    { "type": "FUNC", "name": "Z_WM_CREATE_TO" }
  ],
  "dependencies": ["DEVK900123"]
}
EOF

########################################
# TRANSPORT: DEVK900127
########################################
cat > "$ROOT/transports/DEVK900127.json" << 'EOF'
{
  "transport": "DEVK900127",
  "owner": "JSMITH",
  "description": "IDoc extensions for O2C + WM",
  "created_on": "2026-06-13",
  "objects": [
    { "type": "IDOC", "name": "ZDELVRY01" },
    { "type": "IDOC", "name": "ZWM_BINMAP01" },
    { "type": "IDOCSEG", "name": "ZE1ZDLV1" },
    { "type": "IDOCSEG", "name": "ZE1ZWM01" }
  ],
  "dependencies": ["DEVK900123"]
}
EOF

########################################
# TRANSPORT: DEVK900129
########################################
cat > "$ROOT/transports/DEVK900129.json" << 'EOF'
{
  "transport": "DEVK900129",
  "owner": "JSMITH",
  "description": "WM metadata + RFC destinations + batch jobs",
  "created_on": "2026-06-14",
  "objects": [
    { "type": "JSON", "name": "movement_type_Z999" },
    { "type": "JSON", "name": "strategy_ZPUT01" },
    { "type": "JSON", "name": "strategy_ZPICK02" },
    { "type": "JSON", "name": "queue_ZWM_Q_INBOUND" },
    { "type": "JSON", "name": "print_profile_ZPICK01" },
    { "type": "RFC", "name": "ZEXT_APO" },
    { "type": "RFC", "name": "ZEXT_WMS" },
    { "type": "RFC", "name": "ZEXT_LABELSYS" },
    { "type": "JOB", "name": "ZJOB_O2C_MONITOR" },
    { "type": "JOB", "name": "ZJOB_WM_BIN_SYNC" }
  ],
  "dependencies": ["DEVK900123", "DEVK900124", "DEVK900125"]
}
EOF

########################################
# FINALISATION: Git Init + ZIP Creation
########################################

echo "Initialising Git repository..."

cd "$ROOT"
git init >/dev/null 2>&1 || true
git add .
git commit -m "Initial commit: Full O2C + WM Repository" >/dev/null 2>&1 || true
cd ..

echo "Creating ZIP archive..."
zip -r "${ROOT}.zip" "$ROOT" >/dev/null 2>&1 || true

echo "------------------------------------------------------------"
echo "Repository build complete."
echo "Location:   $ROOT/"
echo "ZIP file:   ${ROOT}.zip"
echo "------------------------------------------------------------"
echo "You can now import, inspect, or distribute the repository."
echo "------------------------------------------------------------"
