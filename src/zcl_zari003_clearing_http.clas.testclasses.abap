"! ทดสอบเฉพาะการอ่าน body
"! ไม่แตะ DB ไม่ต่อ Salesforce
CLASS ltc_clearing_http DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! body ครบถ้วนแปลงได้และเลขเอกสารถูกเติมศูนย์ให้ตรงกับที่เก็บในตาราง
    METHODS parse_accepts_full_body      FOR TESTING.
    "! ขาด field ที่ใช้ระบุใบ ต้องไม่ผ่าน
    METHODS parse_rejects_missing_key    FOR TESTING.
    "! Status S แต่ไม่มีเลข clearing ต้องไม่ผ่าน
    METHODS parse_rejects_success_wo_doc FOR TESTING.
    "! Status นอกเหนือจาก S และ E ต้องไม่ผ่าน
    METHODS parse_rejects_bad_status     FOR TESTING.
    "! Status E ไม่ต้องมีเลข clearing ก็ผ่านได้
    METHODS parse_accepts_error_status   FOR TESTING.

ENDCLASS.


CLASS ltc_clearing_http IMPLEMENTATION.

  METHOD parse_accepts_full_body.
    zcl_zari003_clearing_http=>parse_request(
      EXPORTING iv_body    = `{"RequestId":"20260924_143000","CompanyCode":"2000",`
                          && `"PaymentDocumentNo":"1000002301","PaymentAccountingDocument":"3500000006",`
                          && `"PaymentAccountingDocYear":"2026","ClearingDocument":"3000000012",`
                          && `"ClearingDocumentYear":"2026","ClearingStatus":"S","ClearingMessage":""}`
      IMPORTING es_request = DATA(ls_request)
                ev_error   = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_initial( lv_error ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-request_id                  exp = '20260924_143000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-payment_accounting_document exp = '3500000006' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-payment_accounting_doc_year exp = '2026' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-clearing_document           exp = '3000000012' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-clearing_document_year      exp = '2026' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-clearing_status             exp = 'S' ).
  ENDMETHOD.

  METHOD parse_rejects_missing_key.
    zcl_zari003_clearing_http=>parse_request(
      EXPORTING iv_body  = `{"CompanyCode":"2000","ClearingStatus":"S"}`
      IMPORTING ev_error = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_error CS 'PaymentAccountingDocument' ) ).
  ENDMETHOD.

  METHOD parse_rejects_success_wo_doc.
    zcl_zari003_clearing_http=>parse_request(
      EXPORTING iv_body  = `{"CompanyCode":"2000","PaymentAccountingDocument":"3500000006",`
                        && `"PaymentAccountingDocYear":"2026","ClearingStatus":"S"}`
      IMPORTING ev_error = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_error CS 'ClearingDocument' ) ).
  ENDMETHOD.

  METHOD parse_rejects_bad_status.
    zcl_zari003_clearing_http=>parse_request(
      EXPORTING iv_body  = `{"CompanyCode":"2000","PaymentAccountingDocument":"3500000006",`
                        && `"PaymentAccountingDocYear":"2026","ClearingStatus":"X"}`
      IMPORTING ev_error = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_error CS 'ClearingStatus must be S or E' ) ).
  ENDMETHOD.

  METHOD parse_accepts_error_status.
    zcl_zari003_clearing_http=>parse_request(
      EXPORTING iv_body    = `{"CompanyCode":"2000","PaymentAccountingDocument":"3500000006",`
                          && `"PaymentAccountingDocYear":"2026","ClearingStatus":"E",`
                          && `"ClearingMessage":"Open item not found"}`
      IMPORTING es_request = DATA(ls_request)
                ev_error   = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_initial( lv_error ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-clearing_status  exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-clearing_message exp = 'Open item not found' ).
  ENDMETHOD.

ENDCLASS.
