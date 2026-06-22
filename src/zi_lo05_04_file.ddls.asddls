@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Interface Invoice Upload - File info'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZI_LO05_04_FILE
  as select from ztb_lo05_04_file
  association [0..1] to ZVH_LO05_04_SCENARIO as _Scenario on $projection.Scenario = _Scenario.Scenario
  association [0..1] to I_User               as _User     on $projection.CreatedBy = _User.UserID
  composition [0..*] of ZI_LO05_04_XLSX      as _Item
{
  key uuid                  as Uuid,
      filename              as Filename,
      status                as Status,
      @Semantics.largeObject: {
      mimeType : 'mimetype',
      fileName : 'Filename',
      contentDispositionPreference: #INLINE
      }
      attachment            as Attachment,
      @Semantics.mimeType: true
      mimetype              as Mimetype,

      is_invgoods           as IsInvgoods,
      is_invserv            as IsInvserv,
      is_subdecre           as IsSubdecre,
      scenario              as Scenario,
      _Scenario.Description as ScenarioDescription,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      _User.UserDescription as CreatedByName,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      
      _User,
      _Scenario,
      _Item
}
