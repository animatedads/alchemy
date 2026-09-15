/* Queue-level delegated stand-in advice: Payments may authorise the physical
 * cash fact, but only Ledger may record the mandatory settlement. */
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
profiles=.FederationBankRegulatoryProfileRegistry~standard; p=profiles~byCurrency("GBP")

customers=.FederationBankCustomerRegistry~new
call must customers~add(.FederationBankCustomer~new("CUST-QATM","RETAIL","GB","GB","STANDARD")),"customer"
paccounts=.FederationBankLedger~new
call must paccounts~addAccount(.FederationBankAccount~new("QATM-GBP","CUST-QATM","GBP","OFFSHORE_CURRENT","IOM",p~profileId,.false,.false,10000)),"payments account"
payments=.FederationBankPaymentsEngine~new(customers,paccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)

executor=.FederationBankFixtureSqlExecutor~new; db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",p~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("QATM-GBP","CUST-QATM","GBP","OFFSHORE_CURRENT","IOM",p~profileId,.false,.false,10000)),"ledger account"
call must ledger~postTransfer("QATM-SEED","FB-SETTLEMENT-GBP","QATM-GBP",4000,"GBP"),"seed"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
/* Account Engine is not involved in this channel test; a valid object is still
 * supplied because the runtime hosts all worker facades for acceptance tests. */
aenv=.FederationBankFixtures~freshAccountEnvironment
runtime=.FederationBankBackendRuntime~new(topology,.FederationBankAccountEngine~new(aenv["authority"]),payments,ledgerEngine)

d=.directory~new
d["terminalId"]="ATM-IOM-007"; d["atmNetworkId"]="FB-ATM-IOM"; d["offlineAuthorityId"]="STANDIN-007"
d["rulesetId"]="FB-ATM-IOM"; d["rulesVersion"]="21"; d["physicalTransactionId"]="ATM-IOM-007-DISP-77"; d["terminalSequence"]="77"
d["dispensedMinor"]=18000; d["authorityMode"]="DELEGATED_STAND_IN"
cmd=.FederationBankCommand~new("QATM-ADV-1","OFFLINE_WITHDRAWAL_ADVICE","QATM-IDEM-1","CUST-QATM","QATM-GBP","","GBP",18000,"ATM","ATM-IOM-007",.nil,"","","","","","","","","RETAIL","STANDARD",d)
call qmust runtime~submitTransfer(cmd),"submit ATM advice"
auth=runtime~processPaymentsOne
call must auth,"Payments validates delegated offline evidence"
call assert auth~value["debitAuthority"]="SETTLEMENT_MUST_POST","queue instruction carries narrow mandatory-post authority"
call assert ledger~balanceMinor("QATM-GBP")=4000,"Payments cannot alter monetary truth"
posted=runtime~processLedgerOne
call must posted,"Ledger records physical cash settlement"
call assert ledger~balanceMinor("QATM-GBP")=-14000,"Ledger posts beyond authorised floor because cash already left"
call assert posted~value["withdrawalsBlocked"]="true","Ledger result exposes resulting withdrawal restriction"
completed=runtime~processPaymentsCompletionOne
call must completed,"Payments completes offline settlement advice"
call assert completed~value["fundsState"]="UNAUTHORISED_EXCESS","channel result retains post-settlement funds state"
call assert usage~usedMinor("CUST-QATM","GBP",cmd~requestedAt)=18000,"offline exposure recorded only after Ledger commit"
call qmust runtime~getPaymentsResult,"channel receives structured settlement result"

say "PASS Queue Fabric ATM offline advice -> Payments authority -> mandatory Ledger settlement -> restriction result"
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
