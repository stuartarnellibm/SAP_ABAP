*&---------------------------------------------------------------------*
*& Table ZCPG_WM_SLOTTING_CFG
*&---------------------------------------------------------------------*
*& Slotting Configuration Table
*& Stores configuration parameters for warehouse slotting optimization
*&
*& Transport: CPDK900150
*& Package: ZCPG_WM
*&---------------------------------------------------------------------*

@EndUserText.label : 'WM Slotting Configuration'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcpg_wm_slotting_cfg {
  key client            : mandt not null;
  key lgnum             : lgnum not null;
  key config_key        : char30 not null;
  config_value          : char255;
  description           : char80;
  @Semantics.user.createdBy : true
  created_by            : syuname;
  @Semantics.systemDateTime.createdAt : true
  created_at            : timestampl;
  @Semantics.user.lastChangedBy : true
  changed_by            : syuname;
  @Semantics.systemDateTime.lastChangedAt : true
  changed_at            : timestampl;
}

*&---------------------------------------------------------------------*
*& Sample Configuration Data
*&---------------------------------------------------------------------*
* LGNUM | CONFIG_KEY              | CONFIG_VALUE | DESCRIPTION
* 001   | VELOCITY_THRESHOLD_A    | 50           | Min picks/month for Class A
* 001   | VELOCITY_THRESHOLD_B    | 20           | Min picks/month for Class B
* 001   | STORAGE_TYPE_CLASS_A    | 001          | Storage type for Class A
* 001   | STORAGE_TYPE_CLASS_B    | 002          | Storage type for Class B
* 001   | STORAGE_TYPE_CLASS_C    | 003          | Storage type for Class C
* 001   | MAX_DISTANCE_CLASS_A    | 50           | Max distance from dock (m)
* 001   | MAX_DISTANCE_CLASS_B    | 100          | Max distance from dock (m)
* 001   | ENABLE_BATCH_ROTATION   | X            | Enable FIFO/FEFO
* 001   | MIN_ANALYSIS_DAYS       | 30           | Minimum analysis period
* 001   | CAPACITY_BUFFER_PCT     | 10           | Reserve capacity %