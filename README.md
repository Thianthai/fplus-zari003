# ZARI003 — Automatic Incoming Payments: Payment Result to Salesforce

| Item | Value |
|------|-------|
| RICEFW ID | **ZARI003** |
| Description | Automatic Incoming Payments - Payment Result to Salesforce |
| Type | Interface (outbound) |
| Platform | SAP S/4HANA Cloud **Public Edition** |
| Development model | **ABAP Cloud** (Developer Extensibility) |
| Protocol | Salesforce REST **Composite API** (`POST /services/data/v66.0/composite`) |
| Repo sync | abapGit (local ⇄ GitHub ⇄ S/4HANA Cloud) |
| Package | **`ZARI003`** — package เดียว ไม่มี sub-package |
| Data source | `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` (**เป็นของ package `ZARI002`**) |
| RICEFW ที่เกี่ยวข้อง | **ZARI002** (รับข้อมูลเข้า) · **ZARE002** (หน้าจอ + post FI + clearing) |

## Scope

ส่งผลลัพธ์ของ payment กลับไปให้ Salesforce เมื่องานฝั่ง SAP เสร็จแล้ว

```
Salesforce ──▶ SBPA ──▶ ZARI002 ──▶ ZTAR_I002_PYMT  status = N
                        (API)       ZTAR_I002_ITEM
                                          │
                                    ZARE002 หน้าจอ
                                          │
                              กด Submit ──▶ post JE  (Payment Doc)
                                          │
                              BOT ──▶ post Clearing  (Clearing Doc)
                                          │
                                    ZARE002 บันทึกผล status = C
                                          │
                                          ▼
                                     ZARI003  ──▶ Salesforce
                                     (งานของ repo นี้)     Completed
```

**ขอบเขตของ ZARI003** คือขั้นสุดท้ายขั้นเดียว: อ่าน item ของ payment ที่ปิดงานแล้ว
ประกอบ record ส่งเข้า Composite API แล้วบันทึกผลการส่งลง `salesforce_status` / `salesforce_message`

**ไม่อยู่ในขอบเขต**: หน้าจอ · การ post FI · การ clearing · การส่งผล Reject (เป็นของ ZARE002)

## Object หลัก

| Object | ชนิด | หน้าที่ |
|---|---|---|
| `ZCL_ZARI003_SFDC_RESULT` | Class | อ่าน item -> ประกอบ record `Completed` -> แบ่งชุด 25 -> ยิง Composite API -> เขียนผลลง header |
| `ZARI003` | Message class | ข้อความของ flow นี้ |

ของกลางที่ใช้ร่วม: `ZCL_UTILITY=>create_sfdc_client( )` จาก package **`ZBCUTILITY`**
(ขอ token ใหม่ทุกครั้งแล้วใส่ `Authorization: Bearer` ให้เสร็จ — ดู `fplus-zbcutility`)

## เอกสาร

| ไฟล์ | เนื้อหา |
|---|---|
| [docs/01_architecture.md](docs/01_architecture.md) | ขอบเขต · ตำแหน่งใน flow · การแบ่งงานกับ RICEFW อื่น |
| [docs/02_object_list.md](docs/02_object_list.md) | รายการ object + สถานะ |
| [docs/03_open_questions.md](docs/03_open_questions.md) | ทะเบียนข้อสงสัย |

## การแบ่งงาน push

| สิ่งที่ทำ | ใคร |
|---|---|
| **ABAP object ทุกชนิด** | **ผู้ใช้** ผ่าน abapGit จาก ADT |
| **เอกสาร** (`docs/`, `README.md`, `CLAUDE.md`) | **Claude** commit และ push เอง |
