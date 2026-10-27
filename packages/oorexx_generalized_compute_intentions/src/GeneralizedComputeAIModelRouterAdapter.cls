/* Generalized Compute Intentions v0.1-dev6
 * Optional binding to ooRexx AI Model Router v0.1.
 *
 * AI Model Router is a non-entitling cross-provider route selector.  This
 * adapter preserves that boundary: a permitted model route becomes router
 * evidence inside a PlannedAdmittanceRoute; it is not WLU admission, Runtime
 * Registry acquisition, provider invocation, credentials, or transport.
 */

::class AIModelRouterPlanningContext public
::method init
  expose catalog request source advisoryPolicy policyCatalog policyId actionTime actorMode
  use strict arg catalogArg, requestArg, sourceArg, advisoryPolicyArg, policyCatalogArg, policyIdArg, actionTimeArg=.nil, actorModeArg='AUTOMATED'
  catalog = catalogArg
  request = requestArg
  source = sourceArg
  advisoryPolicy = advisoryPolicyArg
  policyCatalog = policyCatalogArg
  policyId = policyIdArg~string~strip
  actionTime = actionTimeArg
  actorMode = actorModeArg~string~strip~translate
  if catalog == .nil then raise syntax 93.900 array('AI Model Router catalog is required')
  if request == .nil then raise syntax 93.900 array('AI Model Router request is required')
  if source == .nil then raise syntax 93.900 array('AI Model Router WLU evidence source is required')
  if advisoryPolicy == .nil then raise syntax 93.900 array('AI Model Router advisory policy is required')
  if policyCatalog == .nil then raise syntax 93.900 array('AI Model Router institutional policy catalog is required')
  if policyId == '' then raise syntax 93.900 array('AI Model Router policy id is required')
  if actorMode == '' then actorMode = 'AUTOMATED'

::attribute catalog get
::attribute request get
::attribute source get
::attribute advisoryPolicy get
::attribute policyCatalog get
::attribute policyId get
::attribute actionTime get
::attribute actorMode get

::class AIModelRouterPlanningState public
::method init
  expose ok code detail plan outcome
  use strict arg okArg, codeArg, detailArg='', planArg=.nil, outcomeArg=.nil
  ok = okArg == .true
  code = codeArg~string~strip
  detail = detailArg~string
  plan = planArg
  outcome = outcomeArg
::attribute ok get
::attribute code get
::attribute detail get
::attribute plan get
::attribute outcome get

::class AIModelRouterIntentionAdapter subclass RouterIntentionAdapter
::method init
  expose router
  use strict arg routerArg
  if routerArg == .nil then raise syntax 93.900 array('AI Model Router is required')
  if \routerArg~hasMethod('route') then raise syntax 93.900 array('AI Model Router must expose route')
  router = routerArg

/* Called once by GeneralizedComputeIntentionProvider for the complete candidate
 * set.  No state is retained on the adapter, so another planning turn always
 * re-evaluates current WLU evidence and institutional policy. */
::method beginPlan
  expose router
  use strict arg workload, candidates, context=.nil
  routing = self~routingContext(context)
  if routing == .nil then return .AIModelRouterPlanningState~new(.false, 'AI_MODEL_ROUTER_CONTEXT_REQUIRED', 'planning context has no AI Model Router authority inputs')

  outcome = router~route(routing~catalog, routing~request, routing~source, -
      routing~advisoryPolicy, routing~policyCatalog, routing~policyId, -
      routing~actionTime, routing~actorMode)
  if outcome == .nil then return .AIModelRouterPlanningState~new(.false, 'AI_MODEL_ROUTER_NO_OUTCOME', 'router returned no outcome')
  if \outcome~ok then return .AIModelRouterPlanningState~new(.false, outcome~code, outcome~detail, .nil, outcome)
  if outcome~value == .nil then return .AIModelRouterPlanningState~new(.false, 'AI_MODEL_ROUTER_NO_PLAN', 'permitted router outcome carried no plan', .nil, outcome)
  return .AIModelRouterPlanningState~new(.true, 'AI_MODEL_ROUTE_PERMITTED', '', outcome~value, outcome)

::method assessForPlan
  use strict arg workload, resource, context=.nil, planState=.nil
  authority = 'ai.model.router/0.1'
  if resource == .nil | \resource~isA(.AIModelRouteCandidate) then -
      return .IntentionAssessment~new(.false, authority, 'AI_MODEL_ROUTER_RESOURCE_REQUIRED', resource)
  if planState == .nil then return .IntentionAssessment~new(.false, authority, 'AI_MODEL_ROUTER_PLAN_STATE_REQUIRED')
  if \planState~ok then return .IntentionAssessment~new(.false, authority, planState~code, planState~outcome)
  if planState~plan~routeId \= resource~routeId then -
      return .IntentionAssessment~new(.false, authority, 'AI_MODEL_ROUTE_NOT_SELECTED', planState~outcome)

  /* The route is policy-permitted and selected, but deliberately not admitted
   * or executable. Ordinary GCI WLU/allocation/computation checks still apply,
   * and the eventual handoff still requires authoritative revalidation. */
  return .IntentionAssessment~new(.true, authority, 'AI_MODEL_ROUTE_PERMITTED_NOT_ADMITTED', planState~outcome)

::method assess
  use strict arg workload, resource, context=.nil
  state = self~beginPlan(workload, .array~of(resource), context)
  return self~assessForPlan(workload, resource, context, state)

::method routingContext private
  use strict arg context=.nil
  if context == .nil then return .nil
  if context~isA(.AIModelRouterPlanningContext) then return context
  if context~isA(.Directory) then do
    routeContext = context['AI_MODEL_ROUTER_CONTEXT']
    if routeContext \== .nil then do
      if routeContext~isA(.AIModelRouterPlanningContext) then return routeContext
    end
  end
  return .nil

::requires 'GeneralizedComputeIntentions.cls'
::requires 'AIModelRouter.cls'
