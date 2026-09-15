root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
profiles=.FederationBankRegulatoryProfileRegistry~standard
pCustomers=.FederationBankCustomerRegistry~new; pAccounts=.FederationBankLedger~new
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)
executor=.FederationBankFixtureSqlExecutor~new; db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store); p=profiles~byCurrency("GBP")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",p~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)
gateway=.FederationBankAtmGateway~new(topology,runtime,ledgerEngine)

call openAccount runtime,"GBP-RSV","OFFLINE-OPEN-RSV"
call openAccount runtime,"GBP-STAND","OFFLINE-OPEN-STAND"
call must ledger~postTransfer("OFFLINE-SEED-RSV","FB-SETTLEMENT-GBP","GBP-RSV",30000,"GBP"),"seed reserved"
call must ledger~postTransfer("OFFLINE-SEED-STAND","FB-SETTLEMENT-GBP","GBP-STAND",4000,"GBP"),"seed standin"

login=req("ATM-IOM-001-LGN-200","LOGON","",200,.directory~new)
login["data"]["cardId"]="4111111111111111"; login["data"]["credentialType"]="DEMO_PIN"; login["data"]["credential"]="1234"
x=gateway~handleRequest(login); call assert x["ok"]=.true,"logon"; sid=x["data"]["sessionId"]

/* RESERVED_ALLOWANCE is policy/legal authorised and backed by a real hold. */
ra=req("ATM-IOM-001-OFA-201","GET_OFFLINE_ALLOWANCE",sid,201,.directory~new); ra["idempotencyKey"]="OFA-ATM-IOM-001-201"
ra["data"]["accountId"]="GBP-RSV"; ra["data"]["currency"]="GBP"; ra["data"]["amountMinor"]=10000; ra["data"]["authorityMode"]="RESERVED_ALLOWANCE"
x=gateway~handleRequest(ra); if x["ok"]=.false then say "DEBUG RESERVED" .JSON~toJSON(x); call assert x["ok"]=.true,"reserved authority issued"
call assert x["code"]="OFFLINE_RESERVED_ALLOWANCE_ISSUED","reserved authority code"
reservedId=x["data"]["offlineAuthorityId"]; reservedHold=x["data"]["holdId"]
call assert ledger~balanceMinor("GBP-RSV")=30000,"reserved authority no book movement"
call assert ledger~availableBalanceMinor("GBP-RSV")=20000,"reserved authority consumes availability"
call assert ledger~hold(reservedHold)~status="ACTIVE","reserved authority hold active"

/* Recreate the gateway: retained authority/session state must be sufficient. */
gateway=.FederationBankAtmGateway~new(topology,runtime,ledgerEngine)
call assert gateway~offlineAuthorities~authority(reservedId)<>.nil,"reserved authority rebuilt from retained topic"

advice=req("ATM-IOM-001-OWA-202","OFFLINE_WITHDRAWAL_ADVICE",sid,202,.directory~new); advice["idempotencyKey"]="OWA-ATM-IOM-001-202"
advice["data"]["offlineAuthorityId"]=reservedId; advice["data"]["accountId"]="GBP-RSV"; advice["data"]["currency"]="GBP"; advice["data"]["amountMinor"]=10000; advice["data"]["physicalTransactionId"]="PHYS-OFFLINE-RSV-202"; advice["data"]["dispensedMinor"]=10000; advice["data"]["authorityMode"]="RESERVED_ALLOWANCE"
before=ledger~postings~items
x=gateway~handleRequest(advice); if x["ok"]=.false then say "DEBUG RSV ADVICE" .JSON~toJSON(x); call assert x["ok"]=.true,"reserved advice settled"
call assert ledger~balanceMinor("GBP-RSV")=20000,"reserved advice debits once"
call assert ledger~hold(reservedHold)~status="RELEASED","reserved hold consumed"
call assert ledger~postings~items=before+2,"reserved advice exactly two legs"
call assert gateway~offlineAuthorities~authority(reservedId)["status"]="CONSUMED","reserved authority consumed"

/* Lost reply/replay uses same authority and same banking idempotency safely. */
postCount=ledger~postings~items
x=gateway~handleRequest(advice); call assert x["ok"]=.true,"reserved advice replay"
call assert ledger~balanceMinor("GBP-RSV")=20000,"reserved replay no second debit"
call assert ledger~postings~items=postCount,"reserved replay no second postings"

