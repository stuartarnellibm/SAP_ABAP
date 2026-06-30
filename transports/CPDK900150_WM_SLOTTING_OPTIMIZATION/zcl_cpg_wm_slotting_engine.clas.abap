CLASS zcl_cpg_wm_slotting_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Constructor
    "! @parameter iv_lgnum | Warehouse number
    "! @parameter iv_days | Analysis period in days
    "! @parameter iv_test_mode | Test mode flag
    METHODS constructor
      IMPORTING
        iv_lgnum     TYPE lgnum
        iv_days      TYPE i
        iv_test_mode TYPE char1 OPTIONAL.

    "! Recommend optimal storage bin for material
    "! @parameter iv_matnr | Material number
    "! @parameter iv_velocity_class | Velocity classification (A/B/C)
    "! @parameter it_bin_capacity | Available bin capacity data
    "! @parameter ev_recommended_lgtyp | Recommended storage type
    "! @parameter ev_recommended_lgpla | Recommended storage bin
    "! @parameter ev_distance_saved | Distance saved in meters
    METHODS recommend_bin
      IMPORTING
        iv_matnr              TYPE matnr
        iv_velocity_class     TYPE char1
        it_bin_capacity       TYPE ANY TABLE
      EXPORTING
        ev_recommended_lgtyp  TYPE lgtyp
        ev_recommended_lgpla  TYPE lgpla
        ev_distance_saved     TYPE p
      RAISING
        cx_sy_arithmetic_error.

    "! Calculate material velocity score
    "! @parameter iv_picks_30d | Picks in last 30 days
    "! @parameter iv_picks_90d | Picks in last 90 days
    "! @parameter rv_score | Velocity score (0-100)
    METHODS calculate_velocity_score
      IMPORTING
        iv_picks_30d  TYPE i
        iv_picks_90d  TYPE i
      RETURNING
        VALUE(rv_score) TYPE p.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: mv_lgnum     TYPE lgnum,
          mv_days      TYPE i,
          mv_test_mode TYPE char1.

    "! Get storage type for velocity class
    "! @parameter iv_velocity_class | Velocity class (A/B/C)
    "! @parameter rv_lgtyp | Storage type
    METHODS get_storage_type_for_class
      IMPORTING
        iv_velocity_class TYPE char1
      RETURNING
        VALUE(rv_lgtyp)   TYPE lgtyp.

    "! Calculate distance between two bins
    "! @parameter iv_bin1 | First bin
    "! @parameter iv_bin2 | Second bin
    "! @parameter rv_distance | Distance in meters
    METHODS calculate_distance
      IMPORTING
        iv_bin1           TYPE lgpla
        iv_bin2           TYPE lgpla
      RETURNING
        VALUE(rv_distance) TYPE p.

ENDCLASS.



CLASS zcl_cpg_wm_slotting_engine IMPLEMENTATION.

  METHOD constructor.
    mv_lgnum = iv_lgnum.
    mv_days = iv_days.
    mv_test_mode = iv_test_mode.
  ENDMETHOD.

  METHOD recommend_bin.
    DATA: lv_target_lgtyp TYPE lgtyp,
          lv_best_bin     TYPE lgpla,
          lv_best_score   TYPE p,
          lv_current_dist TYPE p,
          lv_new_dist     TYPE p.

    " Get target storage type based on velocity class
    lv_target_lgtyp = get_storage_type_for_class( iv_velocity_class ).

    " Find best available bin in target storage type
    LOOP AT it_bin_capacity ASSIGNING FIELD-SYMBOL(<fs_bin>).
      DATA(lv_lgtyp) = CAST lgtyp( <fs_bin>-('LGTYP') ).
      DATA(lv_lgpla) = CAST lgpla( <fs_bin>-('LGPLA') ).
      DATA(lv_available) = CAST p( <fs_bin>-('AVAILABLE_CAPACITY') ).
      DATA(lv_distance) = CAST p( <fs_bin>-('DISTANCE_FROM_DOCK') ).

      " Check if bin matches target storage type and has capacity
      IF lv_lgtyp = lv_target_lgtyp AND lv_available > 0.
        " Calculate score (lower distance = higher score)
        DATA(lv_score) = 100 - ( lv_distance / 10 ).

        " Select bin with highest score
        IF lv_best_bin IS INITIAL OR lv_score > lv_best_score.
          lv_best_bin = lv_lgpla.
          lv_best_score = lv_score.
          lv_new_dist = lv_distance.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " Set recommendations
    ev_recommended_lgtyp = lv_target_lgtyp.
    ev_recommended_lgpla = lv_best_bin.

    " Calculate distance saved (simplified)
    " In real implementation, would get current bin distance
    ev_distance_saved = COND #(
      WHEN iv_velocity_class = 'A' THEN 100
      WHEN iv_velocity_class = 'B' THEN 25
      ELSE 10
    ).

  ENDMETHOD.

  METHOD calculate_velocity_score.
    " Weight recent activity more heavily
    rv_score = ( iv_picks_30d * 2 + iv_picks_90d ) / 3.

    " Normalize to 0-100 scale
    IF rv_score > 100.
      rv_score = 100.
    ENDIF.
  ENDMETHOD.

  METHOD get_storage_type_for_class.
    " Map velocity class to storage type
    " A items -> Fast pick area (001)
    " B items -> Standard pick area (002)
    " C items -> Reserve storage (003)
    rv_lgtyp = SWITCH #( iv_velocity_class
      WHEN 'A' THEN '001'
      WHEN 'B' THEN '002'
      WHEN 'C' THEN '003'
      ELSE '002'
    ).
  ENDMETHOD.

  METHOD calculate_distance.
    " Simplified distance calculation based on bin naming
    " Real implementation would use actual warehouse coordinates
    DATA: lv_num1 TYPE i,
          lv_num2 TYPE i.

    " Extract numeric portion of bin IDs
    lv_num1 = CONV i( iv_bin1+0(4) ).
    lv_num2 = CONV i( iv_bin2+0(4) ).

    " Calculate Manhattan distance (simplified)
    rv_distance = abs( lv_num1 - lv_num2 ) * 2.
  ENDMETHOD.

ENDCLASS.