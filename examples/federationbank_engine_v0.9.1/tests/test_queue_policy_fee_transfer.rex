parse source . . script
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
profiles=.FederationBankRegulatoryProfileRegistry~standard
pCustomers=.FederationBankCustomerRegistry~new
pAccounts=.FederationBankLedger~new
feeGate=.FederationBankFeePolicyGate~new(.FederationBankFixtures~feeCatalog)
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage,.nil,feeGate)
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
profile=profiles~byCurrency("USD")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)

call openAccount runtime,"FEE-SRC","FEE-OPEN-1"
call openAccount runtime,"FEE-DST","FEE-OPEN-2"
call must ledger~postTransfer("FEE-SEED","FB-SETTLEMENT-USD","FEE-SRC",1000000,"USD"),"seed"

pay=.FederationBankCommand~new("FEE-PAY-1","TRANSFER","FEE-TX-1","CUST-FEE","FEE-SRC","FEE-DST","USD",400000,"WEB","CUST-FEE")
call qmust runtime~submitTransfer(pay),"submit fee transfer"
auth=runtime~processPaymentsOne
call must auth,"Payments authorises fee transfer"
call assert auth~value["schema"]="federationbank.ledger.post-transfer/0.6","fee transfer uses v0.6 Ledger contract"
call assert auth~value["feeAmountMinor"]=125,"USD fixture fee resolved from Institutional Policy"
call assert auth~value["feePolicyId"]=.FederationBankBuild~FEE_POLICY_DEFAULT,"fee policy identity attached"
call assert auth~value["feePolicyRuleId"]="USD-RETAIL-TRANSFER-FEE-WEB","fee rule provenance attached"
call assert ledger~balanceMinor("FEE-SRC")=1000000,"Payments cannot charge fee before Ledger"
posted=runtime~processLedgerOne
call must posted,"Ledger commits fee-bearing transfer"
feeAccount=ledgerEngine~feeIncomeAccountId("USD","STANDARD_TRANSFER")
call assert ledger~balanceMinor("FEE-SRC")=599875,"source debited transfer plus fee"
call assert ledger~balanceMinor("FEE-DST")=400000,"target credited transfer only"
call assert ledger~balanceMinor(feeAccount)=125,"fee credited to Ledger-owned internal fee income"
ps=ledger~transactionPostings("FEE-TX-1")
call assert ps~items=4,"fee-bearing transaction has four postings"
sum=0; roles=.directory~new
do posting over ps
  sum += posting~amountMinor
  roles[posting~postingRole]=.true
end
call assert sum=0,"all fee-bearing postings balance to zero"
call assert roles~hasIndex("TRANSFER_DEBIT") & roles~hasIndex("TRANSFER_CREDIT") & roles~hasIndex("FEE_DEBIT") & roles~hasIndex("FEE_CREDIT"),"posting roles distinguish transfer and fee"
completed=runtime~processPaymentsCompletionOne
call must completed,"Payments completes fee transfer"
call assert completed~value["feeAmountMinor"]=125,"fee amount projected to channel result"
call assert completed~value["feeIncomeAccountId"]=feeAccount,"fee account provenance projected"
call assert usage~usedMinor("CUST-FEE","USD",pay~requestedAt)=400000,"customer transaction usage counts transfer amount, not bank fee"
call qmust runtime~getPaymentsResult,"channel receives fee transfer result"

/* Available-funds gate must include the policy fee, not only requested transfer. */
pay2=.FederationBankCommand~new("FEE-PAY-2","TRANSFER","FEE-TX-2","CUST-FEE","FEE-SRC","FEE-DST","USD",599875,"WEB","CUST-FEE")
call qmust runtime~submitTransfer(pay2),"submit transfer equal to book availability before fee"
call must runtime~processPaymentsOne,"Payments policy authorises second transfer"
blocked=runtime~processLedgerOne
call assert blocked~ok=.false,"Ledger rejects when fee pushes total debit over available funds"
call assert blocked~code="INSUFFICIENT_AVAILABLE_FUNDS","fee-aware funds rejection explicit"
call assert ledger~balanceMinor("FEE-SRC")=599875,"rejected fee transfer leaves source unchanged"
call assert ledger~balanceMinor(feeAccount)=125,"rejected fee transfer leaves fee income unchanged"
call assert ledger~transactionPostings("FEE-TX-2")~items=0,"rejected fee transfer creates zero postings"
call assert runtime~processPaymentsCompletionOne~ok=.false,"failed Ledger fee transfer remains failed"
call qmust runtime~getPaymentsResult,"channel receives failed fee transfer result"

say "PASS policy-driven fee -> atomic four-leg Ledger transaction + fee-aware available balance"
exit 0

openAccount: procedure expose runtime
  use arg r,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-FEE","","","USD",0,"WEB","CUST-FEE",.nil,"OFFSHORE_CURRENT",accountId,"Fee Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust r~submitOpenAccount(c),"submit "||accountId
  call must r~processAccountOne,"open "||accountId
  call must r~processPaymentsProjectionOne,"payments projection "||accountId
  call must r~processLedgerProjectionOne,"ledger projection "||accountId
  call qmust r~getAccountResult,"result "||accountId
  return
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
