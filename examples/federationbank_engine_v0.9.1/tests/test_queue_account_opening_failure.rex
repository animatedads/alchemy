/* A channel receives a structured non-monetary Engine outcome. It does not
   perform or recover from CivicPort/credit checks itself. */
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end

env = .FederationBankFixtures~freshEnvironment
e = env["engine"]
ext = env["external"]
ext["civicTransport"]~failNext
q = .FederationBankQueueService~new(e, root)
cmd = .FederationBankCommand~new("Q-OPEN-FAIL", "OPEN_ACCOUNT", "Q-OPEN-FAIL-IDEM", "CUST-Q-FAIL", "", "", "GBP", 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", "GBP-Q-FAIL", "Queue Failure Applicant", "1992-11-12", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")

call qmust q~submit(cmd), "submit opening request"
handled = q~processOne
call assert \handled~ok, "Engine rejected failed address verification"
call assert handled~code = "ADDRESS_VERIFICATION_REJECTED", "Engine classification survives queue worker"
call assert e~customers~customer("CUST-Q-FAIL") == .nil, "failed check creates no customer"
call assert e~ledger~account("GBP-Q-FAIL") == .nil, "failed check creates no account"
call assert e~ledger~postings~items = 0, "failed check is non-monetary"
call assert ext["creditAgency"]~calls = 0, "credit agency not called after address failure"

res = q~getResult
call qmust res, "receive failure result"
payload = res~value~payload
call assert payload["commandId"] = "Q-OPEN-FAIL", "failure result correlated"
call assert payload["code"] = "ADDRESS_VERIFICATION_REJECTED", "failure code published"
call assert payload["outcome"] = "REJECTED", "structured rejection outcome published"
call assert payload["reason"] = "ADDRESS_VERIFICATION_FAILED", "structured failure reason published"
call assert payload["corporatePolicyId"] = "FB-ACCOUNT-OPENING", "resolved policy provenance published"
call assert payload["legalGenerationId"] = "FB-LEGAL-GBP", "Legal Effect provenance published"

say "PASS failed Engine external check -> structured non-monetary queue outcome"
exit 0

qmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankQueueService.cls"
::requires "FederationBankFixtures.cls"
