::class Store public
::method commitTransfer
  txSql = "INSERT INTO transactions (transaction_id, amount_minor) VALUES (?, ?)"
  postingSql = "INSERT INTO postings (posting_id, transaction_id, amount_minor) VALUES (?, ?, ?)"
  return txSql || postingSql
