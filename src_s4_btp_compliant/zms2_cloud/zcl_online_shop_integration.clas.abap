CLASS zcl_online_shop_integration DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Send order data to cloud integration platform
    "! @parameter iv_order_id | Order ID
    "! @parameter iv_created_by | User who created the order
    "! @raising zcx_integration_error | Integration error
    CLASS-METHODS send_order_to_cloud
      IMPORTING
        iv_order_id   TYPE numc08
        iv_created_by TYPE syuname
      RAISING
        zcx_integration_error.

    "! Process order in background using Background Processing Framework
    "! @parameter iv_order_id | Order ID
    "! @parameter iv_created_by | User who created the order
    CLASS-METHODS process_order_background
      IMPORTING
        iv_order_id   TYPE numc08
        iv_created_by TYPE syuname.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! Convert order data to JSON format
    "! @parameter iv_order_id | Order ID
    "! @parameter iv_created_by | User who created the order
    "! @parameter rv_json | JSON string
    CLASS-METHODS convert_order_to_json
      IMPORTING
        iv_order_id   TYPE numc08
        iv_created_by TYPE syuname
      RETURNING
        VALUE(rv_json) TYPE string.

    "! Send HTTP request to cloud platform
    "! @parameter iv_json_data | JSON payload
    "! @parameter rv_response | HTTP response
    "! @raising zcx_integration_error | Integration error
    CLASS-METHODS send_http_request
      IMPORTING
        iv_json_data TYPE string
      RETURNING
        VALUE(rv_response) TYPE string
      RAISING
        zcx_integration_error.

ENDCLASS.



CLASS zcl_online_shop_integration IMPLEMENTATION.

  METHOD send_order_to_cloud.
    TRY.
        " Convert order data to JSON
        DATA(lv_json) = convert_order_to_json(
          iv_order_id   = iv_order_id
          iv_created_by = iv_created_by
        ).

        " Send to cloud platform via HTTP
        DATA(lv_response) = send_http_request( lv_json ).

        " Log successful transmission
        " TODO: Implement application logging

      CATCH cx_root INTO DATA(lx_error).
        " Wrap in custom exception
        RAISE EXCEPTION TYPE zcx_integration_error
          EXPORTING
            previous = lx_error
            textid   = zcx_integration_error=>send_failed.
    ENDTRY.
  ENDMETHOD.

  METHOD process_order_background.
    " Use Background Processing Framework (bgPF) - ABAP Cloud compliant
    " This replaces the old CALL FUNCTION...IN BACKGROUND TASK pattern
    
    TRY.
        " Create background job using bgPF
        DATA(lo_job_template_api) = cl_bgmc_process_factory=>get_default( )->create( ).
        
        " Set job name and parameters
        lo_job_template_api->set_name( |ONLINE_SHOP_ORDER_{ iv_order_id }| ).
        lo_job_template_api->set_description( |Process order { iv_order_id } for user { iv_created_by }| ).
        
        " Schedule the job
        lo_job_template_api->schedule( ).
        
        " Alternative: Use Job Scheduling API for more complex scenarios
        " DATA(lo_job_scheduler) = cl_apj_rt_api=>create_job_scheduler( ).
        
      CATCH cx_root INTO DATA(lx_error).
        " Log error but don't fail the main process
        " TODO: Implement proper error logging
    ENDTRY.
  ENDMETHOD.

  METHOD convert_order_to_json.
    " Create order structure
    DATA: BEGIN OF ls_order,
            order_id   TYPE numc08,
            created_by TYPE syuname,
            timestamp  TYPE timestampl,
            event_type TYPE string,
          END OF ls_order.

    ls_order-order_id = iv_order_id.
    ls_order-created_by = iv_created_by.
    GET TIME STAMP FIELD ls_order-timestamp.
    ls_order-event_type = 'ORDER_CREATED'.

    " Convert to JSON using /UI2/CL_JSON (released for ABAP Cloud)
    rv_json = /ui2/cl_json=>serialize(
      data          = ls_order
      compress      = abap_true
      pretty_name   = /ui2/cl_json=>pretty_mode-camel_case
    ).
  ENDMETHOD.

  METHOD send_http_request.
    " Use HTTP client (released API for ABAP Cloud)
    " This would connect to SAP Event Mesh or Integration Suite
    
    TRY.
        " Create HTTP client using destination service
        " In real implementation, use Communication Arrangement
        DATA(lo_http_client) = cl_http_client=>create_by_destination(
          destination = 'AZURE_EVENT_MESH'  " Communication Arrangement
        ).

        " Set request method and headers
        lo_http_client->request->set_method( if_http_request=>co_request_method_post ).
        lo_http_client->request->set_header_field(
          name  = 'Content-Type'
          value = 'application/json'
        ).

        " Set request body
        lo_http_client->request->set_cdata( iv_json_data ).

        " Send request
        lo_http_client->send( ).

        " Receive response
        lo_http_client->receive( ).

        " Get response data
        rv_response = lo_http_client->response->get_cdata( ).

        " Check HTTP status
        DATA(lv_status) = lo_http_client->response->get_status( ).
        IF lv_status-code < 200 OR lv_status-code >= 300.
          RAISE EXCEPTION TYPE zcx_integration_error
            EXPORTING
              textid = zcx_integration_error=>http_error.
        ENDIF.

        " Close connection
        lo_http_client->close( ).

      CATCH cx_http_client_failed INTO DATA(lx_http).
        RAISE EXCEPTION TYPE zcx_integration_error
          EXPORTING
            previous = lx_http
            textid   = zcx_integration_error=>http_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.