"! งาน background ของ bgPF สำหรับแจ้ง SBPA ว่ามี Reject รอบใหม่
"! ZCL_ZARI003_REJECT_BATCH=>schedule สร้างและลงทะเบียนไว้ตอน save ของ Reject
"! ทำงานหลัง commit ของ Reject แล้วส่งต่อให้ ZCL_ZARI003_REJECT_BATCH->send
"! ใช้แบบ transactional uncontrolled เพราะต้องยิง HTTP และ COMMIT WORK เอง
"! attribute ถูกเก็บลงระบบตอนลงทะเบียนแล้วอ่านกลับมาตอนทำงาน จึงเก็บแค่ค่าธรรมดา ห้ามเก็บ object
CLASS zcl_zari003_reject_batch_bg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    "! รับ batch id ที่จะแจ้ง SBPA
    METHODS constructor
      IMPORTING iv_batch_id TYPE ztar_i002_pymt-reject_batch_id.

  PRIVATE SECTION.

    "! batch id ที่จะแจ้ง SBPA
    DATA gv_batch_id TYPE ztar_i002_pymt-reject_batch_id.

ENDCLASS.


CLASS zcl_zari003_reject_batch_bg IMPLEMENTATION.

  METHOD constructor.

    gv_batch_id = iv_batch_id.

  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.

    " ผลการยิงถูกเขียนลง reject_message ใน send แล้ว ไม่ต้องทำอะไรต่อ
    " ไม่โยน exception กลับให้ bgPF เพราะไม่ต้องการให้ระบบยิงซ้ำเอง
    " การส่งซ้ำรอตัดสินใน OQ-42
    NEW zcl_zari003_reject_batch( )->send( gv_batch_id ).

  ENDMETHOD.

ENDCLASS.
