CLASS lhc_zi_lo05_04_file DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    TYPES: lty_file TYPE STRUCTURE FOR READ RESULT zi_lo05_04_file\\header.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR header RESULT result.

*    METHODS get_instance_features_item FOR INSTANCE FEATURES
*      IMPORTING keys REQUEST requested_features FOR item RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR header RESULT result.

*    METHODS get_instance_author_item FOR INSTANCE AUTHORIZATION
*      IMPORTING keys REQUEST requested_authorizations FOR item RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR header RESULT result.

*    METHODS get_global_author_item FOR GLOBAL AUTHORIZATION
*    IMPORTING REQUEST requested_authorizations FOR item RESULT result.

    METHODS uploadexceldata FOR MODIFY
      IMPORTING keys FOR ACTION header~uploadexceldata RESULT result.

    METHODS parkinvoice FOR MODIFY
      IMPORTING keys FOR ACTION header~parkinvoice RESULT result.

    METHODS postinvoice FOR MODIFY
      IMPORTING keys FOR ACTION header~postinvoice RESULT result.

    METHODS fields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR header~fields.

    METHODS process_data
      IMPORTING
        is_file       TYPE lty_file
        iv_attachment TYPE zi_lo05_04_file-attachment
      EXPORTING
        et_item       TYPE ANY TABLE
        ev_message    TYPE string.

    METHODS excel_string_to_date
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(ev_value) TYPE d.

    METHODS currency_conv_to_internal
      IMPORTING
        currency             TYPE  i_currency-currency
        amount_external      TYPE  bapicurr-bapicurr
        max_number_of_digits TYPE  i
      EXPORTING
        amount_internal      TYPE any.

    METHODS getdefaultsforcreate FOR READ
      IMPORTING keys FOR FUNCTION header~getdefaultsforcreate RESULT result.

*    METHODS precheck_update FOR PRECHECK
*      IMPORTING entities FOR UPDATE header.

ENDCLASS.

