::class FBStaffTestSupport public
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
::method principal class
  use arg staffId,branch="DOUGLAS"
  return .FederationBankStaffPrincipalRef~new(staffId,"FB-IAM","IAM:"||staffId,"ACTIVE","FEDERATIONBANK-AUSTRALIA-IOM",branch,"HR:"||staffId)~seal
::method session class
  use arg staffId,sessionId,branch="DOUGLAS",desk="DESK-04",start=.nil,expires=.nil
  if start==.nil then start=.DateTime~new-.TimeSpan~new(0,5)
  if expires==.nil then expires=.DateTime~new+.TimeSpan~new(1,0)
  return .FederationBankStaffSessionContext~new(sessionId,staffId,branch,desk,"WS:"||desk,"IAM-AUTH:"||sessionId,start,expires,"SEC:"||sessionId)~seal
::method assignment class
  use arg staffId,roleClass,id="",branch="DOUGLAS",maxMinor=0,ops=.nil
  if id="" then id="ASSIGN:"||staffId||":"||roleClass
  return .FederationBankStaffRoleAssignment~new(id,staffId,roleClass,roleClass||"_STANDARD",branch,maxMinor,.DateTime~new-.TimeSpan~new(0,1),.DateTime~new+.TimeSpan~new(1,0),"FB-IAM","IAM:"||id,ops)~seal
::method context class
  use arg staffId,roleClass,sessionId,branch="DOUGLAS",desk="DESK-04",maxMinor=0,ops=.nil,delegations=.nil,elevations=.nil
  a=self~assignment(staffId,roleClass,"",branch,maxMinor,ops)
  return .FederationBankStaffContextSnapshot~new("CTX:"||staffId,self~principal(staffId,branch),self~session(staffId,sessionId,branch,desk),.array~of(a),delegations,elevations)~seal
::method action class
  use arg actionId,staffId,sessionId,amountMinor=100000,branch="DOUGLAS",desk="DESK-04",operation="TRANSFER",currency="GBP"
  return .FederationBankStaffActionIntent~new(actionId,"CMD:"||actionId,"IDEM:"||actionId,staffId,sessionId,operation,"CUST-001","GBP-SRC","GBP-DST",currency,amountMinor,branch,desk,"CASE:"||actionId,.DateTime~new)~seal
::method contexts class
  use arg first,second=.nil,third=.nil
  d=.directory~new
  if first<>.nil then d[first~principal~staffId]=first
  if second<>.nil then d[second~principal~staffId]=second
  if third<>.nil then d[third~principal~staffId]=third
  return d
::requires "FederationBankStaffAuthorityPolicyFixtures.cls"
