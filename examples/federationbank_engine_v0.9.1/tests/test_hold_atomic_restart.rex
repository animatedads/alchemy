profiles=.FederationBankRegulatoryProfileRegistry~standard
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
profile=profiles~byCurrency("GBP")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("HOLD-GBP","CUST-HR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"account"
call must ledger~postTransfer("HR-SEED","FB-SETTLEMENT-GBP","HOLD-GBP",1000000,"GBP"),"seed"

evidence=authorityEvidence()
receipt=holdReceipt("HR-CMD-1","HR-IDEM-1","PLACE_HOLD","HR-HOLD",400000)
executor~failNext
failed=ledger~placeHold("HR-HOLD","HOLD-GBP","CUST-HR",400000,"GBP",.DateTime~new,evidence,receipt)
call assert failed~ok=.false,"injected hold write fails"
call assert failed~code="HOLD_DATABASE_ROLLBACK","hold rollback explicit"
call assert ledger~hold("HR-HOLD")=.nil,"failed SQL creates no hold projection"
call assert ledger~availableBalanceMinor("HOLD-GBP")=1000000,"failed SQL changes no availability"
call must ledger~placeHold("HR-HOLD","HOLD-GBP","CUST-HR",400000,"GBP",.DateTime~new,evidence,receipt),"retry same logical hold"
call assert ledger~availableBalanceMinor("HOLD-GBP")=600000,"retry creates hold once"

/* Fresh Ledger process: account metadata is reconstructed elsewhere from the
   retained account topic; hold truth itself is reconstructed from SQL. */
store2=.FederationBankSqlLedgerStore~new(db,3,15)
ledger2=.FederationBankLedger~new(store2)
call must ledger2~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"restart settlement"
call must ledger2~addAccount(.FederationBankAccount~new("HOLD-GBP","CUST-HR","GBP","OFFSHORE_CURRENT","IOM",profile~profileId)),"restart account"
call must ledger2~hydratePostingsFromStore,"recover postings"
call must ledger2~hydrateHoldsFromStore,"recover holds"
call assert ledger2~balanceMinor("HOLD-GBP")=1000000,"book balance recovered"
call assert ledger2~hold("HR-HOLD")~status="ACTIVE","active hold recovered"
call assert ledger2~availableBalanceMinor("HOLD-GBP")=600000,"available balance recovered"

releaseReceipt=holdReceipt("HR-CMD-2","HR-IDEM-2","RELEASE_HOLD","HR-HOLD",0)
executor~failNext
releaseFail=ledger2~releaseHold("HR-HOLD","CUST-HR",.DateTime~new,evidence,releaseReceipt)
call assert releaseFail~ok=.false,"injected release write fails"
call assert ledger2~hold("HR-HOLD")~status="ACTIVE","failed release leaves hold active"
call assert ledger2~availableBalanceMinor("HOLD-GBP")=600000,"failed release changes no availability"
call must ledger2~releaseHold("HR-HOLD","CUST-HR",.DateTime~new,evidence,releaseReceipt),"retry release"
call assert ledger2~availableBalanceMinor("HOLD-GBP")=1000000,"release retry restores availability"

say "PASS hold SQL atomicity + restart hydration"
exit 0

authorityEvidence: procedure
  d=.directory~new
  d["securityPolicyId"]="FB-BOUNCER"; d["securityPolicyVersion"]="1"; d["securityDisposition"]="ALLOW"
  d["corporatePolicyId"]="FB-CUSTOMER-TXN-LIMITS"; d["corporatePolicyVersion"]="1"; d["corporatePolicyRuleId"]="GBP-RETAIL-HOLD-WEB"
  d["legalProfileId"]="FB-LEGAL-GBP"; d["legalGenerationId"]="FB-LEGAL-GBP"; d["legalGenerationVersion"]="1"; d["regulatoryProfileId"]="FB-IOM-GBP"
  return d
holdReceipt: procedure
  use arg commandId,idem,op,holdId,amount
  d=.directory~new
  d["commandId"]=commandId; d["idempotencyKey"]=idem; d["operation"]=op; d["outcome"]="ACCEPTED"
  d["customerId"]="CUST-HR"; d["accountId"]="HOLD-GBP"; d["transactionId"]=holdId; d["currency"]="GBP"; d["amountMinor"]=amount
  d["regulatoryProfileId"]="FB-IOM-GBP"; d["securityPolicyId"]="FB-BOUNCER"; d["securityPolicyVersion"]="1"; d["securityDisposition"]="ALLOW"
  d["corporatePolicyId"]="FB-CUSTOMER-TXN-LIMITS"; d["corporatePolicyVersion"]="1"; d["corporatePolicyRuleId"]="GBP-RETAIL-HOLD-WEB"
  d["legalProfileId"]="FB-LEGAL-GBP"; d["legalGenerationId"]="FB-LEGAL-GBP"; d["legalGenerationVersion"]="1"; d["createdAt"]=.DateTime~new~utcIsoDate; d["holdId"]=holdId
  return d
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
