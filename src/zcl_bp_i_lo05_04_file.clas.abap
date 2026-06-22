CLASS zcl_bp_i_lo05_04_file DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_lo05_04_file.
  PUBLIC SECTION.

    CONSTANTS:
      c_scenario_invgoods   TYPE ztb_lo05_04_file-scenario VALUE 'InvGoods',
      c_scenario_invservice TYPE ztb_lo05_04_file-scenario VALUE 'InvService',
      c_scenario_subdecre   TYPE ztb_lo05_04_file-scenario VALUE 'SubDeCre',
      c_scenario_vat        TYPE ztb_lo05_04_file-scenario VALUE 'VAT',
      c_lstatus_valid       TYPE ztb_lo05_04_xlsx-line_status VALUE 'Valid',
      c_lstatus_invalid     TYPE ztb_lo05_04_xlsx-line_status VALUE 'Invalid',
      c_lstatus_parkrd      TYPE ztb_lo05_04_xlsx-line_status VALUE 'Parking Ready',
      c_lstatus_parked      TYPE ztb_lo05_04_xlsx-line_status VALUE 'Parked',
      c_lstatus_postrd      TYPE ztb_lo05_04_xlsx-line_status VALUE 'Posting Ready',
      c_lstatus_posted      TYPE ztb_lo05_04_xlsx-line_status VALUE 'Posted',
      c_lstatus_failed      TYPE ztb_lo05_04_xlsx-line_status VALUE 'Failed',
      c_status_initial      TYPE ztb_lo05_04_file-status VALUE 'Initial',
      c_status_invalid      TYPE ztb_lo05_04_file-status VALUE 'Invalid',
      c_status_valid        TYPE ztb_lo05_04_file-status VALUE 'Valid',
      c_status_processing   TYPE ztb_lo05_04_file-status VALUE 'Processing',
      c_status_parked       TYPE ztb_lo05_04_file-status VALUE 'Parked',
      c_status_processing_post   TYPE ztb_lo05_04_file-status VALUE 'Processing_Post',
      c_status_processed    TYPE ztb_lo05_04_file-status VALUE 'Processed'.
ENDCLASS.



CLASS ZCL_BP_I_LO05_04_FILE IMPLEMENTATION.
ENDCLASS.
