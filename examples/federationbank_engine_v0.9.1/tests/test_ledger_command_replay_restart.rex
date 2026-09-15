profiles=.FederationBankRegulatoryProfileRegistry~standard
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
profile=profiles~byCurrency("EUR")
call addAccounts ledger,profile
engine=.FederationBankLedgerEngine~new(ledger,profiles)
call must ledger~postTransfer("REPLAY-SEED","FB-SETTLEMENT-EUR","RP-SRC",1000000,"EUR"),"seed"

transfer=transferInstruction()
first=engine~postTransfer(transfer)
call must first,"first Ledger transfer"
call assert ledger~balanceMinor("RP-SRC")=800000,"first transfer debit"

/* New worker with no posting projection: durable receipt must turn the same
   internal instruction into success and hydrate SQL truth, never duplicate. */
store2=.FederationBankSqlLedgerStore~new(db,3,15)
ledger2=.FederationBankLedger~new(store2)
call addAccounts ledger2,profile
engine2=.FederationBankLedgerEngine~new(ledger2,profiles)
replayed=engine2~postTransfer(transfer)
call must replayed,"replayed transfer after restart"
call assert replayed~value["code"]="LEDGER_REPLAY_RECOVERED","transfer durable replay recovered"
call assert ledger2~balanceMinor("RP-SRC")=800000,"replay hydrates but does not re-debit"
call assert ledger2~balanceMinor("RP-DST")=200000,"replay hydrates target once"

hold=holdInstruction("PLACE_HOLD","RP-HOLD-IDEM-1","RP-HOLD-1",300000)
placed=engine2~manageHold(hold)
call must placed,"first hold"
call assert ledger2~availableBalanceMinor("RP-SRC")=500000,"hold available balance"

store3=.FederationBankSqlLedgerStore~new(db,3,15)
ledger3=.FederationBankLedger~new(store3)
call addAccounts ledger3,profile
call must ledger3~hydratePostingsFromStore,"restart posting hydration"
engine3=.FederationBankLedgerEngine~new(ledger3,profiles)
replayHold=engine3~manageHold(hold)
call must replayHold,"replayed hold after restart"
call assert replayHold~value["code"]="HOLD_REPLAY_RECOVERED","hold durable replay recovered"
call assert ledger3~availableBalanceMinor("RP-SRC")=500000,"replayed hold recovered exactly once"

release=holdInstruction("RELEASE_HOLD","RP-HOLD-IDEM-2","RP-HOLD-1",0)
call must engine3~manageHold(release),"release hold"
call assert ledger3~availableBalanceMinor("RP-SRC")=800000,"release restores availability"

store4=.FederationBankSqlLedgerStore~new(db,3,15)
ledger4=.FederationBankLedger~new(store4)
call addAccounts ledger4,profile
call must ledger4~hydratePostingsFromStore,"final posting hydration"
engine4=.FederationBankLedgerEngine~new(ledger4,profiles)
replayRelease=engine4~manageHold(release)
call must replayRelease,"replayed release after restart"
call assert replayRelease~value["code"]="HOLD_REPLAY_RECOVERED","release durable replay recovered"
call assert ledger4~hold("RP-HOLD-1")~status="RELEASED","released hold hydrated"
call assert ledger4~availableBalanceMinor("RP-SRC")=800000,"release replay cannot reserve again"

say "PASS Ledger transfer/hold durable command replay across worker restart"
exit 0

addAccounts: procedure
  use arg ledger,profile
  call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-EUR","FEDERATIONBANK","EUR","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
  call must ledger~addAccount(.FederationBankAccount~new("RP-SRC","CUST-RP","EUR","OFFSHORE_CURRENT","IOM",profile~profileId)),"source"
  call must ledger~addAccount(.FederationBankAccount~new("RP-DST","CUST-RP","EUR","OFFSHORE_CURRENT","IOM",profile~profileId)),"target"
  return
baseInstruction: procedure
  d=.directory~new
  d["commandId"]="RP-CMD"; d["customerId"]="CUST-RP"; d["sourceAccountId"]="RP-SRC"; d["targetAccountId"]="RP-DST"
  d["currency"]="EUR"; d["channel"]="WEB"; d["actorId"]="CUST-RP"; d["requestedAt"]=.DateTime~new~utcIsoDate
  d["productCode"]=""; d["accountId"]=""; d["legalName"]=""; d["dateOfBirth"]=""; d["postcode"]=""; d["addressCountry"]=""
  d["applicantResidence"]=""; d["applicantDomicile"]=""; d["applicantSegment"]="RETAIL"; d["applicantRiskTier"]="STANDARD"; d["details"]=.directory~new
  d["securityPolicyId"]="FB-BOUNCER"; d["securityPolicyVersion"]="1"; d["securityDisposition"]="ALLOW"
  d["corporatePolicyId"]="FB-CUSTOMER-TXN-LIMITS"; d["corporatePolicyVersion"]="1"; d["corporatePolicyRuleId"]="EUR-RETAIL-WEB"
  d["legalProfileId"]="FB-LEGAL-EUR"; d["legalGenerationId"]="FB-LEGAL-EUR"; d["legalGenerationVersion"]="1"; d["regulatoryProfileId"]="FB-IOM-EUR"
  return d
transferInstruction: procedure
  d=baseInstruction()
  d["schema"]="federationbank.ledger.post-transfer/0.3"; d["operation"]="TRANSFER"; d["commandId"]="RP-TX-CMD"; d["idempotencyKey"]="RP-TX-IDEM"; d["transactionId"]="RP-TX-IDEM"; d["amountMinor"]=200000
  return d
holdInstruction: procedure
  use arg op,idem,holdId,amount
  d=baseInstruction()
  d["schema"]="federationbank.ledger.hold/0.5"; d["operation"]=op; d["commandId"]="CMD-"||idem; d["idempotencyKey"]=idem; d["amountMinor"]=amount; d["holdId"]=holdId
  details=.directory~new; details["holdId"]=holdId; d["details"]=details
  if op="RELEASE_HOLD" then d["corporatePolicyRuleId"]="EUR-RETAIL-RELEASE-HOLD-WEB"
  else d["corporatePolicyRuleId"]="EUR-RETAIL-HOLD-WEB"
  return d
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
