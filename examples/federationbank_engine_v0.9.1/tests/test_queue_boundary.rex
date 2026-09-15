parse source . . script
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
e=.FederationBankFixtures~engine
q=.FederationBankQueueService~new(e,root)
open=.FederationBankCommand~new("Q-OPEN","OPEN_ACCOUNT","Q-OPEN-IDEM","CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT","GBP-Q1")
put=q~submit(open)
call qmust put,"submit open"
handled=q~processOne
call must handled,"process open"
call assert handled~value["regulatoryProfileId"]="FB-IOM-GBP","queued GBP regulatory route"
res=q~getResult
call qmust res,"get result"
payload=res~value~payload
call assert payload["commandId"]="Q-OPEN","result command id"
call assert payload["regulatoryProfileId"]="FB-IOM-GBP","result regulatory provenance"
call assert payload["legalGenerationId"]="FB-LEGAL-GBP","result legal provenance"
call assert q~manager~depth(q~OPS_QUEUE,q~WORKER_PRINCIPAL)~value["total"]=0,"ops queue drained"
say "PASS durable queue boundary + result audit payload"
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
