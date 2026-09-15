/* Policy-derived fee must share the transfer's SQL atomicity/idempotency unit. */
profiles=.FederationBankRegulatoryProfileRegistry~standard
profile=profiles~byCurrency("GBP")
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("FAR-SRC","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"source"
call must ledger~addAccount(.FederationBankAccount~new("FAR-DST","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"target"
call must ledger~postTransfer("FAR-SEED","FB-SETTLEMENT-GBP","FAR-SRC",1000000,"GBP"),"seed"
engine=.FederationBankLedgerEngine~new(ledger,profiles)

customers=.FederationBankCustomerRegistry~new
call must customers~add(.FederationBankCustomer~new("CUST-FAR","RETAIL","GB","GB","STANDARD")),"customer"
paccounts=.FederationBankLedger~new
call must paccounts~addAccount(.FederationBankAccount~new("FAR-SRC","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"payments source"
call must paccounts~addAccount(.FederationBankAccount~new("FAR-DST","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"payments target"
payments=.FederationBankPaymentsEngine~new(customers,paccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),.FederationBankUsageTracker~new,.nil,.FederationBankFeePolicyGate~new(.FederationBankFixtures~feeCatalog))
cmd=.FederationBankCommand~new("FAR-CMD","TRANSFER","FAR-IDEM","CUST-FAR","FAR-SRC","FAR-DST","GBP",100000,"WEB","CUST-FAR")
auth=payments~authorizeTransfer(cmd)
call must auth,"fee authority"
call assert auth~value["feeAmountMinor"]=200,"GBP fixture fee policy"

beforePostings=ledger~postings~items
executor~failNext
failed=engine~postTransfer(auth~value)
call assert failed~ok=.false,"injected SQL failure rejects fee transaction"
call assert failed~code="LEDGER_DATABASE_ROLLBACK","fee transaction rollback explicit"
call assert ledger~postings~items=beforePostings,"rollback exposes zero partial fee/transfer postings"
call assert ledger~balanceMinor("FAR-SRC")=1000000,"rollback source balance unchanged"
call assert ledger~balanceMinor("FAR-DST")=0,"rollback target balance unchanged"
feeAccount=engine~feeIncomeAccountId("GBP","STANDARD_TRANSFER")
call assert ledger~balanceMinor(feeAccount)=0,"rollback fee income unchanged"
call assert \ledger~hasTransaction("FAR-IDEM"),"rollback does not consume transaction identity"

ok=engine~postTransfer(auth~value)
call must ok,"retry same logical fee transaction"
call assert ledger~balanceMinor("FAR-SRC")=899800,"retry debits transfer plus fee once"
call assert ledger~balanceMinor("FAR-DST")=100000,"retry credits transfer once"
call assert ledger~balanceMinor(feeAccount)=200,"retry credits fee once"
call assert ledger~transactionPostings("FAR-IDEM")~items=4,"retry commits four postings"

/* Fresh Ledger worker must recover committed receipt/postings and never refee. */
ledger2=.FederationBankLedger~new(store)
call must ledger2~addAccount(.FederationBankAccount~new("FAR-SRC","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"restart source"
call must ledger2~addAccount(.FederationBankAccount~new("FAR-DST","CUST-FAR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"restart target"
engine2=.FederationBankLedgerEngine~new(ledger2,profiles)
replay=engine2~postTransfer(auth~value)
call must replay,"restart replay recovery"
call assert replay~value["code"]="LEDGER_REPLAY_RECOVERED","durable receipt recognised after restart"
call assert replay~value["recoveredFromDurableReceipt"]="true","replay provenance explicit"
call assert ledger2~transactionPostings("FAR-IDEM")~items=4,"restart hydrates original four postings only"
call assert ledger2~balanceMinor("FAR-SRC")=899800,"restart source truth recovered"
call assert ledger2~balanceMinor("FAR-DST")=100000,"restart target truth recovered"
call assert ledger2~balanceMinor(feeAccount)=200,"restart fee income truth recovered"

say "PASS fee SQL atomic rollback/retry + durable restart replay without double charge"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
