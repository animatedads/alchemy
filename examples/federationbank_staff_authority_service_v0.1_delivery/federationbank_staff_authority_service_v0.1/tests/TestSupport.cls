::class FBStaffServiceTestSupport public
::method assertTrue class
  use arg condition,message="assertTrue failed"
  if \condition then raise syntax 98.900 array(message)
::method assertFalse class
  use arg condition,message="assertFalse failed"
  if condition then raise syntax 98.900 array(message)
::method assertEq class
  use arg expected,actual,message="assertEq failed"
  if expected~string\=actual~string then raise syntax 98.900 array(message||" expected="||expected||" actual="||actual)
::method pass class
  use arg message
  say "PASS:" message
::method engine class
  return .FederationBankStaffAuthorityEngine~new(.FederationBankStaffAuthorityGate~new(.FederationBankStaffAuthorityPolicyFixtures~publishedCatalog))
::method service class
  use arg store=.nil,sink=.nil
  return .FederationBankStaffAuthorityService~new(self~engine,store,sink)
::method principal class
  use arg staffId,branch="DOUGLAS"
  return .FederationBankStaffPrincipalRef~new(staffId,"FB-IAM","IAM:"||staffId,"ACTIVE","FEDERATIONBANK-AUSTRALIA-IOM",branch,"HR:"||staffId)~seal
::method session class
  use arg staffId,sessionId,branch="DOUGLAS",desk="DESK-04"
  return .FederationBankStaffSessionContext~new(sessionId,staffId,branch,desk,"WS:"||desk,"AUTH:"||sessionId,.DateTime~new-.TimeSpan~new(0,5),.DateTime~new+.TimeSpan~new(1,0),"SEC:"||sessionId)~seal
::method assignment class
  use arg staffId,roleClass,branch="DOUGLAS",ops=.nil,maxMinor=0
  id="ASN:"||staffId||":"||roleClass
  return .FederationBankStaffRoleAssignment~new(id,staffId,roleClass,roleClass||"_STANDARD",branch,maxMinor,.DateTime~new-.TimeSpan~new(0,5),.DateTime~new+.TimeSpan~new(1,0),"FB-IAM","IAM:"||id,ops)~seal
::method context class
  use arg staffId,roleClass,sessionId,branch="DOUGLAS",desk="DESK-04",ops=.nil,maxMinor=0
  return .FederationBankStaffContextSnapshot~new("CTX:"||staffId,self~principal(staffId,branch),self~session(staffId,sessionId,branch,desk),.array~of(self~assignment(staffId,roleClass,branch,ops,maxMinor)))~seal
::method action class
  use arg id,staffId="TELLER-04",sessionId="S-TEL",amount=250000,branch="DOUGLAS",desk="DESK-04"
  return .FederationBankStaffActionIntent~new("ACT:"||id,"CMD:"||id,"IDEM:"||id,staffId,sessionId,"TRANSFER","CUST-001","GBP-SRC","GBP-DST","GBP",amount,branch,desk,"CASE:"||id,.DateTime~new)~seal
::method putContext class
  use arg svc,cmdId,ctx
  p=.directory~new; p["context"]=ctx
  return svc~handle(.FederationBankStaffServiceEnvelope~new(cmdId,"FBSTAFF.CONTEXT.PUT","IAM-SYNC","IAM",p))
::requires "FederationBankStaffAuthorityService.cls"
::requires "FederationBankStaffAuthorityPolicyFixtures.cls"
