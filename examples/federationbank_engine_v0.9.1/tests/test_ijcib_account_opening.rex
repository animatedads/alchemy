/* The Account Engine owns CivicPort + IJCIB.  IJCIB returns evidence, and
   FederationBank Institutional Policy owns the banking outcome. */
env = .FederationBankFixtures~freshIJCIBEnvironment
e = env["engine"]
ext = env["external"]
cmd = newOpen("IJCIB-OPEN-ACCEPT-1", "IJCIB-IDEM-ACCEPT-1", "CUST-IJCIB-ACCEPT", "GBP-IJCIB-ACCEPT")
r = e~handle(cmd)
call must r, "IJCIB account opening"
call assert r~value["outcome"] = "ACCEPTED", "qualified bureau product accepted by bank fixture policy"
call assert ext["civicTransport"]~calls = 1, "CivicPort called first"
call assert ext["creditAgency"]~calls = 1, "IJCIB called by engine"
req = ext["creditAgency"]~lastRequest
call assert req~subjectAddressReference = r~value["addressVerificationReference"], "IJCIB gets CivicPort token, not raw browser authority"
call assert req~requestedProductCode = "FB-IJCIB-FIXTURE-GBP", "IJCIB product selected by Institutional Policy"
call assert r~value["creditStatus"] = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS", "bureau disposition retained"
call assert r~value["creditMethodologyVersion"] = "IJCIB-METH-2026.3-REDACTED", "methodology retained"
call assert e~customers~customer("CUST-IJCIB-ACCEPT") <> .nil, "customer created only after all gates"
call assert e~ledger~account("GBP-IJCIB-ACCEPT") <> .nil, "account created only after all gates"
sql = env["executor"]~lastCommand~stdinText
call assert sql~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE;") > 0, "account opening one serializable transaction"
call assert sql~pos("federationbank_customers") > 0, "customer row atomic"
call assert sql~pos("federationbank_accounts") > 0, "account row atomic"
call assert sql~pos("federationbank_credit_intelligence_evidence") > 0, "full IJCIB evidence row atomic"
call assert sql~pos("federationbank_command_receipts") > 0, "durable receipt atomic"
call assert sql~upper~pos(c2x("IJCIB.QUAL.FIXTURE.OPAQUE")) > 0, "opaque bureau evidence persisted without decoding"
call assert sql~pos("COMMIT;") > 0, "single commit"

/* A suppressed score is not treated as zero or guessed around.  Corporate
   policy refers the application and creates no customer/account. */
env2 = .FederationBankFixtures~freshIJCIBEnvironment
env2["external"]["creditAgency"]~suppress("IJCIB.SUPPRESSION.OPAQUE")
e2 = env2["engine"]
cmd2 = newOpen("IJCIB-OPEN-SUPPRESS-1", "IJCIB-IDEM-SUPPRESS-1", "CUST-IJCIB-SUPPRESS", "EUR-IJCIB-SUPPRESS", "EUR")
r2 = e2~handle(cmd2)
call assert \r2~ok, "suppressed evidence does not open account"
call assert r2~code = "ACCOUNT_OPEN_REFERRED", "suppression maps to bank referral"
call assert r2~value["reason"] = "IJCIB_EVIDENCE_SUPPRESSED", "referral reason is bank policy semantics"
call assert e2~customers~customer("CUST-IJCIB-SUPPRESS") == .nil, "referred customer not persisted"
call assert e2~ledger~account("EUR-IJCIB-SUPPRESS") == .nil, "referred account not persisted"

/* Bureau-side referral stays referral.  The bank does not decode its reasons. */
env3 = .FederationBankFixtures~freshIJCIBEnvironment
env3["external"]["creditAgency"]~setDisposition("INTELLIGENCE_PRODUCT_RELEASED_SUBJECT_TO_REFERRAL")
e3 = env3["engine"]
r3 = e3~handle(newOpen("IJCIB-OPEN-REFER-1", "IJCIB-IDEM-REFER-1", "CUST-IJCIB-REFER", "AUD-IJCIB-REFER", "AUD"))
call assert \r3~ok & r3~code = "ACCOUNT_OPEN_REFERRED", "bureau referral remains non-monetary referral"
call assert r3~value["reason"] = "IJCIB_PRODUCT_REQUIRES_REFERRAL", "published disposition drives bank policy"
call assert e3~customers~customer("CUST-IJCIB-REFER") == .nil, "bureau referral no customer state"
say "PASS engine-owned CivicPort -> sealed IJCIB evidence -> Institutional Policy -> atomic account opening"
exit 0

newOpen: procedure
  use arg commandId, idem, customerId, accountId, currency = "GBP"
  return .FederationBankCommand~new(commandId, "OPEN_ACCOUNT", idem, customerId, "", "", currency, 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", accountId, "IJCIB Test Applicant", "1990-05-06", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
