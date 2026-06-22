@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption Invoice Upload - FileContent'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_LO05_04_XLSX
  as projection on ZI_LO05_04_XLSX
{
  key Uuid,
  key LineId,
  key LineNumber,
      CompanyCode,
      AccountingDocumentType,
      DocumentDate,
      PostingDate,
      SupplierInvoiceIDByInvcgParty,
      InvoicingParty,
      ReconciliationAccount,
      directquotedexchangerate,
      SupplierPostingLineItemText,
      DocumentCurrency,
      @Semantics.amount.currencyCode : 'DocumentCurrency'
      InvoiceGrossAmount,
      @Semantics.amount.currencyCode : 'DocumentCurrency'
      UnplannedDeliveryCost,
      DocumentHeaderText,
      AssignmentReference,
      PaymentTerms,
      DueCalculationBaseDate,
      SupplierInvoiceItem,
      PurchaseOrder,
      PurchaseOrderItem,
      Plant,
      IsSubsequentDebitCredit,
      TaxCode,
      @Semantics.amount.currencyCode : 'DocumentCurrency'
      SupplierInvoiceItemAmount,
      PurchaseOrderUnit,
      @Semantics.quantity.unitOfMeasure : 'PurchaseOrderUnit'
      QuantityInPurchaseOrderUnit,
      OrdinalNumber,
      WBSElement,
      FixedAsset,
      GLAccount,
      FunctionalArea,
      CostCenter,
      SupplierInvoice,
      SupplierInvoiceFiscalYear,
      LineStatus,
      LineStatusCriticality,
      DebitCreditCode,
      DebitCreditCodeGL,
      @Semantics.amount.currencyCode : 'DocumentCurrency'
      SupplierInvoiceItemAmountGL,
      TaxCodeGL,
      ProfitCenter,
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      TaxBaseAmountInTransCrcy,
      Error,
      ErrorMessage,
      LastChangedAt,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Header : redirected to parent ZC_LO05_04_FILE
}
