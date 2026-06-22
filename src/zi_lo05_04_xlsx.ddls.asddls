@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Interface Invoice Upload - File content'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZI_LO05_04_XLSX
  as select from ztb_lo05_04_xlsx
  association to parent ZI_LO05_04_FILE as _Header on $projection.Uuid = _Header.Uuid
{
  key uuid                          as Uuid,
  key line_id                       as LineId,
  key line_no                       as LineNumber,
      companycode                   as CompanyCode,
      accountingdocumenttype        as AccountingDocumentType,
      documentdate                  as DocumentDate,
      postingdate                   as PostingDate,
      supplierinvoiceidbyinvcgparty as SupplierInvoiceIDByInvcgParty,
      invoicingparty                as InvoicingParty,
      reconciliationaccount         as ReconciliationAccount,
      directquotedexchangerate      as directquotedexchangerate,
      supplierpostinglineitemtext   as SupplierPostingLineItemText,
      documentcurrency              as DocumentCurrency,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      invoicegrossamount            as InvoiceGrossAmount,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      unplanneddeliverycost         as UnplannedDeliveryCost,
      documentheadertext            as DocumentHeaderText,
      assignmentreference           as AssignmentReference,
      paymentterms                  as PaymentTerms,
      duecalculationbasedate        as DueCalculationBaseDate,
      supplierinvoiceitem           as SupplierInvoiceItem,
      purchaseorder                 as PurchaseOrder,
      purchaseorderitem             as PurchaseOrderItem,
      plant                         as Plant,
      issubsequentdebitcredit       as IsSubsequentDebitCredit,
      taxcode                       as TaxCode,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      supplierinvoiceitemamount     as SupplierInvoiceItemAmount,
      purchaseorderunit             as PurchaseOrderUnit,
      @Semantics.quantity.unitOfMeasure: 'PurchaseOrderUnit'
      quantityinpurchaseorderunit   as QuantityInPurchaseOrderUnit,
      ordinalnumber                 as OrdinalNumber,
      wbselement                    as WBSElement,
      fixedasset                    as FixedAsset,
      glaccount                     as GLAccount,
      functionalarea                as FunctionalArea,
      costcenter                    as CostCenter,
      supplierinvoice               as SupplierInvoice,
      supplierinvoicefiscalyear     as SupplierInvoiceFiscalYear,
      error                         as Error,
      line_status                   as LineStatus,
      line_status_criticality       as LineStatusCriticality,
      debitcreditcode               as DebitCreditCode,
      debitcreditcodegl             as DebitCreditCodeGL,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      supplierinvoiceitemamountgl   as SupplierInvoiceItemAmountGL,
      taxcodegl                     as TaxCodeGL,
      profitcenter                  as ProfitCenter,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      taxbaseamountintranscrcy      as TaxBaseAmountInTransCrcy,
      error_message                 as ErrorMessage,
      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                    as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by               as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at               as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at         as LocalLastChangedAt,

      _Header
}
