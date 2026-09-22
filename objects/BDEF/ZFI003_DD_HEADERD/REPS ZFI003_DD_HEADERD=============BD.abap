abstract;
strict ( 2 );
with hierarchy;

define behavior for ZFI003_DD_Headerd //alias <alias_name>
{
  field ( suppress ) dummy_key;

  deep mapping for zfi003_s_headerd
    {
          acc_type          = acc_type;
          amount            = amount;
          com_code          = com_code;
          currency          = currency;
          customer          = customer;
          debit_credit_code = debit_credit_code;
          doc_currency      = doc_currency;
          doc_date          = doc_date;
          doc_header_text   = doc_header_text;
          doc_reference     = doc_reference;
          post_date         = post_date;
          supplier          = supplier;
          doc_item_text     = doc_item_text;
      sub _itemTable        = items;
    }

  association _itemTable;

}

define behavior for ZFI003_DD_Itemd //alias <alias_name>
{
  field ( suppress ) dummy_key, item;

  deep mapping for zfi003_s_itemd
    {
      amount            = amount;
      currency          = currency;
      debit_credit_code = debit_credit_code;
      gl_account        = gl_account;
      assign_ref        = assign_ref;
      doc_item_text     = doc_item_text;
      tax_code          = tax_code;
      cost_center       = cost_center;
      profit_center     = profit_center;
    }

  association _parent;
}