::class Store public
::method commitTransferPostings
  txSql = "INSERT INTO transactions (transaction_id, amount_minor, fee_amount_minor) VALUES (?, ?, ?)"
  postingSql = "INSERT INTO postings (posting_id, transaction_id, amount_minor, posting_role) VALUES (?, ?, ?, ?)"
  return txSql || postingSql
