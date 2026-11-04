/* Remote Compute MU: authenticated mesh ingress v0.1-dev3 candidate.
 * The transport supplies the authenticated context OUT OF BAND.
 * A payload-supplied identity is NEVER sufficient for admission.
 * The injected policy alone verifies identity, service capability,
 * current LDAP/mesh epoch, ownership fence, and message freshness.
 * This service does not create or validate placement or WLU leases.
 */
::class RemoteComputeMUMeshService public
::method init
  expose frontend policy
  use strict arg frontend = .nil, policy = .nil

::method handle
  expose frontend policy
  use strict arg envelope, trustedContext = .nil
  if \envelope~isA(.Directory) then return self~response('', 'BAD_ENVELOPE')
  if \envelope~hasIndex('requestId') then return self~response('', 'MISSING_REQUEST_ID')
  rid = envelope~at('requestId')
  if \rid~isA(.String) then return self~response('', 'BAD_REQUEST_ID')
  if rid~length < 1 | rid~length > 128 then return self~response('', 'BAD_REQUEST_ID')
  if \envelope~hasIndex('service') then return self~response(rid, 'MISSING_SERVICE')
  service = envelope~at('service')
  if service \== 'compute.remote/0.1' then return self~response(rid, 'SERVICE_NOT_FOUND')
  if \envelope~hasIndex('operation') then return self~response(rid, 'MISSING_OPERATION')
  operation = envelope~at('operation')
  if operation \== 'DISPATCH' & operation \== 'STATUS' & operation \== 'CANCEL' & operation \== 'RECOVER' then return self~response(rid, 'UNSUPPORTED_OPERATION')
  if \envelope~hasIndex('jobId') then return self~response(rid, 'MISSING_JOB_ID')
  jobId = envelope~at('jobId')
  if \jobId~isA(.String) then return self~response(rid, 'BAD_JOB_ID')
  if jobId~length < 1 | jobId~length > 128 then return self~response(rid, 'BAD_JOB_ID')
  if \self~safeId(jobId) then return self~response(rid, 'BAD_JOB_ID')

  /* Policy is mandatory on ALL verbs, including supposedly read-only STATUS.
     trustedContext must come from the verified carrier, not the message. */
  if policy == .nil | trustedContext == .nil then return self~response(rid, 'UNAUTHENTICATED')
  decision = policy~admit(trustedContext, service, operation, jobId, rid)
  if decision \== 'ALLOW' then return self~response(rid, 'NOT_AUTHORIZED')
  if frontend == .nil then return self~response(rid, 'CONTROLLER_NOT_BOUND')

  select
    when operation == 'DISPATCH' then do
      if \envelope~hasIndex('intent') then return self~response(rid, 'MISSING_INTENT')
      fields = envelope~at('intent')
      if \fields~isA(.Directory) then return self~response(rid, 'BAD_INTENT')
      if \fields~hasIndex('jobId') then return self~response(rid, 'MISSING_INTENT_JOB_ID')
      if fields~at('jobId') \== jobId then return self~response(rid, 'INTENT_ID_MISMATCH')
      intent = .RemoteComputeMUIntent~new(fields)
      assessment = intent~verify
      if assessment \== 'OK' then return self~response(rid, assessment)
      result = frontend~dispatch(intent)
    end
    when operation == 'STATUS' then result = frontend~refresh(jobId)
    when operation == 'CANCEL' then result = frontend~cancel(jobId)
    when operation == 'RECOVER' then result = frontend~reconcile(jobId)
    otherwise return self~response(rid, 'UNSUPPORTED_OPERATION')
  end
  return self~response(rid, 'ACCEPTED', result)

::method safeId private
  use strict arg value
  valid = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
  do i = 1 to value~length
    if pos(value~substr(i,1), valid) == 0 then return .false
  end
  return .true

::method response private
  use strict arg rid, outcome, result = .nil
  reply = .Directory~new
  reply['schema'] = 'compute.remote.reply/0.1'
  reply['requestId'] = rid
  reply['outcome'] = outcome
  /* Results remain semantic objects. The real Queue Fabric/XTP serializer
     MUST use an explicit allowlisted projection, not generic object dumps. */
  if result \== .nil then reply['result'] = result
  return reply

::requires 'RemoteComputeMUFront.cls'
