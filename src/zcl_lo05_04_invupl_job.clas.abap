CLASS zcl_lo05_04_invupl_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
    INTERFACES if_apj_rt_run.
    INTERFACES if_apj_dt_defaults.

    TYPES:
      BEGIN OF ty_name_range,
        sign   TYPE c LENGTH 1,
        option TYPE c LENGTH 2,
        low    TYPE uuid,
        high   TYPE uuid,
      END OF ty_name_range.
    TYPES: ty_name_ranges TYPE STANDARD TABLE OF ty_name_range WITH EMPTY KEY.
    DATA: uuid TYPE ty_name_ranges.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      mt_item  TYPE TABLE OF zi_lo05_04_xlsx,
      mt_num03 TYPE n LENGTH 3.

    METHODS:
      upload_invoice
        IMPORTING is_param TYPE zi_lo05_04_file OPTIONAL,
      convert_abap_timestamp_odata
        IMPORTING
          iv_date             TYPE sydate
          iv_time             TYPE syuzeit
          iv_msec             TYPE mt_num03 DEFAULT 000
        RETURNING
          VALUE(rv_timestamp) TYPE string ,
      currency_conv_to_external
        IMPORTING
          currency        TYPE  i_currency-currency
          amount_internal TYPE  any
        EXPORTING
          amount_external TYPE bapicurr-bapicurr.
ENDCLASS.



