e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,2000000)
ctx=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
req=.FBStaffChannelServiceTestSupport~request("RECOVER")
root="/tmp/fbstaffch-recover-"||time("S")||"-"||random(100000,999999)
store=.FederationBankStaffChannelServiceStore~new(root)
real=.FederationBankStaffChannelEngineCorePort~new(e); flaky=.FBStaffChannelFailOnceCorePort~new(real)
svc=.FBStaffChannelServiceTestSupport~service(e,store,.nil,.nil,flaky)
env=.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:RECOVER",req,.FBStaffChannelServiceTestSupport~contexts(ctx))
r=svc~handle(env)
.FBStaffChannelServiceTestSupport~assertFalse(r~ok,"simulated transport failure surfaced")
.FBStaffChannelServiceTestSupport~assertEq("CORE_PORT_UNAVAILABLE",r~code,"transport classification")
.FBStaffChannelServiceTestSupport~assertEq(2000000,e~ledger~balanceMinor("GBP-SRC"),"Core not invoked")
/* New service instance loads the previously committed READY_FOR_CORE state.
 * Replaying the same service command safely continues it. */
svc2=.FBStaffChannelServiceTestSupport~service(e,store)
w=svc2~state~work(req~workId)
.FBStaffChannelServiceTestSupport~assertEq("READY_FOR_CORE",w~state,"write-ahead state recovered")
r=svc2~handle(env)
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"same command resumes")
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",r~value~state,"completed after recovery")
.FBStaffChannelServiceTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"posted exactly once")
.FBStaffChannelServiceTestSupport~pass("READY_FOR_CORE is durable before Core submission and restart-safe")
::requires "FederationBankStaffChannelServicePersistence.cls"
::requires "TestSupport.cls"
