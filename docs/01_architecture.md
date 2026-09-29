# 01 — Architecture

## 1. ตำแหน่งใน flow รวม

```
Salesforce ──▶ SBPA ──▶ ZARI002 ──insert──▶ ZTAR_I002_PYMT (status N)
                        (inbound API)       ZTAR_I002_ITEM
                                                  │
                                            ZARE002 (หน้าจอ)
                                                  │
                       ผู้ใช้กด Submit ──▶ API #1 ──▶ post JE (I_JournalEntryTP)
                                                  │        stamp payment_accounting_document
                                                  │
                       BOT ดึงคิว ──▶ API #4 (OData) ──▶ clear ผ่าน Clear Incoming Payments
                                                  │
                       BOT ส่งผล ──▶ API #3 ──▶ stamp clearing_accounting_document + status C
                                                  │
                                                  ▼
                                            ZARI003 (repo นี้)
                                                  │
                                                  ▼
                                     Salesforce  BST_SAP_Status__c = Completed
```

API #3 เป็นของ ZARI003 (ย้ายมาจาก ZARE002 2026-09-28): `ZARI003_CLEARING` -> `ZCL_ZARI003_CLEARING_HTTP` -> `ZCL_ZARI003_CLEARING_RESULT`
บันทึกเลข clearing สำเร็จแล้วเรียก `ZCL_ZARI003_SFDC_RESULT` ต่อทันที

**แจ้ง Salesforce เฉพาะเคส clearing สำเร็จเท่านั้น** (business ยืนยัน 2026-09-29) — BOT แจ้ง `E` · ไม่เจอใบ · ใบมีเลข clearing อยู่แล้ว
จะ `RETURN` ก่อนถึง `send_payment_result( )` ทั้งหมด ไม่ต้องแก้โปรแกรม
สัญญา request/response ของ API #3 อยู่ที่ `fplus-zare002/docs/10_api_contract.md` (ที่เดียวกับ API #1 / #4 ที่ BOT ใช้)

## 2. ขอบเขต

| อยู่ในขอบเขต | ไม่อยู่ในขอบเขต |
|---|---|
| API #3 รับผล clearing จาก BOT -> stamp `clearing_*` + status C | หน้าจอ (ZARE002) |
| อ่าน item ทุกบรรทัดของ payment ที่ปิดงานแล้ว | |
| ประกอบ record ส่ง Composite API เป็น `Completed` | post FI (ZARE002) |
| ตัวยิง SFDC ให้ปุ่ม Reject ของ ZARE002 (`send( )` — ZARE002 ประกอบ record `Rejected` เอง) | |
| แบ่งยิงทีละ 25 record ตาม limit ของ Composite API | ตัวการ clear ในระบบ (BOT) · คิวของ BOT API #4 (ZARE002) |
| เขียน `salesforce_status` / `salesforce_message` ลง header (path Completed) | ปุ่ม Reject + การเขียนผล Reject ลง table (ZARE002) |
| คืนผลให้ผู้เรียกไปแสดงต่อ | การรับข้อมูลเข้า (ZARI002) |

## 3. การส่ง Salesforce

| เรื่อง | ค่า |
|---|---|
| endpoint | `POST /services/data/v66.0/composite` |
| payload | `{"allOrNone": true, "compositeRequest": [...]}` |
| 1 subrequest | `PATCH /services/data/v66.0/sobjects/cgcloud__Order_Payment__c/{salesforce_item_id}` |
| limit | **25 subrequest ต่อ call** — payment ที่มี item มากกว่านี้แบ่งยิงหลายรอบ |
| field ที่ส่ง | `BST_PaymentCollection__c` · `BST_SAP_Status__c` · `BST_SAP_RejectReason__c` · `BST_SAP_BatchId__c` · `BST_SAP_ResponseDate__c` |
| ค่า status | `Completed` (API #3) · `Rejected` (ปุ่ม Reject ของ ZARE002 ส่งผ่าน `send( )` ของคลาสเดียวกัน) |
| auth | `ZCL_UTILITY=>create_sfdc_client( )` จาก package `ZBCUTILITY` |

`BST_SAP_BatchId__c` ยังถูกตัดเหลือ 15 ตัว เพราะฝั่ง Salesforce ยังไม่ขยาย field
(`request_id` จริงยาว 20) — ดู `fplus-zare002/docs/06_open_questions.md` OQ-28

## 4. การบันทึกผล

| ผล | `salesforce_status` | `salesforce_message` |
|---|---|---|
| ยิงครบทุกชุดสำเร็จ | `S` | ว่าง |
| ชุดใดชุดหนึ่งไม่สำเร็จ | `E` | error code + ข้อความจาก Salesforce |
| ใบไม่มี item | ไม่เขียน | ไม่เขียน |

**การยิงไม่สำเร็จไม่ทำให้งานบัญชีเป็นโมฆะ** เอกสาร JE และ clearing เกิดไปแล้วจริง
เก็บผลไว้เพื่อหาวิธีส่งซ้ำทีหลัง

## 5. ข้อจำกัดที่รู้อยู่

- ยังไม่มีกลไกส่งซ้ำอัตโนมัติเมื่อ `salesforce_status = E` (ดู `docs/03_open_questions.md`)
- code ยิง Salesforce ซ้ำกับ `ZCL_ZARE002_SFDC_RESULT` โดยตั้งใจ ต้องแก้คู่กันเสมอ