CLASS ZCL_LO05_04_INVUPL_JOB IMPLEMENTATION.


  METHOD if_apj_rt_run~execute.
    DATA:
      ls_param_file TYPE zi_lo05_04_file.

    LOOP AT uuid INTO DATA(ls_uuid).
      ls_param_file-uuid = ls_uuid-low.
      EXIT.
    ENDLOOP.

    " trigger process with parameter
    CALL METHOD upload_invoice( ls_param_file ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
*      data: g_exchange_rates TYPE cl_exchange_rates=>ty_exchange_rates.
*       data: g_result TYPE cl_exchange_rates=>ty_messages.
*   g_result = cl_exchange_rates=>put( EXPORTING exchange_rates = g_exchange_rates ).
*
*    EXIT.
    DATA: ls_param_file TYPE zi_lo05_04_file.
    CALL METHOD upload_invoice( ls_param_file ).
  ENDMETHOD.


  METHOD convert_abap_timestamp_odata.
    rv_timestamp = iv_date(4) && '-' && iv_date+4(2) && '-' && iv_date+6(2) && 'T00:00'.
  ENDMETHOD.


  METHOD currency_conv_to_external.
    DATA: int_shift      TYPE i,
          dec_amount_int TYPE bapicurr-bapicurr.

    SELECT SINGLE decimals
         FROM  i_currency
         WHERE currency = @currency
         INTO @DATA(lv_currdec).

    IF sy-subrc = 0. "Currency has a number of decimals not equal two
      int_shift = 2 - lv_currdec.
    ELSE. "Currency is no exceptional currency. It has two decimals
      int_shift = 0.
    ENDIF.

*   Fill AMOUNT_EXTERNAL and shift decimal point depending on CURRENCY
    dec_amount_int = amount_internal.
    amount_external = 10 ** int_shift.
    amount_external = amount_external * dec_amount_int.
  ENDMETHOD.


  METHOD upload_invoice.
    TYPES: BEGIN OF lty_msg_value,
             lang  TYPE string,
             value TYPE string,
           END OF lty_msg_value.

    TYPES: BEGIN OF lty_errdetail,
             contentid    TYPE string,
             code         TYPE string,
             message      TYPE string,
             longtext_url TYPE string,
             propertyref  TYPE string,
             severity     TYPE string,    " 'error' | 'warning' | 'info'
             transition   TYPE abap_bool,
             target       TYPE string,
           END OF lty_errdetail.
    TYPES ltt_errdetail TYPE STANDARD TABLE OF lty_errdetail WITH EMPTY KEY.

    TYPES: BEGIN OF ty_application,
             component_id      TYPE string,
             service_namespace TYPE string,
             service_id        TYPE string,
             service_version   TYPE string,
           END OF ty_application.

    TYPES: BEGIN OF ty_error_resolution,
             sap_transaction TYPE string, " maps "SAP_Transaction"
             sap_note        TYPE string, " maps "SAP_Note"
           END OF ty_error_resolution.

    TYPES: BEGIN OF lty_innererror,
             application      TYPE ty_application,
             transactionid    TYPE string,
             timestamp        TYPE string,
             error_resolution TYPE ty_error_resolution,
             errordetails     TYPE ltt_errdetail,
           END OF lty_innererror.

    TYPES: BEGIN OF ty_error,
             code       TYPE string,
             message    TYPE lty_msg_value,  " .value chứa nội dung msg tổng
             innererror TYPE lty_innererror,
           END OF ty_error.

    TYPES: BEGIN OF ty_odata_error,
             error TYPE ty_error,
           END OF ty_odata_error.

    TYPES: BEGIN OF ty_odata_data,
             supplierinvoice TYPE string,
             fiscalyear      TYPE string,
           END OF ty_odata_data.

    TYPES: BEGIN OF ty_odata_success,
             d TYPE ty_odata_data,
           END OF ty_odata_success.

    TYPES: BEGIN OF ty_odata_post,
             success TYPE string,
           END OF ty_odata_post.

    TYPES: BEGIN OF ty_odata_data_post,
             post TYPE ty_odata_post,
           END OF ty_odata_data_post.

    TYPES: BEGIN OF ty_odata_success_post,
             d TYPE ty_odata_data_post,
           END OF ty_odata_success_post.

    DATA: ls_root            TYPE ty_odata_error,
          ls_success         TYPE ty_odata_success,
          ls_success_post    TYPE ty_odata_success_post,
          lt_item            TYPE TABLE FOR CREATE zi_lo05_04_file\_item,
          ls_invoice         TYPE STRUCTURE FOR ACTION IMPORT i_supplierinvoicetp~create,
          lt_invoice         TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create,
          lv_error           TYPE zi_lo05_04_xlsx-error,
          lt_item_processed  TYPE TABLE OF zi_lo05_04_xlsx,
          lr_cscn            TYPE if_com_scenario_factory=>ty_query-cscn_id_range,
          lv_json            TYPE string,
          lv_uri_path        TYPE string,
          lv_poitem          TYPE int4,
          lv_amount_external TYPE bapicurr-bapicurr,
          lv_mess            TYPE string.

    " Step 1: Get staging table
    SELECT item~*
        FROM zi_lo05_04_file AS header
            INNER JOIN zi_lo05_04_xlsx AS item
                    ON header~uuid = item~uuid
        WHERE header~status IN ( @zcl_bp_i_lo05_04_file=>c_status_processing,
                                 @zcl_bp_i_lo05_04_file=>c_status_processing_post )
          AND header~uuid IN @uuid
        INTO TABLE @DATA(lt_item_stage).
    IF sy-subrc <> 0.
      " Do not process
      RETURN.
    ELSE.
      SORT lt_item_stage BY uuid supplierinvoiceidbyinvcgparty.
    ENDIF.

    SELECT header~*
        FROM zi_lo05_04_file AS header
        WHERE header~status IN ( @zcl_bp_i_lo05_04_file=>c_status_processing,
                                 @zcl_bp_i_lo05_04_file=>c_status_processing_post )
          AND header~uuid IN @uuid
        INTO TABLE @DATA(lt_header).
    IF sy-subrc <> 0.
      " Do not process
      RETURN.
    ENDIF.

    SELECT ekpo~purchaseorder,
           ekpo~purchaseorderitem,
           ekpo~netamount,
           ekpo~orderquantity,
           ekpo~purchaseorderquantityunit,
           ekpo~orderpriceunit,
           ekko~supplier
        FROM i_purchaseorderapi01 AS ekko
            INNER JOIN i_purchaseorderitemapi01 AS ekpo
                    ON ekko~purchaseorder = ekpo~purchaseorder
            INNER JOIN @lt_item_stage AS _item
                    ON ekpo~purchaseorder = _item~purchaseorder
                   AND ekpo~purchaseorderitem = _item~purchaseorderitem
        INTO TABLE @DATA(lt_purchaseorders).

    "Because orderunit is converted auto to internal value
    "API needs commercial value -> need to convert again to another field
    SELECT  t006a~unitofmeasure,
            t006a~unitofmeasurecommercialname,
            t006~unitofmeasureisocode
        FROM i_unitofmeasuretext AS t006a
            INNER JOIN @lt_purchaseorders AS purchaseorders
                    ON purchaseorders~purchaseorderquantityunit = t006a~unitofmeasure
                    OR purchaseorders~orderpriceunit = t006a~unitofmeasure
            INNER JOIN i_unitofmeasure AS t006
                    ON t006a~unitofmeasure = t006~unitofmeasure
        WHERE t006a~language = 'E'
        INTO TABLE @DATA(lt_unit).
    IF sy-subrc = 0.
      SORT lt_unit BY unitofmeasure.
    ENDIF.

    SELECT SINGLE personfullname
        FROM i_businessuserbasic
        WHERE userid = @sy-uname
        INTO @DATA(lv_personfullname).

    LOOP AT lt_item_stage ASSIGNING FIELD-SYMBOL(<ls_item_stage>)
        GROUP BY ( uuid                          = <ls_item_stage>-uuid
                   supplierinvoiceidbyinvcgparty = <ls_item_stage>-supplierinvoiceidbyinvcgparty
                   documentdate                  = <ls_item_stage>-documentdate
                   invoicingparty                = <ls_item_stage>-invoicingparty  )
             ASSIGNING FIELD-SYMBOL(<ls_group>) .
      CLEAR: lt_invoice, lt_item_processed, " Each File/SupplierInvoiceIDByInvcgParty + documentdate + invoicingparty
             lv_mess, ls_root, ls_success, lv_mess, lv_error, lv_amount_external, lv_json, lv_poitem.

      LOOP AT GROUP <ls_group> INTO DATA(ls_group_mem).
        IF ls_group_mem-purchaseorder IS NOT INITIAL.
          DATA(lv_withpo) = abap_true.
        ENDIF.

        IF ls_group_mem-glaccount IS NOT INITIAL AND
           VALUE #( lt_header[ uuid = ls_group_mem-uuid ]-scenario OPTIONAL ) = zcl_bp_i_lo05_04_file=>c_scenario_vat.
          DATA(lv_withvat) = abap_true.
        ENDIF.

        APPEND ls_group_mem TO lt_item_processed.
      ENDLOOP.

      """"GET METHOD-START""""
      TRY.
          " Find CA by scenario
          lr_cscn = VALUE #( ( sign = 'I' option = 'EQ' low = 'SAP_COM_0057' ) ).
          DATA(lo_factory) = cl_com_arrangement_factory=>create_instance( ).
          lo_factory->query_ca(
            EXPORTING
              is_query           = VALUE #( cscn_id_range = lr_cscn )
            IMPORTING
              et_com_arrangement = DATA(lt_ca) ).

          IF lt_ca IS INITIAL.
            lv_mess = 'Could not find Communication Arrangement SAP_COM_0057'.
            LOOP AT lt_item_processed ASSIGNING FIELD-SYMBOL(<ls_item_processed>).
              <ls_item_processed>-error = abap_true.
              IF <ls_item_processed>-errormessage IS INITIAL.
                <ls_item_processed>-errormessage = lv_mess.
              ELSE.
                <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                   lv_mess.
              ENDIF.
            ENDLOOP.
            CONTINUE.
          ENDIF.

          "Take the first one
          DATA(lo_ca) = VALUE #( lt_ca[ 1 ] OPTIONAL ).

          DATA(lt_inb_services) = lo_ca->get_inbound_services( ).
          DATA(ls_inb_service) = VALUE #( lt_inb_services[ 2 ] OPTIONAL ).
          DATA(lv_url) = VALUE #( ls_inb_service-urls[ 1 ] OPTIONAL ).
          DATA(lo_http_destination) = cl_http_destination_provider=>create_by_url( lv_url ).

          "Create HTTP client by destination
          TRY.
              DATA(lo_web_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ).
            CATCH cx_web_http_client_error.
              lv_mess = 'Could not create HTTP client by destination'.
              LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                <ls_item_processed>-error = abap_true.
                IF <ls_item_processed>-errormessage IS INITIAL.
                  <ls_item_processed>-errormessage = lv_mess.
                ELSE.
                  <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                     lv_mess.
                ENDIF.
              ENDLOOP.
              CONTINUE.
          ENDTRY.
*
          DATA(lo_web_http_request) = lo_web_http_client->get_http_request( ).

          lo_web_http_request->set_header_fields( VALUE #(
            ( name = 'x-csrf-token'       value = 'Fetch' )
            ( name = 'DataServiceVersion' value = '2.0' ) ) ).

          lo_web_http_request->set_authorization_basic(
            EXPORTING
              i_username = 'PIR_USER'
              i_password = 'h+@RZdKh~(Exl3>r$9~<W7T>Kmm994kQ6}qe/]B$' ).

