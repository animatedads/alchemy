/*
 * Vector Meridian Markets operator workspace semantic fixture.
 *
 * This is presentation/application-release vocabulary only.  It contains no
 * VMM pricing, routing, inventory, risk, synthetic, funding, collateral or
 * accounting implementation.  Every action is a semantic user-intent label
 * which remains subject to server-side availability and domain authority.
 */
::class VMMWireUIDesignFixture public

::method build class
  w=.WireUIDesignWorkspace~new("VectorMeridianMarkets.OperatorWorkspace")

  recordSlots=.table~new
  do f over .array~of("title","summary","state","value","detail","evidence","updatedAt")
    recordSlots[f]="TEXT"
  end
  collectionSlots=.table~new; collectionSlots["items"]="COLLECTION"
  actionSlots=.table~new; actionSlots["label"]="TEXT"; actionSlots["enabled"]="BOOLEAN"

  record=.WireUIVisualComponent~new("VMM_RECORD","1","SEMANTIC_RECORD",recordSlots,.array~of("surface","record","evidence"),.array~of("SEMANTIC_ACTION"))
  collection=.WireUIVisualComponent~new("VMM_COLLECTION","1","SEMANTIC_COLLECTION",collectionSlots,.array~of("surface","collection"),.array~of("SEMANTIC_ACTION"))
  action=.WireUIVisualComponent~new("VMM_ACTION","1","ACTION_BUTTON",actionSlots,.array~of("action","severity"),.array~of("SEMANTIC_ACTION"))
  do x over .array~of(record,collection,action); call must w~register(x); end

  firm=self~element("FIRM_RISK_SUMMARY","FIRM_RISK", -
    .array~of("capitalBase","capitalUtilisation","leverageUtilisation","dailyLossUtilisation","algoState","exceptionCount","asOf"))
  orders=self~element("ORDER_WORKLIST","ORDER_COLLECTION",.array~of("items"),.array~of("VMM.ORDER.SELECT"))
  order=self~element("ORDER_DETAIL","ORDER_DETAIL", -
    .array~of("orderId","instrumentIdentity","side","quantity","filledQuantity","state","routeId","correlationId","idempotencyKey","reconciliationState","asOf"))
  orderCancel=self~element("ORDER_CANCEL","OPERATOR_INTENT",.array~of("label","enabled"),.array~of("VMM.ORDER.CANCEL.REQUEST"))
  orderReconcile=self~element("ORDER_RECONCILE","OPERATOR_INTENT",.array~of("label","enabled"),.array~of("VMM.ORDER.RECONCILE.REQUEST"))

  inventory=self~element("INVENTORY_WORKLIST","INVENTORY_COLLECTION",.array~of("items"),.array~of("VMM.INVENTORY.SELECT"))
  position=self~element("POSITION_DETAIL","INVENTORY_DETAIL", -
    .array~of("instrumentIdentity","principalQuantity","markedValue","realisedPnL","unrealisedPnL","locateState","marketStructureState","asOf"))
  algo=self~element("ALGO_STATE","ALGORITHM_RISK_STATE", -
    .array~of("strategyId","strategyVersion","state","inventoryLimit","lossLimit","lastDecisionEvidence","asOf"))
  algoKill=self~element("ALGO_KILL","OPERATOR_INTENT",.array~of("label","enabled"),.array~of("VMM.ALGO.KILL.REQUEST"))
  algoResume=self~element("ALGO_RESUME","OPERATOR_INTENT",.array~of("label","enabled"),.array~of("VMM.ALGO.RESUME.REQUEST"))

  synthetics=self~element("SYNTHETIC_WORKLIST","SYNTHETIC_COLLECTION",.array~of("items"),.array~of("VMM.SYNTHETIC.SELECT"))
  synthetic=self~element("SYNTHETIC_DETAIL","SYNTHETIC_DETAIL", -
    .array~of("contractRef","productType","counterpartyDisplay","state","notional","currency","vmmValue","variationMargin","initialMargin","closeoutState","valuationEvidence","asOf"))

  funding=self~element("FUNDING_WORKLIST","FUNDING_COLLECTION",.array~of("items"),.array~of("VMM.FUNDING.SELECT"))
  fundingDetail=self~element("FUNDING_DETAIL","FUNDING_DETAIL", -
    .array~of("facilityRef","counterpartyDisplay","currency","drawnAmount","accruedInterest","maturity","evidence","asOf"))
  collateral=self~element("COLLATERAL_WORKLIST","COLLATERAL_COLLECTION",.array~of("items"),.array~of("VMM.COLLATERAL.SELECT"))
  collateralDetail=self~element("COLLATERAL_DETAIL","COLLATERAL_DETAIL", -
    .array~of("collateralRef","contractRef","custodianDisplay","assetIdentity","grossCarryingValue","riskRecognisedValue","haircutBps","custodyState","evidence","asOf"))

  exceptions=self~element("EXCEPTION_WORKLIST","EXCEPTION_COLLECTION",.array~of("items"),.array~of("VMM.EXCEPTION.SELECT"))
  exception=self~element("EXCEPTION_DETAIL","EXCEPTION_DETAIL", -
    .array~of("exceptionRef","type","severity","state","relatedRef","reason","evidence","raisedAt","asOf"))
  exceptionAck=self~element("EXCEPTION_ACK","OPERATOR_INTENT",.array~of("label","enabled"),.array~of("VMM.EXCEPTION.ACKNOWLEDGE.REQUEST"))

  navDealing=self~element("NAV_DEALING","WORKSPACE_NAVIGATION",.array~of("label","enabled"),.array~of("VMM.WORKSPACE.DEALING"))
  navInstitutional=self~element("NAV_INSTITUTIONAL","WORKSPACE_NAVIGATION",.array~of("label","enabled"),.array~of("VMM.WORKSPACE.INSTITUTIONAL"))
  navTreasury=self~element("NAV_TREASURY","WORKSPACE_NAVIGATION",.array~of("label","enabled"),.array~of("VMM.WORKSPACE.TREASURY"))
  navExceptions=self~element("NAV_EXCEPTIONS","WORKSPACE_NAVIGATION",.array~of("label","enabled"),.array~of("VMM.WORKSPACE.EXCEPTIONS"))

  elements=.array~of(firm,orders,order,orderCancel,orderReconcile,inventory,position,algo,algoKill,algoResume, -
    synthetics,synthetic,funding,fundingDetail,collateral,collateralDetail,exceptions,exception,exceptionAck, -
    navDealing,navInstitutional,navTreasury,navExceptions)
  do x over elements; call must w~register(x); end

  tokens=.table~new
  tokens["space.unit"]="8"; tokens["radius.control"]="6"; tokens["density"]="compact"
  tokens["authority.browser"]="projection-only"; tokens["authority.action"]="server-availability-required"
  recipes=.table~new
  recipes["vmm.summary"]="surface.primary/record.summary"
  recipes["vmm.worklist"]="surface.primary/list.operational"
  recipes["vmm.detail"]="surface.secondary/record.evidence"
  recipes["vmm.action"]="surface.action/button.authoritative"
  material=.WireUIMaterialSet~new("VMM_OPERATOR_MATERIAL","2",tokens,recipes)
  call must w~register(material)

  projections=.array~new
  ignore=self~projection(w,projections,"FIRM_RISK_SUMMARY_VIEW",firm,record,"VMM_FIRM_RISK_SUMMARY","","vmm.summary")
  ignore=self~projection(w,projections,"ORDER_WORKLIST_VIEW",orders,collection,"VMM_ORDER_WORKLIST","VMM.ORDER.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"ORDER_DETAIL_VIEW",order,record,"VMM_ORDER_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"ORDER_CANCEL_VIEW",orderCancel,action,"VMM_ORDER_CANCEL","VMM.ORDER.CANCEL.REQUEST","vmm.action.danger")
  ignore=self~projection(w,projections,"ORDER_RECONCILE_VIEW",orderReconcile,action,"VMM_ORDER_RECONCILE","VMM.ORDER.RECONCILE.REQUEST","vmm.action")
  ignore=self~projection(w,projections,"INVENTORY_WORKLIST_VIEW",inventory,collection,"VMM_INVENTORY_WORKLIST","VMM.INVENTORY.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"POSITION_DETAIL_VIEW",position,record,"VMM_POSITION_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"ALGO_STATE_VIEW",algo,record,"VMM_ALGO_STATE","","vmm.detail")
  ignore=self~projection(w,projections,"ALGO_KILL_VIEW",algoKill,action,"VMM_ALGO_KILL","VMM.ALGO.KILL.REQUEST","vmm.action.danger")
  ignore=self~projection(w,projections,"ALGO_RESUME_VIEW",algoResume,action,"VMM_ALGO_RESUME","VMM.ALGO.RESUME.REQUEST","vmm.action")
  ignore=self~projection(w,projections,"SYNTHETIC_WORKLIST_VIEW",synthetics,collection,"VMM_SYNTHETIC_WORKLIST","VMM.SYNTHETIC.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"SYNTHETIC_DETAIL_VIEW",synthetic,record,"VMM_SYNTHETIC_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"FUNDING_WORKLIST_VIEW",funding,collection,"VMM_FUNDING_WORKLIST","VMM.FUNDING.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"FUNDING_DETAIL_VIEW",fundingDetail,record,"VMM_FUNDING_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"COLLATERAL_WORKLIST_VIEW",collateral,collection,"VMM_COLLATERAL_WORKLIST","VMM.COLLATERAL.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"COLLATERAL_DETAIL_VIEW",collateralDetail,record,"VMM_COLLATERAL_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"EXCEPTION_WORKLIST_VIEW",exceptions,collection,"VMM_EXCEPTION_WORKLIST","VMM.EXCEPTION.SELECT","vmm.worklist")
  ignore=self~projection(w,projections,"EXCEPTION_DETAIL_VIEW",exception,record,"VMM_EXCEPTION_DETAIL","","vmm.detail")
  ignore=self~projection(w,projections,"EXCEPTION_ACK_VIEW",exceptionAck,action,"VMM_EXCEPTION_ACK","VMM.EXCEPTION.ACKNOWLEDGE.REQUEST","vmm.action")
  ignore=self~projection(w,projections,"NAV_DEALING_VIEW",navDealing,action,"VMM_NAV_DEALING","VMM.WORKSPACE.DEALING","vmm.nav")
  ignore=self~projection(w,projections,"NAV_INSTITUTIONAL_VIEW",navInstitutional,action,"VMM_NAV_INSTITUTIONAL","VMM.WORKSPACE.INSTITUTIONAL","vmm.nav")
  ignore=self~projection(w,projections,"NAV_TREASURY_VIEW",navTreasury,action,"VMM_NAV_TREASURY","VMM.WORKSPACE.TREASURY","vmm.nav")
  ignore=self~projection(w,projections,"NAV_EXCEPTIONS_VIEW",navExceptions,action,"VMM_NAV_EXCEPTIONS","VMM.WORKSPACE.EXCEPTIONS","vmm.nav")

  nav=.array~of("NAV_DEALING","NAV_INSTITUTIONAL","NAV_TREASURY","NAV_EXCEPTIONS","FIRM_RISK_SUMMARY")
  j=.WireUIJourneyDesign~new("VMM_OPERATOR_WORKSPACE","2","DEALING")
  call must j~defineState("DEALING",self~join(nav,.array~of("ORDER_WORKLIST","ORDER_DETAIL","ORDER_CANCEL","ORDER_RECONCILE","INVENTORY_WORKLIST","POSITION_DETAIL","ALGO_STATE","ALGO_KILL","ALGO_RESUME")),.array~new,.array~new)
  call must j~defineState("INSTITUTIONAL",self~join(nav,.array~of("SYNTHETIC_WORKLIST","SYNTHETIC_DETAIL")),.array~new,.array~new)
  call must j~defineState("TREASURY",self~join(nav,.array~of("FUNDING_WORKLIST","FUNDING_DETAIL","COLLATERAL_WORKLIST","COLLATERAL_DETAIL")),.array~new,.array~new)
  call must j~defineState("EXCEPTIONS",self~join(nav,.array~of("EXCEPTION_WORKLIST","EXCEPTION_DETAIL","EXCEPTION_ACK")),.array~new,.array~new)

  states=.array~of("DEALING","INSTITUTIONAL","TREASURY","EXCEPTIONS")
  do from over states
    ignore=self~navTransition(j,from,"DEALING","VMM.WORKSPACE.DEALING")
    ignore=self~navTransition(j,from,"INSTITUTIONAL","VMM.WORKSPACE.INSTITUTIONAL")
    ignore=self~navTransition(j,from,"TREASURY","VMM.WORKSPACE.TREASURY")
    ignore=self~navTransition(j,from,"EXCEPTIONS","VMM.WORKSPACE.EXCEPTIONS")
  end
  call must j~seal; call must w~register(j)

  releaseMeta=.table~new
  releaseMeta["legalEntityId"]="VECTOR_MERIDIAN_MARKETS_LTD"
  releaseMeta["authority"]="SERVER_AUTHORITATIVE_PROJECTION"
  releaseMeta["vmmBaseline"]="0.11"
  release=.WireUISiteRelease~new("VECTOR_MERIDIAN_MARKETS_OPERATIONS","2",releaseMeta)
  do x over .array~of(record,collection,action); call must release~pin(x~ref); end
  do x over elements; call must release~pin(x~ref); end
  call must release~pin(material~ref)
  do x over projections; call must release~pin(x~ref); end
  call must release~pin(j~ref)
  call must release~seal; call must w~register(release)

  d=.directory~new
  d["workspace"]=w; d["release"]=release; d["journey"]=j; d["material"]=material; d["projections"]=projections
  return d

