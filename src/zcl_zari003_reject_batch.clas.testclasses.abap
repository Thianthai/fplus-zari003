"! ทดสอบการสร้าง payload และการแปลผลจาก SBPA โดยไม่ยิงจริงและไม่แตะ DB
CLASS ltc_reject_batch DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! payload มี batch id
    METHODS payload_has_batch_id    FOR TESTING.
    "! HTTP 2xx คือสำเร็จ และข้อความบอก batch id
    METHODS response_2xx_is_success FOR TESTING.
    "! HTTP 4xx ไม่สำเร็จ ข้อความมี HTTP status และเนื้อหาที่ SBPA ตอบมา
    METHODS response_4xx_is_failure FOR TESTING.
    "! body ว่างยังแปลผลได้ ไม่ dump
    METHODS response_empty_body     FOR TESTING.

ENDCLASS.


CLASS ltc_reject_batch IMPLEMENTATION.

  METHOD payload_has_batch_id.
    DATA(lv_json) = zcl_zari003_reject_batch=>build_payload( '20260929_143000' ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"RejectBatchId":"20260929_143000"` ) ).
  ENDMETHOD.

  METHOD response_2xx_is_success.
    DATA(ls_result) = zcl_zari003_reject_batch=>parse_response( iv_batch_id    = '20260929_143000'
                                                                iv_http_status = 202
                                                                iv_body        = `` ).

    cl_abap_unit_assert=>assert_true( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-http_status exp = 202 ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-message CS '20260929_143000' ) ).
  ENDMETHOD.

  METHOD response_4xx_is_failure.
    DATA(ls_result) = zcl_zari003_reject_batch=>parse_response( iv_batch_id    = '20260929_143000'
                                                                iv_http_status = 400
                                                                iv_body        = `{"error":"invalid batch"}` ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-message CS '400' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-message CS 'invalid batch' ) ).
  ENDMETHOD.

  METHOD response_empty_body.
    DATA(ls_result) = zcl_zari003_reject_batch=>parse_response( iv_batch_id    = '20260929_143000'
                                                                iv_http_status = 500
                                                                iv_body        = `` ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-message CS '500' ) ).
  ENDMETHOD.

ENDCLASS.