*        "set request method and execute request
          TRY.
              DATA(lo_web_http_response) = lo_web_http_client->execute( if_web_http_client=>get ).
            CATCH cx_web_http_client_error.
              lv_mess = 'Could not execute GET Token request'.
              LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                <ls_item_processed>-error = abap_true.
                IF <ls_item_processed>-errormessage IS INITIAL.
                  <ls_item_processed>-errormessage = lv_mess.
                ELSE.
                  <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                     lv_mess.
                ENDIF.
              ENDLOOP.
              CONTINUE.
          ENDTRY.

          DATA(lv_token) = lo_web_http_response->get_header_field( 'x-csrf-token' ).
          DATA(lv_response) = lo_web_http_response->get_text( ).

        CATCH cx_http_dest_provider_error.
          lv_mess = 'Could not execute GET Token request'.
          LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
            <ls_item_processed>-error = abap_true.
            IF <ls_item_processed>-errormessage IS INITIAL.
              <ls_item_processed>-errormessage = lv_mess.
            ELSE.
              <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                 lv_mess.
            ENDIF.
          ENDLOOP.
          CONTINUE.
      ENDTRY.
      """"GET METHOD-END""""

      """""POST METHOD-START"""""
      TRY.
          lo_web_http_request = lo_web_http_client->get_http_request( ).

          "======= HEADER=======
          lo_web_http_request->set_header_field( i_name = 'x-csrf-token' i_value = lv_token ).
          lo_web_http_request->set_header_field( i_name = 'content-type' i_value = 'application/json; charset=utf-8' ).
          lo_web_http_request->set_header_field( i_name = 'accept' i_value = 'application/json' ).
          lo_web_http_request->set_header_field( i_name = 'dataserviceversion' i_value = '2.0' ).
          lo_web_http_request->set_header_field( i_name = 'x-requested-with' i_value = 'XMLHttpRequest' ).

          lo_web_http_request->set_authorization_basic(
            i_username = 'PIR_USER'
            i_password = 'h+@RZdKh~(Exl3>r$9~<W7T>Kmm994kQ6}qe/]B$' ).

          "======= BODY JSON =======
          IF ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd OR "Ready for Parked
           ( ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd AND "Create
             ls_group_mem-supplierinvoice IS INITIAL ).

            ""--------CREATE/PARK CASE-START--------
            lo_web_http_request->set_uri_path( i_uri_path = '/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/A_SupplierInvoice' ).

            SORT lt_item_processed BY supplierinvoiceitem.

            DATA(lv_documentdate) = convert_abap_timestamp_odata(
              EXPORTING
                iv_date = ls_group_mem-documentdate
                iv_time = '000000' ).

            DATA(lv_postingdate) = convert_abap_timestamp_odata(
              EXPORTING
                iv_date = ls_group_mem-postingdate
                iv_time = '000000' ).

            DATA(lv_duecalculationbasedate) = convert_abap_timestamp_odata(
              EXPORTING
                iv_date = ls_group_mem-duecalculationbasedate
                iv_time = '000000' ).

            CLEAR lv_amount_external.
            currency_conv_to_external(
              EXPORTING
                amount_internal = ls_group_mem-invoicegrossamount
                currency        = ls_group_mem-documentcurrency
              IMPORTING
                amount_external = lv_amount_external ).
            ls_group_mem-invoicegrossamount = lv_amount_external.

            CLEAR lv_amount_external.
            currency_conv_to_external(
              EXPORTING
                amount_internal = ls_group_mem-unplanneddeliverycost
                currency        = ls_group_mem-documentcurrency
              IMPORTING
                amount_external = lv_amount_external ).
            ls_group_mem-unplanneddeliverycost = lv_amount_external.

            "Open payload
            lv_json =
              '{' &&
                '"d" : {' &&
                    '"CompanyCode" : "'                   && ls_group_mem-companycode && '",' &&
                    '"DocumentDate" : "'                  && lv_documentdate && '",' &&
                    '"PostingDate" : "'                   && lv_postingdate && '",' &&
                    '"SupplierInvoiceIDByInvcgParty" : "' && ls_group_mem-supplierinvoiceidbyinvcgparty && '",' &&
                    '"InvoicingParty" : "'                && ls_group_mem-invoicingparty && '",' &&
                    '"DocumentCurrency" : "'              && ls_group_mem-documentcurrency && '",' &&
                    '"InvoiceGrossAmount" : "'            && ls_group_mem-invoicegrossamount && '",' &&
                    '"UnplannedDeliveryCost" : "'         && ls_group_mem-unplanneddeliverycost && '",' &&
                    '"DocumentHeaderText": "'             && ls_group_mem-documentheadertext && '",' &&
                    '"AssignmentReference": "'            && ls_group_mem-assignmentreference && '",'.


              lv_json = lv_json &&
                    '"YY1_CreatedByHeader_MIH" : "'   && |{ sy-uname } - { lv_personfullname }| && '",'.

            IF ls_group_mem-duecalculationbasedate IS NOT INITIAL.
              lv_json = lv_json &&
                    '"DueCalculationBaseDate" : "'        && lv_duecalculationbasedate && '",'.
            ENDIF.

            IF ls_group_mem-SupplierPostingLineItemText IS NOT INITIAL.
              lv_json = lv_json &&
                    '"SupplierPostingLineItemText" : "'   && ls_group_mem-SupplierPostingLineItemText && '",'.
            ENDIF.

            IF ls_group_mem-reconciliationaccount IS NOT INITIAL.
              lv_json = lv_json &&
                    '"ReconciliationAccount" : "'         && ls_group_mem-reconciliationaccount && '",'.
            ENDIF.

            IF ls_group_mem-directquotedexchangerate IS NOT INITIAL.
              lv_json = lv_json &&
                    '"DirectQuotedExchangeRate" : "'         && ls_group_mem-DirectQuotedExchangeRate && '",'.
            ENDIF.

            IF ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd.
              lv_json = lv_json &&
                    '"SupplierInvoiceStatus" : "A",'.
            ENDIF.

            lv_json = lv_json &&
                    '"TaxDeterminationDate": "'           && lv_postingdate && '",' &&
                    '"PaymentTerms": "'                   && ls_group_mem-paymentterms && '",' &&
                    '"AccountingDocumentType" : "'        && ls_group_mem-accountingdocumenttype && '",' &&
                    '"SupplierInvoiceIsCreditMemo" : "'   && COND #( WHEN ls_group_mem-debitcreditcode = 'H' THEN 'X' ELSE '' ) && '",' &&
                    '"TaxIsCalculatedAutomatically" : true'.

            "Refer to Purchase Order
            IF lv_withpo = abap_true.
              lv_json = lv_json && ',"to_SuplrInvcItemPurOrdRef" : { "results" : ['.

              CLEAR lv_poitem.
              LOOP AT lt_item_processed  INTO ls_group_mem.
                lv_poitem += 1.
                IF lv_poitem > 1.
                  lv_json = lv_json && ','.
                ENDIF.

                CLEAR lv_amount_external.
                currency_conv_to_external(
                  EXPORTING
                    amount_internal = ls_group_mem-supplierinvoiceitemamount
                    currency        = ls_group_mem-documentcurrency
                  IMPORTING
                    amount_external = lv_amount_external ).
                ls_group_mem-supplierinvoiceitemamount = lv_amount_external.

                CLEAR lv_amount_external.
                currency_conv_to_external(
                  EXPORTING
                    amount_internal = ls_group_mem-supplierinvoiceitemamountgl
                    currency        = ls_group_mem-documentcurrency
                  IMPORTING
                    amount_external = lv_amount_external ).
                ls_group_mem-supplierinvoiceitemamountgl = lv_amount_external.

                DATA(ls_purchaseorder) = VALUE #( lt_purchaseorders[
                                                  purchaseorder = ls_group_mem-purchaseorder
                                                  purchaseorderitem = ls_group_mem-purchaseorderitem ] OPTIONAL ).

                lv_json = lv_json && '{'.
                lv_json = lv_json &&
                   '"SupplierInvoiceItem" : "'       && ls_group_mem-supplierinvoiceitem && '",' &&
                   '"PurchaseOrder" : "'             && ls_group_mem-purchaseorder && '",' &&
                   '"PurchaseOrderItem" : "'         && ls_group_mem-purchaseorderitem && '",' &&
                   '"DocumentCurrency" : "'          && ls_group_mem-documentcurrency && '",' &&
                   '"SupplierInvoiceItemAmount" : "' && ls_group_mem-supplierinvoiceitemamount && '",' &&
                   '"PurchaseOrderQuantityUnit": "'  && VALUE #( lt_unit[ unitofmeasure =
                                                                 ls_purchaseorder-purchaseorderquantityunit ]-unitofmeasurecommercialname OPTIONAL ) && '",' &&
                   '"PurchaseOrderQtyUnitISOCode": "'  && VALUE #( lt_unit[ unitofmeasure =
                                                                   ls_purchaseorder-purchaseorderquantityunit ]-unitofmeasureisocode OPTIONAL ) && '",' &&
                   '"PurchaseOrderPriceUnitISOCode": "'  && VALUE #( lt_unit[ unitofmeasure =
                                                                     ls_purchaseorder-orderpriceunit ]-unitofmeasureisocode OPTIONAL ) && '",' &&
                   '"QuantityInPurchaseOrderUnit":"' && ls_group_mem-quantityinpurchaseorderunit && '",' &&
                   '"TaxCode" : "'                   && ls_group_mem-taxcode && '",' &&
