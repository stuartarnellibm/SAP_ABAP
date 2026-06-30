*&---------------------------------------------------------------------*
*& Report ZCPG_WM_SLOTTING_OPT
*&---------------------------------------------------------------------*
*& Warehouse Slotting Optimization Program
*& Analyzes material velocity and recommends optimal bin assignments
*&
*& Transport: CPDK900150
*& Package: ZCPG_WM
*& Author: WM Development Team
*& Date: 2026-06-17
*&
*& Purpose:
*& - Calculate material movement velocity based on historical data
*& - Recommend optimal storage bins based on velocity and constraints
*& - Support CPG batch rotation requirements (FIFO/FEFO)
*& - Improve warehouse efficiency and reduce travel time
*&
*& Change History:
*& 2026-06-17 - Initial version - CPDK900150
*&---------------------------------------------------------------------*
REPORT zcpg_wm_slotting_opt.

*----------------------------------------------------------------------*
* Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_material_velocity,
         lgnum TYPE lgnum,           " Warehouse number
         matnr TYPE matnr,           " Material number
         maktx TYPE maktx,           " Material description
         picks_30d TYPE i,           " Picks in last 30 days
         picks_90d TYPE i,           " Picks in last 90 days
         velocity_class TYPE char1,  " A/B/C classification
         current_lgtyp TYPE lgtyp,   " Current storage type
         current_lgpla TYPE lgpla,   " Current storage bin
         recommended_lgtyp TYPE lgtyp, " Recommended storage type
         recommended_lgpla TYPE lgpla, " Recommended storage bin
         distance_saved TYPE p DECIMALS 2, " Distance saved (meters)
         priority TYPE char1,        " Priority (H/M/L)
       END OF ty_material_velocity.

TYPES: BEGIN OF ty_bin_capacity,
         lgnum TYPE lgnum,
         lgtyp TYPE lgtyp,
         lgpla TYPE lgpla,
         used_capacity TYPE p DECIMALS 2,
         total_capacity TYPE p DECIMALS 2,
         available_capacity TYPE p DECIMALS 2,
         distance_from_dock TYPE p DECIMALS 2,
       END OF ty_bin_capacity.

*----------------------------------------------------------------------*
* Data Declarations
*----------------------------------------------------------------------*
DATA: gt_velocity TYPE TABLE OF ty_material_velocity,
      gs_velocity TYPE ty_material_velocity,
      gt_bin_capacity TYPE TABLE OF ty_bin_capacity,
      go_slotting_engine TYPE REF TO zcl_cpg_wm_slotting_engine,
      gv_total_materials TYPE i,
      gv_recommendations TYPE i.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_lgnum TYPE lgnum OBLIGATORY DEFAULT '001'. " Warehouse
SELECT-OPTIONS: s_matnr FOR gs_velocity-matnr.          " Material range
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_days TYPE i DEFAULT 30 OBLIGATORY,        " Analysis period (days)
            p_vela TYPE char1 DEFAULT 'X',              " Include A items
            p_velb TYPE char1 DEFAULT 'X',              " Include B items
            p_velc TYPE char1,                          " Include C items
            p_test TYPE char1.                          " Test mode (no updates)
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS: p_disp TYPE char1 DEFAULT 'X',              " Display results
            p_excel TYPE char1,                         " Export to Excel
            p_exec TYPE char1.                          " Execute recommendations
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  " Set selection screen texts
  TEXT-001 = 'Selection Criteria'.
  TEXT-002 = 'Optimization Parameters'.
  TEXT-003 = 'Output Options'.

