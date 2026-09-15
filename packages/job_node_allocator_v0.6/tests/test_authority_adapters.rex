call assertTrue .JobNodeAllocatorBuild~VERSION="0.6", "allocator version"

/* Real Security Effect v0.10 assessment objects. */
action=.SecurityActionSurface~new("A1","PRINCIPAL-1","JOB_EXECUTE")~seal
snap=.SecuritySnapshot~new("S1","PRINCIPAL-1")~seal
pol=.SecurityPolicyFramework~new("P1","1",.nil,.nil,"author","approver")~seal
secAllow=.SecurityAssessment~new(action,snap,pol)~setDisposition("ALLOW")~finalise
secReject=.SecurityAssessment~new(action,snap,pol)~setDisposition("REJECT")~finalise

/* Real Legal Effect v0.14 assessment objects; status is the published result seam. */
legalAllow=.LegalEffectAssessment~new(.nil,.nil,.nil,.nil)~setStatus("ADMISSIBLE")
legalBlock=.LegalEffectAssessment~new(.nil,.nil,.nil,.nil)~setStatus("BLOCKED")

/* Real Access Permissions v0.1 decision objects, with tiny semantic inputs. */
req=.TestAccessReq~new
apol=.TestPolicy~new
accessAllow=.AccessControlDecision~new(.true,"ALLOW","",req,apol)
accessDeny=.AccessControlDecision~new(.false,"DENY","blocked",req,apol)
preq=.TestPermReq~new
permAllow=.PermissionDecision~new(.true,"ALLOW","",preq,apol)
permDeny=.PermissionDecision~new(.false,"DENY","blocked",preq,apol)

m=.JobNodeAuthorityEvidenceMap~new
m~put("NODE-A",.JobNodeAuthorityEvidence~new(secAllow,legalAllow,accessAllow,permAllow))
m~put("NODE-B",.JobNodeAuthorityEvidence~new(secReject,legalAllow,accessAllow,permAllow))
m~put("NODE-C",.JobNodeAuthorityEvidence~new(secAllow,legalBlock,accessAllow,permAllow))
m~put("NODE-D",.JobNodeAuthorityEvidence~new(secAllow,legalAllow,accessDeny,permAllow))
m~put("NODE-E",.JobNodeAuthorityEvidence~new(secAllow,legalAllow,accessAllow,permDeny))
assessor=.JobNodeDecisionObjectAssessor~new(m)

reqs=.JobNodeRequirement~new
job=.JobPlacementRequest~new("JOB-1",reqs,"OWNER")
do n over .array~of("NODE-A","NODE-B","NODE-C","NODE-D","NODE-E")
 cap=.NodeCapabilityStatement~new(n)
 obs=.NodeCapacityObservation~new(n,1,1,100,1000,100,100,10,10,0,0)
 reasons=assessor~assess(job,cap,obs,100)
 select
  when n="NODE-A" then call assertTrue reasons~items=0,"all four authorities permit"
  when n="NODE-B" then call assertContains reasons,"SECURITY_REJECT"
  when n="NODE-C" then call assertContains reasons,"LEGAL_BLOCKED"
  when n="NODE-D" then call assertContains reasons,"ACCESS_DENY"
  when n="NODE-E" then call assertContains reasons,"PERMISSION_DENY"
 end
end
say "PASS actual Security/Legal/Access Permissions decision adapters"
exit 0

assertTrue: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
assertContains: procedure
 use arg a,wanted
 do x over a; if x=wanted then return; end
 say "FAIL missing" wanted
 exit 1

::class TestAccessReq
::method semanticIdentity; return "REQ-ID"
::attribute principalId get
::attribute domainId get
::method init; expose principalId domainId; principalId="PRINCIPAL-1"; domainId="DOMAIN-1"
::class TestPolicy
::method semanticIdentity; return "POLICY-ID"
::class TestPermReq
::method semanticIdentity; return "PREQ-ID"
::attribute principalId get
::attribute objectId get
::attribute objectClass get
::attribute methodName get
::attribute securityDisposition get
::attribute securityPolicyIdentity get
::attribute securityTraceIdentity get
::method init
 expose principalId objectId objectClass methodName securityDisposition securityPolicyIdentity securityTraceIdentity
 principalId="PRINCIPAL-1"; objectId="OBJ-1"; objectClass="TEST"; methodName="RUN"; securityDisposition="ALLOW"; securityPolicyIdentity="SEC-POL"; securityTraceIdentity="TRACE"

::requires "JobNodeAuthorityAdapters.cls"
::requires "SecurityEffect.cls"
::requires "LegalEffect.cls"
::requires "AccessPermissions.cls"
