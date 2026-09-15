profiles = .FederationBankRegulatoryProfileRegistry~standard
executor = .FederationBankFixtureSqlExecutor~new
db = .FederationBankFixtures~database(executor)
store = .FederationBankSqlLedgerStore~new(db,3,15)
ledger = .FederationBankLedger~new(store)
profile = profiles~byCurrency("USD")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)), "settlement"
call must ledger~addAccount(.FederationBankAccount~new("HOLD-SRC","CUST-HOLD","USD","OFFSHORE_CURRENT","IOM",profile~profileId)), "source"
call must ledger~addAccount(.FederationBankAccount~new("HOLD-DST","CUST-HOLD","USD","OFFSHORE_CURRENT","IOM",profile~profileId)), "destination"
call must ledger~postTransfer("HOLD-SEED","FB-SETTLEMENT-USD","HOLD-SRC",1000000,"USD"), "seed"
call assert ledger~balanceMinor("HOLD-SRC") = 1000000, "seed book balance"
call assert ledger~availableBalanceMinor("HOLD-SRC") = 1000000, "seed available balance"

evidence = authorityEvidence()
receipt = holdReceipt("CMD-HOLD-1","IDEM-HOLD-1","PLACE_HOLD","H-001",300000)
placed = ledger~placeHold("H-001","HOLD-SRC","CUST-HOLD",300000,"USD",.DateTime~new,evidence,receipt)
call must placed, "place hold"
call assert ledger~balanceMinor("HOLD-SRC") = 1000000, "hold does not change book balance"
call assert ledger~activeHeldMinor("HOLD-SRC") = 300000, "active held amount"
call assert ledger~availableBalanceMinor("HOLD-SRC") = 700000, "hold reduces available balance"

blocked = ledger~postTransfer("HOLD-BLOCKED","HOLD-SRC","HOLD-DST",800000,"USD")
call assert blocked~ok = .false, "transfer cannot spend held funds"
call assert blocked~code = "INSUFFICIENT_AVAILABLE_FUNDS", "available funds failure explicit"
call assert ledger~balanceMinor("HOLD-SRC") = 1000000, "blocked transfer no book movement"

allowed = ledger~postTransfer("HOLD-ALLOWED","HOLD-SRC","HOLD-DST",700000,"USD")
call must allowed, "transfer up to available amount"
call assert ledger~balanceMinor("HOLD-SRC") = 300000, "book balance after transfer"
call assert ledger~availableBalanceMinor("HOLD-SRC") = 0, "active hold still reserves remainder"

releaseReceipt = holdReceipt("CMD-HOLD-2","IDEM-HOLD-2","RELEASE_HOLD","H-001",0)
released = ledger~releaseHold("H-001","CUST-HOLD",.DateTime~new,evidence,releaseReceipt)
call must released, "release hold"
call assert ledger~hold("H-001")~status = "RELEASED", "hold released"
call assert ledger~balanceMinor("HOLD-SRC") = 300000, "release does not change book balance"
call assert ledger~availableBalanceMinor("HOLD-SRC") = 300000, "release restores availability"

say "PASS Ledger-owned holds preserve book balance and constrain available funds"
exit 0

authorityEvidence: procedure
  d=.directory~new
  d["securityPolicyId"]="FB-BOUNCER"; d["securityPolicyVersion"]="1"; d["securityDisposition"]="ALLOW"
  d["corporatePolicyId"]="FB-CUSTOMER-TXN-LIMITS"; d["corporatePolicyVersion"]="1"; d["corporatePolicyRuleId"]="USD-RETAIL-HOLD-WEB"
  d["legalProfileId"]="FB-LEGAL-USD"; d["legalGenerationId"]="FB-LEGAL-USD"; d["legalGenerationVersion"]="1"; d["regulatoryProfileId"]="FB-IOM-USD"
  return d
holdReceipt: procedure
  use arg commandId,idem,op,holdId,amount
  d=.directory~new
  d["commandId"]=commandId; d["idempotencyKey"]=idem; d["operation"]=op; d["outcome"]="ACCEPTED"
  d["customerId"]="CUST-HOLD"; d["accountId"]="HOLD-SRC"; d["transactionId"]=holdId; d["currency"]="USD"; d["amountMinor"]=amount
  d["regulatoryProfileId"]="FB-IOM-USD"; d["securityPolicyId"]="FB-BOUNCER"; d["securityPolicyVersion"]="1"; d["securityDisposition"]="ALLOW"
  d["corporatePolicyId"]="FB-CUSTOMER-TXN-LIMITS"; d["corporatePolicyVersion"]="1"; d["corporatePolicyRuleId"]="USD-RETAIL-HOLD-WEB"
  d["legalProfileId"]="FB-LEGAL-USD"; d["legalGenerationId"]="FB-LEGAL-USD"; d["legalGenerationVersion"]="1"; d["createdAt"]=.DateTime~new~utcIsoDate
  d["holdId"]=holdId
  if op="PLACE_HOLD" then d["holdStatus"]="ACTIVE"
  else d["holdStatus"]="RELEASED"
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
