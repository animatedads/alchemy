/* A valid relationship decision only creates a STAFF-channel bank command.
 * The unmodified FederationBank v0.9 fixture policy has no STAFF rule, so Core
 * Banking rejects it. This is intentional evidence that adapter authority does
 * not bypass corporate banking policy. */
e=.FederationBankFixtures~engine
now=.DateTime~new
dec=.FederationBankRelationshipDecision~new("DEC-CORE-1","CASE-CORE","E-CORE","CUST-001","FB-STAFF-AUTH","STAFF_TRANSACTION_AUTHORITY","AUTH:CORE:1","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","POL:CORE:1","",now)~seal
el=.FBRelationshipTestSupport~decisionElement("E-CORE","FB-STAFF-AUTH","AUTH:CORE:1","STAFF_TRANSACTION_AUTHORITY")
req=.FederationBankRelationshipActionRequest~new("REQ-CORE","CMD-CORE","IDEM-CORE","CASE-CORE","CUST-001","TRANSFER","TELLER-9","TELLER",now,"USD-SRC","USD-DST","USD",250000)~seal
adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
translated=adapter~translate(dec,req,el)
.FBRelationshipTestSupport~assertTrue(translated~ok,"translation succeeds")
call open e,"USD-SRC","OPEN-SRC"
call open e,"USD-DST","OPEN-DST"
seed=e~ledger~postTransfer("SEED","FB-SETTLEMENT-USD","USD-SRC",2000000,"USD")
.FBRelationshipTestSupport~assertTrue(seed~ok,"seed")
r=e~handle(translated~value~bankCommand)
.FBRelationshipTestSupport~assertFalse(r~ok,"Core Banking independently rejects unconfigured STAFF policy")
.FBRelationshipTestSupport~assertEq("LIMIT_POLICY_NO_RULE",r~code,"Core policy remains final")
.FBRelationshipTestSupport~assertEq(2000000,e~ledger~balanceMinor("USD-SRC"),"no money moved")
.FBRelationshipTestSupport~assertEq(0,e~ledger~balanceMinor("USD-DST"),"no target posting")
.FBRelationshipTestSupport~pass("relationship authority cannot bypass FederationBank policy/legal/Ledger chain")
exit 0
open: procedure
  use arg e,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","USD",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",accountId)
  r=e~handle(c)
  if \r~ok then do; say "FAIL open" accountId r~code r~detail; exit 1; end
  return
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "FederationBankFixtures.cls"
::requires "TestSupport.cls"
