root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
env = .FederationBankFixtures~freshEnvironment
e = env["engine"]
ext = env["external"]
q = .FederationBankQueueService~new(e, root)
cmd = .FederationBankCommand~new("Q-OPEN-NEW", "OPEN_ACCOUNT", "Q-OPEN-NEW-IDEM", "CUST-Q-NEW", "", "", "EUR", 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", "EUR-Q-NEW", "Queue Applicant", "1992-11-12", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
call qmust q~submit(cmd), "submit opening request"
handled = q~processOne
call must handled, "process opening request"
call assert handled~value["outcome"] = "ACCEPTED", "Engine accepts opening"
call assert ext["civicTransport"]~calls = 1, "Engine invoked CivicPort behind queue boundary"
call assert ext["creditAgency"]~calls = 1, "Engine invoked credit agency behind queue boundary"
call assert e~customers~customer("CUST-Q-NEW") <> .nil, "Engine created customer"
call assert e~ledger~account("EUR-Q-NEW") <> .nil, "Engine created account"
res = q~getResult
call qmust res, "receive opening result"
payload = res~value~payload
call assert payload["commandId"] = "Q-OPEN-NEW", "result correlated to request"
call assert payload["outcome"] = "ACCEPTED", "structured accepted outcome published"
call assert payload["corporatePolicyId"] = "FB-ACCOUNT-OPENING", "opening policy provenance published"
call assert payload["legalGenerationId"] = "FB-LEGAL-EUR", "EUR Legal Effect provenance published"
call assert payload["addressContractGeneration"] = "civic.postcode.lookup/0.1", "CivicPort provenance published"
call assert payload["creditBureauReference"] <> "", "credit bureau reference published"
say "PASS queue -> Engine-owned CivicPort/credit checks -> DB -> result for new account"
exit 0
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
::requires "FederationBankQueueService.cls"
::requires "FederationBankFixtures.cls"