::method element class private
  use arg id,type,fields=.nil,actions=.nil
  md=.table~new
  md["authority"]="VMM_SERVER"
  md["browserRole"]="projection-and-intent-only"
  md["legalEntityId"]="VECTOR_MERIDIAN_MARKETS_LTD"
  return .WireUISemanticElement~new(id,"2",type,fields,actions,"AUTHENTICATED",md)

::method projection class private
  use arg workspace,output,id,element,component,definitionId,actionName,styleRole
  bindings=.table~new
  ew=element~asWire
  do f over ew["fields"]; bindings[f]=f; end
  md=.table~new; md["operatorSurface"]="VMM"; md["serverActionAvailabilityRequired"]=.true
  p=.WireUIProjectionDesign~new(id,"2","HUMAN_VISUAL",element~ref,component~ref,definitionId,actionName,styleRole,styleRole,bindings,md)
  call must workspace~register(p); output~append(p); return p

::method navTransition class private
  use arg journey,fromState,toState,trigger
  if fromState=toState then return .true
  call must journey~allowTransition(fromState,toState,trigger,"operator selected VMM workspace")
  return .true

::method join class private
  use arg left,right
  out=.array~new; do x over left; out~append(x); end; do x over right; out~append(x); end; return out

::routine must
  use arg result
  if result~isA(.WireUIDesignResult) then if \result~ok then raise syntax 88.900 array(result~code,result~detail)
  return result

::requires "WireUIBuilderAll.cls"
