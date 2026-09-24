# 02 — Object List

`⬜` ยังไม่สร้าง · `🟨` ส่ง code แล้วรอสร้าง · `🟦` activate แล้วรอ push · `✅` อยู่ใน repo

| Object | ชนิด | ไฟล์ | Status |
|---|---|---|---|
| `ZARI003` | Package | `src/package.devc.xml` | ⬜ รอ link abapGit |
| `ZCL_ZARI003_SFDC_RESULT` | Class — ส่งผล payment กลับ Salesforce | `src/zcl_zari003_sfdc_result.clas.abap` | ⬜ |
| `ZCL_ZARI003_SFDC_RESULT` testclasses | ทดสอบ build payload และ parse response โดยไม่ต่อ Salesforce | `src/zcl_zari003_sfdc_result.clas.testclasses.abap` | ⬜ |
| `ZARI003` | Message class | `src/zari003.msag.xml` | ⬜ |

## ของที่ใช้ร่วมจาก package อื่น

| Object | Package | ใช้ทำอะไร |
|---|---|---|
| `ZCL_UTILITY` | `ZBCUTILITY` | `create_sfdc_client( )` ขอ token และคืน HTTP client ที่ใส่ Bearer แล้ว |
| `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` | `ZARI002` | อ่าน item · เขียน `salesforce_status` / `salesforce_message` |
