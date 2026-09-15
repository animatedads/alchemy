parse source . . script
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
at = .DateTime~new

m1 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
t1 = .FederationBankServiceTopology~new(m1)
u1 = .FederationBankPaymentsUsageProjection~new(t1~topics)
call assert u1~usedMinor("CUST-001","USD",at) = 0, "initial usage zero"
call must u1~recordCommitted("CUST-001","USD",100000,at,"TX-U-1"), "first usage event"
call must u1~recordCommitted("CUST-001","USD",250000,at,"TX-U-2"), "second usage event"
call assert u1~usedMinor("CUST-001","USD",at) = 350000, "live usage aggregate"
call assert t1~topics~retainedPublications~items = 2, "one retained fact per committed transaction"
/* Redelivery of the same committed tx must not increment the projection. */
rdup = u1~recordCommitted("CUST-001","USD",100000,at,"TX-U-1")
call must rdup, "duplicate usage event"
call assert u1~usedMinor("CUST-001","USD",at) = 350000, "duplicate tx idempotent"

/* New queue manager + topic fabric simulates Payments worker restart. */
m2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
t2 = .FederationBankServiceTopology~new(m2)
u2 = .FederationBankPaymentsUsageProjection~new(t2~topics)
call assert u2~usedMinor("CUST-001","USD",at) = 350000, "usage rebuilt from retained queue facts"
call assert u2~hasTransaction("TX-U-1"), "first tx marker recovered"
call assert u2~hasTransaction("TX-U-2"), "second tx marker recovered"
call must u2~recordCommitted("CUST-001","USD",50000,at,"TX-U-3"), "post-restart usage event"
call assert u2~usedMinor("CUST-001","USD",at) = 400000, "post-restart increment"

m3 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
t3 = .FederationBankServiceTopology~new(m3)
u3 = .FederationBankPaymentsUsageProjection~new(t3~topics)
call assert u3~usedMinor("CUST-001","USD",at) = 400000, "second restart stable"
call assert t3~topics~retainedPublications~items = 3, "retained usage event history stable"
say "PASS Payments usage projection rebuilds from durable retained Queue Fabric facts"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
