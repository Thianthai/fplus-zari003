@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment Result - Rejected Items'

// รายการที่ถูก Reject ให้ SBPA ดึงไปสรุปแล้วส่ง email ให้ user
// SBPA ได้ reject_batch_id จาก ZCL_ZARI003_REJECT_BATCH แล้วกรองด้วยเลขนั้น
// ทุกใบที่ Reject ในการกดครั้งเดียวได้ reject_batch_id เดียวกัน
// 1 row ต่อ 1 item field ของ header ซ้ำในทุก item ของใบเดียวกัน
// SBPA รวมแถวเองตาม PaymentDocumentNo
define view entity ZI_ZARI003_REJECT_ITEM
  as select from ztar_i002_pymt as Payment
    inner join ztar_i002_item as Item on Payment.payment_uuid = Item.payment_uuid
{
      // key ของ view เป็น item uuid เพราะ 1 row คือ 1 item
  key Item.item_uuid                      as ItemUuid,

      // เลขรอบของการกด Reject ใช้กรองใน $filter
      @EndUserText.label: 'Reject Batch ID'
      Payment.reject_batch_id             as RejectBatchId,

      // ---------- header ----------
      @EndUserText.label: 'Salesforce ID'
      Payment.salesforce_id               as SalesforceId,
      @EndUserText.label: 'Payment Document No.'
      Payment.payment_document_no         as PaymentDocumentNo,
      @EndUserText.label: 'No. of Items in Payment'
      Payment.number_of_items_in_payment  as NumberOfItemsInPayment,
      @EndUserText.label: 'Company Code'
      Payment.company_code                as CompanyCode,
      @EndUserText.label: 'Posting Date'
      Payment.posting_date                as PostingDate,
      @EndUserText.label: 'G/L Account'
      Payment.gl_account                  as GlAccount,
      @EndUserText.label: 'Payment Method'
      Payment.payment_method              as PaymentMethod,
      @EndUserText.label: 'Cheque No.'
      Payment.cheque_no                   as ChequeNo,
      @EndUserText.label: 'Issue Date'
      Payment.issue_date                  as IssueDate,
      @EndUserText.label: 'Due On'
      Payment.due_on                      as DueOn,
      @EndUserText.label: 'Cheque Bank Branch'
      Payment.cheque_bank_branch          as ChequeBankBranch,

      // สกุลเงินของยอดระดับ header
      // ต้องมีเพราะ field จำนวนเงินต้องอ้างสกุลเงินเสมอ
      @EndUserText.label: 'Payment Currency'
      Payment.currency                    as PaymentCurrency,

      @Semantics.amount.currencyCode: 'PaymentCurrency'
      @EndUserText.label: 'Rounding Difference'
      Payment.rounding_diff               as RoundingDiff,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      @EndUserText.label: 'Advance Payment'
      Payment.advance_payment             as AdvancePayment,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      @EndUserText.label: 'Fees'
      Payment.fees                        as Fees,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      @EndUserText.label: 'Payment Amount'
      Payment.payment_amount              as PaymentAmount,

      @EndUserText.label: 'Status'
      Payment.status                      as Status,

      // ---------- item ----------
      @EndUserText.label: 'Salesforce Item ID'
      Item.salesforce_item_id             as SalesforceItemId,
      @EndUserText.label: 'Customer'
      Item.customer_code                  as CustomerCode,
      @EndUserText.label: 'Billing Note No.'
      Item.billing_note_no                as BillingNoteNo,
      @EndUserText.label: 'Accounting Document'
      Item.accounting_document            as AccountingDocument,
      @EndUserText.label: 'Billing Document'
      Item.billing_document               as BillingDocument,
      @EndUserText.label: 'Invoice Posting Date'
      Item.invoice_posting_date           as InvoicePostingDate,

      // สกุลเงินของยอดระดับ item
      @EndUserText.label: 'Currency'
      Item.currency                       as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Invoice Amount'
      Item.invoice_amount                 as InvoiceAmount,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Amount Paid'
      Item.amount_paid                    as AmountPaid,
      @EndUserText.label: 'Partial Amount'
      Item.partial_amount                 as PartialAmount,
      @EndUserText.label: 'Sale Submit Date'
      Item.sale_submit_date               as SaleSubmitDate,
      @EndUserText.label: 'Reject Reason'
      Item.reject_reason                  as RejectReason
}
where
      Payment.status          =  'R'
      // ใบที่ Reject ก่อนมีการเก็บ reject_batch_id จะไม่มีเลขนี้ จึงไม่ต้องส่งให้ SBPA
  and Payment.reject_batch_id <> ''
