@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Consumption Invoice Upload - File info'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define root view entity ZC_LO05_04_FILE
  provider contract transactional_query
  as projection on ZI_LO05_04_FILE
{
      @UI.hidden: true
  key Uuid,
      @EndUserText.label: 'File Name'
      Filename,
      @EndUserText.label: 'File Status' 
      Status,
      @Semantics.largeObject: {
           mimeType: 'MimeType',
           fileName: 'Filename',
           acceptableMimeTypes: [ 'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ],
           contentDispositionPreference: #INLINE }
      Attachment,
      Mimetype,
      @EndUserText.label: 'Invoice-Goods'
      IsInvgoods,
      @EndUserText.label: 'Invoice-Service'
      IsInvserv,
      @EndUserText.label: 'Subsequence Debit.Credit'
      IsSubdecre,
      @EndUserText.label: 'Scenario'
      @ObjectModel.text.element: [ 'ScenarioDescription' ]
      Scenario, 
      ScenarioDescription,
      @EndUserText.label: 'Last Changed On'
      LastChangedAt,
      @EndUserText.label: 'User'
      CreatedBy,
      @EndUserText.label: 'Created By'
      CreatedByName,
      @EndUserText.label: 'Created On'
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      _Item : redirected to composition child ZC_LO05_04_XLSX
}
