::class RIDWireUITestFixtures public
::method setup class
  use arg status="APPROVED", family="MORTGAGE", clock=.nil
  fx=.RIDWorkIntegrationFixtures~setup(family,"FEDERATIONBANK_PLC","FEDERATION_MORTGAGE","HOME-1","HOME-1|2026.08|A",clock)
  signed=.RIDWorkIntegrationFixtures~providerStatus(fx,"WIRE-STATUS-1",1,status)
  .RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx,signed))
  .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
  feed=.RIDIntermediaryWireFeed~new(fx["MANAGER"],fx["BRIDGE"]~topicFabric,"TESTFEED","FIRM-1","REP-1","RID_ADMIN")
  .RIDTestSupport~ok(feed~configure)
  fx["FEED"]=feed
  return fx
::method app class
  use arg fx,signingRegistry=.nil,signatureService=.nil,securityContext=.nil
  if securityContext==.nil then securityContext=.RIDWireSecurityPolicyFixtures~context("ADVISER","RID:ADVISER:REP-1")
  return .RIDTestSupport~ok(.RIDWireRuntimeFactory~build("RID-APP","S1","WEB",fx["ENGINE"],fx["ENV"]["CATALOG"],fx["SERVICE"],fx["FEED"],signingRegistry,signatureService,"FIRM-1","REP-1",securityContext))
::method action class
  use arg app,instance,semantic,detail=.nil,context=.nil
  if detail==.nil then detail=.directory~new
  if context<>.nil then detail["workspaceContext"]=context
  m=.directory~new; m["type"]="UI_ACTION"; m["applicationId"]="RID-APP"; m["sessionId"]="S1"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail
  return m
::method selectCase class
  use arg app,caseId
  d=.directory~new; d["selectedIds"]=.array~of(caseId); d["scopeRevision"]=app~workspaceQuery("RID.CASES")~scopeRevision
  return app~receive(self~action(app,"case-query","CASES.SELECT",d))
::requires "RIDWireUIApplication.cls"
::requires "WorkTestSupport.cls"

::requires "RIDWireSecurityPolicyFixtures.cls"
