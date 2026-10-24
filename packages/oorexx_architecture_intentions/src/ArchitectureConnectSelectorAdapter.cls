/* Read-only architecture adapter for exact oorexx.connect_selector/0.1.
 * Inject the actual selector with explicit registered adapters; inspect() only
 * calls ConnectSelector~explain(), never execute(). The result is a feasibility
 * witness, not deployment/live network proof. Optional package dependency.
 */
::requires 'ConnectSelector.cls'

::class ArchitectureConnectSelectorAdapter public
::attribute selector get
::method init
  expose selector
  use strict arg selector
  if \selector~hasMethod('explain') | \selector~hasMethod('select') then -
    raise syntax 93.900 array('ARCH_CONNECT_SELECTOR_API_REQUIRED')

::method inspect
  use strict arg row
  detail = row['serviceIntent']
  if detail == .nil then raise syntax 93.900 array('ARCH_CONNECT_INTENT_REQUIRED')
  binding = row['binding']
  if binding == 'direct_call' then provider = 'DIRECT'
  else if binding == 'json_rpc' then provider = 'RPC'
  else if binding == 'queue_fabric' then provider = 'QUEUE'
  else raise syntax 93.900 array('ARCH_JMS_NOT_SELECTOR_PROVIDER')
  intent = .ConnectIntent~new(detail['operation'],detail['mode'], -
    detail['requirement'],provider,detail['destination'])
  observed = self~selector~explain(intent)
  review = .Directory~new
  review['schema'] = 'alchemy.architecture.selector-review/0.1'
  review['selectorContract'] = 'oorexx.connect_selector/0.1'
  review['edgeId'] = row['id']
  review['binding'] = binding
  review['provider'] = provider
  review['operation'] = detail['operation']
  review['mode'] = detail['mode']
  review['requirement'] = detail['requirement']
  review['code'] = observed['code']
  review['reason'] = observed['reason']
  review['ok'] = observed['ok']
  review['executable'] = .false
  review['liveTargetQualified'] = .false
  if observed['ok'] then review['status'] = 'ELIGIBLE_REGISTERED'
  else review['status'] = 'NOT_SUPPORTED_BY_REGISTERED_SELECTOR'
  review['interpretation'] = 'Read-only registered adapter eligibility; no operation executed, no live guarantee proved'
  return review
