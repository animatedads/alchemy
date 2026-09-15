parse source . . script
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
aenv=.FederationBankFixtures~freshEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["engine"])
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
pCustomers=.FederationBankCustomerRegistry~new
pAccounts=.FederationBankLedger~new
profiles=.FederationBankRegulatoryProfileRegistry~standard
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)
ledger=.FederationBankLedger~new
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)

open=.FederationBankCommand~new("AR-OPEN","OPEN_ACCOUNT","AR-IDEM","CUST-AR","","","EUR",0,"WEB","CUST-AR",.nil,"OFFSHORE_CURRENT","EUR-AR","Restart Customer","1990-03-04","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call qmust runtime~submitOpenAccount(open),"submit"
call must runtime~processAccountOne,"account open"
call must runtime~processPaymentsProjectionOne,"payments projection live"
call must runtime~processLedgerProjectionOne,"ledger projection live"
call assert pAccounts~account("EUR-AR")<>.nil,"live Payments account"
call assert ledger~account("EUR-AR")<>.nil,"live Ledger account"
call assert topology~topics~retainedPublications~items>=1,"account retained state exists"

/* Fresh queue-manager and empty worker projections. */
manager2=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology2=.FederationBankServiceTopology~new(manager2)
newCustomers=.FederationBankCustomerRegistry~new
newAccounts=.FederationBankLedger~new
newUsage=.FederationBankPaymentsUsageProjection~new(topology2~topics)
newPayments=.FederationBankPaymentsEngine~new(newCustomers,newAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),newUsage)
newLedger=.FederationBankLedger~new
newLedgerEngine=.FederationBankLedgerEngine~new(newLedger,profiles)
call must newPayments~rebuildAccountProjections(topology2~topics),"rebuild Payments accounts"
call must newLedgerEngine~rebuildAccountProjections(topology2~topics),"rebuild Ledger account metadata"
call assert newCustomers~customer("CUST-AR")<>.nil,"customer recovered from retained account state"
call assert newAccounts~account("EUR-AR")<>.nil,"Payments account recovered"
call assert newAccounts~account("EUR-AR")~regulatoryProfileId="FB-IOM-EUR","regulatory profile recovered"
call assert newLedger~account("EUR-AR")<>.nil,"Ledger account metadata recovered"
say "PASS account projections rebuild from retained Queue Fabric state"
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
