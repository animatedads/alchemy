/* Relationship decision authority + staff actor authority + customer/core
 * policy are independent gates in one executable chain. */
now=.DateTime~new
caseEl=.RelationshipCaseElement~new("E-CHAIN","DECISION","BANK_ACTION_DECISION","AUTHORISES_BANK_ACTION","FB-STAFF-AUTH","AUTH:CHAIN","STAFF_TRANSACTION_AUTHORITY",.nil,"RESTRICTED")~seal
dec=.FederationBankRelationshipDecision~new("DEC-CHAIN","CASE-CHAIN","E-CHAIN","CUST-001","FB-STAFF-AUTH","STAFF_TRANSACTION_AUTHORITY","AUTH:CHAIN","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:CHAIN","",now)~seal
req=.FederationBankRelationshipActionRequest~new("REQ-CHAIN","CMD-CHAIN","IDEM-CHAIN","CASE-CHAIN","CUST-001","TRANSFER","TELLER-04","TELLER",now,"GBP-SRC","GBP-DST","GBP",250000)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
tr=adapter~translate(dec,req,caseEl)
.FBStaffTestSupport~assertTrue(tr~ok,"relationship authority translation")
ctx=.FBStaffTestSupport~context("TELLER-04","TELLER","S-CHAIN")
a=.FederationBankRelationshipStaffAuthorityBridge~actionFromTranslation("ACT-CHAIN",tr~value,ctx)
.FBStaffTestSupport~assertTrue(a~ok,"relationship command becomes staff action, not staff authority")
staff=.FBStaffTestSupport~engine~authorise("ENV-CHAIN",a~value,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertTrue(staff~ok,"staff authority independently satisfied")
bound=.FederationBankStaffCommandBinder~bind(a~value,staff~value["envelope"],tr~value~bankCommand)
.FBStaffTestSupport~assertTrue(bound~ok,"same translated command bound to staff authority")
e=.FederationBankStaffCorePolicyFixtures~engine
call open e,"GBP-SRC","OPEN-SRC"
call open e,"GBP-DST","OPEN-DST"
.FBStaffTestSupport~assertTrue(e~ledger~postTransfer("SEED-CHAIN","FB-SETTLEMENT-GBP","GBP-SRC",1000000,"GBP")~ok,"seed")
r=e~handle(bound~value)
.FBStaffTestSupport~assertTrue(r~ok,"Core Banking independently accepts")
.FBStaffTestSupport~assertEq(750000,e~ledger~balanceMinor("GBP-SRC"),"source committed")
.FBStaffTestSupport~assertEq(250000,e~ledger~balanceMinor("GBP-DST"),"target committed")
.FBStaffTestSupport~assertEq("CASE-CHAIN",bound~value~detail("relationshipCaseId"),"relationship evidence survives")
.FBStaffTestSupport~assertEq("ENV-CHAIN",bound~value~detail("staffAuthorityEnvelopeId"),"staff evidence survives")
.FBStaffTestSupport~pass("relationship authority + staff authority + Core Banking policy chain")
exit 0
open: procedure
  use arg e,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"STAFF","TELLER-04",.nil,"OFFSHORE_CURRENT",accountId,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  r=e~handle(c); if \r~ok then raise syntax 98.900 array("open failed "||accountId||" "||r~code)
  return
::requires "FederationBankRelationshipStaffAuthorityBridge.cls"
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "FederationBankStaffCorePolicyFixtures.cls"
::requires "TestSupport.cls"
