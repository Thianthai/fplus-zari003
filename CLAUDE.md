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

## ⚠️ Code ซ้ำกับ ZARE002 โดยตั้งใจ

`ZCL_ZARI003_SFDC_RESULT` เป็น **copy** ของ `ZCL_ZARE002_SFDC_RESULT` (repo `fplus-zare002`)
ตกลงกันไว้ 2026-09-24 ว่าจะแยกขาดตาม WRICEF แทนการทำ class กลาง

| path | RICEFW | class |
|---|---|---|
| Reject -> Salesforce `Rejected` | ZARE002 | `ZCL_ZARE002_SFDC_RESULT` |
| Clearing เสร็จ -> Salesforce `Completed` | **ZARI003** | `ZCL_ZARI003_SFDC_RESULT` |

**ถ้า Salesforce เปลี่ยนชื่อ field, endpoint, หรือ API version ต้องแก้ทั้งสองที่**
เคยเจอ `INVALID_FIELD` มาแล้วตอนชื่อ field ผิด — ดู `fplus-zare002/docs/06_open_questions.md` OQ-30

## ⚠️ Cross-package — table เป็นของ ZARI002

`ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` อยู่ package **`ZARI002`** คนละ repo คนละ transport

| ใคร | ทำอะไรกับ table |
|---|---|
| **ZARI002** | insert อย่างเดียว เขียน `status = 'N'` |
| **ZARE002** | อ่านทุก row · update `reject_reason` ที่ item · header: `status` `payment_accounting_document` `payment_fiscal_year` `clearing_accounting_document` `clearing_fiscal_year` `submit_message` `clearing_message` · และ `salesforce_status` / `salesforce_message` เฉพาะ **path Reject** |
| **ZARI003** (งานนี้) | อ่าน item · **เขียน `salesforce_status` / `salesforce_message` เฉพาะ path Completed** |

## ของกลางที่ใช้

`ZCL_UTILITY` (package `ZBCUTILITY` · repo `fplus-zbcutility`)

- `create_sfdc_client( )` — ขอ token ใหม่ทุกครั้งแล้วคืน HTTP client ที่ใส่ `Authorization: Bearer` แล้ว
- **ห้ามสร้าง Communication Arrangement ใหม่ไปหา Salesforce** ใช้ `ZCA_SFDC_TOKEN` ผ่าน class กลางเท่านั้น
- เหตุผล: Salesforce client credentials ไม่ส่ง `expires_in` ทำให้ arrangement แบบ OAuth ถือ token ค้าง

## Coding rules

ใช้กฎกลางทั้งหมด โดยเฉพาะ

- **Comment หนึ่งบรรทัดหนึ่งเรื่อง** ห้ามใช้ `·` คั่น ใช้ `->` ไม่ใช่ `→`
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
