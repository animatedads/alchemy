/* Generalized Compute Intentions -> Intention Service dev11 adapter.
 *
 * The core planner remains language/service neutral. This optional adapter
 * registers the currently meaningful compute-planning operations with a fresh
 * IntentionService and exposes the structured object-preserving provider.
 *
 * Registration confers no compute, WLU, allocation or router authority.
 */
::requires 'GeneralizedComputeIntentions.cls'
::requires 'IntentionService.cls'
::requires 'IntentionProviders.cls'

::class GeneralizedComputeIntentionServiceAdapter public
::method init
  expose planner structuredProvider
  use strict arg plannerArg
  if plannerArg == .nil then raise syntax 93.900 array('Generalized compute intention planner is required')
  planner = plannerArg
  structuredProvider = .GeneralizedComputeStructuredIntentionProvider~new(planner)

::attribute planner get
::attribute structuredProvider get

::method registerCurrentSurface
  expose planner structuredProvider
  use strict arg service, workload=.nil, context=.nil
  if service == .nil then raise syntax 93.900 array('Intention Service is required')

  if service~bucket('COMPUTE_QUERY') == .nil then -
    service~registerBucket('COMPUTE_QUERY', -
      .IntentionBucketPolicy~new('FLEXIBLE', 60, 12, .false, .false))
  if service~bucket('COMPUTE_ADMISSION_PLAN') == .nil then -
    service~registerBucket('COMPUTE_ADMISSION_PLAN', -
      .IntentionBucketPolicy~new('EXPLICIT', 75, 8, .true, .false))

  registrations = .Array~new
  registrations~append(self~registerOne(service, 'plan compute admittance', -
      'PLAN_ADMITTANCE', 'COMPUTE_QUERY', workload, context))
  registrations~append(self~registerOne(service, 'explain compute admittance', -
      'EXPLAIN_ADMITTANCE', 'COMPUTE_QUERY', workload, context))
  registrations~append(self~registerOne(service, 'preferred compute route', -
      'PREFERRED_ROUTE', 'COMPUTE_QUERY', workload, context))
  registrations~append(self~registerOne(service, 'prepare compute admission', -
      'PREPARE_ADMISSION', 'COMPUTE_ADMISSION_PLAN', workload, context))

  service~registerProvider(structuredProvider)
  return registrations

::method registerOne private
  expose planner structuredProvider
  use strict arg service, phrase, operation, bucketName, workload=.nil, context=.nil
  event = .GeneralizedComputeRegisteredIntentionEvent~new(structuredProvider, -
      operation, workload, context)
  registration = service~register(phrase, event, bucketName)
  registration~metadata['provider'] = planner~providerId
  registration~metadata['operation'] = operation
  registration~metadata['mutating'] = .false
  if workload == .nil then do
    descriptor = planner~operationDescriptor(operation, workload, context)
    registration~metadata['currently_available'] = descriptor['available']
    registration~metadata['current_state'] = descriptor['state']
    registration~metadata['current_reason'] = descriptor['reason']
  end
  return registration

::class GeneralizedComputeRegisteredIntentionEvent public
::method init
  expose structuredProvider operation workload context
  use strict arg structuredProviderArg, operationArg, workloadArg=.nil, contextArg=.nil
  structuredProvider = structuredProviderArg
  operation = operationArg
  workload = workloadArg
  context = contextArg

::method invoke
  expose structuredProvider operation workload context
  use strict arg decision
  if decision == .nil then raise syntax 93.900 array('Intention decision is required')
  if decision~status == 'READY' then raise syntax 93.900 array('COMPUTE_INTENTION_NOT_READY')

  effectiveWorkload = workload
  effectiveContext = context
  slots = decision~slots
  if slots == .nil then do
    if slots~hasIndex('WORKLOAD') then effectiveWorkload = slots['WORKLOAD']
    if slots~hasIndex('CONTEXT') then effectiveContext = slots['CONTEXT']
    if slots~hasIndex('REQUEST') then return structuredProvider~executeRequest(slots['REQUEST'])
  end
  if effectiveWorkload == .nil then raise syntax 93.900 array('COMPUTE_INTENTION_WORKLOAD_REQUIRED')
  request = .GeneralizedComputeIntentionRequest~new('READY', operation, -
      effectiveWorkload, effectiveContext)
  return structuredProvider~executeRequest(request)
