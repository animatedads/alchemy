/* External checks and policy referrals are non-monetary outcomes: no customer,
   account or ledger truth may appear. */

/* CivicPort failure */
env = .FederationBankFixtures~freshEnvironment
e = env["engine"]
ext = env["external"]
ext["civicTransport"]~failNext
cmd = newOpen("OPEN-CIVIC-FAIL", "IDEM-CIVIC-FAIL", "CUST-CIVIC-FAIL", "GBP-CIVIC-FAIL")
basePostings = e~ledger~postings~items
r = e~handle(cmd)
call assert \r~ok, "Civic failure rejects opening"
call assert r~code = "ADDRESS_VERIFICATION_REJECTED", "Civic failure classification"
call assert r~value["outcome"] = "REJECTED", "Civic failure is structured rejection"
call assert e~customers~customer("CUST-CIVIC-FAIL") == .nil, "Civic failure creates no customer"
call assert e~ledger~account("GBP-CIVIC-FAIL") == .nil, "Civic failure creates no account"
call assert e~ledger~postings~items = basePostings, "Civic failure is non-monetary"
call assert ext["creditAgency"]~calls = 0, "credit agency not called after failed address"

/* Credit bureau timeout/refusal */
env2 = .FederationBankFixtures~freshEnvironment
e2 = env2["engine"]
ext2 = env2["external"]
ext2["creditAgency"]~failNext
cmd2 = newOpen("OPEN-CREDIT-FAIL", "IDEM-CREDIT-FAIL", "CUST-CREDIT-FAIL", "EUR-CREDIT-FAIL", "EUR")
r2 = e2~handle(cmd2)
call assert \r2~ok, "credit timeout rejects opening"
call assert r2~code = "CREDIT_SCORE_REJECTED", "credit failure classification"
call assert r2~value["outcome"] = "REJECTED", "credit failure structured rejection"
call assert e2~customers~customer("CUST-CREDIT-FAIL") == .nil, "credit failure creates no customer"
call assert e2~ledger~account("EUR-CREDIT-FAIL") == .nil, "credit failure creates no account"
call assert e2~ledger~postings~items = 0, "credit failure has no ledger postings"

/* Corporate opening policy referral: bureau supplies facts; policy decides. */
env3 = .FederationBankFixtures~freshEnvironment
e3 = env3["engine"]
ext3 = env3["external"]
ext3["creditAgency"]~setScore(600)
cmd3 = newOpen("OPEN-REFER", "IDEM-REFER", "CUST-REFER", "AUD-REFER", "AUD")
r3 = e3~handle(cmd3)
call assert \r3~ok, "policy referral does not open account"
call assert r3~code = "ACCOUNT_OPEN_REFERRED", "referral classification"
call assert r3~value["outcome"] = "REFERRED", "structured referral outcome"
call assert r3~value["reason"] = "CREDIT_POLICY_REFER", "Institutional Policy owns referral threshold"
call assert r3~value["corporatePolicyId"] = "FB-ACCOUNT-OPENING", "opening policy provenance retained"
call assert e3~customers~customer("CUST-REFER") == .nil, "referred applicant not persisted as customer"
call assert e3~ledger~account("AUD-REFER") == .nil, "referred account not created"
call assert e3~ledger~postings~items = 0, "referral non-monetary"

say "PASS account-opening external failures/referral create no customer/account/ledger state"
exit 0

newOpen: procedure
  use arg commandId, idem, customerId, accountId, currency = "GBP"
  return .FederationBankCommand~new(commandId, "OPEN_ACCOUNT", idem, customerId, "", "", currency, 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", accountId, "Test Applicant", "1990-05-06", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
