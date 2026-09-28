"! API ที่ BOT เรียกกลับมาบอกผลการ clear ทีละใบ
"! GET คืนตัวอย่างโครงสร้างไว้ให้ดูโดยไม่ต้องเปิดเอกสาร
"! POST รับผล 1 ใบแล้วส่งต่อให้ ZCL_ZARI003_CLEARING_RESULT
"! JSON key เป็น PascalCase เหมือน API อื่นที่ BOT ใช้
"! ทุกค่าเป็น string รวมถึงปีบัญชี เพราะเป็นรหัสไม่ใช่จำนวนที่เอาไปคำนวณ
CLASS zcl_zari003_clearing_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

    TYPES:
      "! request ที่ BOT ส่งมา
      BEGIN OF ty_request,
        request_id                  TYPE string,
        company_code                TYPE string,
        payment_document_no         TYPE string,
        payment_accounting_document TYPE string,
        payment_accounting_doc_year TYPE string,
        clearing_document           TYPE string,
        clearing_document_year      TYPE string,
        clearing_status             TYPE string,
        clearing_message            TYPE string,
      END OF ty_request,

      "! response ที่ตอบกลับ
      "! SapStatus C คือ SAP บันทึกผล clearing เรียบร้อย E คือไม่ผ่าน
      "! SalesforceStatus เป็นผลของการแจ้ง Salesforce ต่อ ไม่ใช่ความรับผิดชอบของ BOT
      BEGIN OF ty_response,
        sap_status         TYPE string,
        sap_message        TYPE string,
        salesforce_status  TYPE string,
        salesforce_message TYPE string,
      END OF ty_response,

      "! ตัวอย่างที่ GET ตอบกลับ
      BEGIN OF ty_usage,
        service  TYPE string,
        method   TYPE string,
        request  TYPE ty_request,
        response TYPE ty_response,
        note     TYPE STANDARD TABLE OF string WITH EMPTY KEY,
      END OF ty_usage.

    CONSTANTS gc_msgid TYPE symsgid VALUE 'ZARI003'.

    "! แปลง body เป็น request ที่ ZCL_ZARI003_CLEARING_RESULT ใช้ได้
    "! คืน ev_error เมื่อ body ผิดรูปแบบหรือข้อมูลที่จำเป็นขาด
    "! แยกเป็น static ไว้ทดสอบโดยไม่ต้องมี request จริง
    CLASS-METHODS parse_request
      IMPORTING iv_body    TYPE string
      EXPORTING es_request TYPE zcl_zari003_clearing_result=>ty_request
                ev_error   TYPE string.

  PRIVATE SECTION.

    "! GET คือตัวอย่าง request และ response
    METHODS handle_get
      CHANGING co_response TYPE REF TO if_web_http_response.

    "! POST คือรับผล 1 ใบ
    "! คืน HTTP status 200 เมื่อ body ถูกต้อง ไม่ว่าผลจะเป็น C หรือ E
    "! คืน HTTP status 400 เมื่อ body ผิดรูปแบบ
    METHODS handle_post
      IMPORTING io_request  TYPE REF TO if_web_http_request
      CHANGING  co_response TYPE REF TO if_web_http_response.

    "! คืน JSON พร้อม status
    METHODS reply
      IMPORTING iv_status   TYPE i
                iv_reason   TYPE string
                iv_json     TYPE string
      CHANGING  co_response TYPE REF TO if_web_http_response.

    "! แปลงผลเป็น JSON
    CLASS-METHODS build_response
      IMPORTING is_result      TYPE zcl_zari003_clearing_result=>ty_result
      RETURNING VALUE(rv_json) TYPE string.

    "! text ของ message class
    CLASS-METHODS message_text
      IMPORTING iv_number      TYPE symsgno
                iv_v1          TYPE simple OPTIONAL
                iv_v2          TYPE simple OPTIONAL
                iv_v3          TYPE simple OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_zari003_clearing_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    CASE request->get_method( ).
      WHEN 'GET'.
        handle_get( CHANGING co_response = response ).

      WHEN 'POST'.
        handle_post( EXPORTING io_request  = request
                     CHANGING  co_response = response ).

      WHEN OTHERS.
        response->set_status( i_code   = 405
                              i_reason = 'Method Not Allowed' ).

    ENDCASE.

  ENDMETHOD.


  METHOD handle_get.

    " ตัวอย่างล้วน ไม่ได้อ่านจาก DB
    DATA(ls_usage) = VALUE ty_usage(
      service = `ZARI003_CLEARING`
      method  = `POST /sap/bc/http/sap/ZARI003_CLEARING`

      request = VALUE #( request_id                  = `20260924_143000`
                         company_code                = `2000`
                         payment_document_no         = `1000002301`
                         payment_accounting_document = `3500000006`
                         payment_accounting_doc_year = `2026`
                         clearing_document           = `3000000012`
                         clearing_document_year      = `2026`
                         clearing_status             = `S`
                         clearing_message            = `` )

      response = VALUE #( sap_status         = `C`
                          sap_message        = `Payment 1000002301 cleared by document 3000000012`
                          salesforce_status  = `E`
                          salesforce_message = `Salesforce rejected the update: NOT_FOUND` )

      note = VALUE #( ( `ส่งทีละ 1 ใบ` )
                      ( `RequestId รูปแบบ YYYYMMDD_hhmmss ยังไม่บังคับ เก็บไว้รอ log table` )
                      ( `4 field ถัดมาคือค่าที่ได้จาก API ดึงคิว ส่งกลับมาตรงๆ` )
                      ( `ClearingStatus S คือ clear สำเร็จ ต้องมี ClearingDocument และ ClearingDocumentYear` )
                      ( `ClearingStatus E คือ clear ไม่สำเร็จ ใส่เหตุผลใน ClearingMessage ใบจะยังอยู่ในคิวให้ทำใหม่` )
                      ( `ทุกค่าเป็น string รวมถึงปีบัญชี` )
                      ( `SapStatus C คือ SAP บันทึกผลเรียบร้อย E คือไม่ผ่าน ดูเหตุผลที่ SapMessage` )
                      ( `SalesforceStatus S คือแจ้ง Salesforce สำเร็จ E คือไม่สำเร็จ ว่างคือไม่ได้ยิง` )
                      ( `SalesforceStatus E ไม่ใช่ปัญหาของ BOT ฝั่ง SAP จัดการส่งซ้ำเอง` )
                      ( `body ผิดรูปแบบได้ 400 โครงเดียวกัน SapStatus เป็น E` )
                      ( `ไม่ต้องใช้ CSRF token` ) ) ).

    reply( EXPORTING iv_status   = 200
                     iv_reason   = 'OK'
                     iv_json     = xco_cp_json=>data->from_abap( ls_usage
                                     )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                                     )->to_string( )
           CHANGING  co_response = co_response ).

  ENDMETHOD.


  METHOD handle_post.

    parse_request( EXPORTING iv_body    = io_request->get_text( )
                   IMPORTING es_request = DATA(ls_request)
                             ev_error   = DATA(lv_error) ).

    IF lv_error IS NOT INITIAL.
      reply( EXPORTING iv_status   = 400
                       iv_reason   = 'Bad Request'
                       iv_json     = build_response( VALUE #(
                                       sap_status  = zcl_zari003_clearing_result=>gc_sap_error
                                       sap_message = lv_error ) )
             CHANGING  co_response = co_response ).
      RETURN.
    ENDIF.

    DATA(ls_result) = NEW zcl_zari003_clearing_result( )->process( ls_request ).

    reply( EXPORTING iv_status   = 200
                     iv_reason   = 'OK'
                     iv_json     = build_response( ls_result )
           CHANGING  co_response = co_response ).

  ENDMETHOD.


  METHOD reply.

    co_response->set_header_field( i_name  = 'Content-Type'
                                   i_value = 'application/json' ).

    co_response->set_status( i_code   = iv_status
                             i_reason = iv_reason ).

    co_response->set_text( iv_json ).

  ENDMETHOD.


  METHOD parse_request.

    DATA ls_json TYPE ty_request.

    CLEAR: es_request, ev_error.

    TRY.
        xco_cp_json=>data->from_string( iv_body
          )->apply( VALUE #( ( xco_cp_json=>transformation->pascal_case_to_underscore ) )
          )->write_to( REF #( ls_json ) ).
      CATCH cx_root.
        ev_error = message_text( iv_number = '009' iv_v1 = `body is not valid JSON` ).
        RETURN.
    ENDTRY.

    " ข้อมูลที่ขาดไม่ได้ ต้องระบุใบให้ได้ก่อนถึงจะทำอะไรต่อ
    DATA(lv_missing) = COND string(
      WHEN ls_json-company_code IS INITIAL                THEN `CompanyCode`
      WHEN ls_json-payment_accounting_document IS INITIAL THEN `PaymentAccountingDocument`
      WHEN ls_json-payment_accounting_doc_year IS INITIAL THEN `PaymentAccountingDocYear`
      WHEN ls_json-clearing_status IS INITIAL             THEN `ClearingStatus` ).

    IF lv_missing IS NOT INITIAL.
      ev_error = message_text( iv_number = '009' iv_v1 = |{ lv_missing } is required| ).
      RETURN.
    ENDIF.

    DATA(lv_status) = to_upper( condense( ls_json-clearing_status ) ).

    IF  lv_status <> zcl_zari003_clearing_result=>gc_bot_success
    AND lv_status <> zcl_zari003_clearing_result=>gc_bot_error.
      ev_error = message_text( iv_number = '009'
                               iv_v1     = |ClearingStatus must be S or E, got { ls_json-clearing_status }| ).
      RETURN.
    ENDIF.

    " clear สำเร็จต้องมีเลข clearing กับปีบัญชีเสมอ
    IF lv_status = zcl_zari003_clearing_result=>gc_bot_success.
      DATA(lv_missing_clearing) = COND string(
        WHEN ls_json-clearing_document IS INITIAL      THEN `ClearingDocument`
        WHEN ls_json-clearing_document_year IS INITIAL THEN `ClearingDocumentYear` ).

      IF lv_missing_clearing IS NOT INITIAL.
        ev_error = message_text( iv_number = '009'
                                 iv_v1     = |{ lv_missing_clearing } is required when ClearingStatus is S| ).
        RETURN.
      ENDIF.
    ENDIF.

    es_request = VALUE #(
      request_id                  = ls_json-request_id
      company_code                = ls_json-company_code
      payment_document_no         = ls_json-payment_document_no
      " เลขเอกสารในตารางเก็บแบบเติมศูนย์ข้างหน้า ค่าที่ BOT ส่งมาอาจไม่เติมมาให้
      payment_accounting_document = |{ ls_json-payment_accounting_document ALPHA = IN }|
      payment_accounting_doc_year = ls_json-payment_accounting_doc_year
      clearing_document           = |{ ls_json-clearing_document ALPHA = IN }|
      clearing_document_year      = ls_json-clearing_document_year
      clearing_status             = lv_status
      clearing_message            = ls_json-clearing_message ).

  ENDMETHOD.


  METHOD build_response.

    rv_json = xco_cp_json=>data->from_abap( VALUE ty_response(
                sap_status         = is_result-sap_status
                sap_message        = is_result-sap_message
                salesforce_status  = is_result-salesforce_status
                salesforce_message = is_result-salesforce_message )
                )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                )->to_string( ).

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_number WITH iv_v1 iv_v2 iv_v3 INTO rv_text.

  ENDMETHOD.

ENDCLASS.
