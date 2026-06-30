*"* use this source file for your ABAP unit test classes
CLASS ltc_slotting_engine DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_cut TYPE REF TO zcl_cpg_wm_slotting_engine.

    METHODS: setup,
             teardown,
             test_constructor FOR TESTING,
             test_velocity_score_calculation FOR TESTING,
             test_recommend_bin_class_a FOR TESTING,
             test_recommend_bin_class_b FOR TESTING,
             test_recommend_bin_class_c FOR TESTING,
             test_recommend_bin_no_capacity FOR TESTING,
             test_storage_type_mapping FOR TESTING.

ENDCLASS.


CLASS ltc_slotting_engine IMPLEMENTATION.

  METHOD setup.
    " Create instance for testing
    CREATE OBJECT mo_cut
      EXPORTING
        iv_lgnum     = '001'
        iv_days      = 30
        iv_test_mode = 'X'.
  ENDMETHOD.

  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.

  METHOD test_constructor.
    " Test: Constructor initializes object correctly
    DATA: lo_engine TYPE REF TO zcl_cpg_wm_slotting_engine.

    CREATE OBJECT lo_engine
      EXPORTING
        iv_lgnum     = '001'
        iv_days      = 90
        iv_test_mode = 'X'.

    cl_abap_unit_assert=>assert_bound(
      act = lo_engine
      msg = 'Slotting engine should be instantiated'
    ).
  ENDMETHOD.

  METHOD test_velocity_score_calculation.
    " Test: Velocity score calculation
    DATA: lv_score TYPE p.

    " Test case 1: High velocity
    lv_score = mo_cut->calculate_velocity_score(
      iv_picks_30d = 100
      iv_picks_90d = 200
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_score
      exp = 100  " Should be capped at 100
      msg = 'High velocity score should be capped at 100'
    ).

    " Test case 2: Medium velocity
    lv_score = mo_cut->calculate_velocity_score(
      iv_picks_30d = 20
      iv_picks_90d = 40
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_score
      exp = '26.67'
      msg = 'Medium velocity score should be calculated correctly'
      tol = '0.01'
    ).

    " Test case 3: Low velocity
    lv_score = mo_cut->calculate_velocity_score(
      iv_picks_30d = 5
      iv_picks_90d = 10
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_score
      exp = '6.67'
      msg = 'Low velocity score should be calculated correctly'
      tol = '0.01'
    ).

    " Test case 4: Zero velocity
    lv_score = mo_cut->calculate_velocity_score(
      iv_picks_30d = 0
      iv_picks_90d = 0
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_score
      exp = 0
      msg = 'Zero velocity should return zero score'
    ).
  ENDMETHOD.

  METHOD test_recommend_bin_class_a.
    " Test: Recommend bin for Class A (high velocity) material
    DATA: lv_lgtyp TYPE lgtyp,
          lv_lgpla TYPE lgpla,
          lv_distance TYPE p.

    " Prepare test data - bin capacity table
    TYPES: BEGIN OF ty_bin_test,
             lgnum              TYPE lgnum,
             lgtyp              TYPE lgtyp,
             lgpla              TYPE lgpla,
             used_capacity      TYPE p,
             total_capacity     TYPE p,
             available_capacity TYPE p,
             distance_from_dock TYPE p,
           END OF ty_bin_test.

    DATA: lt_bins TYPE TABLE OF ty_bin_test.

    " Add test bins
    lt_bins = VALUE #(
      ( lgnum = '001' lgtyp = '001' lgpla = '0001-01-01'
        used_capacity = 50 total_capacity = 100 available_capacity = 50
        distance_from_dock = 10 )
      ( lgnum = '001' lgtyp = '001' lgpla = '0001-01-02'
        used_capacity = 80 total_capacity = 100 available_capacity = 20
        distance_from_dock = 15 )
      ( lgnum = '001' lgtyp = '002' lgpla = '0002-01-01'
        used_capacity = 30 total_capacity = 100 available_capacity = 70
        distance_from_dock = 50 )
    ).

    " Execute
    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = '000000000000100001'
        iv_velocity_class = 'A'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
        ev_recommended_lgpla = lv_lgpla
        ev_distance_saved = lv_distance
    ).

    " Assert: Should recommend storage type 001 (fast pick)
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '001'
      msg = 'Class A material should be assigned to storage type 001'
    ).

    " Assert: Should recommend closest available bin
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgpla
      exp = '0001-01-01'
      msg = 'Should recommend closest bin with capacity'
    ).

    " Assert: Distance saved should be significant for Class A
    cl_abap_unit_assert=>assert_equals(
      act = lv_distance
      exp = 50
      msg = 'Class A should save significant distance'
    ).
  ENDMETHOD.

  METHOD test_recommend_bin_class_b.
    " Test: Recommend bin for Class B (medium velocity) material
    DATA: lv_lgtyp TYPE lgtyp,
          lv_lgpla TYPE lgpla,
          lv_distance TYPE p.

    TYPES: BEGIN OF ty_bin_test,
             lgnum              TYPE lgnum,
             lgtyp              TYPE lgtyp,
             lgpla              TYPE lgpla,
             used_capacity      TYPE p,
             total_capacity     TYPE p,
             available_capacity TYPE p,
             distance_from_dock TYPE p,
           END OF ty_bin_test.

    DATA: lt_bins TYPE TABLE OF ty_bin_test.

    lt_bins = VALUE #(
      ( lgnum = '001' lgtyp = '002' lgpla = '0002-01-01'
        used_capacity = 40 total_capacity = 100 available_capacity = 60
        distance_from_dock = 30 )
    ).

    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = '000000000000100002'
        iv_velocity_class = 'B'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
        ev_recommended_lgpla = lv_lgpla
        ev_distance_saved = lv_distance
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '002'
      msg = 'Class B material should be assigned to storage type 002'
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_distance
      exp = 25
      msg = 'Class B should save moderate distance'
    ).
  ENDMETHOD.

  METHOD test_recommend_bin_class_c.
    " Test: Recommend bin for Class C (low velocity) material
    DATA: lv_lgtyp TYPE lgtyp,
          lv_lgpla TYPE lgpla,
          lv_distance TYPE p.

    TYPES: BEGIN OF ty_bin_test,
             lgnum              TYPE lgnum,
             lgtyp              TYPE lgtyp,
             lgpla              TYPE lgpla,
             used_capacity      TYPE p,
             total_capacity     TYPE p,
             available_capacity TYPE p,
             distance_from_dock TYPE p,
           END OF ty_bin_test.

    DATA: lt_bins TYPE TABLE OF ty_bin_test.

    lt_bins = VALUE #(
      ( lgnum = '001' lgtyp = '003' lgpla = '0003-01-01'
        used_capacity = 20 total_capacity = 100 available_capacity = 80
        distance_from_dock = 100 )
    ).

    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = '000000000000100003'
        iv_velocity_class = 'C'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
        ev_recommended_lgpla = lv_lgpla
        ev_distance_saved = lv_distance
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '003'
      msg = 'Class C material should be assigned to storage type 003'
    ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_distance
      exp = 10
      msg = 'Class C should save minimal distance'
    ).
  ENDMETHOD.

  METHOD test_recommend_bin_no_capacity.
    " Test: Handle case when no bins have available capacity
    DATA: lv_lgtyp TYPE lgtyp,
          lv_lgpla TYPE lgpla,
          lv_distance TYPE p.

    TYPES: BEGIN OF ty_bin_test,
             lgnum              TYPE lgnum,
             lgtyp              TYPE lgtyp,
             lgpla              TYPE lgpla,
             used_capacity      TYPE p,
             total_capacity     TYPE p,
             available_capacity TYPE p,
             distance_from_dock TYPE p,
           END OF ty_bin_test.

    DATA: lt_bins TYPE TABLE OF ty_bin_test.

    " All bins at full capacity
    lt_bins = VALUE #(
      ( lgnum = '001' lgtyp = '001' lgpla = '0001-01-01'
        used_capacity = 100 total_capacity = 100 available_capacity = 0
        distance_from_dock = 10 )
    ).

    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = '000000000000100004'
        iv_velocity_class = 'A'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
        ev_recommended_lgpla = lv_lgpla
        ev_distance_saved = lv_distance
    ).

    " Should still return storage type but no specific bin
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '001'
      msg = 'Should return target storage type even with no capacity'
    ).

    cl_abap_unit_assert=>assert_initial(
      act = lv_lgpla
      msg = 'Should return empty bin when no capacity available'
    ).
  ENDMETHOD.

  METHOD test_storage_type_mapping.
    " Test: Verify storage type mapping for all velocity classes
    " This is an indirect test through recommend_bin

    DATA: lv_lgtyp TYPE lgtyp.

    TYPES: BEGIN OF ty_bin_test,
             lgnum              TYPE lgnum,
             lgtyp              TYPE lgtyp,
             lgpla              TYPE lgpla,
             used_capacity      TYPE p,
             total_capacity     TYPE p,
             available_capacity TYPE p,
             distance_from_dock TYPE p,
           END OF ty_bin_test.

    DATA: lt_bins TYPE TABLE OF ty_bin_test.

    " Prepare bins for all storage types
    lt_bins = VALUE #(
      ( lgnum = '001' lgtyp = '001' lgpla = '0001-01-01'
        available_capacity = 100 distance_from_dock = 10 )
      ( lgnum = '001' lgtyp = '002' lgpla = '0002-01-01'
        available_capacity = 100 distance_from_dock = 30 )
      ( lgnum = '001' lgtyp = '003' lgpla = '0003-01-01'
        available_capacity = 100 distance_from_dock = 100 )
    ).

    " Test Class A -> Storage Type 001
    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = 'TEST001'
        iv_velocity_class = 'A'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
    ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '001'
      msg = 'Class A should map to storage type 001'
    ).

    " Test Class B -> Storage Type 002
    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = 'TEST002'
        iv_velocity_class = 'B'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
    ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '002'
      msg = 'Class B should map to storage type 002'
    ).

    " Test Class C -> Storage Type 003
    mo_cut->recommend_bin(
      EXPORTING
        iv_matnr = 'TEST003'
        iv_velocity_class = 'C'
        it_bin_capacity = lt_bins
      IMPORTING
        ev_recommended_lgtyp = lv_lgtyp
    ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_lgtyp
      exp = '003'
      msg = 'Class C should map to storage type 003'
    ).
  ENDMETHOD.

ENDCLASS.