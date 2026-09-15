::class FBIntermediaryStaffTestSupport public
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
::method staffContext class
  use arg staffId="RID-STAFF-17",roleClass="INTERMEDIARY_REPRESENTATIVE",sessionId="S-RID-17",branch="DOUGLAS",desk="DESK-04"
  p=.FederationBankStaffPrincipalRef~new(staffId,"FB-IAM","IAM:"||staffId,"ACTIVE","FEDERATIONBANK-AUSTRALIA-IOM",branch,"HR:"||staffId)~seal
  s=.FederationBankStaffSessionContext~new(sessionId,staffId,branch,desk,"WS:"||desk,"AUTH:"||sessionId,.DateTime~new-.TimeSpan~new(0,5),.DateTime~new+.TimeSpan~new(1,0),"SEC:"||sessionId)~seal
  a=.FederationBankStaffRoleAssignment~new("ASN:"||staffId||":"||roleClass,staffId,roleClass,roleClass||"_STANDARD",branch,0,.DateTime~new-.TimeSpan~new(0,5),.DateTime~new+.TimeSpan~new(1,0),"FB-IAM","IAM:ASN:"||staffId)~seal
  return .FederationBankStaffContextSnapshot~new("CTX:"||staffId,p,s,.array~of(a))~seal
::method staffAction class
  use arg actionId="RID-ACT-1",staffId="RID-STAFF-17",sessionId="S-RID-17",operation="INTERMEDIARY_ADVISE",caseId="RID-CASE-1",scope="INSTITUTIONAL",at=.nil
  if at==.nil then at=.DateTime~new
  return .FederationBankStaffActionIntent~new(actionId,"CMD:"||actionId,"IDEM:"||actionId,staffId,sessionId,operation,"CUST-001","","","",0,"DOUGLAS","DESK-04",caseId,at,.nil,.nil,scope)~seal
::method staffAuthority class
  use arg action,ctx,envelopeId="STAFF-ENV-1"
  contexts=.directory~new; contexts[action~staffId]=ctx
  return self~staffEngine~authorise(envelopeId,action,contexts)
::method ridRegistry class
  ir=.RIDIntermediaryRegistry~new
  ignore=ir~registerFirm(.RIDIntermediaryFirm~new("FIRM-1","LEGAL:FIRM-1","REG:FIRM-1"))
  ignore=ir~registerRepresentative(.RIDIntermediaryRepresentative~new("REP-1","FIRM-1","PERSON:REP-1"))
  return ir
::method product class
  use arg semanticIdentity="HOME-1|2026.08|A",family="MORTGAGE",jurisdiction="GB"
  provider=.RIDProviderIdentity~new("FEDERATIONBANK_PLC","FEDERATION_MORTGAGE","FEDERATION_GROUP","PROVIDER:EVIDENCE:1")
  return .RIDProductReference~new("PROD-1",provider,"HOME-1","2026.08",semanticIdentity,family,jurisdiction,"MORTGAGE_PRODUCT","PRODUCT:EVIDENCE:1")
::method ridCase class
  use arg caseId="RID-CASE-1",semanticIdentity="HOME-1|2026.08|A",adviceMode="ADVISED",jurisdiction="GB",firmId="FIRM-1",representativeId="REP-1",at=.nil
  if at==.nil then at=.DateTime~new
  return .RIDDistributionCase~new(caseId,"CUST-001",firmId,representativeId,"PROD-1",semanticIdentity,adviceMode,jurisdiction,at)
::method repBinding class
  use arg staffId="RID-STAFF-17",firmId="FIRM-1",representativeId="REP-1",from=.nil,until=.nil
  if from==.nil then from=.DateTime~new-.TimeSpan~new(0,5)
  return .FederationBankIntermediaryStaffRepresentativeBinding~new("BIND-1",staffId,firmId,representativeId,from,until,"FB-IAM-RID-BINDING","IAM-RID:BIND-1")~seal
::method request class
  use arg action,activity="ADVISE",caseId="RID-CASE-1",semanticIdentity="HOME-1|2026.08|A",family="MORTGAGE",jurisdiction="GB",adviceMode="ADVISED",firmId="FIRM-1",representativeId="REP-1"
  return .FederationBankIntermediaryStaffRequest~new("REQ:"||action~actionId,action,firmId,representativeId,"PROD-1",semanticIdentity,family,jurisdiction,activity,adviceMode,caseId,action~requestedAt)~seal
::method goodBundle class
  use arg operation="INTERMEDIARY_ADVISE",activity="ADVISE",adviceMode="ADVISED"
  now=.DateTime~new; action=self~staffAction("RID-ACT-1","RID-STAFF-17","S-RID-17",operation,"RID-CASE-1","INSTITUTIONAL",now); ctx=self~staffContext; auth=self~staffAuthority(action,ctx); self~assertTrue(auth~ok,"staff authority fixture")
  d=.directory~new; d["NOW"]=now; d["ACTION"]=action; d["STAFF_AUTHORITY"]=auth~value["envelope"]; d["REQUEST"]=self~request(action,activity,"RID-CASE-1","HOME-1|2026.08|A","MORTGAGE","GB",adviceMode); d["BINDING"]=self~repBinding("RID-STAFF-17","FIRM-1","REP-1",now-.TimeSpan~new(0,5)); d["CASE"]=self~ridCase("RID-CASE-1","HOME-1|2026.08|A",adviceMode,"GB","FIRM-1","REP-1",now); d["PRODUCT"]=self~product; d["REGISTRY"]=self~ridRegistry; return d
::method engine class
  return .FederationBankIntermediaryStaffAuthorityEngine~new
::method authoriseBundle class
  use arg d,envelopeId="RID-STAFF-ENV-1"
  return self~engine~authorise(envelopeId,d["REQUEST"],d["ACTION"],d["STAFF_AUTHORITY"],d["BINDING"],d["CASE"],d["PRODUCT"],d["REGISTRY"])
::requires "FederationBankIntermediaryStaffAuthority.cls"
::requires "FederationBankStaffAuthorityPolicyFixtures.cls"
