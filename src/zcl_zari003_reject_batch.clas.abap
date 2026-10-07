"! แจ้ง SBPA ว่ามี Reject รอบใหม่ โดยส่ง reject_batch_id ไปให้
"! caller คือ saver ของปุ่ม Reject ใน ZARE002 ซึ่งเรียก schedule หลังเขียน reject_batch_id ลง table
"! schedule แค่ลงทะเบียนงาน background (bgPF) ไว้ งานจะเริ่มหลัง commit ของ Reject
"! ถ้า Reject ถูก rollback งานนี้จะหายไปด้วย
"! งาน background เรียก send ซึ่งยิง API Trigger ของ SBPA แล้วเขียนผลทับลง reject_message ของทุกใบใน batch
"! auth เป็น OAuth 2.0 client credentials ของ Communication Arrangement ระบบขอ token ให้เอง
"! API key และ trigger id อ่านจาก Additional Properties ของ arrangement เพราะต่างกันในแต่ละระบบ
CLASS zcl_zari003_reject_batch DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! ผลของการแจ้ง SBPA 1 ครั้ง
      "! message คือข้อความที่เขียนลง reject_message
      BEGIN OF ty_result,
        success     TYPE abap_bool,
        http_status TYPE i,
        message     TYPE string,
      END OF ty_result.

    "! ลงทะเบียนงานแจ้ง SBPA ไว้ทำใน background หลัง commit
    "! เรียกได้ใน save phase ของ RAP เพราะไม่ยิง HTTP และไม่ COMMIT เอง
    "! คืนค่าว่างเมื่อลงทะเบียนสำเร็จ
    "! คืนข้อความ error เมื่อลงทะเบียนไม่ได้ ให้ caller เขียนลง reject_message แทน
    CLASS-METHODS schedule
      IMPORTING iv_batch_id     TYPE ztar_i002_pymt-reject_batch_id
      RETURNING VALUE(rv_error) TYPE string.

    "! สร้าง JSON ตามรูปแบบ API Trigger ของ SBPA
    "! invocationContext เป็นค่าคงที่ตามที่ SBPA กำหนด
    "! input มี reject batch id ตัวเดียว
    CLASS-METHODS build_payload
      IMPORTING iv_batch_id    TYPE ztar_i002_pymt-reject_batch_id
      RETURNING VALUE(rv_json) TYPE string.

    "! path ของ API Trigger ต่อจาก host ของ Communication Arrangement
    CLASS-METHODS build_path
      IMPORTING iv_trigger_id  TYPE string
      RETURNING VALUE(rv_path) TYPE string.

    "! แปลผลที่ได้จาก SBPA
    "! HTTP 2xx ถือว่าสำเร็จ
    "! นอกนั้นไม่สำเร็จ และแนบเนื้อหาที่ SBPA ตอบมาไว้ในข้อความ
    CLASS-METHODS parse_response
      IMPORTING iv_batch_id      TYPE ztar_i002_pymt-reject_batch_id
                iv_http_status   TYPE i
                iv_body          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! ยิง SBPA 1 ครั้ง แล้วเขียนผลลง reject_message ของทุกใบใน batch แล้ว COMMIT WORK
    "! ต้องเรียกนอก RAP เท่านั้น ปกติถูกเรียกจากงาน background ใน ZCL_ZARI003_REJECT_BATCH_BG
    METHODS send
      IMPORTING iv_batch_id      TYPE ztar_i002_pymt-reject_batch_id
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    CONSTANTS:
      "! Communication Scenario และ Outbound Service ขาออกไป SBPA
      gc_comm_scenario      TYPE sxco_cds_object_name VALUE 'ZCS_REJECT_BATCH',
      gc_service_id         TYPE c LENGTH 40          VALUE 'ZARI003_REJECT_BATCH_REST',

      "! ชื่อ Additional Properties ของ ZCS_REJECT_BATCH
      "! ค่าจริงกรอกใน Communication Arrangement ของแต่ละระบบ
      gc_prop_api_key       TYPE string VALUE 'API_KEY',
      gc_prop_trigger_id    TYPE string VALUE 'TRIGGER_ID',

      "! path ของ API Trigger คือ prefix ตามด้วย trigger id แล้วปิดด้วย suffix
      "! Outbound Service ตั้ง path เป็น / class นี้ใส่ path เต็มเอง
      gc_path_prefix        TYPE string VALUE '/public/irpa/runtime/v1/apiTriggers/',
      gc_path_suffix        TYPE string VALUE '/runs',

      "! header ที่ SBPA ใช้ตรวจ API key นอกเหนือจาก Bearer token
      gc_header_api_key     TYPE string VALUE 'irpa-api-key',

      "! ชื่อ member ใน JSON ตามรูปแบบ API Trigger ของ SBPA
      "! ชื่อ input ต้องตรงกับที่ตั้งไว้ใน automation ของ SBPA ตัวพิมพ์เล็กใหญ่มีผล
      gc_fld_context        TYPE string VALUE 'invocationContext',
      gc_fld_input          TYPE string VALUE 'input',
      gc_fld_batch_id       TYPE string VALUE 'RejectBatchID',

      "! ค่า invocationContext ที่ SBPA กำหนดให้ส่งแบบนี้ตรงๆ
      gc_invocation_context TYPE string VALUE '${invocation_context}',

      "! ความยาวของเนื้อหาจาก SBPA ที่ใส่ใน message ได้ต่อ placeholder
      gc_text_max           TYPE i VALUE 50,

      gc_msgid              TYPE symsgid VALUE 'ZARI003'.

    "! อ่าน API key และ trigger id จาก Additional Properties ของ Communication Arrangement
    "! คืน abap_false เมื่อหา arrangement ไม่เจอ หรือค่าใดค่าหนึ่งว่าง
    METHODS read_config
      EXPORTING ev_api_key      TYPE string
                ev_trigger_id   TYPE string
      RETURNING VALUE(rv_found) TYPE abap_bool.

    "! เขียนผลลง reject_message ของทุกใบใน batch แล้ว COMMIT WORK
    "! ทับข้อความ Reject สำเร็จที่ ZARE002 เขียนไว้ตอน save
    METHODS save_message
      IMPORTING iv_batch_id TYPE ztar_i002_pymt-reject_batch_id
                iv_message  TYPE string.

    "! text ของ message class
    "! placeholder ละไม่เกิน 50 ตัว
    CLASS-METHODS message_text
      IMPORTING iv_number      TYPE symsgno
                iv_v1          TYPE simple OPTIONAL
                iv_v2          TYPE simple OPTIONAL
                iv_v3          TYPE simple OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_zari003_reject_batch IMPLEMENTATION.

  METHOD schedule.

    TRY.
        DATA(lo_process) = cl_bgmc_process_factory=>get_default( )->create( ).

        lo_process->set_name( 'ZARI003 reject batch to SBPA' ).
        lo_process->set_operation_tx_uncontrolled( NEW zcl_zari003_reject_batch_bg( iv_batch_id ) ).

        " งานจะเริ่มหลัง commit ของ LUW ที่เรียก ถ้า rollback งานจะหายไปด้วย
        lo_process->save_for_execution( ).

      CATCH cx_bgmc INTO DATA(lx_bgmc).
        rv_error = message_text( iv_number = '014'
                                 iv_v1     = iv_batch_id
                                 iv_v2     = lx_bgmc->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD build_payload.

    rv_json = xco_cp_json=>data->builder( )->begin_object(
                )->add_member( gc_fld_context )->add_string( gc_invocation_context
                )->add_member( gc_fld_input )->begin_object(
                  )->add_member( gc_fld_batch_id )->add_string( iv_batch_id
                )->end_object(
                )->end_object( )->get_data( )->to_string( ).

  ENDMETHOD.


  METHOD build_path.

    rv_path = |{ gc_path_prefix }{ iv_trigger_id }{ gc_path_suffix }|.

  ENDMETHOD.


  METHOD parse_response.

    rs_result-http_status = iv_http_status.

    IF iv_http_status BETWEEN 200 AND 299.
      rs_result-success = abap_true.
      rs_result-message = message_text( iv_number = '010'
                                        iv_v1     = iv_batch_id ).
      RETURN.
    ENDIF.

    rs_result-success = abap_false.
    rs_result-message = message_text( iv_number = '011'
                                      iv_v1     = iv_batch_id
                                      iv_v2     = |{ iv_http_status }|
                                      iv_v3     = substring( val = iv_body
                                                             len = nmin( val1 = strlen( iv_body )
                                                                         val2 = gc_text_max ) ) ).

  ENDMETHOD.


  METHOD send.

    DATA lv_api_key    TYPE string.
    DATA lv_trigger_id TYPE string.

    " 1. ไม่มีใบใน batch นี้ ไม่ต้องยิง
    SELECT SINGLE @abap_true
      FROM ztar_i002_pymt
      WHERE reject_batch_id = @iv_batch_id
      INTO @DATA(lv_exists).

    IF lv_exists = abap_false.
      rs_result-message = message_text( iv_number = '013'
                                        iv_v1     = iv_batch_id ).
      RETURN.
    ENDIF.

    " 2. อ่าน API key และ trigger id ของระบบนี้
    " ไม่มีค่าแปลว่ายังไม่ได้กรอกใน Communication Arrangement จึงไม่ยิง
    IF read_config( IMPORTING ev_api_key    = lv_api_key
                              ev_trigger_id = lv_trigger_id ) = abap_false.
      rs_result-message = message_text( iv_number = '015'
                                        iv_v1     = iv_batch_id ).
      save_message( iv_batch_id = iv_batch_id
                    iv_message  = rs_result-message ).
      RETURN.
    ENDIF.

    " 3. ยิง API Trigger ของ SBPA
    " token ของ OAuth 2.0 ระบบขอให้เองจากการตั้งค่าใน Communication Arrangement
    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = gc_comm_scenario
                                 service_id    = gc_service_id ).

        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( build_path( lv_trigger_id ) ).
        lo_request->set_header_field( i_name  = 'Content-Type'
                                      i_value = 'application/json' ).
        lo_request->set_header_field( i_name  = gc_header_api_key
                                      i_value = lv_api_key ).
        lo_request->set_text( build_payload( iv_batch_id ) ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        rs_result = parse_response( iv_batch_id    = iv_batch_id
                                    iv_http_status = lo_response->get_status( )-code
                                    iv_body        = lo_response->get_text( ) ).

        lo_client->close( ).

      CATCH cx_root INTO DATA(lx_root).
        " ต่อไม่ถึง SBPA หรือ Communication Arrangement ยังไม่ได้ผูก
        rs_result-success     = abap_false.
        rs_result-http_status = 0.
        rs_result-message     = message_text( iv_number = '012'
                                              iv_v1     = iv_batch_id
                                              iv_v2     = lx_root->get_text( ) ).
    ENDTRY.

    " 4. เขียนผลทับข้อความ Reject สำเร็จที่ ZARE002 เขียนไว้
    save_message( iv_batch_id = iv_batch_id
                  iv_message  = rs_result-message ).

  ENDMETHOD.


  METHOD read_config.

    DATA lr_scenario TYPE if_com_scenario_factory=>ty_query-cscn_id_range.

    CLEAR: ev_api_key,
           ev_trigger_id.

    rv_found = abap_false.

    TRY.
        lr_scenario = VALUE #( ( sign = 'I' option = 'EQ' low = gc_comm_scenario ) ).

        cl_com_arrangement_factory=>create_instance( )->query_ca(
          EXPORTING is_query           = VALUE #( cscn_id_range = lr_scenario )
          IMPORTING et_com_arrangement = DATA(lt_arrangement) ).

        " scenario นี้ผูกได้ระบบละ 1 arrangement เท่านั้น จึงใช้ตัวแรก
        IF lt_arrangement IS INITIAL.
          RETURN.
        ENDIF.

        DATA(lo_arrangement) = lt_arrangement[ 1 ].
        DATA(lt_property)    = lo_arrangement->get_properties( ).

        LOOP AT lt_property INTO DATA(ls_property).
          CASE ls_property-name.
            WHEN gc_prop_api_key.
              ev_api_key = VALUE #( ls_property-values[ 1 ] OPTIONAL ).
            WHEN gc_prop_trigger_id.
              ev_trigger_id = VALUE #( ls_property-values[ 1 ] OPTIONAL ).
          ENDCASE.
        ENDLOOP.

      CATCH cx_root.
        " อ่าน arrangement ไม่ได้ ถือว่าไม่มีค่า
        RETURN.
    ENDTRY.

    rv_found = xsdbool( ev_api_key IS NOT INITIAL AND ev_trigger_id IS NOT INITIAL ).

  ENDMETHOD.


  METHOD save_message.

    DATA lv_now TYPE abp_lastchange_tstmpl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user)    = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_message) = CONV ztar_i002_pymt-reject_message( iv_message ).

    UPDATE ztar_i002_pymt
      SET reject_message        = @lv_message,
          last_changed_by       = @lv_user,
          last_changed_at       = @lv_now,
          local_last_changed_at = @lv_now
      WHERE reject_batch_id = @iv_batch_id.

    COMMIT WORK.

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_number WITH iv_v1 iv_v2 iv_v3 INTO rv_text.

  ENDMETHOD.

ENDCLASS.
