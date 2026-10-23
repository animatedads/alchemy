/* provider v2 */
::class AccountStore public

::method loadAccounts
  use strict arg customerId, includeClosed = .false
  before = "anchor-before"
  sql = "SELECT account_id, balance, name FROM account WHERE customer_id = ?"
  after = "anchor-after"
  return sql

::method loadAccountStatus
  use strict arg customerId
  return customerId
