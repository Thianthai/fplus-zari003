# ZARI003 — Payment Result to Salesforce

## Project constraints

1. **Platform**: SAP S/4HANA Cloud **Public Edition** — Developer Extensibility
2. **ABAP Language Version**: **ABAP for Cloud Development** เท่านั้น
3. ใช้ได้เฉพาะ object ที่อยู่ใน **Released APIs (C1 contract)**
4. Sync ผ่าน **abapGit** เท่านั้น
5. ทุก object ลง package **`ZARI003`** ตัวเดียว (ไม่มี sub-package)

## Naming convention

ใช้กฎกลางใน `~/.claude/CLAUDE.md` ทุกข้อ **แต่เปลี่ยน prefix จาก `Y*` เป็น `Z*`**
โดย `<APP>` ของ project นี้ = **`ZARI003`** — รูปแบบเดียวกับ ZARI002 และ ZARE002

| ชนิด | Pattern | ชื่อจริง |
|------|---------|---------|
| Package | `Z<APP>` | `ZARI003` |
| Global class | `ZCL_<APP>_<PURPOSE>` | `ZCL_ZARI003_SFDC_RESULT` |
| Message class | `Z<APP>` | `ZARI003` |

## ⚠️ ตัวส่ง Salesforce ตัวเดียวของทั้ง 2 path

`ZCL_ZARI003_SFDC_RESULT` เป็นตัวประกอบ payload และตัวยิง Salesforce **ตัวเดียว** ของทั้ง flow
(เดิมเป็น copy ของ `ZCL_ZARE002_SFDC_RESULT` ตั้งแต่ 2026-09-24 → รวมเป็นตัวเดียว 2026-09-29 `7e922d1` / zare002 `7653f57`)

| path | caller | method | ใครเขียน `salesforce_*` |
|---|---|---|---|
| Reject -> `Rejected` | ปุ่ม Reject ของ ZARE002 (`ZBP_R_ZARE002` → `rejectItem`) ใน **interaction phase ของ RAP** | `send( )` — ยิงอย่างเดียว ไม่แตะ DB | saver ของ ZARE002 |
| Clearing สำเร็จ -> `Completed` | `ZCL_ZARI003_CLEARING_RESULT` (API #3) | `send_payment_result( )` — อ่าน item + ยิง + `UPDATE` + `COMMIT WORK` | คลาสนี้เอง |

- **ห้ามให้ path Reject เรียก `send_payment_result( )`** — COMMIT ใน RAP ไม่ได้ (runtime error)
- **แก้คลาสนี้ = กระทบทั้ง Reject และ Completed** ต้องทดสอบทั้ง 2 path · ข้อดีคือ Salesforce เปลี่ยนชื่อ field / endpoint แก้ที่เดียว
  (เคยเจอ `INVALID_FIELD` ตอนชื่อ field ผิด — `fplus-zare002/docs/06_open_questions.md` OQ-30)
- ZARE002 จึงพึ่ง ZARI003 → **transport ZARI003 ขึ้นก่อนหรือพร้อม ZARE002 เสมอ**

## ⚠️ Cross-package — table เป็นของ ZARI002

`ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` อยู่ package **`ZARI002`** คนละ repo คนละ transport

| ใคร | ทำอะไรกับ table |
|---|---|
| **ZARI002** | insert อย่างเดียว เขียน `status = 'N'` |
| **ZARE002** | อ่านทุก row · update `reject_reason` ที่ item · header: `status = 'R'` + `salesforce_status` / `salesforce_message` (**path Reject**) · `payment_accounting_document` `payment_fiscal_year` `submit_message` (**Submit**) |
| **ZARI003** (งานนี้) | API #3: `clearing_accounting_document` `clearing_fiscal_year` `clearing_message` `status = 'C'` · แล้ว **เขียน `salesforce_status` / `salesforce_message` เฉพาะ path Completed** (ย้าย API #3 มาจาก ZARE002 2026-09-28) |

## ของกลางที่ใช้

`ZCL_UTILITY` (package `ZBCUTILITY` · repo `fplus-zbcutility`)

- `create_sfdc_client( )` — ขอ token ใหม่ทุกครั้งแล้วคืน HTTP client ที่ใส่ `Authorization: Bearer` แล้ว
- **ห้ามสร้าง Communication Arrangement ใหม่ไปหา Salesforce** ใช้ `ZCA_SFDC_TOKEN` ผ่าน class กลางเท่านั้น
- เหตุผล: Salesforce client credentials ไม่ส่ง `expires_in` ทำให้ arrangement แบบ OAuth ถือ token ค้าง

## Coding rules

ใช้กฎกลางทั้งหมด โดยเฉพาะ

- **Comment หนึ่งบรรทัดหนึ่งเรื่อง** ห้ามใช้ `·` คั่น ใช้ `->` ไม่ใช่ `→`
- **ห้ามใช้ชื่อเรียกชั่วคราว `API #1`–`API #4` (หรือ "API ดึงคิว" ฯลฯ) ใน ABAP ทุกชนิด** (ผู้ใช้สั่ง 2026-09-29) — เป็นชื่อที่ใช้คุยกันเท่านั้น
  ให้ระบุ RICEFW + class / service จริงแทน เช่น `HTTP service ZARE002_SUBMIT (ZCL_ZARE002_SUBMIT_HTTP)` · `ZI_ZARE002_CLEARING` · `ZARI003_CLEARING`
  · ใช้ได้เฉพาะใน `docs/` และในแชท · รวมถึงเลข OQ / เลข phase ก็ห้ามอยู่ใน comment เหมือนกัน
- **Comment ห้ามอ้างเลขเอกสาร / เลข object ของ test data**
- **ห้ามใส่ emoji ใน comment ของ ABAP object**
- **ABAP Doc (`"!`) ทุก class · method · constant group · type**
- **placeholder `&1`–`&4` ของ message class รับได้ 50 ตัวต่อตัว**
- ห้าม print หรือ log ตัว access token

## Git — การแบ่งงาน

| สิ่งที่ทำ | ใคร commit/push |
|---|---|
| **ABAP object ทุกชนิด** | **ผู้ใช้** |
| **เอกสาร** (`docs/`, `README.md`, `CLAUDE.md`) | **Claude** commit และ push เอง ไม่ต้องรอสั่ง |

- Claude **ห้ามสร้างไฟล์ ABAP ลง repo** — ส่งเป็น code block ใน chat
- `.abapgit.xml` และ `package.devc.xml` เป็นของที่ **SAP serialize เอง**
- Remote: https://github.com/Thianthai/fplus-zari003.git