/* Invented authority cannot be promoted into mandatory settlement. */
fake=req("ATM-IOM-001-OWA-203","OFFLINE_WITHDRAWAL_ADVICE",sid,203,.directory~new); fake["idempotencyKey"]="OWA-ATM-IOM-001-203"
fake["data"]["offlineAuthorityId"]="OFFAUTH-INVENTED"; fake["data"]["accountId"]="GBP-STAND"; fake["data"]["currency"]="GBP"; fake["data"]["amountMinor"]=1000; fake["data"]["physicalTransactionId"]="PHYS-FAKE-203"; fake["data"]["dispensedMinor"]=1000; fake["data"]["authorityMode"]="DELEGATED_STAND_IN"
preFake=ledger~postings~items
x=gateway~handleRequest(fake); call assert x["ok"]=.false,"invented authority rejected"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_UNKNOWN","invented authority code"
call assert ledger~postings~items=preFake,"invented authority no monetary truth"

/* The same low-balance account cannot obtain a RESERVED_ALLOWANCE that the
   Ledger cannot actually reserve.  No authority is published on failure. */
lowReserve=req("ATM-IOM-001-OFA-203A","GET_OFFLINE_ALLOWANCE",sid,2031,.directory~new); lowReserve["idempotencyKey"]="OFA-ATM-IOM-001-203A"
lowReserve["data"]["accountId"]="GBP-STAND"; lowReserve["data"]["currency"]="GBP"; lowReserve["data"]["amountMinor"]=10000; lowReserve["data"]["authorityMode"]="RESERVED_ALLOWANCE"
x=gateway~handleRequest(lowReserve); call assert x["ok"]=.false,"unfunded reserved authority rejected"
call assert gateway~offlineAuthorities~authority("OFFAUTH-OFA-ATM-IOM-001-203A")==.nil,"failed reserve publishes no authority"

/* DELEGATED_STAND_IN is bank-issued without a hold.  It may later settle
   physical cash beyond ordinary available funds. */
sa=req("ATM-IOM-001-OFA-204","GET_OFFLINE_ALLOWANCE",sid,204,.directory~new); sa["idempotencyKey"]="OFA-ATM-IOM-001-204"
sa["data"]["accountId"]="GBP-STAND"; sa["data"]["currency"]="GBP"; sa["data"]["amountMinor"]=18000; sa["data"]["authorityMode"]="DELEGATED_STAND_IN"
x=gateway~handleRequest(sa); if x["ok"]=.false then say "DEBUG STANDIN" .JSON~toJSON(x); call assert x["ok"]=.true,"standin authority issued"; standId=x["data"]["offlineAuthorityId"]
call assert x["data"]["holdId"]="","standin has no reservation"
call assert ledger~balanceMinor("GBP-STAND")=4000,"standin issue no book movement"
call assert ledger~availableBalanceMinor("GBP-STAND")=4000,"standin issue no hidden hold"

/* Authority envelope is bound to terminal/account/currency/amount. */
over=req("ATM-IOM-001-OWA-204A","OFFLINE_WITHDRAWAL_ADVICE",sid,2041,.directory~new); over["idempotencyKey"]="OWA-ATM-IOM-001-204A"
over["data"]["offlineAuthorityId"]=standId; over["data"]["accountId"]="GBP-STAND"; over["data"]["currency"]="GBP"; over["data"]["amountMinor"]=18001; over["data"]["physicalTransactionId"]="PHYS-OVER-204A"; over["data"]["dispensedMinor"]=18001; over["data"]["authorityMode"]="DELEGATED_STAND_IN"
x=gateway~handleRequest(over); call assert x["ok"]=.false,"standin amount ceiling enforced"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_AMOUNT_EXCEEDED","standin amount ceiling code"
/* Customer sessions themselves are terminal-bound. */
wrongSession=req("ATM-IOM-999-BAL-204B","GET_BALANCE",sid,2042,.directory~new); wrongSession["terminalId"]="ATM-IOM-999"; wrongSession["data"]["accountId"]="GBP-STAND"
x=gateway~handleRequest(wrongSession); call assert x["ok"]=.false,"session terminal binding enforced"; call assert x["code"]="SESSION_TERMINAL_MISMATCH","session terminal mismatch code"

