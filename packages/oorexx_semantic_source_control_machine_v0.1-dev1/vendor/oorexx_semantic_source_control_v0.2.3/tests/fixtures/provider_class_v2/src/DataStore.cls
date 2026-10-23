::class AccountStore public subclass Object

::method loadAccounts
  use strict arg customerId
  before = "anchor-before"
  sql = "SELECT account_id, name, balance FROM account WHERE customer_id = ?"
  after = "anchor-after"
  return sql

::method legacyDelete
  use strict arg batchId
  return batchId
