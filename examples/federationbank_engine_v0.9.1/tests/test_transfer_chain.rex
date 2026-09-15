e = .FederationBankFixtures~engine
call open e, "USD-SRC", "OPEN-SRC"
call open e, "USD-DST", "OPEN-DST"
seed = e~ledger~postTransfer("SEED", "FB-SETTLEMENT-USD", "USD-SRC", 2000000, "USD")
call must seed, "seed"
beforeCount = e~ledger~postings~items
cmd = .FederationBankCommand~new("TX-CMD-1", "TRANSFER", "TX-IDEM-1", "CUST-001", "USD-SRC", "USD-DST", "USD", 250000, "WEB", "CUST-001")
r = e~handle(cmd)
call must r, "transfer"
call assert r~value["securityDisposition"] = "ALLOW", "bouncer allow"
call assert r~value["securityPolicyId"] = "FB-BOUNCER", "bouncer policy provenance"
call assert r~value["corporatePolicyId"] = "FB-CUSTOMER-TXN-LIMITS", "corporate policy id"
call assert r~value["corporatePolicyVersion"] = "1", "corporate policy version"
call assert r~value["corporatePolicyRuleId"] = "USD-RETAIL-WEB", "corporate policy rule"
call assert r~value["regulatoryProfileId"] = "FB-IOM-USD", "regulatory profile"
call assert r~value["legalGenerationId"] = "FB-LEGAL-USD", "legal generation"
call assert e~ledger~balanceMinor("USD-SRC") = 1750000, "source balance"
call assert e~ledger~balanceMinor("USD-DST") = 250000, "target balance"
call assert e~ledger~postings~items = beforeCount + 2, "exactly two postings"
pair = e~ledger~transactionPostings("TX-IDEM-1")
call assert pair~items = 2, "transaction pair count"
call assert pair[1]~amountMinor + pair[2]~amountMinor = 0, "double entry balances to zero"
say "PASS transfer bouncer -> corporate policy -> legal effect -> ledger"
exit 0
open: procedure
  use arg e, accountId, idem
  c=.FederationBankCommand~new("CMD-" || idem,"OPEN_ACCOUNT",idem,"CUST-001","","","USD",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",accountId)
  call must e~handle(c), "open " || accountId
  return
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
