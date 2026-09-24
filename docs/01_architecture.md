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

ZARI003 ถูกเรียกจาก `ZCL_ZARE002_CLEARING_RESULT` (handler ของ API #3) ทันทีหลังบันทึกเลข clearing สำเร็จ

## 2. ขอบเขต

| อยู่ในขอบเขต | ไม่อยู่ในขอบเขต |
|---|---|
| อ่าน item ทุกบรรทัดของ payment ที่ปิดงานแล้ว | หน้าจอ (ZARE002) |
| ประกอบ record ส่ง Composite API เป็น `Completed` | post FI (ZARE002) |
| แบ่งยิงทีละ 25 record ตาม limit ของ Composite API | clearing (BOT + ZARE002) |
| เขียน `salesforce_status` / `salesforce_message` ลง header | การส่งผล Reject (ZARE002) |
| คืนผลให้ผู้เรียกไปแสดงต่อ | การรับข้อมูลเข้า (ZARI002) |

## 3. การส่ง Salesforce

| เรื่อง | ค่า |
|---|---|
| endpoint | `POST /services/data/v66.0/composite` |
| payload | `{"allOrNone": true, "compositeRequest": [...]}` |
| 1 subrequest | `PATCH /services/data/v66.0/sobjects/cgcloud__Order_Payment__c/{salesforce_item_id}` |
| limit | **25 subrequest ต่อ call** — payment ที่มี item มากกว่านี้แบ่งยิงหลายรอบ |
| field ที่ส่ง | `BST_PaymentCollection__c` · `BST_SAP_Status__c` · `BST_SAP_RejectReason__c` · `BST_SAP_BatchId__c` · `BST_SAP_ResponseDate__c` |
| ค่า status | `Completed` (path Reject ของ ZARE002 ใช้ `Rejected`) |
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
