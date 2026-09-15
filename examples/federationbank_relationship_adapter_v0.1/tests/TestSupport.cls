::class FBRelationshipTestSupport public
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
::method decisionElement class
  use arg elementId,sourceSystem,sourceRef,authorityClass,semanticKind="BANK_ACTION_DECISION"
  return .RelationshipCaseElement~new(elementId,"DECISION",semanticKind,"AUTHORISES_BANK_ACTION",sourceSystem,sourceRef,authorityClass,.nil,"RESTRICTED")~seal
::requires "RelationshipCase.cls"
