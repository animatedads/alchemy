::class FBStaffChannelTestSupport public
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
::method staffEngine class
  return .FederationBankStaffAuthorityEngine~new(.FederationBankStaffAuthorityGate~new(.FederationBankStaffAuthorityPolicyFixtures~publishedCatalog))
::method orchestrator class
  use arg coreEngine
  gate=.FederationBankStaffChannelGate~new(.FederationBankStaffChannelPolicyFixtures~publishedCatalog)
  staffPort=.FederationBankStaffChannelLocalStaffAuthorityPort~new(self~staffEngine)
  corePort=.FederationBankStaffChannelEngineCorePort~new(coreEngine)
  return .FederationBankStaffChannelOrchestrator~new(gate,staffPort,corePort)
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
::method contexts class
  use arg first,second=.nil,third=.nil
  d=.directory~new
  if first<>.nil then d[first~principal~staffId]=first
  if second<>.nil then d[second~principal~staffId]=second
  if third<>.nil then d[third~principal~staffId]=third
  return d
::method directRequest class
  use arg id,staffId="TELLER-04",sessionId="S-TEL",amountMinor=250000,currency="GBP",operation="TRANSFER",source="GBP-SRC",target="GBP-DST",branch="DOUGLAS",desk="DESK-04"
  now=.DateTime~new
  command=.FederationBankCommand~new("CMD:"||id,operation,"IDEM:"||id,"CUST-001",source,target,currency,amountMinor,"STAFF",staffId,now)
  snapshot=.FederationBankStaffChannelCommandSnapshot~fromCommand(command)
  return .FederationBankStaffChannelRequest~new("REQ:"||id,"WORK:"||id,"CUSTOMER_INSTRUCTION",staffId,sessionId,branch,desk,snapshot,.nil,now)~seal
::method relationshipRequest class
  use arg id,staffId="TELLER-04",sessionId="S-TEL",amountMinor=250000,currency="GBP",operation="TRANSFER",source="GBP-SRC",target="GBP-DST",branch="DOUGLAS",desk="DESK-04"
  now=.DateTime~new; caseId="CASE:"||id; elementId="E:"||id; decisionId="DEC:"||id; authRef="AUTH:"||id
  decision=.FederationBankRelationshipDecision~new(decisionId,caseId,elementId,"CUST-001","FB-COMPLIANCE","STAFF_TRANSACTION_AUTHORITY",authRef,"CUSTOMER_INSTRUCTION_VALIDATED",operation,"POL:"||id,"",now)~seal
  element=.RelationshipCaseElement~new(elementId,"DECISION","CUSTOMER_INSTRUCTION_VALIDATED","AUTHORISES_BANK_ACTION","FB-COMPLIANCE",authRef,"STAFF_TRANSACTION_AUTHORITY",now,"RESTRICTED")~seal
  req=.FederationBankRelationshipActionRequest~new("RELREQ:"||id,"CMD:"||id,"IDEM:"||id,caseId,"CUST-001",operation,staffId,"TELLER",now,source,target,currency,amountMinor)~seal
  adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
  translated=adapter~translate(decision,req,element)
  if \translated~ok then raise syntax 98.900 array("relationship translation failed "||translated~code||":"||translated~detail)
  evidenceResult=.FederationBankStaffChannelRelationshipEvidence~fromTranslation(translated~value)
  if \evidenceResult~ok then raise syntax 98.900 array("relationship evidence failed "||evidenceResult~code)
  snapshot=.FederationBankStaffChannelCommandSnapshot~fromCommand(translated~value~bankCommand)
  return .FederationBankStaffChannelRequest~new("REQ:"||id,"WORK:"||id,"RELATIONSHIP_DECISION",staffId,sessionId,branch,desk,snapshot,evidenceResult~value,now)~seal
::method noActionRequest class
  use arg id,staffId="CMP-01",sessionId="S-CMP",branch="DOUGLAS",desk="COMPLIANCE-01"
  now=.DateTime~new; caseId="CASE:"||id; elementId="E:"||id; decisionId="DEC:"||id; authRef="AUTH:"||id
  decision=.FederationBankRelationshipDecision~new(decisionId,caseId,elementId,"CUST-001","FB-COMPLIANCE","COMPLIANCE_DECISION",authRef,"NO_BANK_ACTION","NONE","POL:"||id,"",now)~seal
  element=.RelationshipCaseElement~new(elementId,"DECISION","NO_BANK_ACTION","AUTHORISES_BANK_ACTION","FB-COMPLIANCE",authRef,"COMPLIANCE_DECISION",now,"RESTRICTED")~seal
  req=.FederationBankRelationshipActionRequest~new("RELREQ:"||id,"CMD:"||id,"IDEM:"||id,caseId,"CUST-001","NONE",staffId,"COMPLIANCE",now)~seal
  adapter=.FederationBankRelationshipAdapter~new(.FederationBankRelationshipPolicyGate~new(.FederationBankRelationshipPolicyFixtures~publishedCatalog))
  translated=adapter~translate(decision,req,element)
  if \translated~ok then raise syntax 98.900 array("no-action translation failed "||translated~code||":"||translated~detail)
  evidence=.FederationBankStaffChannelRelationshipEvidence~fromTranslation(translated~value)
  if \evidence~ok then raise syntax 98.900 array("no-action evidence failed")
  return .FederationBankStaffChannelRequest~new("REQ:"||id,"WORK:"||id,"RELATIONSHIP_DECISION",staffId,sessionId,branch,desk,.nil,evidence~value,now)~seal
::method openAccounts class
  use arg engine,actor="TELLER-04"
  call openOne engine,"GBP-SRC","OPEN-SRC",actor
  call openOne engine,"GBP-DST","OPEN-DST",actor
  return
openOne: procedure
  use arg e,accountId,idem,actor
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"STAFF",actor,.nil,"OFFSHORE_CURRENT",accountId,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  r=e~handle(c); if \r~ok then raise syntax 98.900 array("open failed "||accountId||" "||r~code||":"||r~detail)
  return
::method seed class
  use arg engine,amountMinor=5000000
  r=engine~ledger~postTransfer("SEED:"||amountMinor,"FB-SETTLEMENT-GBP","GBP-SRC",amountMinor,"GBP")
  if \r~ok then raise syntax 98.900 array("seed failed "||r~code)
  return r
::requires "FederationBankStaffChannelPolicyFixtures.cls"
::requires "FederationBankStaffAuthorityPolicyFixtures.cls"
::requires "FederationBankStaffCorePolicyFixtures.cls"
::requires "FederationBankRelationshipPolicyFixtures.cls"
::requires "RelationshipCase.cls"
