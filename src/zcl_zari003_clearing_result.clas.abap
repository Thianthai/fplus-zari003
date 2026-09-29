"! รับผลการ clear ของ 1 payment จาก BOT แล้วปิดงานฝั่ง SAP
"! สำเร็จ บันทึกเลข clearing กับปีบัญชี ตั้งสถานะเป็น Cleared แล้วแจ้ง Salesforce ต่อ
"! ไม่สำเร็จ เก็บเหตุผลไว้อย่างเดียว
"! ใบยังอยู่ในคิว ZI_ZARE002_CLEARING ของ ZARE002 รอบถัดไป BOT จะหยิบไปทำใหม่เอง หรือ user หยิบไปทำ manual
"! ผลของการแจ้ง Salesforce ไม่ย้อนกลับมาทำให้ clearing เป็นโมฆะ เพราะงานบัญชีเสร็จไปแล้วจริง
"! การแจ้ง Salesforce และการเขียน salesforce_status เป็นของ ZCL_ZARI003_SFDC_RESULT คลาสนี้แค่เรียกและรับผลมาแสดง
"! 1 payment เท่ากับ 1 LUW ของตัวเอง ต้องเรียกนอก RAP
CLASS zcl_zari003_clearing_result DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      "! ค่า ClearingStatus ที่ BOT ส่งมา
      gc_bot_success     TYPE string VALUE 'S',
      gc_bot_error       TYPE string VALUE 'E',

      "! ค่า SapStatus ที่ตอบกลับไป
      "! C คือ SAP บันทึกผล clearing เรียบร้อย
      "! E คือไม่ผ่าน ดูเหตุผลที่ SapMessage
      gc_sap_cleared     TYPE c LENGTH 1 VALUE 'C',
      gc_sap_error       TYPE c LENGTH 1 VALUE 'E',

      gc_msgid           TYPE symsgid           VALUE 'ZARI003',
      gc_status_cleared  TYPE ze_request_status VALUE 'C'.

    TYPES:
      "! สิ่งที่ BOT ส่งเข้ามา 1 ใบ
      "! ปีบัญชีมาคู่กับเลขเอกสารเสมอ เพราะเลขเอกสารบัญชี unique แค่ภายใน company code และปีบัญชี
      "! request_id ยังไม่ได้ใช้ทำอะไร เก็บไว้รอ log table ที่จะบันทึกทุกครั้งที่ BOT ยิงเข้ามา
      BEGIN OF ty_request,
        request_id                  TYPE string,
        company_code                TYPE ztar_i002_pymt-company_code,
        payment_document_no         TYPE ztar_i002_pymt-payment_document_no,
        payment_accounting_document TYPE ztar_i002_pymt-payment_accounting_document,
        payment_accounting_doc_year TYPE ztar_i002_pymt-payment_fiscal_year,
        clearing_document           TYPE ztar_i002_pymt-clearing_accounting_document,
        clearing_document_year      TYPE ztar_i002_pymt-clearing_fiscal_year,
        clearing_status             TYPE string,
        clearing_message            TYPE string,
      END OF ty_request,

      "! ผลที่ตอบกลับไปให้ BOT
      "! sap_status บอกว่าฝั่ง SAP รับผล clearing หรือไม่
      "! salesforce_status บอกผลการแจ้ง Salesforce ต่อ ซึ่งไม่ใช่ความรับผิดชอบของ BOT
      "! salesforce_status ว่างแปลว่าไม่ได้ยิง เช่นกรณี BOT แจ้ง error มา
      BEGIN OF ty_result,
        sap_status         TYPE c LENGTH 1,
        sap_message        TYPE string,
        salesforce_status  TYPE ze_response_status,
        salesforce_message TYPE string,
      END OF ty_result.

    "! ทำ 1 ใบให้จบ
    "! อ่าน payment จากเลขเอกสาร JE แล้วตัดสินตามสถานะที่ BOT แจ้งมา
    METHODS process
      IMPORTING is_request       TYPE ty_request
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    TYPES:
      "! payment ที่หาเจอจากเลขเอกสาร JE
      BEGIN OF ty_payment,
        payment_uuid                 TYPE sysuuid_x16,
        payment_document_no          TYPE ztar_i002_pymt-payment_document_no,
        clearing_accounting_document TYPE ztar_i002_pymt-clearing_accounting_document,
      END OF ty_payment.

    "! หา payment จาก company code เลขเอกสาร JE และปีบัญชี
    METHODS read_payment
      IMPORTING is_request      TYPE ty_request
      EXPORTING es_payment      TYPE ty_payment
      RETURNING VALUE(rv_found) TYPE abap_bool.

    "! บันทึกเลข clearing ปีบัญชี สถานะ และข้อความ แล้ว COMMIT WORK
    METHODS save_clearing
      IMPORTING iv_payment_uuid TYPE sysuuid_x16
                is_request      TYPE ty_request
                iv_message      TYPE string.

    "! เก็บเฉพาะข้อความของขั้น clearing โดยไม่แตะเลขเอกสารและสถานะ
    METHODS save_message
      IMPORTING iv_payment_uuid TYPE sysuuid_x16
                iv_message      TYPE string.

    "! text ของ message class
    "! placeholder ละไม่เกิน 50 ตัว
    METHODS message_text
      IMPORTING iv_number      TYPE symsgno
                iv_v1          TYPE simple OPTIONAL
                iv_v2          TYPE simple OPTIONAL
                iv_v3          TYPE simple OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_zari003_clearing_result IMPLEMENTATION.

  METHOD process.

    DATA ls_payment TYPE ty_payment.

    rs_result-sap_status = gc_sap_error.

    " 1. หาใบจากเลขเอกสาร JE ที่เราส่งให้ BOT ไปตอนดึงคิว
    DATA(lv_found) = read_payment( EXPORTING is_request = is_request
                                   IMPORTING es_payment = ls_payment ).

    IF lv_found = abap_false.
      rs_result-sap_message = message_text( iv_number = '005'
                                            iv_v1     = is_request-payment_accounting_document
                                            iv_v2     = is_request-company_code ).
      RETURN.
    ENDIF.

    " 2. BOT แจ้งว่า clear ไม่สำเร็จ
    " เก็บเหตุผลไว้อย่างเดียว ไม่แตะเลขเอกสารและสถานะ
    " ใบยังไม่มีเลข clearing จึงยังอยู่ในคิว ZI_ZARE002_CLEARING ของ ZARE002 คืนถัดไป BOT หยิบไปทำใหม่เอง
    IF is_request-clearing_status = gc_bot_error.
      rs_result-sap_message = message_text(
                                iv_number = '008'
                                iv_v1     = ls_payment-payment_document_no
                                iv_v2     = substring( val = is_request-clearing_message
                                                       len = nmin( val1 = strlen( is_request-clearing_message )
                                                                   val2 = 50 ) )
                                iv_v3     = COND #( WHEN strlen( is_request-clearing_message ) > 50
                                                    THEN substring( val = is_request-clearing_message
                                                                    off = 50
                                                                    len = nmin( val1 = strlen( is_request-clearing_message ) - 50
                                                                                val2 = 50 ) ) ) ).

      save_message( iv_payment_uuid = ls_payment-payment_uuid
                    iv_message      = rs_result-sap_message ).

      RETURN.
    ENDIF.

    " 3. ใบนี้มีเลข clearing อยู่แล้ว
    " เลขเดียวกันแปลว่า BOT ส่งซ้ำ ถือว่าสำเร็จและไม่ทำอะไรต่อ
    " เลขต่างกันแปลว่ามีอะไรผิด ไม่เขียนทับของเดิมเด็ดขาด
    IF ls_payment-clearing_accounting_document IS NOT INITIAL.
      rs_result-sap_message = message_text( iv_number = '006'
                                            iv_v1     = ls_payment-payment_document_no
                                            iv_v2     = ls_payment-clearing_accounting_document ).

      IF ls_payment-clearing_accounting_document = is_request-clearing_document.
        rs_result-sap_status = gc_sap_cleared.
      ENDIF.

      RETURN.
    ENDIF.

    " 4. clear สำเร็จ บันทึกเลข clearing กับสถานะ
    rs_result-sap_status  = gc_sap_cleared.
    rs_result-sap_message = message_text( iv_number = '007'
                                          iv_v1     = ls_payment-payment_document_no
                                          iv_v2     = is_request-clearing_document ).

    save_clearing( iv_payment_uuid = ls_payment-payment_uuid
                   is_request      = is_request
                   iv_message      = rs_result-sap_message ).

    " 5. แจ้ง Salesforce ว่าใบนี้ Completed
    " ZCL_ZARI003_SFDC_RESULT เป็นคนเขียน salesforce_status และ salesforce_message เอง คลาสนี้แค่รับผลมาตอบ BOT
    " ยิงไม่สำเร็จไม่ทำให้ clearing เป็นโมฆะ เพราะเอกสารบัญชีเกิดไปแล้วจริง
    DATA(ls_sfdc) = NEW zcl_zari003_sfdc_result( )->send_payment_result( ls_payment-payment_uuid ).

    rs_result-salesforce_status  = ls_sfdc-status.
    rs_result-salesforce_message = ls_sfdc-message.

  ENDMETHOD.


  METHOD read_payment.

    CLEAR es_payment.

    rv_found = abap_false.

    SELECT SINGLE
      FROM ztar_i002_pymt
      FIELDS payment_uuid,
             payment_document_no,
             clearing_accounting_document
      WHERE company_code                = @is_request-company_code
        AND payment_accounting_document = @is_request-payment_accounting_document
        AND payment_fiscal_year         = @is_request-payment_accounting_doc_year
      INTO CORRESPONDING FIELDS OF @es_payment.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_found = abap_true.

  ENDMETHOD.


  METHOD save_clearing.

    DATA lv_now TYPE abp_lastchange_tstmpl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user)    = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_message) = CONV ztar_i002_pymt-clearing_message( iv_message ).

    UPDATE ztar_i002_pymt
      SET clearing_accounting_document = @is_request-clearing_document,
          clearing_fiscal_year         = @is_request-clearing_document_year,
          status                       = @gc_status_cleared,
          clearing_message             = @lv_message,
          last_changed_by              = @lv_user,
          last_changed_at              = @lv_now,
          local_last_changed_at        = @lv_now
      WHERE payment_uuid = @iv_payment_uuid.

    COMMIT WORK.

  ENDMETHOD.


  METHOD save_message.

    DATA lv_now TYPE abp_lastchange_tstmpl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user)    = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_message) = CONV ztar_i002_pymt-clearing_message( iv_message ).

    UPDATE ztar_i002_pymt
      SET clearing_message      = @lv_message,
          last_changed_by       = @lv_user,
          last_changed_at       = @lv_now,
          local_last_changed_at = @lv_now
      WHERE payment_uuid = @iv_payment_uuid.

    COMMIT WORK.

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_number WITH iv_v1 iv_v2 iv_v3 INTO rv_text.

  ENDMETHOD.

ENDCLASS.
