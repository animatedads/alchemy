parse source . . script
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end

/* Shared Queue Fabric only; each backend has its own domain state. */
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology = .FederationBankServiceTopology~new(manager)
usage = .FederationBankPaymentsUsageProjection~new(topology~topics)

/* Account Engine has its own DB/external-service environment. */
aenv = .FederationBankFixtures~freshAccountEnvironment
accountEngine = .FederationBankAccountEngine~new(aenv["authority"])

/* Payments owns customer/account projections plus authority gates, never a DB ledger. */
pCustomers = .FederationBankCustomerRegistry~new
pAccounts = .FederationBankLedger~new
profiles = .FederationBankRegulatoryProfileRegistry~standard
paymentsEngine = .FederationBankPaymentsEngine~new(pCustomers, pAccounts, profiles, .FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog), .FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry), .FederationBankBouncer~new(.FederationBankBouncer~standardFramework), usage)

/* Ledger has a different SQL executor/store and is the only monetary writer. */
lexecutor = .FederationBankFixtureSqlExecutor~new
ldb = .FederationBankFixtures~database(lexecutor)
lstore = .FederationBankSqlLedgerStore~new(ldb,3,15)
lledger = .FederationBankLedger~new(lstore)
profile = profiles~byCurrency("USD")
call must lledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)), "ledger settlement account"
ledgerEngine = .FederationBankLedgerEngine~new(lledger, profiles)
runtime = .FederationBankBackendRuntime~new(topology, accountEngine, paymentsEngine, ledgerEngine)

/* New customer/account is requested by the channel but created only in Account Engine. */
open1 = .FederationBankCommand~new("A-OPEN-1","OPEN_ACCOUNT","A-IDEM-1","CUST-SPLIT","","","USD",0,"WEB","CUST-SPLIT",.nil,"OFFSHORE_CURRENT","USD-SRC","Queue Customer","1988-06-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call qmust runtime~submitOpenAccount(open1), "submit source opening"
call must runtime~processAccountOne, "account engine source opening"
call must runtime~processPaymentsProjectionOne, "payments receives source projection"
call must runtime~processLedgerProjectionOne, "ledger receives source projection"
call qmust runtime~getAccountResult, "source opening result"

open2 = .FederationBankCommand~new("A-OPEN-2","OPEN_ACCOUNT","A-IDEM-2","CUST-SPLIT","","","USD",0,"WEB","CUST-SPLIT",.nil,"OFFSHORE_CURRENT","USD-DST","Queue Customer","1988-06-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call qmust runtime~submitOpenAccount(open2), "submit destination opening"
call must runtime~processAccountOne, "account engine destination opening"
call must runtime~processPaymentsProjectionOne, "payments receives destination projection"
call must runtime~processLedgerProjectionOne, "ledger receives destination projection"
call qmust runtime~getAccountResult, "destination opening result"
call assert pAccounts~account("USD-SRC") <> .nil, "Payments has source projection"
call assert lledger~account("USD-SRC") <> .nil, "Ledger has source projection"

/* Seed only through Ledger domain authority for the fixture. */
call must lledger~postTransfer("SEED-SPLIT","FB-SETTLEMENT-USD","USD-SRC",10000000,"USD"), "seed source balance"

pay = .FederationBankCommand~new("PAY-1","TRANSFER","TX-SPLIT-1","CUST-SPLIT","USD-SRC","USD-DST","USD",4000000,"WEB","CUST-SPLIT")
call qmust runtime~submitTransfer(pay), "channel submits payment"
auth = runtime~processPaymentsOne
call must auth, "Payments authorises"
call assert auth~code = "PAYMENT_AUTHORISED", "Payments stops at authority boundary"
call assert lledger~balanceMinor("USD-SRC") = 10000000, "authorisation alone cannot alter Ledger balance"

/* Channel principal is intentionally unable to bypass Payments and write Ledger. */
denied = manager~put(.FederationBankServiceTopology~LEDGER_COMMANDS, auth~value, .nil, .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
call assert denied~ok = .false, "channel denied direct Ledger PUT"
call assert denied~code = "ACCESS_DENIED", "Ledger ACL denial explicit"

posted = runtime~processLedgerOne
call must posted, "Ledger commits transfer"
call assert lledger~balanceMinor("USD-SRC") = 6000000, "Ledger debit after commit"
call assert lledger~balanceMinor("USD-DST") = 4000000, "Ledger credit after commit"
completed = runtime~processPaymentsCompletionOne
call must completed, "Payments publishes completion"
call assert completed~code = "TRANSFER_COMMITTED", "customer completion only after Ledger"
call assert usage~usedMinor("CUST-SPLIT","USD",pay~requestedAt) = 4000000, "usage advances only after Ledger commit"
gotResult = runtime~getPaymentsResult
call qmust gotResult, "channel receives final payment result"
call assert gotResult~value~payload["code"] = "TRANSFER_COMMITTED", "channel sees committed result"
call assert gotResult~value~payload["databaseOutcome"] = "COMMITTED", "DB outcome projected"

/* Queue-native usage projection survives a Payments worker restart. */
manager2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology2 = .FederationBankServiceTopology~new(manager2)
usage2 = .FederationBankPaymentsUsageProjection~new(topology2~topics)
call assert usage2~usedMinor("CUST-SPLIT","USD",pay~requestedAt) = 4000000, "Payments usage rebuilt after worker restart"

say "PASS three queue-addressable engines + Ledger ACL + retained Payments usage restart"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
qmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
