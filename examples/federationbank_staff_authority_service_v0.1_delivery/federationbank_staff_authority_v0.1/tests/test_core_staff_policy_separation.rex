/* Staff authority and customer/corporate banking policy are separate gates. */
e=.FederationBankStaffCorePolicyFixtures~engine
ctx=.FBStaffTestSupport~context("TELLER-04","TELLER","S-CORE")
a=.FBStaffTestSupport~action("A-CORE","TELLER-04","S-CORE",250000)
auth=.FBStaffTestSupport~engine~authorise("ENV-CORE",a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertTrue(auth~ok,"staff authority")
call open e,"GBP-SRC","OPEN-SRC"
call open e,"GBP-DST","OPEN-DST"
seed=e~ledger~postTransfer("SEED","FB-SETTLEMENT-GBP","GBP-SRC",2000000,"GBP")
.FBStaffTestSupport~assertTrue(seed~ok,"seed")
cmd=.FederationBankCommand~new(a~commandId,"TRANSFER",a~idempotencyKey,"CUST-001","GBP-SRC","GBP-DST","GBP",250000,"STAFF","TELLER-04",a~requestedAt)
bound=.FederationBankStaffCommandBinder~bind(a,auth~value["envelope"],cmd)
.FBStaffTestSupport~assertTrue(bound~ok,"bound command")
r=e~handle(bound~value)
.FBStaffTestSupport~assertTrue(r~ok,"Core Banking independently accepts configured STAFF corporate policy")
.FBStaffTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"source committed")
.FBStaffTestSupport~assertEq(250000,e~ledger~balanceMinor("GBP-DST"),"target committed")
/* A valid staff envelope cannot turn a too-large customer transaction into an allow. */
sup=.FBStaffTestSupport~context("SUP-02","SUPERVISOR","S-SUP2")
mgr=.FBStaffTestSupport~context("MGR-01","BRANCH_MANAGER","S-MGR")
a2=.FBStaffTestSupport~action("A-CORE-HIGH","SUP-02","S-SUP2",3000000)
ap=.FederationBankStaffApproval~new("AP-MGR",a2,"MGR-01","S-MGR","BRANCH_MANAGER","EVID:MGR")~seal
au2=.FBStaffTestSupport~engine~authorise("ENV-HIGH",a2,.FBStaffTestSupport~contexts(sup,mgr),.array~of(ap))
.FBStaffTestSupport~assertTrue(au2~ok,"staff authority can reach 30k with checker")
cmd2=.FederationBankCommand~new(a2~commandId,"TRANSFER",a2~idempotencyKey,"CUST-001","GBP-SRC","GBP-DST","GBP",3000000,"STAFF","SUP-02",a2~requestedAt)
b2=.FederationBankStaffCommandBinder~bind(a2,au2~value["envelope"],cmd2)
.FBStaffTestSupport~assertTrue(b2~ok,"high staff authority bound")
r=e~handle(b2~value)
.FBStaffTestSupport~assertFalse(r~ok,"customer/corporate policy still final")
.FBStaffTestSupport~assertEq("CORPORATE_POLICY_DENIED",r~code,"staff authority cannot bypass bank product limits")
.FBStaffTestSupport~pass("staff authority and Core Banking policy remain independent")
exit 0
open: procedure
  use arg e,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"STAFF","TELLER-04",.nil,"OFFSHORE_CURRENT",accountId,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  r=e~handle(c)
  if \r~ok then do; say "FAIL open" accountId r~code r~detail; exit 1; end
  return
::requires "FederationBankStaffCorePolicyFixtures.cls"
::requires "TestSupport.cls"
