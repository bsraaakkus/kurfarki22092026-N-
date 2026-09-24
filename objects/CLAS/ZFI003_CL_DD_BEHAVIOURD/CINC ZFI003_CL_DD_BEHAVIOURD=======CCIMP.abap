*//24.09.2026

CLASS lhc_zfi003_dd_behaviour DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zfi003_dd_behaviourd RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ zfi003_dd_behaviourd RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK zfi003_dd_behaviourd.

    METHODS kur_farki FOR MODIFY
      IMPORTING keys FOR ACTION zfi003_dd_behaviourd~kur_farki.
"test
ENDCLASS.

CLASS lhc_zfi003_dd_behaviour IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD kur_farki.
    DATA lv_index_item TYPE int4.

    IF keys IS INITIAL.
      APPEND VALUE #( dummy = 1 ) TO failed-behaviour.

      DATA(lv_msg) = new_message_with_text( text = 'Veri olmadan işlem yapılamaz.' severity = cl_abap_behv=>ms-error ).

      APPEND VALUE #( %msg  = lv_msg
                      dummy = 1 ) TO reported-behaviour.
      EXIT.
    ENDIF.

    DATA(ls_data) = VALUE #( keys[ dummy = 1 ] OPTIONAL ).

    DATA: lt_je_deep TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          lv_cid     TYPE abp_behv_cid.
    TRY.
        lv_cid = to_upper( cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ) ).
      CATCH cx_uuid_error.
        ASSERT 1 = 0.
    ENDTRY.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    SELECT tax~* FROM zfi003_t_taxcd AS tax
    INNER JOIN @ls_data-%param-_itemtable AS itable ON tax~tax_code = itable~tax_code
    INTO TABLE @DATA(lt_taxcode).
    IF sy-subrc NE 0.
      APPEND VALUE #( dummy = 1 ) TO failed-behaviour.

      lv_msg = new_message_with_text( text = 'Vergi bakım tablosunu doldurunuz.' severity = cl_abap_behv=>ms-error ).

      APPEND VALUE #( %msg  = lv_msg
                      dummy = 1 ) TO reported-behaviour.
      EXIT.
    ENDIF.
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

    IF ls_data-%param-customer IS NOT INITIAL AND ls_data-%param-supplier IS NOT INITIAL.
      APPEND VALUE #( dummy = 1 ) TO failed-behaviour.

      lv_msg = new_message_with_text( text = 'Müşteri ve Satıcı aynı anda doldurulamaz.' severity = cl_abap_behv=>ms-error ).

      APPEND VALUE #( %msg  = lv_msg
                      dummy = 1 ) TO reported-behaviour.
      EXIT.
    ENDIF.

    SORT lt_taxcode BY tax_code.
    DELETE ADJACENT DUPLICATES FROM lt_taxcode COMPARING tax_code.

    LOOP AT ls_data-%param-_itemtable INTO DATA(ls_control).
      READ TABLE lt_taxcode TRANSPORTING NO FIELDS WITH KEY tax_code = ls_control-tax_code.
      IF sy-subrc NE 0.
        APPEND VALUE #( dummy = 1 ) TO failed-behaviour.

        lv_msg = new_message_with_text( text = |{ ls_control-tax_code } vergisi bakım tablosunda bulunmamaktadır.| severity = cl_abap_behv=>ms-error ).

        APPEND VALUE #( %msg  = lv_msg
                        dummy = 1 ) TO reported-behaviour.
        EXIT.
      ENDIF.

    ENDLOOP.

    IF ls_data-%param-_itemtable IS NOT INITIAL.

      DATA(lv_line) = lines( ls_data-%param-_itemtable ).

    ENDIF.

*---> 9004402960 BTOK&GSEVIM 03.09.2026
    IF ls_data-%param-doc_reference IS NOT INITIAL.

    DATA: lv_part1 TYPE string,
          lv_part2 TYPE string.

    SELECT SINGLE DOCUMENTREFERENCEID,
                  ACCOUNTINGDOCUMENT
      FROM I_JOURNALENTRY
      WHERE DOCUMENTREFERENCEID    eq @ls_data-%param-doc_reference
        AND CompanyCode            eq @ls_data-%param-com_code
        AND PostingDate            eq @ls_data-%param-post_date
        AND AccountingDocumentType eq @ls_data-%param-acc_type
      INTO @DATA(ls_referance).

      if  ls_referance-AccountingDocument IS NOT INITIAL.

*        lv_msg = new_message_with_text( text = |{ ls_data-%param-doc_reference } referans numarasıyla { ls_referance-AccountingDocument } dokuman numarası kayıt edilmistir | severity = cl_abap_behv=>ms-error ).
        APPEND VALUE #( %msg     = new_message_with_text(
                        text     = |{ ls_referance-AccountingDocument } dokuman numarası kayıt edilmistir.|
                        severity = if_abap_behv_message=>severity-error )
                        dummy    = 1 ) TO reported-behaviour.


        APPEND VALUE #( %msg     = new_message_with_text(
                        text     = |{ ls_data-%param-doc_reference } referans numarasıyla|
                        severity = if_abap_behv_message=>severity-error )
                        dummy    = 1 ) TO reported-behaviour.



      ENDIF.

    ENDIF.
