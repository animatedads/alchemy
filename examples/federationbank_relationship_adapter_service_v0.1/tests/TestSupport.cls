::class FBRelationshipServiceTestSupport public
::method assertTrue class
  use arg condition,message="assertTrue failed"
  if \condition then raise syntax 88.990 array(message)
::method assertFalse class
  use arg condition,message="assertFalse failed"
  if condition then raise syntax 88.991 array(message)
::method assertEq class
  use arg expected,actual,message="assertEq failed"
  if expected~string\=actual~string then raise syntax 88.992 array(message,"expected="||expected,"actual="||actual)
::method pass class
  use arg name
  say "PASS:" name
::method fixture class
  catalog=.FederationBankRelationshipPolicyFixtures~publishedCatalog
  adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(catalog))
  return adapter
::method transaction class
  use arg id="1",operation="TRANSFER",customerId="CUST-001"
  now=.DateTime~new; decId="DEC-"||id; elemId="E-"||id; authRef="AUTH:"||id
  if operation="NONE" then do; authority="COMPLIANCE_DECISION"; actionClass="NO_BANK_ACTION"; actorRole="COMPLIANCE"; actorId="CMP-1"; end
  else do; authority="STAFF_TRANSACTION_AUTHORITY"; actionClass="CUSTOMER_INSTRUCTION_VALIDATED"; actorRole="TELLER"; actorId="TEL-1"; end
  dec=.FederationBankRelationshipDecision~new(decId,"CASE-"||id,elemId,customerId,"FB-AUTH",authority,authRef,actionClass,operation,"POL:"||id,"",now)~seal
  el=.RelationshipCaseElement~new(elemId,"DECISION",actionClass,"AUTHORISES_BANK_ACTION","FB-AUTH",authRef,authority,now,"RESTRICTED")~seal
  req=.FederationBankRelationshipActionRequest~new("ACTION-"||id,"BANKCMD-"||id,"IDEM-"||id,"CASE-"||id,customerId,operation,actorId,actorRole,now,"SRC-"||id,"DST-"||id,"USD",1000)~seal
  d=.directory~new; d["decision"]=dec; d["caseElement"]=el; d["request"]=req; return d
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "RelationshipCase.cls"
