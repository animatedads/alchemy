::class AccountConsumer public

::method render
  -- @source-requires DataStore.AccountStore.loadAccounts AT_LEAST 1
  -- @source-result-ordinal DataStore.AccountStore.loadAccounts 2 NAME
  -- @source-result-ordinal DataStore.AccountStore.loadAccounts 3 BALANCE
  -- @source-data READ ACCOUNT
  use strict arg store, customerId
  rows = store~loadAccounts(customerId)
  return rows

::method cleanup
  -- @source-requires DataStore.AccountStore.legacyDelete AT_LEAST 1
  use strict arg store, batchId
  return store~legacyDelete(batchId)
