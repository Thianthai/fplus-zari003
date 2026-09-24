# 02 — Object List

`⬜` ยังไม่สร้าง · `🟨` ส่ง code แล้วรอสร้าง · `🟦` activate แล้วรอ push · `✅` อยู่ใน repo

| Object | ชนิด | ไฟล์ | Status |
|---|---|---|---|
| `ZARI003` | Package | `src/package.devc.xml` | ✅ baseline `765c773` (`/src/` · FULL) |
| `ZCL_ZARI003_SFDC_RESULT` | Class — `send_payment_result( )` อ่าน item -> ยิง Completed ทีละ 25 -> เขียน `salesforce_status` / `salesforce_message` | `src/zcl_zari003_sfdc_result.clas.abap` | ✅ `8d1d0eb` (2026-09-24) |
| `ZCL_ZARI003_SFDC_RESULT` testclasses | ทดสอบ build payload และ parse response โดยไม่ต่อ Salesforce | `src/zcl_zari003_sfdc_result.clas.testclasses.abap` | ✅ 8 test เขียว |
| `ZARI003` | Message class — 001 ไม่มี item · 002 ส่งสำเร็จ · 003 Salesforce ปฏิเสธ · 004 ต่อไม่ถึง | `src/zari003.msag.xml` | ✅ `8d1d0eb` |

## ของที่ใช้ร่วมจาก package อื่น

| Object | Package | ใช้ทำอะไร |
|---|---|---|
| `ZCL_UTILITY` | `ZBCUTILITY` | `create_sfdc_client( )` ขอ token และคืน HTTP client ที่ใส่ Bearer แล้ว |
| `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` | `ZARI002` | อ่าน item · เขียน `salesforce_status` / `salesforce_message` |

## ยังไม่มีผู้เรียก

`send_payment_result( )` จะถูกเรียกจาก `ZCL_ZARE002_CLEARING_RESULT` (API #3 ของ ZARE002)
ซึ่งยังไม่ได้สร้าง ดู `fplus-zare002/docs/02_implementation_phases.md` หัวข้อ 8B.6
