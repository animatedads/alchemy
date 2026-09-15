/* provider v3: intentionally dangerous mutation change at the tracked site */
::class AccountStore public

::method loadAccounts
  use strict arg customerId
  before = "anchor-before"
  sql = "DELETE FROM account WHERE customer_id = ?"
  after = "anchor-after"
  return sql

::method legacyDelete
  use strict arg batchId
  return batchId