*                   '"SupplierInvoiceItemText" : "'   && |{ sy-uname } - { lv_personfullname }| && '",' &&
                   '"SupplierInvoiceItemText" : "'   && ls_group_mem-SupplierPostingLineItemText && '",' &&
                   '"IsSubsequentDebitCredit": "'    && ls_group_mem-issubsequentdebitcredit && '"'.

                SELECT SINGLE invoiceisgoodsreceiptbased
                     FROM i_purchaseorderitemapi01
                     WHERE purchaseorder              = @ls_group_mem-purchaseorder
                       AND purchaseorderitem          = @ls_group_mem-purchaseorderitem
                       AND invoiceisgoodsreceiptbased = @abap_true
                     INTO @DATA(lv_invoiceisgoodsreceiptbased).
                IF sy-subrc = 0.
                  SELECT SINGLE
                        referencedocumentfiscalyear,
                        referencedocument,
                        referencedocumentitem
                      FROM i_purchaseorderhistoryapi01
                      WHERE purchaseorder                 = @ls_group_mem-purchaseorder
                        AND purchaseorderitem             = @ls_group_mem-purchaseorderitem
                        AND purchasinghistorydocumenttype = '1' "GR
                      INTO @DATA(ls_purchaseorderhistory).
                  IF sy-subrc = 0.
                    lv_json = lv_json && ',' &&
                        '"ReferenceDocument" : "'          && ls_purchaseorderhistory-referencedocument && '",' &&
                        '"ReferenceDocumentItem" : "'      && ls_purchaseorderhistory-referencedocumentitem && '",' &&
                        '"ReferenceDocumentFiscalYear": "' && ls_purchaseorderhistory-referencedocumentfiscalyear && '"'.
                  ENDIF.
                ENDIF.

                IF VALUE #( lt_header[ uuid = ls_group_mem-uuid ]-scenario OPTIONAL ) = zcl_bp_i_lo05_04_file=>c_scenario_invservice.
                  lv_json = lv_json &&
                    ',"to_SupplierInvoiceItmAcctAssgmt" : { "results" : [ {' &&
                        '"SupplierInvoiceItem" : "'           && ls_group_mem-supplierinvoiceitem && '",' &&
                         '"AccountAssignmentNumber":"01",' &&
                         '"GLAccount" : "'                     && ls_group_mem-glaccount && '",' &&
                         '"FunctionalArea" : "'                && ls_group_mem-functionalarea && '",' &&
                         '"FixedAsset" : "'                    && ls_group_mem-fixedasset && '",' &&
                         '"WBSElement" : "'                    && ls_group_mem-wbselement && '",' &&
                         '"CostCenter" : "'                    && ls_group_mem-costcenter && '",' &&
                         '"TaxCode": "'                        && ls_group_mem-taxcode && '",' &&
                         '"DocumentCurrency":"'                && ls_group_mem-documentcurrency && '",' &&
                         '"SuplrInvcAcctAssignmentAmount" : "' && ls_group_mem-supplierinvoiceitemamount && '",' &&
                         '"PurchaseOrderQuantityUnit" : "'     && VALUE #( lt_unit[ unitofmeasure =
                                                                           ls_purchaseorder-purchaseorderquantityunit ]-unitofmeasurecommercialname OPTIONAL ) && '",' &&
                         '"PurchaseOrderQtyUnitISOCode": "'    && VALUE #( lt_unit[ unitofmeasure =
                                                                           ls_purchaseorder-purchaseorderquantityunit ]-unitofmeasureisocode OPTIONAL ) && '",' &&
                         '"PurchaseOrderPriceUnitISOCode": "'  && VALUE #( lt_unit[ unitofmeasure =
                                                                           ls_purchaseorder-orderpriceunit ]-unitofmeasureisocode OPTIONAL ) && '",' &&
                         '"Quantity": "'                       && ls_group_mem-quantityinpurchaseorderunit && '" } ] }'.
                ENDIF.

                lv_json = lv_json && '}'.
              ENDLOOP.

              lv_json = lv_json && '] }'.
            ENDIF.

            "VAT upload
            IF lv_withvat = abap_true.
              lv_json = lv_json && ',"to_SupplierInvoiceItemGLAcct" : ['.

              CLEAR lv_poitem.
              LOOP AT lt_item_processed INTO ls_group_mem WHERE glaccount IS NOT INITIAL.
                lv_poitem += 1.
                IF lv_poitem > 1.
                  lv_json = lv_json && ','.
                ENDIF.

                CLEAR lv_amount_external.
                currency_conv_to_external(
                  EXPORTING
                    amount_internal = ls_group_mem-supplierinvoiceitemamountgl
                    currency        = ls_group_mem-documentcurrency
                  IMPORTING
                    amount_external = lv_amount_external ).
                ls_group_mem-supplierinvoiceitemamountgl = lv_amount_external.

                CLEAR lv_amount_external.
                currency_conv_to_external(
                  EXPORTING
                    amount_internal = ls_group_mem-taxbaseamountintranscrcy
                    currency        = ls_group_mem-documentcurrency
                  IMPORTING
                    amount_external = lv_amount_external ).
                ls_group_mem-taxbaseamountintranscrcy = lv_amount_external.

                lv_json = lv_json && '{'.
                lv_json = lv_json &&
                   '"SupplierInvoiceItem" : "'       && CONV numc4( ls_group_mem-supplierinvoiceitem ) && '",' &&
                   '"DocumentCurrency" : "'          && ls_group_mem-documentcurrency && '",' &&
                   '"SupplierInvoiceItemAmount" : "' && ls_group_mem-supplierinvoiceitemamountgl && '",' &&
                   '"TaxBaseAmountInTransCrcy" : "'  && ls_group_mem-taxbaseamountintranscrcy && '",' &&
                   '"DebitCreditCode" : "'           && ls_group_mem-debitcreditcodegl && '",' &&
                   '"TaxCode" : "'                   && ls_group_mem-taxcodegl && '",' &&
                   '"GLAccount" : "'                 && ls_group_mem-glaccount && '",' &&
                   '"CostCenter" : "'                && ls_group_mem-costcenter && '",' &&
                   '"ProfitCenter" : "'              && ls_group_mem-profitcenter && '"}'.
              ENDLOOP.

              lv_json = lv_json && ']'.
            ENDIF.

            "Close payload
            lv_json = lv_json && '} }'.

            lo_web_http_request->set_text( lv_json ).
            "======= EXECUTE =======
            DATA(lo_web_http_response_post) = lo_web_http_client->execute( if_web_http_client=>post ).
            DATA(ls_status) = lo_web_http_response_post->get_status( ).
            DATA(lv_body)   = lo_web_http_response_post->get_text( ).

            ""Get error message
            /ui2/cl_json=>deserialize(
              EXPORTING
                json = lv_body
              CHANGING
                data = ls_root ).

            ""Get successful message
            /ui2/cl_json=>deserialize(
              EXPORTING
                json = lv_body
              CHANGING
                data = ls_success ).

            """""SAVING LOG-START"""""
            IF ls_success-d-supplierinvoice IS NOT INITIAL.
              LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                <ls_item_processed>-supplierinvoice = ls_success-d-supplierinvoice.
                <ls_item_processed>-supplierinvoicefiscalyear = ls_success-d-fiscalyear.
                <ls_item_processed>-linestatuscriticality = '3'.
                IF <ls_item_processed>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd.
                  <ls_item_processed>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parked.
                ELSEIF <ls_item_processed>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd.
                  <ls_item_processed>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_posted.
                ENDIF.
              ENDLOOP.
            ELSE.
              IF ls_root-error-innererror-errordetails IS NOT INITIAL.
                LOOP AT ls_root-error-innererror-errordetails ASSIGNING FIELD-SYMBOL(<ls_message>).
                  IF <ls_message>-severity = 'error'.
                    lv_mess = |{ <ls_message>-code } - { <ls_message>-message }|.

                    IF lv_mess CS 'Service provider did not return any business data'.
                      ""No need to display on screen
                    ELSE.
                      LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                        IF <ls_message>-code = 'M8/375' AND
                         <ls_message>-message CS `Fill in mandatory field 'ReferenceDocument`.
                          lv_mess = |{ <ls_message>-code } - No Goods Receipt has been posted for Purchase Order { <ls_item_processed>-purchaseorder }|.
                        ENDIF.

                        IF <ls_message>-code = 'M8/607' AND
                           line_exists( ls_root-error-innererror-errordetails[ code = 'M8/375' ] ).
                          CONTINUE.
                        ENDIF.

                        <ls_item_processed>-error = abap_true.
                        IF <ls_item_processed>-errormessage IS INITIAL.
                          <ls_item_processed>-errormessage = lv_mess.
                        ELSE.
                          <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                             lv_mess.
                        ENDIF.
                      ENDLOOP.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
              ELSE.
                lv_mess = ls_root-error-message-value.
                LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                  <ls_item_processed>-error = abap_true.
                  IF <ls_item_processed>-errormessage IS INITIAL.
                    <ls_item_processed>-errormessage = lv_mess.
                  ELSE.
                    <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                       lv_mess.
                  ENDIF.
                ENDLOOP.
              ENDIF.
            ENDIF.
            """""SAVING LOG-END"""""
            ""--------CREATE/PARK CASE-END--------

          ELSEIF ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd
             AND ls_group_mem-supplierinvoice IS NOT INITIAL. "Post from parked invoices

            ""--------POST CASE-START--------
            lv_uri_path = `/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/Post?SupplierInvoice='`
                       && ls_group_mem-supplierinvoice && `'&FiscalYear='` && ls_group_mem-supplierinvoicefiscalyear && `'` .
            lo_web_http_request->set_uri_path( i_uri_path = lv_uri_path ).
            ""--------POST CASE-END--------

            "======= EXECUTE =======
            lo_web_http_response_post = lo_web_http_client->execute( if_web_http_client=>post ).
            ls_status = lo_web_http_response_post->get_status( ).
            lv_body   = lo_web_http_response_post->get_text( ).

            ""Get error message
            /ui2/cl_json=>deserialize(
              EXPORTING
                json = lv_body
              CHANGING
                data = ls_root ).

            ""Get successful message
            /ui2/cl_json=>deserialize(
              EXPORTING
                json = lv_body
              CHANGING
                data = ls_success_post ).

            """""SAVING LOG-START"""""
            IF ls_success_post-d-post-success IS NOT INITIAL.
              LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                <ls_item_processed>-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_posted.
                <ls_item_processed>-linestatuscriticality = '3'.
              ENDLOOP.
            ELSE.
              IF ls_root-error-innererror-errordetails IS NOT INITIAL.
                LOOP AT ls_root-error-innererror-errordetails ASSIGNING <ls_message>.
                  IF <ls_message>-severity = 'error'.
                    lv_mess = |{ <ls_message>-code } - { <ls_message>-message }|.

                    IF lv_mess CS 'Service provider did not return any business data'.
                      ""No need to display on screen
                    ELSE.
                      LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                        <ls_item_processed>-error = abap_true.
                        IF <ls_item_processed>-errormessage IS INITIAL.
                          <ls_item_processed>-errormessage = lv_mess.
                        ELSE.
                          <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                             lv_mess.
                        ENDIF.
                      ENDLOOP.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
              ELSE.
                lv_mess = ls_root-error-message-value.
                LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
                  <ls_item_processed>-error = abap_true.
                  IF <ls_item_processed>-errormessage IS INITIAL.
                    <ls_item_processed>-errormessage = lv_mess.
                  ELSE.
                    <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                       lv_mess.
                  ENDIF.
                ENDLOOP.
              ENDIF.
            ENDIF.
            """""SAVING LOG-END"""""
          ELSE.
            CLEAR: ls_purchaseorder,
                   ls_root,
                   ls_success,
                   ls_status,
                   lv_mess,
                   lv_body,
                   lv_error,
                   lv_amount_external,
                   lv_invoiceisgoodsreceiptbased,
                   lv_documentdate,
                   lv_postingdate,
                   lv_duecalculationbasedate,
                   lv_json,
                   lv_token,
                   lv_poitem,
                   lv_response,
                   lv_url,
                   lv_withpo,
                   lv_withvat.
            CONTINUE.
          ENDIF.

          lo_web_http_client->close(  ).
        CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
          lv_mess = 'Could not execute POST request'.
          LOOP AT lt_item_processed ASSIGNING <ls_item_processed>.
            <ls_item_processed>-error = abap_true.
            IF <ls_item_processed>-errormessage IS INITIAL.
              <ls_item_processed>-errormessage = lv_mess.
            ELSE.
              <ls_item_processed>-errormessage = <ls_item_processed>-errormessage && |; | &&
                                                 lv_mess.
            ENDIF.
          ENDLOOP.
          CONTINUE.
      ENDTRY.
      """""POST METHOD-END"""""
