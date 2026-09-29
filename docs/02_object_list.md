# 02 — Object List

`⬜` ยังไม่สร้าง · `🟨` ส่ง code แล้วรอสร้าง · `🟦` activate แล้วรอ push · `✅` อยู่ใน repo

| Object | ชนิด | ไฟล์ | Status |
|---|---|---|---|
| `ZARI003` | Package | `src/package.devc.xml` | ✅ baseline `765c773` (`/src/` · FULL) |
| `ZCL_ZARI003_SFDC_RESULT` | Class — ตัวส่ง SFDC ตัวเดียว: `send_payment_result( )` (Completed: อ่าน item -> ยิงทีละ 25 -> เขียน `salesforce_*`) · `send( )` + `gc_status_rejected` ให้ปุ่ม Reject ของ ZARE002 (`7e922d1`) | `src/zcl_zari003_sfdc_result.clas.abap` | ✅ `8d1d0eb` (2026-09-24) |
| `ZCL_ZARI003_SFDC_RESULT` testclasses | ทดสอบ build payload และ parse response โดยไม่ต่อ Salesforce | `src/zcl_zari003_sfdc_result.clas.testclasses.abap` | ✅ 11 test (+3 จาก ZARE002: Rejected มี reason · escape `"` · HTTP 401) `7e922d1` |
| `ZARI003` | Message class — 001 ไม่มี item · 002 ส่งสำเร็จ · 003 Salesforce ปฏิเสธ · 004 ต่อไม่ถึง · **API #3**: 005 ไม่เจอใบ · 006 มีเลข clearing อยู่แล้ว · 007 clear สำเร็จ · 008 BOT แจ้ง clear ไม่สำเร็จ · 009 body ผิดรูปแบบ | `src/zari003.msag.xml` | ✅ `8d1d0eb` · 005–009 `97054a4` |
| `ZCL_ZARI003_CLEARING_RESULT` | Class — API #3 logic: หาใบจากเลข JE + ปี -> stamp clearing + status C หรือเก็บ `clearing_message` -> เรียก `send_payment_result( )` | `src/zcl_zari003_clearing_result.clas.abap` | ✅ `97054a4` (2026-09-28) |
| `ZCL_ZARI003_CLEARING_HTTP` | Class — handler API #3 (`if_http_service_extension`) · `parse_request` static ทดสอบได้ | `src/zcl_zari003_clearing_http.clas.abap` | ✅ `97054a4` |
| `ZCL_ZARI003_CLEARING_HTTP` testclasses | ทดสอบการอ่าน body 5 เคส | `src/zcl_zari003_clearing_http.clas.testclasses.abap` | ✅ 5 test |
| `ZARI003_CLEARING` | HTTP Service — `/sap/bc/http/sap/ZARI003_CLEARING` · inbound `ZARI003_CLEARING_HTTP` | `src/zari003_clearing.http.xml` | ✅ `97054a4` · GET ผ่านด้วย comm user ของ BOT |
| `ZCS_CLEARING_RESULT` | Communication Scenario inbound — `ZARI003_CLEARING_HTTP` · Basic | `src/zcs_clearing_result.sco1.xml` | ✅ published locally |
| Communication Arrangement `ZCA_CLEARING_RESULT` | × `SBPA_DEV` · inbound user เดียวกับ API #4 | — ไม่ขึ้น git | ✅ |

## ของที่ใช้ร่วมจาก package อื่น

| Object | Package | ใช้ทำอะไร |
|---|---|---|
| `ZCL_UTILITY` | `ZBCUTILITY` | `create_sfdc_client( )` ขอ token และคืน HTTP client ที่ใส่ Bearer แล้ว |
| `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` | `ZARI002` | อ่าน item · เขียน `salesforce_status` / `salesforce_message` |

## ผู้เรียก

`send_payment_result( )` ถูกเรียกจาก `ZCL_ZARI003_CLEARING_RESULT` (API #3) ใน package เดียวกัน
API #3 เดิมอยู่ ZARE002 (`ZCL_ZARE002_CLEARING_*` · message `ZARE002` 120–124) ย้ายมาและลบของเดิมแล้ว 2026-09-28