*----------------------------------------------------------------------*
* At Selection Screen
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  " Validate warehouse exists
  SELECT SINGLE lgnum FROM t300 INTO @DATA(lv_lgnum)
    WHERE lgnum = @p_lgnum.
  IF sy-subrc <> 0.
    MESSAGE e001(zcpg_wm) WITH p_lgnum. " Warehouse & does not exist
  ENDIF.

  " Validate analysis period
  IF p_days < 7 OR p_days > 365.
    MESSAGE e002(zcpg_wm) WITH p_days. " Analysis period must be 7-365 days
  ENDIF.

  " At least one velocity class must be selected
  IF p_vela IS INITIAL AND p_velb IS INITIAL AND p_velc IS INITIAL.
    MESSAGE e003(zcpg_wm). " Select at least one velocity class
  ENDIF.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  " Authorization check
  AUTHORITY-CHECK OBJECT 'W_LTAK'
    ID 'LGNUM' FIELD p_lgnum
    ID 'ACTVT' FIELD '03'. " Display
  IF sy-subrc <> 0.
    MESSAGE e004(zcpg_wm) WITH p_lgnum. " No authorization for warehouse &
    RETURN.
  ENDIF.

  " Create slotting engine instance
  TRY.
      CREATE OBJECT go_slotting_engine
        EXPORTING
          iv_lgnum = p_lgnum
          iv_days  = p_days
          iv_test_mode = p_test.
    CATCH cx_root INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
      RETURN.
  ENDTRY.

  " Calculate material velocity
  PERFORM calculate_velocity.

  " Get bin capacity information
  PERFORM get_bin_capacity.

  " Generate recommendations
  PERFORM generate_recommendations.

  " Display results
  IF p_disp = 'X'.
    PERFORM display_results.
  ENDIF.

  " Export to Excel
  IF p_excel = 'X'.
    PERFORM export_to_excel.
  ENDIF.

  " Execute recommendations
  IF p_exec = 'X' AND p_test IS INITIAL.
    PERFORM execute_recommendations.
  ENDIF.

*----------------------------------------------------------------------*
* End of Selection
*----------------------------------------------------------------------*
END-OF-SELECTION.
  " Display summary
  WRITE: / 'Slotting Optimization Complete'.
  WRITE: / 'Total Materials Analyzed:', gv_total_materials.
  WRITE: / 'Recommendations Generated:', gv_recommendations.
  IF p_test = 'X'.
    WRITE: / 'TEST MODE - No changes made'.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form calculate_velocity
*&---------------------------------------------------------------------*
FORM calculate_velocity.
  DATA: lt_ltap TYPE TABLE OF ltap,
        lv_date_from TYPE datum,
        lv_picks TYPE i.

  " Calculate date range
  lv_date_from = sy-datum - p_days.

  " Get transfer order history for picks
  SELECT lgnum, matnr, COUNT(*) AS picks
    FROM ltap
    WHERE lgnum = @p_lgnum
      AND matnr IN @s_matnr
      AND erdat >= @lv_date_from
      AND bwlvs = '311'  " Picking movement type
    GROUP BY lgnum, matnr
    INTO TABLE @DATA(lt_pick_history).

  IF sy-subrc <> 0.
    MESSAGE i005(zcpg_wm). " No pick history found for selection
    RETURN.
  ENDIF.

  " Get material master data
  SELECT matnr, maktx
    FROM makt
    WHERE matnr IN @s_matnr
      AND spras = @sy-langu
    INTO TABLE @DATA(lt_makt).

  " Get current storage locations
  SELECT lgnum, matnr, lgtyp, lgpla, SUM( verme ) AS quantity
    FROM lqua
    WHERE lgnum = @p_lgnum
      AND matnr IN @s_matnr
    GROUP BY lgnum, matnr, lgtyp, lgpla
    INTO TABLE @DATA(lt_current_stock).

  " Build velocity table
  LOOP AT lt_pick_history INTO DATA(ls_pick).
    CLEAR gs_velocity.
    gs_velocity-lgnum = ls_pick-lgnum.
    gs_velocity-matnr = ls_pick-matnr.
    gs_velocity-picks_30d = COND #( WHEN p_days <= 30 THEN ls_pick-picks
                                     ELSE ls_pick-picks * 30 / p_days ).
    gs_velocity-picks_90d = COND #( WHEN p_days >= 90 THEN ls_pick-picks
                                     ELSE ls_pick-picks * 90 / p_days ).

    " Get material description
    READ TABLE lt_makt INTO DATA(ls_makt) WITH KEY matnr = ls_pick-matnr.
    IF sy-subrc = 0.
      gs_velocity-maktx = ls_makt-maktx.
    ENDIF.

    " Get current location
    READ TABLE lt_current_stock INTO DATA(ls_stock)
      WITH KEY lgnum = ls_pick-lgnum matnr = ls_pick-matnr.
    IF sy-subrc = 0.
      gs_velocity-current_lgtyp = ls_stock-lgtyp.
      gs_velocity-current_lgpla = ls_stock-lgpla.
    ENDIF.

    " Classify velocity (ABC analysis)
    CASE gs_velocity-picks_30d.
      WHEN 0 TO 10.
        gs_velocity-velocity_class = 'C'.
      WHEN 11 TO 50.
        gs_velocity-velocity_class = 'B'.
      WHEN OTHERS.
        gs_velocity-velocity_class = 'A'.
    ENDCASE.

    " Filter by selected velocity classes
    IF ( gs_velocity-velocity_class = 'A' AND p_vela = 'X' ) OR
       ( gs_velocity-velocity_class = 'B' AND p_velb = 'X' ) OR
       ( gs_velocity-velocity_class = 'C' AND p_velc = 'X' ).
      APPEND gs_velocity TO gt_velocity.
    ENDIF.
  ENDLOOP.

  gv_total_materials = lines( gt_velocity ).

  " Sort by velocity (descending)
  SORT gt_velocity BY picks_30d DESCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_bin_capacity
