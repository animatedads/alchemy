root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology = .FederationBankServiceTopology~new(manager)
aenv = .FederationBankFixtures~freshAccountEnvironment
accountEngine = .FederationBankAccountEngine~new(aenv["authority"])
pCustomers = .FederationBankCustomerRegistry~new
pAccounts = .FederationBankLedger~new
profiles = .FederationBankRegulatoryProfileRegistry~standard
usage = .FederationBankPaymentsUsageProjection~new(topology~topics)
paymentsEngine = .FederationBankPaymentsEngine~new(pCustomers, pAccounts, profiles, .FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog), .FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry), .FederationBankBouncer~new(.FederationBankBouncer~standardFramework), usage)
runtime = .FederationBankBackendRuntime~new(topology, accountEngine, paymentsEngine, .nil)

open = .FederationBankCommand~new("QB-OPEN-1","OPEN_ACCOUNT","QB-OPEN-IDEM-1","CUST-QB","","","AUD",0,"WEB","CUST-QB",.nil,"OFFSHORE_CURRENT","QB-AUD-1","Queue Beneficiary Customer","1989-09-09","2000","AU","AU","AU","RETAIL","STANDARD")
call qmust runtime~submitOpenAccount(open), "queue account opening request"
call must runtime~processAccountOne, "Account Engine opens account"
call must runtime~processPaymentsProjectionOne, "Payments receives owning account projection"
call qmust runtime~getAccountResult, "account opening result"

d = .directory~new
d["beneficiaryId"] = "QB-BEN-1"
d["displayName"] = "Sydney Recipient"
d["accountReference"] = "AU-TEST-0001"
d["bankCode"] = "TESTAU2S"
d["country"] = "AU"
d["currency"] = "AUD"
add = .FederationBankCommand~new("QB-BEN-ADD-1","ADD_BENEFICIARY","QB-BEN-IDEM-1","CUST-QB","","","AUD",0,"WEB","CUST-QB",.nil,"","QB-AUD-1","","","","","","","RETAIL","STANDARD",d)
call qmust runtime~submitBeneficiary(add), "channel submits beneficiary request"
handled = runtime~processAccountOne
call must handled, "Account Engine executes beneficiary request"
call assert handled~value["legalGenerationId"] = "FB-LEGAL-AUD", "AUD beneficiary operation uses AUD Legal Effect generation"
call must runtime~processPaymentsBeneficiaryProjectionOne, "Payments receives approved beneficiary projection"
projected = paymentsEngine~beneficiaries~beneficiary("CUST-QB","QB-BEN-1")
call assert projected <> .nil, "Payments has beneficiary read model"
call assert projected~accountReference = "AU-TEST-0001", "Payments projection preserves beneficiary account reference"
res = runtime~getAccountResult
call qmust res, "channel receives beneficiary result"
call assert res~value~payload["beneficiaryId"] = "QB-BEN-1", "channel sees approved beneficiary projection result"

found = .false
do publication over topology~topics~retainedPublications
  if publication~topicName <> .FederationBankServiceTopology~BENEFICIARY_STATE_TOPIC then iterate
  p = publication~payload
  if p["beneficiaryId"] <> "QB-BEN-1" then iterate
  call assert p["schema"] = "federationbank.beneficiary.projection/0.4", "beneficiary projection schema"
  call assert p["status"] = "ACTIVE", "retained beneficiary state active"
  call assert p["version"] = 1, "retained beneficiary version"
  found = .true
end
call assert found, "beneficiary state retained by Queue Fabric"

/* Retention is durable across queue-manager restart. */
manager2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology2 = .FederationBankServiceTopology~new(manager2)
found2 = .false
do publication over topology2~topics~retainedPublications
  if publication~topicName = .FederationBankServiceTopology~BENEFICIARY_STATE_TOPIC then if publication~payload["beneficiaryId"] = "QB-BEN-1" then found2 = .true
end
call assert found2, "beneficiary retained projection survives queue-manager restart"

/* A new Payments worker rebuilds account and beneficiary read models from
   retained state; it receives no authority to mutate Account Engine truth. */
pCustomers2 = .FederationBankCustomerRegistry~new
pAccounts2 = .FederationBankLedger~new
usage2 = .FederationBankPaymentsUsageProjection~new(topology2~topics)
payments2 = .FederationBankPaymentsEngine~new(pCustomers2, pAccounts2, profiles, .FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog), .FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry), .FederationBankBouncer~new(.FederationBankBouncer~standardFramework), usage2)
call must payments2~rebuildAccountProjections(topology2~topics), "Payments rebuilds account read model"
call must payments2~rebuildBeneficiaryProjections(topology2~topics), "Payments rebuilds beneficiary read model"
recovered = payments2~beneficiaries~beneficiary("CUST-QB","QB-BEN-1")
call assert recovered <> .nil, "Payments beneficiary projection rebuilt after restart"
call assert recovered~status = "ACTIVE", "Payments restart preserves beneficiary status"

say "PASS channel -> Queue Fabric -> Account Engine beneficiary lifecycle -> Payments read model + retained restart"
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
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