*
      TRY.
          " update error message to item
          MODIFY ENTITIES OF zi_lo05_04_file
            ENTITY header
              UPDATE FIELDS ( status )
              WITH VALUE #( ( %key-uuid       = ls_group_mem-uuid
                              %data           = VALUE #(
                                uuid   = ls_group_mem-uuid
                                status = COND #( WHEN ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_parkrd
                                                 THEN zcl_bp_i_lo05_04_file=>c_status_parked
                                                 WHEN ls_group_mem-linestatus = zcl_bp_i_lo05_04_file=>c_lstatus_postrd
                                                 THEN zcl_bp_i_lo05_04_file=>c_status_processed ) )
                              %control-status = if_abap_behv=>mk-on ) )
              ENTITY item
              UPDATE FIELDS ( error
                              errormessage
                              supplierinvoice
                              supplierinvoicefiscalyear
                              linestatus
                              linestatuscriticality )
              WITH VALUE #( FOR ls_item_processedf IN lt_item_processed
                            ( %key-uuid       = ls_item_processedf-uuid
                              %key-lineid     = ls_item_processedf-lineid
                              %key-linenumber = ls_item_processedf-linenumber
                              %data           = VALUE #(
                                 uuid                      = ls_item_processedf-uuid
                                 lineid                    = ls_item_processedf-lineid
                                 linenumber                = ls_item_processedf-linenumber
                                 supplierinvoice           = ls_item_processedf-supplierinvoice
                                 supplierinvoicefiscalyear = ls_item_processedf-supplierinvoicefiscalyear
                                 error                     = ls_item_processedf-error
                                 errormessage              = ls_item_processedf-errormessage
                                 linestatus                = COND #( WHEN ls_item_processedf-error = abap_true
                                                                     THEN zcl_bp_i_lo05_04_file=>c_lstatus_failed
                                                                     ELSE ls_item_processedf-linestatus )
                                 linestatuscriticality     = COND #( WHEN ls_item_processedf-error = abap_true
                                                                     THEN '1'
                                                                     ELSE ls_item_processedf-linestatuscriticality ) )
                              %control-supplierinvoice           = if_abap_behv=>mk-on
                              %control-supplierinvoicefiscalyear = if_abap_behv=>mk-on
                              %control-linestatus                = if_abap_behv=>mk-on
                              %control-linestatuscriticality     = if_abap_behv=>mk-on
                              %control-error                     = if_abap_behv=>mk-on
                              %control-errormessage              = if_abap_behv=>mk-on ) )
              MAPPED DATA(ls_mapped_item)
              REPORTED DATA(ls_reported_item)
              FAILED DATA(ls_failed_item).

          COMMIT ENTITIES
           RESPONSE OF zi_lo05_04_file
             FAILED DATA(lt_failed_invoice_commit)
             REPORTED DATA(lt_reported_invoice_commit)
           RESPONSE OF i_supplierinvoicetp
             FAILED DATA(lt_failed_commit2)
             REPORTED DATA(lt_reported_commit2).
        CATCH cx_abap_context_info_error INTO DATA(lx_rap_error) ##NO_HANDLER.
        CATCH cx_static_check  INTO DATA(lx_static_error) ##NO_HANDLER.
      ENDTRY.

      CLEAR: ls_purchaseorder,
             ls_root,
             ls_success,
             ls_status,
             lv_mess,
             lv_body,
             lv_error,
             lv_amount_external,
             lv_invoiceisgoodsreceiptbased,
             lv_documentdate,
             lv_postingdate,
             lv_duecalculationbasedate,
             lv_json,
             lv_token,
             lv_poitem,
             lv_response,
             lv_url,
             lv_withpo,
             lv_withvat.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