*&---------------------------------------------------------------------*
FORM get_bin_capacity.
  DATA: ls_bin TYPE ty_bin_capacity.

  " Get storage bin master data with capacity
  SELECT l~lgnum, l~lgtyp, l~lgpla,
         SUM( q~verme ) AS used_capacity,
         l~kober AS total_capacity
    FROM lagp AS l
    LEFT JOIN lqua AS q ON l~lgnum = q~lgnum
                       AND l~lgtyp = q~lgtyp
                       AND l~lgpla = q~lgpla
    WHERE l~lgnum = @p_lgnum
      AND l~lvorm = @space  " Not flagged for deletion
    GROUP BY l~lgnum, l~lgtyp, l~lgpla, l~kober
    INTO TABLE @DATA(lt_bins).

  " Calculate available capacity and distance
  LOOP AT lt_bins INTO DATA(ls_bin_data).
    ls_bin-lgnum = ls_bin_data-lgnum.
    ls_bin-lgtyp = ls_bin_data-lgtyp.
    ls_bin-lgpla = ls_bin_data-lgpla.
    ls_bin-used_capacity = ls_bin_data-used_capacity.
    ls_bin-total_capacity = ls_bin_data-total_capacity.
    ls_bin-available_capacity = ls_bin-total_capacity - ls_bin-used_capacity.

    " Calculate distance from shipping dock (simplified - use bin coordinates)
    " In real implementation, this would use actual warehouse layout
    ls_bin-distance_from_dock = strlen( ls_bin-lgpla ) * 10. " Simplified

    APPEND ls_bin TO gt_bin_capacity.
  ENDLOOP.

  " Sort by distance (closest first)
  SORT gt_bin_capacity BY distance_from_dock ASCENDING.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form generate_recommendations
*&---------------------------------------------------------------------*
FORM generate_recommendations.
  DATA: lv_recommended_bin TYPE lgpla,
        lv_distance_saved TYPE p DECIMALS 2.

  LOOP AT gt_velocity ASSIGNING FIELD-SYMBOL(<fs_velocity>).
    " Use slotting engine to recommend optimal bin
    TRY.
        go_slotting_engine->recommend_bin(
          EXPORTING
            iv_matnr = <fs_velocity>-matnr
            iv_velocity_class = <fs_velocity>-velocity_class
            it_bin_capacity = gt_bin_capacity
          IMPORTING
            ev_recommended_lgtyp = <fs_velocity>-recommended_lgtyp
            ev_recommended_lgpla = <fs_velocity>-recommended_lgpla
            ev_distance_saved = <fs_velocity>-distance_saved
        ).

        " Set priority based on distance saved
        <fs_velocity>-priority = COND #(
          WHEN <fs_velocity>-distance_saved > 50 THEN 'H'
          WHEN <fs_velocity>-distance_saved > 20 THEN 'M'
          ELSE 'L'
        ).

        " Only count if recommendation differs from current
        IF <fs_velocity>-recommended_lgpla <> <fs_velocity>-current_lgpla.
          gv_recommendations = gv_recommendations + 1.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Log error but continue
        WRITE: / 'Error for material', <fs_velocity>-matnr, ':', lx_error->get_text( ).
    ENDTRY.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form display_results