*<--- 9004402960 BTOK&GSEVIM 03.09.2026
    IF reported-behaviour IS INITIAL.
      APPEND INITIAL LINE TO lt_je_deep ASSIGNING FIELD-SYMBOL(<je_deep>).
      <je_deep>-%cid = lv_cid.
      <je_deep>-%param = VALUE #(
      businesstransactiontype = 'RFBU'
      accountingdocumenttype = ls_data-%param-acc_type
      companycode = ls_data-%param-com_code
      createdbyuser = sy-uname
      documentdate = ls_data-%param-doc_date
      postingdate = ls_data-%param-post_date
      accountingdocumentheadertext = ls_data-%param-doc_header_text
      documentreferenceid = ls_data-%param-doc_reference
      taxdeterminationdate = ls_data-%param-post_date

      _aritems = COND #( WHEN ls_data-%param-customer IS NOT INITIAL
                         THEN VALUE #( ( glaccountlineitem = '000001'
                                         customer          = ls_data-%param-customer
                                         _currencyamount   = VALUE #( ( currencyrole           = '00'
                                                                        journalentryitemamount = 0
                                                                        currency               = ls_data-%param-doc_currency )
                                                                      ( currencyrole           = '10'
                                                                        journalentryitemamount = COND #( WHEN ls_data-%param-debit_credit_code = 'A'
                                                                                                         THEN ls_data-%param-amount * -1
                                                                                                         WHEN ls_data-%param-debit_credit_code = 'B'
                                                                                                         THEN ls_data-%param-amount
                                                                                                       )
                                                                        currency               = 'TRY' )
*                                                                    currency = ls_data-%param-currency )
                                                                      ( currencyrole           = '30'
                                                                        journalentryitemamount = 0
                                                                        currency               = 'EUR' )
                                                                      ( currencyrole           = 'Z0'
                                                                        journalentryitemamount = 0
                                                                        currency               = 'USD' )
)
                                       documentitemtext = ls_data-%param-doc_item_text
                                          ) ) )
        _apitems = COND #( WHEN ls_data-%param-supplier IS NOT INITIAL
                           THEN VALUE #( ( glaccountlineitem = '000001'
                                           supplier          = ls_data-%param-supplier
                                           _currencyamount   = VALUE #( ( currencyrole           = '00'
                                                                          journalentryitemamount = 0
                                                                          currency               = ls_data-%param-doc_currency )
                                                                        ( currencyrole           = '10'
                                                                          journalentryitemamount = COND #( WHEN ls_data-%param-debit_credit_code = 'A'
                                                                                                           THEN ls_data-%param-amount * -1
                                                                                                           WHEN ls_data-%param-debit_credit_code = 'B'
                                                                                                           THEN ls_data-%param-amount
                                                                                                           )
                                                                          currency               = 'TRY' )
*                                                                    currency = ls_data-%param-currency )
                                                                        ( currencyrole           = '30'
                                                                          journalentryitemamount = 0
                                                                          currency               = 'EUR' )
                                                                        ( currencyrole           = 'Z0'
                                                                          journalentryitemamount = 0
                                                                          currency               = 'USD' )
                                                                          )
                                       documentitemtext = ls_data-%param-doc_item_text
                                          ) ) )
         _glitems = VALUE #( FOR ls_item IN ls_data-%param-_itemtable INDEX INTO lv_index
                             FOR ls_taxcode IN lt_taxcode WHERE ( tax_code = ls_item-tax_code )
                           ( glaccountlineitem = lv_index + 1
                             glaccount         = ls_item-gl_account
                             _currencyamount   = VALUE #( ( currencyrole           = '00'
                                                            journalentryitemamount = 0
                                                            currency               = ls_data-%param-doc_currency
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount /  ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                          ( currencyrole           = '10'
*                                                            journalentryitemamount = COND #( WHEN ls_item-debit_credit_code = 'A'
**                                                                                             THEN ( ( 100 - ls_taxcode-percent ) / 100 ) * ls_item-amount * -1
*                                                                                             THEN ls_item-amount * -1
*                                                                                             WHEN ls_item-debit_credit_code = 'B'
**                                                                                             THEN ( ( 100 - ls_taxcode-percent ) / 100 ) * ls_item-amount
*                                                                                             THEN ls_item-amount
*                                                                                             )
                                                            journalentryitemamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) )
                                                                                             )
*                                                            journalentryitemamount = 10000
*                                                            TaxBaseAmount = ( ( 100 - ls_taxcode-percent ) / 100 ) * ls_item-amount
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) )
                                                            currency               = 'TRY' )

