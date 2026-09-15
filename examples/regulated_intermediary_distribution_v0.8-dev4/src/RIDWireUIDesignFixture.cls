/* Wire UI Builder source-of-truth for the Federation regulated intermediary workspace. */
::class RIDWireUIDesignFixture public
::method build class
  w=.WireUIDesignWorkspace~new("Federation.RegulatedIntermediary")

  shellSlots=.table~new; shellSlots["visible"]="BOOLEAN"; shellSlots["firmId"]="TEXT"; shellSlots["representativeId"]="TEXT"; shellSlots["principalId"]="TEXT"; shellSlots["roleName"]="TEXT"; shellSlots["accessDecisionRef"]="TEXT"
  summarySlots=.table~new; do k over .array~of("total","actionRequired","overdue","waitingProvider","complete"); summarySlots[k]="INTEGER"; end
  querySlots=.table~new; querySlots["attentionState"]="TEXT"; querySlots["productFamily"]="TEXT"; querySlots["providerStatus"]="TEXT"; querySlots["sortRef"]="TEXT"; querySlots["sortDirection"]="TEXT"
  tableSlots=.table~new
  do k over .array~of("collectionRef","sortRef","filterRef","anchorRef"); tableSlots[k]="TEXT"; end
  do k over .array~of("windowOffset","windowLimit","windowTotalCount","windowRevision","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision","resultQueryRevision","resultScopeRevision","resultOrderRevision"); tableSlots[k]="INTEGER"; end
  rowSlots=.table~new
  do k over .array~of("caseId","productFamily","workflowState","providerStatus","attentionState","nextAction","waitingOn","workItemId","workStatus"); rowSlots[k]="TEXT"; end
  rowSlots["priority"]="INTEGER"; rowSlots["dueTick"]="TEXT"
  detailSlots=.table~new
  do k over .array~of("caseId","subjectRef","productRefId","productFamily","workflowState","providerStatus","providerEventId","nextAction","workItemId","workStatus","completionMode","completionEvidenceRef"); detailSlots[k]="TEXT"; end
  detailSlots["providerSequence"]="INTEGER"; detailSlots["priority"]="INTEGER"; detailSlots["visible"]="BOOLEAN"; detailSlots["canAcknowledge"]="BOOLEAN"
  signingSlots=.table~new
  do k over .array~of("workItemId","envelopeId","documentType","documentSemanticIdentity","documentVersion","digestAlgorithm","contentDigest","storageRef","durableMediumRef","envelopeState","challengeId","requirementId","signerRef","signerRole","purpose","canonicalMessage","expiresTick"); signingSlots[k]="TEXT"; end
  timelineSlots=.table~new; timelineSlots["visible"]="BOOLEAN"
  do k over .array~of("collectionRef","sortRef","filterRef","anchorRef"); timelineSlots[k]="TEXT"; end
  do k over .array~of("windowOffset","windowLimit","windowTotalCount","windowRevision"); timelineSlots[k]="INTEGER"; end
  timelineRowSlots=.table~new
  do k over .array~of("timelineId","kind","occurredAt","label","status","actorRef","evidenceRef","sourceRef"); timelineRowSlots[k]="TEXT"; end
  signingSlots["visible"]="BOOLEAN"; signingSlots["canPrepareSignature"]="BOOLEAN"; signingSlots["canSubmitSignature"]="BOOLEAN"

  shell=.WireUIVisualComponent~new("RID_APP_SHELL","1","PANEL",shellSlots,.array~of("surface"),.array~new)
  summary=.WireUIVisualComponent~new("RID_SUMMARY","1","SEMANTIC_RECORD",summarySlots,.array~of("surface","status"),.array~new)
  query=.WireUIVisualComponent~new("RID_CASE_QUERY","1","FORM",querySlots,.array~of("surface","field","action"),.array~of("SEMANTIC_ACTION"))
  table=.WireUIVisualComponent~new("RID_CASE_TABLE","1","SEMANTIC_RECORD",tableSlots,.array~of("surface","collection"),.array~of("SEMANTIC_ACTION"))
  row=.WireUIVisualComponent~new("RID_CASE_ROW","1","SEMANTIC_RECORD",rowSlots,.array~of("surface","status","action"),.array~of("SEMANTIC_ACTION"))
  detail=.WireUIVisualComponent~new("RID_CASE_DETAIL","1","SEMANTIC_RECORD",detailSlots,.array~of("surface","status","action"),.array~of("SEMANTIC_ACTION"))
  signing=.WireUIVisualComponent~new("RID_SIGNING_PANEL","1","SEMANTIC_RECORD",signingSlots,.array~of("surface","evidence","action"),.array~of("SEMANTIC_ACTION"))
  timeline=.WireUIVisualComponent~new("RID_CASE_TIMELINE","1","SEMANTIC_RECORD",timelineSlots,.array~of("surface","collection","evidence"),.array~new)
  timelineRow=.WireUIVisualComponent~new("RID_TIMELINE_ROW","1","SEMANTIC_RECORD",timelineRowSlots,.array~of("surface","evidence","status"),.array~new)
  do x over .array~of(shell,summary,query,table,row,detail,signing,timeline,timelineRow); call must w~register(x); end

  eShell=.WireUISemanticElement~new("RID_APP","1","APPLICATION",.array~of("firmId","representativeId","principalId","roleName","accessDecisionRef"),.array~new,"INTERMEDIARY")
  eSummary=.WireUISemanticElement~new("RID_DASHBOARD_SUMMARY","1","OPERATIONAL_SUMMARY",.array~of("total","actionRequired","overdue","waitingProvider","complete"),.array~new,"INTERMEDIARY")
  eQuery=.WireUISemanticElement~new("RID_CASE_QUERY","1","WORKSPACE_QUERY",.array~of("attentionState","productFamily","providerStatus","sortRef","sortDirection"),.array~of("CASES.FILTER","CASES.SORT","CASES.SELECT","DASHBOARD.REFRESH"),"INTERMEDIARY")
  eTable=.WireUISemanticElement~new("RID_CASE_TABLE","1","WORKSPACE_COLLECTION",.array~new,.array~new,"INTERMEDIARY")
  eRow=.WireUISemanticElement~new("RID_CASE_ROW","1","CASE_ATTENTION",.array~of("caseId","providerStatus","attentionState","nextAction","priority"),.array~of("CASE.OPEN"),"INTERMEDIARY")
  eDetail=.WireUISemanticElement~new("RID_CASE_DETAIL","1","CASE_DETAIL",.array~of("caseId","providerStatus","nextAction","workItemId","completionMode"),.array~of("WORK.ACK"),"INTERMEDIARY")
  eSigning=.WireUISemanticElement~new("RID_SIGNING","1","SIGNING_CEREMONY",.array~of("envelopeId","contentDigest","storageRef","durableMediumRef","requirementId","canonicalMessage"),.array~of("SIGNATURE.PREPARE","SIGNATURE.SUBMIT"),"INTERMEDIARY")
  eTimeline=.WireUISemanticElement~new("RID_CASE_TIMELINE","1","CASE_TIMELINE",.array~of("windowTotalCount"),.array~new,"INTERMEDIARY")
  eTimelineRow=.WireUISemanticElement~new("RID_TIMELINE_ROW","1","CASE_TIMELINE_EVENT",.array~of("kind","occurredAt","label","status","evidenceRef","sourceRef"),.array~new,"INTERMEDIARY")
  do x over .array~of(eShell,eSummary,eQuery,eTable,eRow,eDetail,eSigning,eTimeline,eTimelineRow); call must w~register(x); end

  tokens=.table~new; tokens["brand.ink"]="#132238"; tokens["surface"]="#ffffff"; tokens["density"]="compact"; tokens["space.unit"]="8"
  recipes=.table~new; recipes["workspace"]="regulated/workspace"; recipes["case.row"]="regulated/case.row"; recipes["signing"]="regulated/signing"
  material=.WireUIMaterialSet~new("RID_MATERIAL","1",tokens,recipes); call must w~register(material)

  shellBindings=self~bindings(.array~of("firmId","representativeId","principalId","roleName","accessDecisionRef"))
  summaryBindings=self~bindings(.array~of("total","actionRequired","overdue","waitingProvider","complete"))
  queryBindings=self~bindings(.array~of("attentionState","productFamily","providerStatus","sortRef","sortDirection"))
  tableBindings=self~bindings(.array~of("collectionRef","windowOffset","windowLimit","windowTotalCount","sortRef","filterRef","windowRevision","anchorRef","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision","resultQueryRevision","resultScopeRevision","resultOrderRevision"))
  rowBindings=self~bindings(.array~of("caseId","productFamily","workflowState","providerStatus","attentionState","nextAction","waitingOn","priority","dueTick","workItemId","workStatus"))
  detailBindings=self~bindings(.array~of("caseId","subjectRef","productRefId","productFamily","workflowState","providerStatus","providerEventId","providerSequence","nextAction","workItemId","workStatus","completionMode","completionEvidenceRef","priority","canAcknowledge"))
  signingBindings=self~bindings(.array~of("workItemId","envelopeId","documentType","documentSemanticIdentity","documentVersion","digestAlgorithm","contentDigest","storageRef","durableMediumRef","envelopeState","challengeId","requirementId","signerRef","signerRole","purpose","canonicalMessage","expiresTick","canPrepareSignature","canSubmitSignature"))
  timelineBindings=self~bindings(.array~of("collectionRef","windowOffset","windowLimit","windowTotalCount","sortRef","filterRef","windowRevision","anchorRef"))
  timelineRowBindings=self~bindings(.array~of("timelineId","kind","occurredAt","label","status","actorRef","evidenceRef","sourceRef"))
  pShell=.WireUIProjectionDesign~new("RID_APP_SHELL","1","HUMAN_VISUAL",eShell~ref,shell~ref,"RID_APP_SHELL","","workspace","workspace",shellBindings)
  pSummary=.WireUIProjectionDesign~new("RID_SUMMARY","1","HUMAN_VISUAL",eSummary~ref,summary~ref,"RID_SUMMARY","","workspace","workspace",summaryBindings)
  pQuery=.WireUIProjectionDesign~new("RID_CASE_QUERY","1","HUMAN_VISUAL",eQuery~ref,query~ref,"RID_CASE_QUERY","","workspace","workspace",queryBindings)
  pTable=.WireUIProjectionDesign~new("RID_CASE_TABLE","1","HUMAN_VISUAL",eTable~ref,table~ref,"RID_CASE_TABLE","","workspace","workspace",tableBindings)
  pRow=.WireUIProjectionDesign~new("RID_CASE_ROW","1","HUMAN_VISUAL",eRow~ref,row~ref,"RID_CASE_ROW","","case.row","case.row",rowBindings)
  pDetail=.WireUIProjectionDesign~new("RID_CASE_DETAIL","1","HUMAN_VISUAL",eDetail~ref,detail~ref,"RID_CASE_DETAIL","","workspace","workspace",detailBindings)
  pSigning=.WireUIProjectionDesign~new("RID_SIGNING_PANEL","1","HUMAN_VISUAL",eSigning~ref,signing~ref,"RID_SIGNING_PANEL","","signing","signing",signingBindings)
  pTimeline=.WireUIProjectionDesign~new("RID_CASE_TIMELINE","1","HUMAN_VISUAL",eTimeline~ref,timeline~ref,"RID_CASE_TIMELINE","","workspace","workspace",timelineBindings)
  pTimelineRow=.WireUIProjectionDesign~new("RID_TIMELINE_ROW","1","HUMAN_VISUAL",eTimelineRow~ref,timelineRow~ref,"RID_TIMELINE_ROW","","case.row","case.row",timelineRowBindings)
  do x over .array~of(pShell,pSummary,pQuery,pTable,pRow,pDetail,pSigning,pTimeline,pTimelineRow); call must w~register(x); end

  j=.WireUIJourneyDesign~new("RID_INTERMEDIARY_WORKSPACE","1","DASHBOARD")
  call must j~defineState("DASHBOARD",.array~of("RID_APP","RID_DASHBOARD_SUMMARY","RID_CASE_QUERY","RID_CASE_TABLE","RID_CASE_ROW","RID_CASE_DETAIL","RID_SIGNING","RID_CASE_TIMELINE","RID_TIMELINE_ROW"),.array~new,.array~new)
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("FEDERATION_RID_INTERMEDIARY","2026.08.28.3")
  do x over .array~of(shell,summary,query,table,row,detail,signing,timeline,timelineRow,eShell,eSummary,eQuery,eTable,eRow,eDetail,eSigning,eTimeline,eTimelineRow,material,pShell,pSummary,pQuery,pTable,pRow,pDetail,pSigning,pTimeline,pTimelineRow,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)
  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; return d

::method bindings class private
  use arg names
  b=.table~new
  do name over names; b[name]=name; end
  return b

::routine must
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r

::requires "WireUIBuilderAll.cls"
