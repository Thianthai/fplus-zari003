"! ทดสอบการประกอบ payload และการอ่าน response โดยไม่ต่อ Salesforce และไม่แตะ DB
CLASS ltc_sfdc_result DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! payload มีครบทุก field ที่ Salesforce ต้องการและสถานะเป็น Completed
    METHODS payload_has_required_fields FOR TESTING.
    "! ใบที่ปิดงานสำเร็จไม่มี reject reason จึงต้องไม่มี field นั้นใน payload
    METHODS payload_omits_empty_reason  FOR TESTING.
    "! batch id ถูกตัดเหลือ 15 ตัวตามความยาว field ฝั่ง Salesforce
    METHODS payload_truncates_batch_id  FOR TESTING.
    "! ทุก subrequest เป็น 204 คือสำเร็จ
    METHODS response_all_204_is_success FOR TESTING.
    "! subrequest ที่พังทำให้ทั้งชุดไม่สำเร็จ และคืน error ตัวที่เป็นต้นเหตุ
    METHODS response_error_is_reported  FOR TESTING.
    "! PROCESSING_HALTED ไม่ใช่ต้นเหตุ ต้องข้ามไปหาตัวจริง
    METHODS response_skips_halted       FOR TESTING.
    "! body ที่ไม่ใช่รูปแบบที่รู้จักต้องไม่ถือว่าสำเร็จ
    METHODS response_garbage_is_error   FOR TESTING.
    "! รูปแบบวันที่ต้องเป็นแบบที่ Salesforce รับ
    METHODS response_date_format        FOR TESTING.

    "! record ตั้งต้น 1 ตัวสำหรับใบที่ปิดงานสำเร็จ
    METHODS sample_record
      RETURNING VALUE(rt_record) TYPE zcl_zari003_sfdc_result=>tt_record.

ENDCLASS.


CLASS ltc_sfdc_result IMPLEMENTATION.

  METHOD sample_record.
    rt_record = VALUE #( ( item_sf_id    = 'a2J0000000000001AA'
                           header_sf_id  = 'a5j0000000000001AA'
                           status        = zcl_zari003_sfdc_result=>gc_status_completed
                           batch_id      = '20260815_090039_1200'
                           response_date = '2026-09-24T10:00:00+0700' ) ).
  ENDMETHOD.

  METHOD payload_has_required_fields.
    DATA(lv_json) = zcl_zari003_sfdc_result=>build_payload( sample_record( ) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"allOrNone":true` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"method":"PATCH"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `cgcloud__Order_Payment__c/a2J0000000000001AA` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"BST_PaymentCollection__c":"a5j0000000000001AA"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"BST_SAP_Status__c":"Completed"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"BST_SAP_ResponseDate__c":"2026-09-24T10:00:00+0700"` ) ).
  ENDMETHOD.

  METHOD payload_omits_empty_reason.
    DATA(lv_json) = zcl_zari003_sfdc_result=>build_payload( sample_record( ) ).

    cl_abap_unit_assert=>assert_false( xsdbool( lv_json CS `BST_SAP_RejectReason__c` ) ).
  ENDMETHOD.

  METHOD payload_truncates_batch_id.
    DATA(lv_json) = zcl_zari003_sfdc_result=>build_payload( sample_record( ) ).

    " ส่งเข้าไป 20 ตัว ต้องเหลือ 15 ตัวแรก
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"BST_SAP_BatchId__c":"20260815_090039"` ) ).
  ENDMETHOD.

  METHOD response_all_204_is_success.
    DATA(lv_json) = `{"compositeResponse":[{"body":null,"httpHeaders":{},"httpStatusCode":204,"referenceId":"item1"},`
                 && `{"body":null,"httpHeaders":{},"httpStatusCode":204,"referenceId":"item2"}]}`.

    DATA(ls_result) = zcl_zari003_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 200 ).

    cl_abap_unit_assert=>assert_true( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-record_count exp = 2 ).
    cl_abap_unit_assert=>assert_initial( ls_result-error_code ).
  ENDMETHOD.

  METHOD response_error_is_reported.
    DATA(lv_json) = `{"compositeResponse":[{"body":null,"httpStatusCode":204,"referenceId":"item1"},`
                 && `{"body":[{"errorCode":"NOT_FOUND","message":"The requested resource does not exist"}],`
                 && `"httpStatusCode":404,"referenceId":"item2"}]}`.

    DATA(ls_result) = zcl_zari003_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 200 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code exp = 'NOT_FOUND' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-error_message CS 'does not exist' ) ).
  ENDMETHOD.

  METHOD response_skips_halted.
    DATA(lv_json) = `{"compositeResponse":[{"body":[{"errorCode":"PROCESSING_HALTED","message":"halted"}],`
                 && `"httpStatusCode":400,"referenceId":"item1"},`
                 && `{"body":[{"errorCode":"STRING_TOO_LONG","message":"data value too large"}],`
                 && `"httpStatusCode":400,"referenceId":"item2"}]}`.

    DATA(ls_result) = zcl_zari003_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 200 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code exp = 'STRING_TOO_LONG' ).
  ENDMETHOD.

  METHOD response_garbage_is_error.
    DATA(ls_result) = zcl_zari003_sfdc_result=>parse_response( iv_json        = `<html>Bad Gateway</html>`
                                                               iv_http_status = 502 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code exp = zcl_zari003_sfdc_result=>gc_err_parse ).
  ENDMETHOD.

  METHOD response_date_format.
    DATA(lv_date) = zcl_zari003_sfdc_result=>build_response_date( ).

    cl_abap_unit_assert=>assert_equals( act = strlen( lv_date )                        exp = 24 ).
    cl_abap_unit_assert=>assert_equals( act = substring( val = lv_date off = 10 len = 1 ) exp = 'T' ).
    cl_abap_unit_assert=>assert_equals( act = substring( val = lv_date off = 19 len = 5 ) exp = '+0700' ).
  ENDMETHOD.

ENDCLASS.