/* A separately authenticated session on another terminal still cannot spend
   authority issued to ATM-IOM-001. */
login2=req("ATM-IOM-999-LGN-204C","LOGON","",2043,.directory~new); login2["terminalId"]="ATM-IOM-999"; login2["data"]["cardId"]="4111111111111111"; login2["data"]["credentialType"]="DEMO_PIN"; login2["data"]["credential"]="1234"
x=gateway~handleRequest(login2); call assert x["ok"]=.true,"second terminal logon"; sid2=x["data"]["sessionId"]
wrong=over~copy; wrong["commandId"]="ATM-IOM-999-OWA-204D"; wrong["idempotencyKey"]="OWA-ATM-IOM-999-204D"; wrong["terminalId"]="ATM-IOM-999"; wrong["sessionId"]=sid2; wrong["data"]=over["data"]~copy; wrong["data"]["amountMinor"]=1000; wrong["data"]["dispensedMinor"]=1000; wrong["data"]["physicalTransactionId"]="PHYS-WRONGTERM-204D"
x=gateway~handleRequest(wrong); call assert x["ok"]=.false,"authority terminal binding enforced"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_TERMINAL_MISMATCH","authority terminal mismatch code"

/* Another gateway process can reconstruct the stand-in authority. */
gateway=.FederationBankAtmGateway~new(topology,runtime,ledgerEngine)
standAdvice=req("ATM-IOM-001-OWA-205","OFFLINE_WITHDRAWAL_ADVICE",sid,205,.directory~new); standAdvice["idempotencyKey"]="OWA-ATM-IOM-001-205"
standAdvice["data"]["offlineAuthorityId"]=standId; standAdvice["data"]["accountId"]="GBP-STAND"; standAdvice["data"]["currency"]="GBP"; standAdvice["data"]["amountMinor"]=18000; standAdvice["data"]["physicalTransactionId"]="PHYS-OFFLINE-STAND-205"; standAdvice["data"]["dispensedMinor"]=18000; standAdvice["data"]["authorityMode"]="DELEGATED_STAND_IN"
x=gateway~handleRequest(standAdvice); if x["ok"]=.false then say "DEBUG STAND ADVICE" .JSON~toJSON(x); call assert x["ok"]=.true,"standin advice settled"
call assert ledger~balanceMinor("GBP-STAND")=-14000,"standin mandatory settlement crosses zero"
fs=ledger~fundsState("GBP-STAND"); call assert fs["unauthorisedExcessMinor"]=14000,"standin unauthorised excess explicit"; call assert fs["withdrawalsBlocked"]=.true,"post-settlement withdrawals blocked"
call assert gateway~offlineAuthorities~authority(standId)["status"]="CONSUMED","standin authority consumed"

/* Consumed authority cannot be reused for a different physical cash event. */
other=standAdvice~copy; other["commandId"]="ATM-IOM-001-OWA-206"; other["idempotencyKey"]="OWA-ATM-IOM-001-206"; other["terminalSequence"]=206; other["data"]=standAdvice["data"]~copy; other["data"]["physicalTransactionId"]="PHYS-OFFLINE-STAND-206"
preOther=ledger~postings~items
x=gateway~handleRequest(other); call assert x["ok"]=.false,"standin authority single use"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_ALREADY_CONSUMED","single-use code"
call assert ledger~postings~items=preOther,"single-use violation no second settlement"

say "PASS bank-issued retained offline authorities: reserved allowance + delegated stand-in + replay/forgery protection"
exit 0

openAccount: procedure expose runtime
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return
req: procedure
  use arg commandId,op,session,seq,data
  d=.directory~new; d["schema"]="federationbank.atm.request/0.1"; d["commandId"]=commandId; d["idempotencyKey"]=commandId; d["operation"]=op; d["terminalId"]="ATM-IOM-001"; d["terminalSequence"]=seq; d["sessionId"]=session; d["requestedAt"]=.DateTime~new~utcIsoDate; d["rulesetId"]="FB-ATM-IOM-DEMO"; d["rulesVersion"]=1; d["data"]=data; return d
must: procedure; use arg r,label; if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end; return
qmust: procedure; use arg r,label; if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end; return
assert: procedure; use arg condition,label; if \condition then do; say "FAIL" label; exit 1; end; return
::requires "FederationBankAtmGateway.cls"
::requires "FederationBankFixtures.cls"
