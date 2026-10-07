/* MvsIntentionSurfaceAdapter.cls
 * Adapter between the existing discovery-first MVS Intention Runner and
 * Management Intention Discovery.  This file does not reimplement MVS
 * semantics and does not dispatch MVS operations.
 */

::class ManagementMvsIntentionSurfaceSource public
::method init
  use arg runner, sourceId = 'mvs'
  if runner == .nil then raise syntax 93.900 array('MVS intention runner must not be NIL')
  self~runner = runner
  self~sourceIdValue = sourceId

::attribute runner
::attribute sourceIdValue

::method sourceId
  return self~sourceIdValue

/* Surface discovery deliberately refreshes the MVS runner first.  The returned
 * Directory is only a management projection; the actual runner, service and
 * snapshot remain the authoritative objects and are retained intact. */
::method discover
  use arg context=.nil
  runner = self~runner
  snapshot = runner~refresh
  service = runner~service
  operations = .Array~new
  registrations = service~registrations
  supplier = registrations~supplier
  do while supplier~available
    operations~append(supplier~index)
    supplier~next
  end

  surface = .Directory~new
  surface['provider'] = 'mvs.intention.runner/0.1-dev3'
  surface['authority'] = 'MVS'
  surface['operations'] = operations
  surface['mutating'] = .false
  surface['runner'] = runner
  surface['service'] = service
  surface['snapshot'] = snapshot
  surface['context'] = context
  return surface

/* Relevance is delegated to the MVS runner's own Intention Service.  Management
 * does not duplicate MVS vocabulary or maintain a keyword table.  Calling
 * input() is safe here because the existing runner is read-only and refreshes
 * its discovery state before resolving meaning. */
::method assessRelevance
  use arg request, surface, context=.nil
  decision = self~runner~input(request)
  if decision~status == 'UNKNOWN' then do
    return .ManagementRelevanceAssessment~new(.false, 0, 'MVS', 'MVS_INTENTION_UNKNOWN', decision)
  end

  score = 1
  if decision~proposal \== .nil then score = decision~proposal~score
  reason = 'MVS_INTENTION_' || decision~status
  return .ManagementRelevanceAssessment~new(.true, score, 'MVS', reason, decision)

::requires 'ManagementIntentionDiscovery.cls'