CLASS lhc_zi_lo05_04_file IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
      ENTITY header
      FIELDS ( uuid status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file).

    result = VALUE #( FOR ls_file IN lt_file
                      ( %key                              = ls_file-%key
                        %is_draft                         = ls_file-%is_draft
                        %field-mimetype                   =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-f-read_only )
                        %field-filename                   =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-f-read_only )
                        %field-attachment                 =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-f-read_only )
                        %field-scenario                   =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-f-read_only )
                        %delete                           =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-o-disabled )
                        %features-%action-edit            =
                            COND #( WHEN ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-o-disabled )
                        %features-%action-uploadexceldata =
                            COND #( WHEN ls_file-%is_draft = '00'
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                    THEN if_abap_behv=>fc-o-disabled )
                        %features-%action-parkinvoice     =
                            COND #( WHEN ls_file-%is_draft = '00'
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_parked
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing" add by thuy 27/01/26
                                    THEN if_abap_behv=>fc-o-disabled )
                        %features-%action-postinvoice     =
                            COND #( WHEN ls_file-%is_draft = '00'
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processed
*                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_post_processing" add by thuy 27/01/26
                                      OR ls_file-status = zcl_bp_i_lo05_04_file=>c_status_processing"
                                    THEN if_abap_behv=>fc-o-disabled )

                                    ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD uploadexceldata.
    DATA:
      lv_errmsg TYPE string,
      lt_item   TYPE TABLE FOR CREATE zi_lo05_04_file\_item,
      ls_mat    TYPE TABLE FOR UPDATE zi_lo05_04_file,
      lv_status TYPE zi_lo05_04_file-status,
      lt_excel  TYPE TABLE OF zst_lo05_04_inv.

    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
      ENTITY header
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity).

    DATA(lv_attachment) = VALUE #( lt_file_entity[ 1 ]-attachment OPTIONAL ).
    DATA(ls_file) = VALUE #( lt_file_entity[ 1 ] OPTIONAL ).

    IF lv_attachment IS INITIAL.
      lv_errmsg = 'Please choose file to upload'.
    ENDIF.

    IF ls_file-scenario IS INITIAL.
      lv_errmsg = 'Please choose at least one Invoice type'.
    ENDIF.

    IF lv_errmsg IS NOT INITIAL.
      result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                          %param = CORRESPONDING #( key ) ) ).
      APPEND VALUE #(
        %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = lv_errmsg ) ) TO reported-header.
      RETURN.
    ENDIF.

    process_data(
      EXPORTING
        is_file       = ls_file
        iv_attachment = lv_attachment
      IMPORTING
        et_item       = lt_excel
        ev_message    = lv_errmsg ).

    IF lv_errmsg IS NOT INITIAL.
      result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                          %param = CORRESPONDING #( key ) ) ).
      APPEND VALUE #(
        %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = lv_errmsg ) ) TO reported-header.
      RETURN.
    ENDIF.

    IF NOT line_exists( lt_excel[ error = abap_true ] ).
      lv_status = zcl_bp_i_lo05_04_file=>c_status_valid.
    ELSE.
      lv_status = zcl_bp_i_lo05_04_file=>c_status_invalid.
    ENDIF.

    "Checking Existing entry in child entity for user if any
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        BY \_item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_existing_xldata).

    IF lt_existing_xldata IS NOT INITIAL.
      "Delete already existing entries from child entity
      MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY item
        DELETE FROM VALUE #( FOR ls_existing_xldata IN lt_existing_xldata
                             ( %key      = ls_existing_xldata-%key
                               %is_draft = ls_existing_xldata-%is_draft ) )
        MAPPED DATA(ls_del_mapped)
        REPORTED DATA(ls_del_reported)
        FAILED DATA(ls_del_failed).
    ENDIF.

    "Add New Entry for XLData (association)
    lt_item =
        VALUE #( (
            %cid_ref  = keys[ 1 ]-%cid_ref
            %is_draft = keys[ 1 ]-%is_draft
            uuid      = keys[ 1 ]-uuid
            %target   =
                VALUE #(
                    FOR ls_excel IN lt_excel
                      ( %cid      = keys[ 1 ]-%cid_ref
                        %is_draft = keys[ 1 ]-%is_draft
                        %data     =
                            VALUE #(
                                uuid                          = keys[ 1 ]-uuid
                                lineid                        = ls_excel-line_id
                                linenumber                    = ls_excel-line_no
                                companycode                   = ls_excel-companycode
                                accountingdocumenttype        = ls_excel-accountingdocumenttype
                                documentdate                  = ls_excel-documentdate
                                postingdate                   = ls_excel-postingdate
                                supplierinvoiceidbyinvcgparty = ls_excel-supplierinvoiceidbyinvcgparty
                                invoicingparty                = ls_excel-invoicingparty
                                reconciliationaccount         = ls_excel-reconciliationaccount
                                directquotedexchangerate      = ls_excel-directquotedexchangerate
                                documentcurrency              = ls_excel-documentcurrency
                                invoicegrossamount            = ls_excel-invoicegrossamount
                                unplanneddeliverycost         = ls_excel-unplanneddeliverycost
                                documentheadertext            = ls_excel-documentheadertext
                                assignmentreference           = ls_excel-assignmentreference
                                paymentterms                  = ls_excel-paymentterms
                                duecalculationbasedate        = ls_excel-duecalculationbasedate
                                supplierpostinglineitemtext   = ls_excel-supplierpostinglineitemtext
                                supplierinvoiceitem           = ls_excel-supplierinvoiceitem
                                purchaseorder                 = ls_excel-purchaseorder
                                purchaseorderitem             = ls_excel-purchaseorderitem
                                plant                         = ls_excel-plant
                                issubsequentdebitcredit       = ls_excel-issubsequentdebitcredit
                                taxcode                       = ls_excel-taxcode
                                supplierinvoiceitemamount     = ls_excel-supplierinvoiceitemamount
                                purchaseorderunit             = ls_excel-purchaseorderunit
                                quantityinpurchaseorderunit   = ls_excel-quantityinpurchaseorderunit
                                ordinalnumber                 = ls_excel-ordinalnumber
                                wbselement                    = ls_excel-wbselement
                                fixedasset                    = ls_excel-fixedasset
                                glaccount                     = ls_excel-glaccount
                                functionalarea                = ls_excel-functionalarea
                                costcenter                    = ls_excel-costcenter
                                debitcreditcode               = ls_excel-debitcreditcode
                                debitcreditcodegl             = ls_excel-debitcreditcodegl
                                supplierinvoiceitemamountgl   = ls_excel-supplierinvoiceitemamountgl
                                taxbaseamountintranscrcy      = ls_excel-taxbaseamountintranscrcy
                                taxcodegl                     = ls_excel-taxcodegl
                                profitcenter                  = ls_excel-profitcenter
                                linestatus                    = COND #( WHEN ls_excel-error = abap_true
                                                                        THEN zcl_bp_i_lo05_04_file=>c_lstatus_invalid
                                                                        ELSE zcl_bp_i_lo05_04_file=>c_lstatus_valid )
                                linestatuscriticality         = COND #( WHEN ls_excel-error = abap_true
                                                                        THEN '1'
                                                                        ELSE '3' )
                                error                         = ls_excel-error
                                errormessage                  = ls_excel-error_message )
                        %control  =
                            VALUE #(
                                uuid                          = if_abap_behv=>mk-on
                                lineid                        = if_abap_behv=>mk-on
                                linenumber                    = if_abap_behv=>mk-on
                                companycode                   = if_abap_behv=>mk-on
                                accountingdocumenttype        = if_abap_behv=>mk-on
                                documentdate                  = if_abap_behv=>mk-on
                                postingdate                   = if_abap_behv=>mk-on
                                supplierinvoiceidbyinvcgparty = if_abap_behv=>mk-on
                                invoicingparty                = if_abap_behv=>mk-on
                                reconciliationaccount         = if_abap_behv=>mk-on
                                directquotedexchangerate      = if_abap_behv=>mk-on
                                documentcurrency              = if_abap_behv=>mk-on
                                invoicegrossamount            = if_abap_behv=>mk-on
                                unplanneddeliverycost         = if_abap_behv=>mk-on
                                documentheadertext            = if_abap_behv=>mk-on
                                assignmentreference           = if_abap_behv=>mk-on
                                paymentterms                  = if_abap_behv=>mk-on
                                duecalculationbasedate        = if_abap_behv=>mk-on
                                supplierpostinglineitemtext   = if_abap_behv=>mk-on
                                supplierinvoiceitem           = if_abap_behv=>mk-on
                                purchaseorder                 = if_abap_behv=>mk-on
                                purchaseorderitem             = if_abap_behv=>mk-on
                                plant                         = if_abap_behv=>mk-on
                                issubsequentdebitcredit       = if_abap_behv=>mk-on
                                taxcode                       = if_abap_behv=>mk-on
                                supplierinvoiceitemamount     = if_abap_behv=>mk-on
                                purchaseorderunit             = if_abap_behv=>mk-on
                                quantityinpurchaseorderunit   = if_abap_behv=>mk-on
                                ordinalnumber                 = if_abap_behv=>mk-on
                                wbselement                    = if_abap_behv=>mk-on
                                fixedasset                    = if_abap_behv=>mk-on
                                glaccount                     = if_abap_behv=>mk-on
                                functionalarea                = if_abap_behv=>mk-on
                                costcenter                    = if_abap_behv=>mk-on
                                debitcreditcode               = if_abap_behv=>mk-on
                                debitcreditcodegl             = if_abap_behv=>mk-on
                                supplierinvoiceitemamountgl   = if_abap_behv=>mk-on
                                taxbaseamountintranscrcy      = if_abap_behv=>mk-on
                                taxcodegl                     = if_abap_behv=>mk-on
                                profitcenter                  = if_abap_behv=>mk-on
                                linestatus                    = if_abap_behv=>mk-on
                                linestatuscriticality         = if_abap_behv=>mk-on
                                error                         = if_abap_behv=>mk-on
                                errormessage                  = if_abap_behv=>mk-on ) ) ) ) ).

    "Modify Root View data (Change Status)
    MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        UPDATE FROM VALUE #( FOR ls_key IN keys
                             ( %is_draft       = ls_key-%is_draft
                               uuid            = ls_key-uuid
                               status          = lv_status "Update status of file
                               %control-status = if_abap_behv=>mk-on ) )
        MAPPED DATA(ls_mapped_update)
        REPORTED DATA(ls_reported_update)
        FAILED DATA(ls_failed_update).

    MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        CREATE BY \_item
        AUTO FILL CID
        WITH lt_item
        MAPPED DATA(ls_mapped_item)
        REPORTED DATA(ls_reported_item)
        FAILED DATA(ls_failed_item).

    "Read Updated Entry
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
        RESULT DATA(lt_xlhead).

    "Send Status back to front end
    result = VALUE #( FOR ls_upd_head IN lt_xlhead
                      ( %tky   = ls_upd_head-%tky
                        %param = ls_upd_head ) ).
  ENDMETHOD.

  METHOD fields.
    IF keys[ 1 ]-%is_draft = '00'.
      MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
      ENTITY header
      EXECUTE uploadexceldata
      FROM CORRESPONDING #( keys ).
    ENDIF.
  ENDMETHOD.


  METHOD process_data.
    TYPES:
      BEGIN OF lty_excel,
        col1  TYPE string,
        col2  TYPE string,
        col3  TYPE string,
        col4  TYPE string,
        col5  TYPE string,
        col6  TYPE string,
        col7  TYPE string,
        col8  TYPE string,
        col9  TYPE string,
        col10 TYPE string,
        col11 TYPE string,
        col12 TYPE string,
        col13 TYPE string,
        col14 TYPE string,
        col15 TYPE string,
        col16 TYPE string,
        col17 TYPE string,
        col18 TYPE string,
        col19 TYPE string,
        col20 TYPE string,
        col21 TYPE string,
        col22 TYPE string,
        col23 TYPE string,
        col24 TYPE string,
        col25 TYPE string,
        col26 TYPE string,
        col27 TYPE string,
        col28 TYPE string,
        col29 TYPE string,
        col30 TYPE string,
      END OF lty_excel.

    DATA:
      lv_amount_external TYPE bapicurr-bapicurr,
      lt_excel           TYPE STANDARD TABLE OF lty_excel,
      ls_upload_data     TYPE zst_lo05_04_inv,
      lt_upload_data     TYPE STANDARD TABLE OF zst_lo05_04_inv,
      lt_item            TYPE STANDARD TABLE OF zst_lo05_04_inv.

    CONSTANTS:
      lc_start_line TYPE i VALUE 2.

    FREE: lt_upload_data.

    "Move Excel Data to Internal Table
    DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = iv_attachment )->read_access( ).
    DATA(lo_workbook) = lo_xlsx->get_workbook( ).
    IF lines( lo_workbook->worksheet->all->get( ) ) < 4.
      ev_message = 'The number of sheets is less than 4'.
      RETURN.
    ENDIF.

    DATA(lo_worksheet) = COND #( WHEN is_file-scenario = zcl_bp_i_lo05_04_file=>c_scenario_invgoods
                                   THEN lo_workbook->worksheet->at_position( 1 )
                                 WHEN is_file-scenario = zcl_bp_i_lo05_04_file=>c_scenario_invservice
                                   THEN lo_workbook->worksheet->at_position( 2 )
                                 WHEN is_file-scenario = zcl_bp_i_lo05_04_file=>c_scenario_subdecre
                                   THEN lo_workbook->worksheet->at_position( 3 )
                                 WHEN is_file-scenario = zcl_bp_i_lo05_04_file=>c_scenario_vat
                                   THEN lo_workbook->worksheet->at_position( 4 ) ).
    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    DATA(lo_execute) = lo_worksheet->select( lo_selection_pattern )->row_stream( )->operation->write_to(
                                                                      REF #( lt_excel ) ).
    lo_execute->set_value_transformation(
        xco_cp_xlsx_read_access=>value_transformation->string_value )->if_xco_xlsx_ra_operation~execute( ).

    DELETE lt_excel WHERE col1  IS INITIAL
                      AND col2  IS INITIAL
                      AND col3  IS INITIAL
                      AND col4  IS INITIAL
                      AND col5  IS INITIAL
                      AND col6  IS INITIAL
                      AND col7  IS INITIAL
                      AND col8  IS INITIAL
                      AND col9  IS INITIAL
                      AND col10 IS INITIAL
                      AND col11 IS INITIAL
                      AND col12 IS INITIAL
                      AND col13 IS INITIAL
                      AND col14 IS INITIAL
                      AND col15 IS INITIAL
                      AND col16 IS INITIAL
                      AND col17 IS INITIAL
                      AND col18 IS INITIAL
                      AND col19 IS INITIAL
                      AND col20 IS INITIAL
                      AND col21 IS INITIAL
                      AND col22 IS INITIAL
                      AND col23 IS INITIAL
                      AND col24 IS INITIAL
                      AND col25 IS INITIAL
                      AND col26 IS INITIAL
                      AND col27 IS INITIAL
                      AND col28 IS INITIAL
                      AND col29 IS INITIAL
                      AND col30 IS INITIAL.

    DATA(lv_lines) = lines( lt_excel ).
    IF lv_lines > lc_start_line.
      LOOP AT lt_excel INTO DATA(ls_excel) FROM lc_start_line.
        DATA(lv_tabix) = sy-tabix.
        IF lv_tabix = lc_start_line.
          DATA(ls_excel_header) = ls_excel.
          CONTINUE.
        ENDIF.

        IF lv_tabix = lc_start_line + 1.
          CONTINUE.
        ENDIF.

        DO 30 TIMES.
          DATA(lv_index) = sy-index.
          DATA(lv_colname) = |COL{ lv_index }|.
          ASSIGN ls_excel_header-(lv_colname) TO FIELD-SYMBOL(<lv_colname>).
          IF <lv_colname> IS ASSIGNED.
            CASE is_file-scenario.
              WHEN zcl_bp_i_lo05_04_file=>c_scenario_invgoods. "Invoice-Goods
                CASE <lv_colname>.
                  WHEN '1'. "Invoice Date
                    ASSIGN ls_excel-(lv_colname) TO FIELD-SYMBOL(<lv_value>).
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '2'. "Posting Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-postingdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '3'. "Reference
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceidbyinvcgparty = to_upper( <lv_value> ).
                      ls_upload_data-supplierinvoiceidbyinvcgpartyf = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '4'. "Invoicing Party
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicingparty = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '5'. "Reconciliation Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-reconciliationaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '6'. "Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentcurrency = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '7'. "Gross Invoice Amount
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicegrossamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '8'. "Document Header Text
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentheadertext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '9'. "Assignment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-assignmentreference = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '10'. "Key for Terms of Payment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-paymentterms = to_upper( <lv_value> ).
                      ls_upload_data-paymentterms = |{ ls_upload_data-paymentterms ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '11'. "Baseline Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-duecalculationbasedate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '12'. "Invoice Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '13'. "Purchasing Document
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorder = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '14'. "Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorderitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '15'. "Tax on Sales/Purchases Code
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxcode = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '16'. "Amount in Document Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitemamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '17'. "Quantity
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-quantityinpurchaseorderunit = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '18'. "directquotedexchangerate
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-directquotedexchangerate = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '19'. "SupplierPostingLineItemText
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierpostinglineitemtext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                ENDCASE.
              WHEN zcl_bp_i_lo05_04_file=>c_scenario_invservice. "Invoice-Service
                CASE <lv_colname>.
                  WHEN '1'. "Invoice Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '2'. "Posting Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-postingdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '3'. "Reference
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceidbyinvcgparty = to_upper( <lv_value> ).
                      ls_upload_data-supplierinvoiceidbyinvcgpartyf = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '4'. "Invoicing Party
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicingparty = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '5'. "Reconciliation Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-reconciliationaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '6'. "Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentcurrency = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '7'. "Gross Invoice Amount
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicegrossamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '8'. "Document Header Text
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentheadertext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '9'. "Assignment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-assignmentreference = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '10'. "Key for Terms of Payment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-paymentterms = to_upper( <lv_value> ).
                      ls_upload_data-paymentterms = |{ ls_upload_data-paymentterms ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '11'. "Baseline Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-duecalculationbasedate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '12'. "Invoice Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '13'. "Purchasing Document
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorder = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '14'. "Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorderitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '15'. "Tax on Sales/Purchases Code
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxcode = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '16'. "Amount in Document Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitemamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '17'. "Quantity
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-quantityinpurchaseorderunit = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '18'. "WBSElement
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-wbselement = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '19'. "G/L Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-glaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '20'. "Functional Area
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-functionalarea = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '21'. "Cost Center
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-costcenter = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '22'. "directquotedexchangerate
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-directquotedexchangerate = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '23'. "SupplierPostingLineItemText
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierpostinglineitemtext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                ENDCASE.
              WHEN zcl_bp_i_lo05_04_file=>c_scenario_subdecre. "Subsequence Debit.Credit
                CASE <lv_colname>.
                  WHEN '1'. "Invoice Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '2'. "Posting Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-postingdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '3'. "Reference
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceidbyinvcgparty = to_upper( <lv_value> ).
                      ls_upload_data-supplierinvoiceidbyinvcgpartyf = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '4'. "Invoicing Party
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicingparty = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '5'. "Reconciliation Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-reconciliationaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '6'. "Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentcurrency = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '7'. "Gross Invoice Amount
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicegrossamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '8'. "Unplanned Del. Costs
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-unplanneddeliverycost = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '9'. "Document Header Text
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentheadertext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '10'. "Assignment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-assignmentreference = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '11'. "Key for Terms of Payment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-paymentterms = to_upper( <lv_value> ).
                      ls_upload_data-paymentterms = |{ ls_upload_data-paymentterms ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '12'. "Baseline Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-duecalculationbasedate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '13'. "Invoice Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '14'. "Purchasing Document
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorder = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '15'. "Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorderitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '16'. "IsSubsequentDebitCredit
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-issubsequentdebitcredit = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '17'. "DebitCreditCode
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-debitcreditcode = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '18'. "Tax on Sales/Purchases Code
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxcode = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '19'. "Amount in Document Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitemamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '20'. "Quantity
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-quantityinpurchaseorderunit = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '21'. "directquotedexchangerate
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-directquotedexchangerate = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '22'. "SupplierPostingLineItemText
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierpostinglineitemtext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                ENDCASE.
              WHEN zcl_bp_i_lo05_04_file=>c_scenario_vat. "VAT upload
                CASE <lv_colname>.
                  WHEN '1'. "Invoice Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '2'. "Posting Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-postingdate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '3'. "Reference
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceidbyinvcgparty = to_upper( <lv_value> ).
                      ls_upload_data-supplierinvoiceidbyinvcgpartyf = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '4'. "Invoicing Party
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicingparty = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '5'. "Reconciliation Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-reconciliationaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '6'. "Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentcurrency = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '7'. "Gross Invoice Amount
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-invoicegrossamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN 'Unplanned Del. Costs'.
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-unplanneddeliverycost = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '8'. "Document Header Text
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-documentheadertext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '9'. "Assignment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-assignmentreference = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '10'. "Key for Terms of Payment
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-paymentterms = to_upper( <lv_value> ).
                      ls_upload_data-paymentterms = |{ ls_upload_data-paymentterms ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '11'. "Baseline Date
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-duecalculationbasedate = excel_string_to_date( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '12'. "Invoice Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '13'. "Purchasing Document
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorder = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '14'. "Item
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-purchaseorderitem = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '15'. "IsSubsequentDebitCredit
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-issubsequentdebitcredit = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '16'. "DebitCreditCode
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-debitcreditcode = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '17'. "Tax on Sales/Purchases Code
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxcode = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '18'. "Amount in Document Currency
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitemamount = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '19'. "Quantity
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-quantityinpurchaseorderunit = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '20'. "G/L Account
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-glaccount = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '21'. "DebitCreditCode - GL
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-debitcreditcodegl = to_upper( <lv_value> ).
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '22'. "Amount in Document Currency - GL
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierinvoiceitemamountgl = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '23'. "Tax Code
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxcodegl = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '24'. "Tax Base Amount
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-taxbaseamountintranscrcy = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '25'. "Profit Center
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-profitcenter = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '26'. "Cost Center
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-costcenter = |{ <lv_value> ALPHA = IN }|.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '27'. "directquotedexchangerate
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-directquotedexchangerate = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                  WHEN '28'. "SupplierPostingLineItemText
                    ASSIGN ls_excel-(lv_colname) TO <lv_value>.
                    IF <lv_value> IS ASSIGNED.
                      ls_upload_data-supplierpostinglineitemtext = <lv_value>.
                      CONTINUE.
                      UNASSIGN <lv_value>.
                    ENDIF.
                ENDCASE.
            ENDCASE.
            UNASSIGN <lv_colname>.
          ENDIF.
        ENDDO.

        ls_upload_data-line_no = lv_tabix - lc_start_line - 1.
        ls_upload_data-companycode = '5730'.
        ls_upload_data-accountingdocumenttype = 'RE'.
        ls_upload_data-plant = '5730'.

        lv_amount_external = ls_upload_data-invoicegrossamount.
        currency_conv_to_internal(
          EXPORTING
            currency             = ls_upload_data-documentcurrency
            amount_external      = lv_amount_external
            max_number_of_digits = 23
          IMPORTING
            amount_internal      = ls_upload_data-invoicegrossamount ).

        lv_amount_external = ls_upload_data-unplanneddeliverycost.
        currency_conv_to_internal(
          EXPORTING
            currency             = ls_upload_data-documentcurrency
            amount_external      = lv_amount_external
            max_number_of_digits = 23
          IMPORTING
            amount_internal      = ls_upload_data-unplanneddeliverycost ).

        lv_amount_external = ls_upload_data-supplierinvoiceitemamount.
        currency_conv_to_internal(
          EXPORTING
            currency             = ls_upload_data-documentcurrency
            amount_external      = lv_amount_external
            max_number_of_digits = 23
          IMPORTING
            amount_internal      = ls_upload_data-supplierinvoiceitemamount ).

        lv_amount_external = ls_upload_data-supplierinvoiceitemamountgl.
        currency_conv_to_internal(
          EXPORTING
            currency             = ls_upload_data-documentcurrency
            amount_external      = lv_amount_external
            max_number_of_digits = 23
          IMPORTING
            amount_internal      = ls_upload_data-supplierinvoiceitemamountgl ).

        lv_amount_external = ls_upload_data-taxbaseamountintranscrcy.
        currency_conv_to_internal(
          EXPORTING
            currency             = ls_upload_data-documentcurrency
            amount_external      = lv_amount_external
            max_number_of_digits = 23
          IMPORTING
            amount_internal      = ls_upload_data-taxbaseamountintranscrcy ).

        APPEND ls_upload_data TO lt_upload_data.
        CLEAR ls_upload_data.
      ENDLOOP.

      SELECT
            i_supplier~supplier
          FROM i_supplier
              INNER JOIN @lt_upload_data AS _upload_data
                      ON _upload_data~invoicingparty = i_supplier~supplier
          INTO TABLE @DATA(lt_supplier).

      SELECT
            i_paymentterms~paymentterms
          FROM i_paymentterms
              INNER JOIN @lt_upload_data AS _upload_data
                      ON _upload_data~paymentterms = i_paymentterms~paymentterms
          INTO TABLE @DATA(lt_paymentterms).

      SELECT
            i_glaccount~glaccount
          FROM i_glaccount
              INNER JOIN @lt_upload_data AS _upload_data
                      ON _upload_data~glaccount = i_glaccount~glaccount
                      OR _upload_data~reconciliationaccount = i_glaccount~glaccount
          INTO TABLE @DATA(lt_glaccount).

      LOOP AT lt_upload_data INTO ls_upload_data.

        "Negative value check
        IF ls_upload_data-quantityinpurchaseorderunit < 0.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Negative value for field Purchase Order Quantity is not allowed|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        "Supplier existence check
        IF NOT line_exists( lt_supplier[ supplier = ls_upload_data-invoicingparty ] ) AND
            ls_upload_data-invoicingparty IS NOT INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Invoicing Party { ls_upload_data-invoicingparty } does not exist|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        "GR check
        IF NOT line_exists( lt_supplier[ supplier = ls_upload_data-invoicingparty ] ) AND
            ls_upload_data-invoicingparty IS NOT INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Invoicing Party { ls_upload_data-invoicingparty } does not exist|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        "Payment Terms check
        IF NOT line_exists( lt_paymentterms[ paymentterms = ls_upload_data-paymentterms ] ) AND
            ls_upload_data-paymentterms IS NOT INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Payment Terms { ls_upload_data-paymentterms } does not exist|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        "GL check
        IF NOT line_exists( lt_glaccount[ glaccount = ls_upload_data-glaccount ] ) AND
            ls_upload_data-glaccount IS NOT INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |G/L Account { ls_upload_data-glaccount } does not exist|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        "Reconciliation Account check
        IF NOT line_exists( lt_glaccount[ glaccount = ls_upload_data-reconciliationaccount ] ) AND
            ls_upload_data-reconciliationaccount IS NOT INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Reconciliation Account { ls_upload_data-reconciliationaccount } does not exist|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        IF ls_upload_data-supplierinvoiceidbyinvcgpartyf IS NOT INITIAL AND
           strlen( ls_upload_data-supplierinvoiceidbyinvcgpartyf ) > 16.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = |Reference { ls_upload_data-supplierinvoiceidbyinvcgpartyf } exceeds 16 characters|.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " Required field
        IF ls_upload_data-documentdate IS INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = 'Invoice Date is required'.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " Required field
        IF ls_upload_data-documentcurrency IS INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = 'Currency is required'.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " Required field
        IF ls_upload_data-supplierinvoiceitem IS INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = 'Invoice Item is required'.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " Required field
        IF ls_upload_data-purchaseorder IS INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = 'Purchasing Document is required'.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " Required field
        IF ls_upload_data-purchaseorderitem IS INITIAL.
          ls_upload_data-error = abap_true.
          ls_upload_data-error_message = 'Purchasing Item is required'.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
              APPEND ls_upload_data TO lt_item.
            CATCH cx_uuid_error ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        IF ls_upload_data-error <> abap_true.
          TRY.
              ls_upload_data-line_id = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
            CATCH cx_uuid_error ##NO_HANDLER.
              "handle exception
          ENDTRY.
          APPEND ls_upload_data TO lt_item.
        ENDIF.
      ENDLOOP.

      " Send excel structure to item entity
      et_item[] = lt_item[].
    ELSE.
      " No data found for uploading
      ev_message = 'No data found'.
    ENDIF.
  ENDMETHOD.

  METHOD currency_conv_to_internal.
    DATA:
      lv_currdec TYPE int1,
      lv_factor  TYPE p DECIMALS 3.

    IF max_number_of_digits <= 23.
      IF NOT currency IS INITIAL.
        SELECT SINGLE decimals FROM  i_currency
                        WHERE currency = @currency
                        INTO @lv_currdec.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
      ELSE.
*       Set default value for decimal places for standard conversion
        lv_currdec = 2.
      ENDIF.

* Start conversion of external currency value by checking rate of
* currencie's number of decimals not greater than 5
      IF lv_currdec <= 5.
        lv_factor = 100.

        IF lv_currdec <> 0.
          DO lv_currdec TIMES.
            lv_factor = lv_factor / 10.
          ENDDO.
        ENDIF.

        IF lv_factor <> 0.
          amount_internal = amount_external / lv_factor.
        ENDIF.
      ENDIF.
    ENDIF. "MAX_NUMBER_OF_DIGITS <= 23
  ENDMETHOD.

  METHOD getdefaultsforcreate.
    " default value for create action
    LOOP AT keys INTO DATA(ls_key).
      INSERT INITIAL LINE INTO TABLE result
      ASSIGNING FIELD-SYMBOL(<ls_create_result>).

      GET TIME STAMP FIELD DATA(lv_timestamp).

      <ls_create_result> = VALUE #(
                             %cid   = ls_key-%cid
                             %param = VALUE
                             #( status   = zcl_bp_i_lo05_04_file=>c_status_initial
                                scenario = zcl_bp_i_lo05_04_file=>c_scenario_invgoods ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD excel_string_to_date.
    DATA:
      lv_date_int TYPE i.

    CONSTANTS:
      lc_excel_baseline_date  TYPE d VALUE '19000101',
      lc_excel_1900_leap_year TYPE d VALUE '19000228'.

    CHECK iv_value IS NOT INITIAL AND iv_value CN ' 0'.

    TRY.
        lv_date_int = iv_value.
        IF lv_date_int NOT BETWEEN 1 AND 2958465.
          RETURN.
        ENDIF.
        ev_value = lv_date_int + lc_excel_baseline_date - 2.
        " Needed hack caused by the problem that:
        " Excel 2000 incorrectly assumes that the year 1900 is a leap year
        " http://support.microsoft.com/kb/214326/en-us
        IF ev_value < lc_excel_1900_leap_year.
          ev_value += 1.
        ENDIF.
      CATCH cx_sy_conversion_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

*  METHOD get_instance_features_item.
*    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
*      ENTITY item
*      FIELDS ( uuid )
*      WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_file).
*
*    result = VALUE #( FOR ls_file IN lt_file
*                      ( %key                              = ls_file-%key
*                        %is_draft                         = ls_file-%is_draft
*                        %features-%action-parkinvoice = COND #( WHEN ls_file-%is_draft = '00'
*                                                                    THEN if_abap_behv=>fc-f-read_only
*                                                                    ELSE if_abap_behv=>fc-f-unrestricted )
*                        %features-%action-postinvoice = COND #( WHEN ls_file-%is_draft = '00'
*                                                                    THEN if_abap_behv=>fc-f-read_only
*                                                                    ELSE if_abap_behv=>fc-f-unrestricted )
*                                                                    ) ).
*  ENDMETHOD.

  METHOD parkinvoice.
    DATA lt_item TYPE TABLE FOR CREATE zi_lo05_04_file\_item.

    "Checking Existing entry in child entity for user if any
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        BY \_item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_existing_xldata).

    IF lt_existing_xldata IS INITIAL.
      result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                          %param = CORRESPONDING #( key ) ) ).
      APPEND VALUE #(
        %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = 'No data found' ) ) TO reported-header.
      RETURN.
    ENDIF.

    LOOP AT lt_existing_xldata ASSIGNING FIELD-SYMBOL(<ls_existing_xldata>).
      IF <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_valid OR
         <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd.
        <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd. "Ready for Parking
        <ls_existing_xldata>-linestatuscriticality = '2'.
      ELSEIF <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_invalid.
        result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                            %param = CORRESPONDING #( key ) ) ).
        APPEND VALUE #(
          %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Excel Data is invalid' ) ) TO reported-header.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lt_existing_xldata IS NOT INITIAL.
      "Delete already existing entries from child entity
      MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY item
        DELETE FROM VALUE #( FOR ls_existing_xldata IN lt_existing_xldata
                             ( %key      = ls_existing_xldata-%key
                               %is_draft = ls_existing_xldata-%is_draft ) )
        MAPPED DATA(ls_del_mapped)
        REPORTED DATA(ls_del_reported)
        FAILED DATA(ls_del_failed).
    ENDIF.

    "Add New Entry for XLData (association)
    lt_item =
        VALUE #( (
                 %cid_ref  = keys[ 1 ]-%cid_ref
                 %is_draft = keys[ 1 ]-%is_draft
                 uuid      = keys[ 1 ]-uuid
                 %target   =
                 VALUE #(
                          FOR ls_excel IN lt_existing_xldata
                          ( %cid      = keys[ 1 ]-%cid_ref
                            %is_draft = keys[ 1 ]-%is_draft
                            %data     =
                          VALUE #(
                                   uuid                          = keys[ 1 ]-uuid
                                   lineid                        = ls_excel-lineid
                                   linenumber                    = ls_excel-linenumber
                                   companycode                   = ls_excel-companycode
                                   accountingdocumenttype        = ls_excel-accountingdocumenttype
                                   documentdate                  = ls_excel-documentdate
                                   postingdate                   = ls_excel-postingdate
                                   supplierinvoiceidbyinvcgparty = ls_excel-supplierinvoiceidbyinvcgparty
                                   invoicingparty                = ls_excel-invoicingparty
                                   reconciliationaccount         = ls_excel-reconciliationaccount
                                   directquotedexchangerate      = ls_excel-directquotedexchangerate
                                   documentcurrency              = ls_excel-documentcurrency
                                   invoicegrossamount            = ls_excel-invoicegrossamount
                                   unplanneddeliverycost         = ls_excel-unplanneddeliverycost
                                   documentheadertext            = ls_excel-documentheadertext
                                   assignmentreference           = ls_excel-assignmentreference
                                   paymentterms                  = ls_excel-paymentterms
                                   duecalculationbasedate        = ls_excel-duecalculationbasedate
                                   supplierpostinglineitemtext   = ls_excel-supplierpostinglineitemtext
                                   supplierinvoiceitem           = ls_excel-supplierinvoiceitem
                                   purchaseorder                 = ls_excel-purchaseorder
                                   purchaseorderitem             = ls_excel-purchaseorderitem
                                   plant                         = ls_excel-plant
                                   issubsequentdebitcredit       = ls_excel-issubsequentdebitcredit
                                   taxcode                       = ls_excel-taxcode
                                   supplierinvoiceitemamount     = ls_excel-supplierinvoiceitemamount
                                   purchaseorderunit             = ls_excel-purchaseorderunit
                                   quantityinpurchaseorderunit   = ls_excel-quantityinpurchaseorderunit
                                   ordinalnumber                 = ls_excel-ordinalnumber
                                   wbselement                    = ls_excel-wbselement
                                   fixedasset                    = ls_excel-fixedasset
                                   glaccount                     = ls_excel-glaccount
                                   functionalarea                = ls_excel-functionalarea
                                   costcenter                    = ls_excel-costcenter
                                   debitcreditcode               = ls_excel-debitcreditcode
                                   debitcreditcodegl             = ls_excel-debitcreditcodegl
                                   supplierinvoiceitemamountgl   = ls_excel-supplierinvoiceitemamountgl
                                   taxbaseamountintranscrcy      = ls_excel-taxbaseamountintranscrcy
                                   taxcodegl                     = ls_excel-taxcodegl
                                   profitcenter                  = ls_excel-profitcenter
                                   linestatus                    = ls_excel-linestatus
                                   linestatuscriticality         = ls_excel-linestatuscriticality
                                   supplierinvoice               = ls_excel-supplierinvoice
                                   supplierinvoicefiscalyear     = ls_excel-supplierinvoicefiscalyear
                                   error                         = ls_excel-error
                                   errormessage                  = ls_excel-errormessage )
                            %control  =
                          VALUE #(
                                   uuid                          = if_abap_behv=>mk-on
                                   lineid                        = if_abap_behv=>mk-on
                                   linenumber                    = if_abap_behv=>mk-on
                                   companycode                   = if_abap_behv=>mk-on
                                   accountingdocumenttype        = if_abap_behv=>mk-on
                                   documentdate                  = if_abap_behv=>mk-on
                                   postingdate                   = if_abap_behv=>mk-on
                                   supplierinvoiceidbyinvcgparty = if_abap_behv=>mk-on
                                   invoicingparty                = if_abap_behv=>mk-on
                                   reconciliationaccount         = if_abap_behv=>mk-on
                                   directquotedexchangerate      = if_abap_behv=>mk-on
                                   documentcurrency              = if_abap_behv=>mk-on
                                   invoicegrossamount            = if_abap_behv=>mk-on
                                   unplanneddeliverycost         = if_abap_behv=>mk-on
                                   documentheadertext            = if_abap_behv=>mk-on
                                   assignmentreference           = if_abap_behv=>mk-on
                                   paymentterms                  = if_abap_behv=>mk-on
                                   duecalculationbasedate        = if_abap_behv=>mk-on
                                   supplierpostinglineitemtext   = if_abap_behv=>mk-on
                                   supplierinvoiceitem           = if_abap_behv=>mk-on
                                   purchaseorder                 = if_abap_behv=>mk-on
                                   purchaseorderitem             = if_abap_behv=>mk-on
                                   plant                         = if_abap_behv=>mk-on
                                   issubsequentdebitcredit       = if_abap_behv=>mk-on
                                   taxcode                       = if_abap_behv=>mk-on
                                   supplierinvoiceitemamount     = if_abap_behv=>mk-on
                                   purchaseorderunit             = if_abap_behv=>mk-on
                                   quantityinpurchaseorderunit   = if_abap_behv=>mk-on
                                   ordinalnumber                 = if_abap_behv=>mk-on
                                   wbselement                    = if_abap_behv=>mk-on
                                   fixedasset                    = if_abap_behv=>mk-on
                                   glaccount                     = if_abap_behv=>mk-on
                                   functionalarea                = if_abap_behv=>mk-on
                                   costcenter                    = if_abap_behv=>mk-on
                                   debitcreditcode               = if_abap_behv=>mk-on
                                   debitcreditcodegl             = if_abap_behv=>mk-on
                                   supplierinvoiceitemamountgl   = if_abap_behv=>mk-on
                                   taxbaseamountintranscrcy      = if_abap_behv=>mk-on
                                   taxcodegl                     = if_abap_behv=>mk-on
                                   profitcenter                  = if_abap_behv=>mk-on
                                   linestatus                    = if_abap_behv=>mk-on
                                   linestatuscriticality         = if_abap_behv=>mk-on
                                   supplierinvoice               = if_abap_behv=>mk-on
                                   supplierinvoicefiscalyear     = if_abap_behv=>mk-on
                                   error                         = if_abap_behv=>mk-on
                                   errormessage                  = if_abap_behv=>mk-on ) ) ) ) ).

    "Modify Root View data (Change Status)
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
        RESULT DATA(lt_xlhead).

    READ TABLE lt_xlhead INTO DATA(ls_xlhead) INDEX 1.
    IF sy-subrc = 0.
      IF ls_xlhead-status <> zcl_bp_i_lo05_04_file=>c_status_processing.
        MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
            ENTITY header
            UPDATE FROM VALUE #( FOR ls_key IN keys
                                 ( %is_draft       = ls_key-%is_draft
                                   uuid            = ls_key-uuid
                                   status          = zcl_bp_i_lo05_04_file=>c_status_processing
                                   %control-status = if_abap_behv=>mk-on ) )
            MAPPED DATA(ls_mapped_update)
            REPORTED DATA(ls_reported_update)
            FAILED DATA(ls_failed_update).
      ENDIF.
    ENDIF.

    MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        CREATE BY \_item
        AUTO FILL CID
        WITH lt_item
        MAPPED DATA(ls_mapped_item)
        REPORTED DATA(ls_reported_item)
        FAILED DATA(ls_failed_item).

    "Read Updated Entry
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
        RESULT lt_xlhead.

    "Send Status back to front end
    result = VALUE #( FOR ls_upd_head IN lt_xlhead
                      ( %tky   = ls_upd_head-%tky
                        %param = ls_upd_head

                         ) ).
  ENDMETHOD.

  METHOD postinvoice.
    DATA lt_item TYPE TABLE FOR CREATE zi_lo05_04_file\_item.

    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        BY \_item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_existing_xldata).

    IF lt_existing_xldata IS INITIAL.
      result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                          %param = CORRESPONDING #( key ) ) ).
      APPEND VALUE #(
        %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = 'No data found' ) ) TO reported-header.
      RETURN.
    ENDIF.

    LOOP AT lt_existing_xldata ASSIGNING FIELD-SYMBOL(<ls_existing_xldata>).
      IF <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd OR
         <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parked OR
         <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_valid.
        <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd. "Ready for Posting
        <ls_existing_xldata>-linestatuscriticality = '2'.
      ELSEIF <ls_existing_xldata>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_invalid.
        result = VALUE #( FOR key IN keys ( %tky   = key-%tky
                                            %param = CORRESPONDING #( key ) ) ).
        APPEND VALUE #(
          %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Excel Data is invalid' ) ) TO reported-header.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lt_existing_xldata IS NOT INITIAL.
      "Delete already existing entries from child entity
      MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY item
        DELETE FROM VALUE #( FOR ls_existing_xldata IN lt_existing_xldata
                             ( %key      = ls_existing_xldata-%key
                               %is_draft = ls_existing_xldata-%is_draft ) )
        MAPPED DATA(ls_del_mapped)
        REPORTED DATA(ls_del_reported)
        FAILED DATA(ls_del_failed).
    ENDIF.

    "Add New Entry for XLData (association)
    lt_item =
        VALUE #( (
                 %cid_ref  = keys[ 1 ]-%cid_ref
                 %is_draft = keys[ 1 ]-%is_draft
                 uuid      = keys[ 1 ]-uuid
                 %target   =
                 VALUE #(
                          FOR ls_excel IN lt_existing_xldata
                          ( %cid      = keys[ 1 ]-%cid_ref
                            %is_draft = keys[ 1 ]-%is_draft
                            %data     =
                          VALUE #(
                                   uuid                          = keys[ 1 ]-uuid
                                   lineid                        = ls_excel-lineid
                                   linenumber                    = ls_excel-linenumber
                                   companycode                   = ls_excel-companycode
                                   accountingdocumenttype        = ls_excel-accountingdocumenttype
                                   documentdate                  = ls_excel-documentdate
                                   postingdate                   = ls_excel-postingdate
                                   supplierinvoiceidbyinvcgparty = ls_excel-supplierinvoiceidbyinvcgparty
                                   invoicingparty                = ls_excel-invoicingparty
                                   reconciliationaccount         = ls_excel-reconciliationaccount
                                   directquotedexchangerate      = ls_excel-directquotedexchangerate
                                   documentcurrency              = ls_excel-documentcurrency
                                   invoicegrossamount            = ls_excel-invoicegrossamount
                                   unplanneddeliverycost         = ls_excel-unplanneddeliverycost
                                   documentheadertext            = ls_excel-documentheadertext
                                   assignmentreference           = ls_excel-assignmentreference
                                   paymentterms                  = ls_excel-paymentterms
                                   duecalculationbasedate        = ls_excel-duecalculationbasedate
                                   supplierpostinglineitemtext   = ls_excel-supplierpostinglineitemtext
                                   supplierinvoiceitem           = ls_excel-supplierinvoiceitem
                                   purchaseorder                 = ls_excel-purchaseorder
                                   purchaseorderitem             = ls_excel-purchaseorderitem
                                   plant                         = ls_excel-plant
                                   issubsequentdebitcredit       = ls_excel-issubsequentdebitcredit
                                   taxcode                       = ls_excel-taxcode
                                   supplierinvoiceitemamount     = ls_excel-supplierinvoiceitemamount
                                   purchaseorderunit             = ls_excel-purchaseorderunit
                                   quantityinpurchaseorderunit   = ls_excel-quantityinpurchaseorderunit
                                   ordinalnumber                 = ls_excel-ordinalnumber
                                   wbselement                    = ls_excel-wbselement
                                   fixedasset                    = ls_excel-fixedasset
                                   glaccount                     = ls_excel-glaccount
                                   functionalarea                = ls_excel-functionalarea
                                   costcenter                    = ls_excel-costcenter
                                   debitcreditcode               = ls_excel-debitcreditcode
                                   debitcreditcodegl             = ls_excel-debitcreditcodegl
                                   supplierinvoiceitemamountgl   = ls_excel-supplierinvoiceitemamountgl
                                   taxbaseamountintranscrcy      = ls_excel-taxbaseamountintranscrcy
                                   taxcodegl                     = ls_excel-taxcodegl
                                   profitcenter                  = ls_excel-profitcenter
                                   linestatus                    = ls_excel-linestatus
                                   linestatuscriticality         = ls_excel-linestatuscriticality
                                   supplierinvoice               = ls_excel-supplierinvoice
                                   supplierinvoicefiscalyear     = ls_excel-supplierinvoicefiscalyear
                                   error                         = ls_excel-error
                                   errormessage                  = ls_excel-errormessage )
                            %control  =
                          VALUE #(
                                   uuid                          = if_abap_behv=>mk-on
                                   lineid                        = if_abap_behv=>mk-on
                                   linenumber                    = if_abap_behv=>mk-on
                                   companycode                   = if_abap_behv=>mk-on
                                   accountingdocumenttype        = if_abap_behv=>mk-on
                                   documentdate                  = if_abap_behv=>mk-on
                                   postingdate                   = if_abap_behv=>mk-on
                                   supplierinvoiceidbyinvcgparty = if_abap_behv=>mk-on
                                   invoicingparty                = if_abap_behv=>mk-on
                                   reconciliationaccount         = if_abap_behv=>mk-on
                                   directquotedexchangerate      = if_abap_behv=>mk-on
                                   documentcurrency              = if_abap_behv=>mk-on
                                   invoicegrossamount            = if_abap_behv=>mk-on
                                   unplanneddeliverycost         = if_abap_behv=>mk-on
                                   documentheadertext            = if_abap_behv=>mk-on
                                   assignmentreference           = if_abap_behv=>mk-on
                                   paymentterms                  = if_abap_behv=>mk-on
                                   duecalculationbasedate        = if_abap_behv=>mk-on
                                   supplierpostinglineitemtext   = if_abap_behv=>mk-on
                                   supplierinvoiceitem           = if_abap_behv=>mk-on
                                   purchaseorder                 = if_abap_behv=>mk-on
                                   purchaseorderitem             = if_abap_behv=>mk-on
                                   plant                         = if_abap_behv=>mk-on
                                   issubsequentdebitcredit       = if_abap_behv=>mk-on
                                   taxcode                       = if_abap_behv=>mk-on
                                   supplierinvoiceitemamount     = if_abap_behv=>mk-on
                                   purchaseorderunit             = if_abap_behv=>mk-on
                                   quantityinpurchaseorderunit   = if_abap_behv=>mk-on
                                   ordinalnumber                 = if_abap_behv=>mk-on
                                   wbselement                    = if_abap_behv=>mk-on
                                   fixedasset                    = if_abap_behv=>mk-on
                                   glaccount                     = if_abap_behv=>mk-on
                                   functionalarea                = if_abap_behv=>mk-on
                                   costcenter                    = if_abap_behv=>mk-on
                                   debitcreditcode               = if_abap_behv=>mk-on
                                   debitcreditcodegl             = if_abap_behv=>mk-on
                                   supplierinvoiceitemamountgl   = if_abap_behv=>mk-on
                                   taxbaseamountintranscrcy      = if_abap_behv=>mk-on
                                   taxcodegl                     = if_abap_behv=>mk-on
                                   profitcenter                  = if_abap_behv=>mk-on
                                   linestatus                    = if_abap_behv=>mk-on
                                   linestatuscriticality         = if_abap_behv=>mk-on
                                   supplierinvoice               = if_abap_behv=>mk-on
                                   supplierinvoicefiscalyear     = if_abap_behv=>mk-on
                                   error                         = if_abap_behv=>mk-on
                                   errormessage                  = if_abap_behv=>mk-on ) ) ) ) ).

    "Modify Root View data (Change Status)
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
        RESULT DATA(lt_xlhead).

    READ TABLE lt_xlhead INTO DATA(ls_xlhead) INDEX 1.
    IF sy-subrc = 0.
      IF ls_xlhead-status <> zcl_bp_i_lo05_04_file=>c_status_processing_post .
        MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
            ENTITY header
            UPDATE FROM VALUE #( FOR ls_key IN keys
                                 ( %is_draft       = ls_key-%is_draft
                                   uuid            = ls_key-uuid
                                   status          = zcl_bp_i_lo05_04_file=>c_status_processing_post
                                   %control-status = if_abap_behv=>mk-on ) )
            MAPPED DATA(ls_mapped_update)
            REPORTED DATA(ls_reported_update)
            FAILED DATA(ls_failed_update).
      ENDIF.
    ENDIF.

    MODIFY ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        CREATE BY \_item
        AUTO FILL CID
        WITH lt_item
        MAPPED DATA(ls_mapped_item)
        REPORTED DATA(ls_reported_item)
        FAILED DATA(ls_failed_item).

    "Read Updated Entry
    READ ENTITIES OF zi_lo05_04_file IN LOCAL MODE
        ENTITY header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
        RESULT lt_xlhead.

    "Send Status back to front end
    result = VALUE #( FOR ls_upd_head IN lt_xlhead
                      ( %tky   = ls_upd_head-%tky
                        %param = ls_upd_head ) ).
  ENDMETHOD.