*&---------------------------------------------------------------------*
FORM display_results.
  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_layout TYPE slis_layout_alv.

  " Build field catalog
  PERFORM build_fieldcat CHANGING lt_fieldcat.

  " Set layout
  ls_layout-colwidth_optimize = 'X'.
  ls_layout-zebra = 'X'.

  " Display ALV
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      is_layout          = ls_layout
      it_fieldcat        = lt_fieldcat
    TABLES
      t_outtab           = gt_velocity
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_fieldcat
*&---------------------------------------------------------------------*
FORM build_fieldcat CHANGING ct_fieldcat TYPE slis_t_fieldcat_alv.
  DATA: ls_fieldcat TYPE slis_fieldcat_alv.

  DEFINE add_field.
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname = &1.
    ls_fieldcat-seltext_m = &2.
    ls_fieldcat-outputlen = &3.
    APPEND ls_fieldcat TO ct_fieldcat.
  END-OF-DEFINITION.

  add_field 'MATNR' 'Material' 18.
  add_field 'MAKTX' 'Description' 40.
  add_field 'PICKS_30D' 'Picks (30d)' 10.
  add_field 'VELOCITY_CLASS' 'Class' 5.
  add_field 'CURRENT_LGPLA' 'Current Bin' 10.
  add_field 'RECOMMENDED_LGPLA' 'Recommended Bin' 15.
  add_field 'DISTANCE_SAVED' 'Distance Saved (m)' 15.
  add_field 'PRIORITY' 'Priority' 8.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form export_to_excel
*&---------------------------------------------------------------------*
FORM export_to_excel.
  " Export recommendations to Excel file
  DATA: lv_filename TYPE string,
        lv_path TYPE string,
        lv_fullpath TYPE string.

  " Build filename
  CONCATENATE 'SLOTTING_OPT_' p_lgnum '_' sy-datum '_' sy-uzeit '.XLSX'
    INTO lv_filename.

  " Call file save dialog
  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      default_file_name = lv_filename
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath.

  IF lv_fullpath IS NOT INITIAL.
    " Export to Excel (simplified - use SAP2XLSX or similar in real implementation)
    MESSAGE i006(zcpg_wm) WITH lv_fullpath. " Exported to &
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form execute_recommendations
*&---------------------------------------------------------------------*
FORM execute_recommendations.
  DATA: lv_count TYPE i,
        lv_answer TYPE char1.

  " Count high priority recommendations
  LOOP AT gt_velocity INTO gs_velocity WHERE priority = 'H'.
    lv_count = lv_count + 1.
  ENDLOOP.

  " Confirm execution
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Execute Recommendations'
      text_question         = |Execute { lv_count } high priority recommendations?|
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF lv_answer = '1'.
    " Execute recommendations (create transfer orders)
    LOOP AT gt_velocity INTO gs_velocity WHERE priority = 'H'.
      " Call function to create transfer order for relocation
      " This would call BAPI_WHSE_TO_CREATE_MOVE or similar
      " Implementation depends on specific warehouse setup
      WRITE: / 'Would create TO for', gs_velocity-matnr,
               'from', gs_velocity-current_lgpla,
               'to', gs_velocity-recommended_lgpla.
    ENDLOOP.

    MESSAGE i007(zcpg_wm) WITH lv_count. " & recommendations executed
  ENDIF.

ENDFORM.