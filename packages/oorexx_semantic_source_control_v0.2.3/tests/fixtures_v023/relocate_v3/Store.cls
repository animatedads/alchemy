::class Store public
::method commitTransferPostings
  txSql = "INSERT INTO transactions (transaction_id, amount_minor, fee_amount_minor) VALUES (?, ?, ?)"
  postingSql = "INSERT INTO postings (posting_id, transaction_id, amount_minor, posting_role) VALUES (?, ?, ?, ?)"
  return txSql || postingSql

::method commitFxPostings
  txSql = "INSERT INTO transactions (transaction_id, amount_minor, fee_amount_minor) VALUES (?, ?, ?)"
  postingSql = "INSERT INTO postings (posting_id, transaction_id, amount_minor, posting_role) VALUES (?, ?, ?, ?)"
  return txSql || postingSql

::method commitOfflineCashPostings
  txSql = "INSERT INTO transactions (transaction_id, amount_minor, fee_amount_minor) VALUES (?, ?, ?)"
  postingSql = "INSERT INTO postings (posting_id, transaction_id, amount_minor, posting_role) VALUES (?, ?, ?, ?)"
  atmSql = "INSERT INTO atm_settlement_evidence (transaction_id, terminal_id) VALUES (?, ?)"
  return txSql || postingSql || atmSql