*  METHOD get_instance_author_item.
*
*  ENDMETHOD.
*
*  METHOD get_global_author_item.
*
*  ENDMETHOD.

*  METHOD precheck_update.
*    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
*      IF <ls_entity>-status = zcl_bp_i_lo05_04_file=>c_status_processed.
*        "Return Error Message to Front-end.
*        APPEND VALUE #(  %tky = <ls_entity>-%tky ) TO failed-header.
*        APPEND VALUE #( %tky = <ls_entity>-%tky
*                        %msg = new_message_with_text(
*                        severity = if_abap_behv_message=>severity-error
*                        text     = 'Can not edit the Processed File'
*                        ) ) TO reported-header.
*      ENDIF.
*
*    ENDLOOP.
*  ENDMETHOD.

ENDCLASS.

CLASS lsc_zi_lo05_04_file DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PUBLIC SECTION.
    DATA: gv_check TYPE char1.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zi_lo05_04_file IMPLEMENTATION.

  METHOD save_modified.
    " Trigger job
    DATA ls_scheduling_info TYPE cl_apj_rt_api=>ty_scheduling_info.
    DATA ls_end_info TYPE cl_apj_rt_api=>ty_end_info.
    DATA:
      lv_job_text      TYPE cl_apj_rt_api=>ty_job_text VALUE 'Trigger Custom Job to upload Invoice',
      lv_template_name TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZAJT_LO05_04_INVUPL',
      ls_start_info    TYPE cl_apj_rt_api=>ty_start_info,
      lv_jobname       TYPE cl_apj_rt_api=>ty_jobname,
      lv_jobcount      TYPE cl_apj_rt_api=>ty_jobcount,
      lt_param         TYPE cl_apj_rt_api=>tt_job_parameter_value,
      lt_file          LIKE create-header.
    CHECK gv_check IS INITIAL.
    CHECK create-header[] IS NOT INITIAL OR update-header[] IS NOT INITIAL.
    IF create-header IS NOT INITIAL.
      lt_file[] = create-header[].
    ENDIF.

    IF update-header IS NOT INITIAL.
      lt_file[] = update-header[].

      LOOP AT lt_file ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE status IS INITIAL.
        SELECT SINGLE status
            FROM ztb_lo05_04_file
            WHERE uuid = @<ls_file>-uuid
            INTO @<ls_file>-status.
      ENDLOOP.
    ENDIF.

    DELETE lt_file WHERE uuid IS INITIAL.

    IF lines( lt_file[] ) = 0
      OR ( VALUE #( lt_file[ 1 ]-status OPTIONAL ) NE zcl_bp_i_lo05_04_file=>c_status_processing
       AND VALUE #( lt_file[ 1 ]-status OPTIONAL ) NE zcl_bp_i_lo05_04_file=>c_status_processing_post ).
      RETURN.
    ENDIF.
*    ls_start_info-start_immediately = abap_true.
    GET TIME STAMP FIELD DATA(ls_ts1).
    DATA(ls_ts2) = cl_abap_tstmp=>add( tstmp = ls_ts1
                                      secs  = 1 ).

    ls_start_info-timestamp = ls_ts2.

    ls_scheduling_info-periodic_granularity = ''.
    ls_scheduling_info-periodic_value = 1.
    ls_scheduling_info-test_mode = abap_false.
*    ls_scheduling_info-timezone = 'UTC'.
    ls_end_info-type = ''.
    ls_end_info-max_iterations = 1.

    " Prepare param
    lt_param = VALUE #( ( name    = 'UUID'
                          t_value = VALUE #( ( low    = VALUE #( lt_file[ 1 ]-uuid OPTIONAL )
                                               sign   = 'I'
                                               option = 'EQ' ) ) ) ).

    TRY.
        gv_check = 'X'.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = lv_template_name
            iv_job_text            = lv_job_text
            is_start_info          = ls_start_info
            is_scheduling_info   = ls_scheduling_info
            is_end_info          = ls_end_info
            it_job_parameter_value = lt_param[]
          IMPORTING
            ev_jobname             = lv_jobname
            ev_jobcount            = lv_jobcount ).
      CATCH cx_apj_rt INTO DATA(exc).
        DATA(lv_txt) = exc->get_longtext( ).
        DATA(ls_ret) = exc->get_bapiret2( ).
    ENDTRY.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