*                                                         currency = ls_data-%param-currency )
                                                          ( currencyrole           = '30'
                                                            journalentryitemamount = 0
                                                            currency               = 'EUR'
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                          ( currencyrole           = 'Z0'
                                                            journalentryitemamount = 0
                                                            currency               = 'USD'
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                            )
                            documentitemtext    = ls_item-doc_item_text
                            assignmentreference = ls_item-assign_ref
                            taxcode             = ls_item-tax_code
                            profitcenter        = ls_item-profit_center
                            costcenter          = ls_item-cost_center ) )
         _taxitems = VALUE #( FOR ls_item IN ls_data-%param-_itemtable INDEX INTO lv_index
                              FOR ls_taxcode IN lt_taxcode WHERE ( tax_code = ls_item-tax_code )
                             ( glaccountlineitem = lv_line + lv_index + 1
                               taxcode           = ls_item-tax_code
                               _currencyamount   = VALUE #( ( currencyrole           = '00'
                                                              journalentryitemamount = 0
                                                              currency               = ls_data-%param-doc_currency
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                            ( currencyrole           = '10'
                                                              journalentryitemamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount - ( ls_item-amount /  ( 1 + ( ls_taxcode-percent / 100 ) ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ( ls_item-amount - ( ls_item-amount /  ( 1 + ( ls_taxcode-percent / 100 ) ) ) ) )
*                                                              journalentryitemamount = ( ls_taxcode-percent / 100 ) * ls_item-amount
*                                                              journalentryitemamount = 2000
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) )
*                                                              TaxBaseAmount = 10000
                                                              currency               = 'TRY' )
*                                                         currency = ls_data-%param-currency )
                                                            ( currencyrole           = '30'
                                                              journalentryitemamount = 0
                                                              currency               = 'EUR'
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                            ( currencyrole           = 'Z0'
                                                              journalentryitemamount = 0
                                                              currency               = 'USD'
                                                            taxbaseamount = COND #( WHEN ls_item-debit_credit_code = 'A'
                                                                                             THEN ( ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) * -1
                                                                                             WHEN ls_item-debit_credit_code = 'B'
                                                                                             THEN ls_item-amount / ( 1 + ( ls_taxcode-percent / 100 ) ) ) )
                                                              )
                            conditiontype         = ls_taxcode-move_type
                            taxitemclassification = ls_taxcode-tax_type ) )

                            ).

*      IF ls_data-%param-simulation IS NOT INITIAL.
*        result = VALUE #( ( %key-dummy = 1
*                            %param = CORRESPONDING #( ls_data-%param ) ) ).
*      ELSE.
      CLEAR zfi003_cl_dd_behaviourd=>gt_table.
      zfi003_cl_dd_behaviourd=>gt_table = lt_je_deep.
*      ENDIF.
    ENDIF.


  ENDMETHOD.

ENDCLASS.

CLASS lsc_zfi003_dd_behaviour DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

    METHODS adjust_numbers REDEFINITION.

ENDCLASS.

CLASS lsc_zfi003_dd_behaviour IMPLEMENTATION.

  METHOD finalize.
    CLEAR zfi003_cl_dd_behaviourd=>gv_pid.

    IF zfi003_cl_dd_behaviourd=>gt_table IS NOT INITIAL.
      MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
      ENTITY journalentry
      EXECUTE post FROM zfi003_cl_dd_behaviourd=>gt_table
      FAILED DATA(ls_failed_deep)
      REPORTED DATA(ls_reported_deep)
      MAPPED DATA(ls_mapped_deep).
      IF ls_failed_deep IS NOT INITIAL.
        LOOP AT ls_reported_deep-journalentry ASSIGNING FIELD-SYMBOL(<ls_reported_deep>).
          DATA(lv_result) = <ls_reported_deep>-%msg->if_message~get_text( ).

          APPEND VALUE #( %msg  = <ls_reported_deep>-%msg
                          dummy = 1 ) TO reported-behaviour.
        ENDLOOP.
      ELSE.

        DATA(ls_map) = VALUE #( ls_mapped_deep-journalentry[ 1 ] OPTIONAL ).

        zfi003_cl_dd_behaviourd=>gv_pid = ls_map-%pid.

      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD check_before_save.

  ENDMETHOD.

  METHOD save.

    IF zfi003_cl_dd_behaviourd=>gv_pid IS NOT INITIAL.
      CONVERT KEY OF i_journalentrytp FROM zfi003_cl_dd_behaviourd=>gv_pid TO DATA(ls_convert).

      DATA(lv_msg) = new_message_with_text( text = |Fatura: { ls_convert-accountingdocument }| severity = cl_abap_behv=>ms-success ).

      APPEND VALUE #( %msg  = lv_msg
                      dummy = 1
                      ) TO reported-behaviour.



    ENDIF.

  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

  METHOD adjust_numbers.

  ENDMETHOD.

ENDCLASS.