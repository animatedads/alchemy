/* Security Effect v0.14 optional irreversible-commit adapter for
 * ooRexx Access Permissions.
 *
 * The bridge requires both a fresh commit METHOD invocation and a valid
 * continuation/commit revalidation.  Security evidence remains non-authority;
 * PermissionAuthority still decides whether COMMIT may execute.  Successful
 * permission consumes both single-use security validations.
 */

::class SecurityCommitPermissionPreparation public
::attribute request get
::attribute binding get
::attribute invocationValidation get
::attribute continuationValidation get
::attribute invocationGuard get
::attribute continuationGuard get
::method init
  expose request binding invocationValidation continuationValidation invocationGuard continuationGuard
  use arg requestArg, bindingArg, invocationValidationArg, continuationValidationArg, invocationGuardArg, continuationGuardArg
  request = requestArg
  binding = bindingArg
  invocationValidation = invocationValidationArg
  continuationValidation = continuationValidationArg
  invocationGuard = invocationGuardArg
  continuationGuard = continuationGuardArg
::method commitIfAllowed
  expose invocationGuard continuationGuard invocationValidation continuationValidation
  use arg permissionResult
  if permissionResult == .nil then return .SecurityResult~failure("PERMISSION_RESULT_REQUIRED")
  if permissionResult~hasMethod("OK") then do
    if \permissionResult~ok then return .SecurityResult~failure("PERMISSION_EVALUATION_FAILED", permissionResult~code)
    envelope = permissionResult~value
  end
  else envelope = permissionResult
  if envelope == .nil | \envelope~hasMethod("DECISION") then return .SecurityResult~failure("PERMISSION_DECISION_REQUIRED")
  if \envelope~decision~allowed then return .SecurityResult~failure("PERMISSION_DENIED", envelope~decision~code)
  consumed = continuationGuard~consumeWithInvocation(continuationValidation, invocationGuard, invocationValidation)
  if \consumed~ok then return consumed
  return .SecurityResult~success(envelope)

::class SecurityContinuationAccessPermissionsBridge public
::method permissionRequestForCommit
  use arg requestId, originBinding, continuation, commitEvidence, commitAssessment, commitInvocationEvidence, invocationPolicy, invocationGuard, continuationPolicy, continuationGuard, validatedAt = .nil, liveStateIdentity = "", liveContextIdentity = ""
  if invocationGuard == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_GUARD_REQUIRED")
  if continuationGuard == .nil then return .SecurityResult~failure("SECURITY_CONTINUATION_GUARD_REQUIRED")
  bindingResult = .SecurityPermissionBindingFactory~fromInvocationAssessment(commitAssessment)
  if \bindingResult~ok then return bindingResult
  binding = bindingResult~value
  invocationValidation = invocationGuard~validate(binding, commitInvocationEvidence, invocationPolicy, validatedAt)
  if \invocationValidation~ok then return invocationValidation
  continuationValidation = continuationGuard~validateCommit(originBinding, continuation, commitEvidence, commitAssessment, continuationPolicy, validatedAt, liveStateIdentity, liveContextIdentity)
  if \continuationValidation~ok then return continuationValidation
  request = .PermissionRequest~new(requestId, binding~subjectId, binding~objectId, binding~objectClass, binding~methodName, binding~intendedAt)
  if \request~bindSecurityAssessment(commitAssessment) then return .SecurityResult~failure("PERMISSION_SECURITY_BINDING_REJECTED")
  request~seal
  prep = .SecurityCommitPermissionPreparation~new(request, binding, invocationValidation~value, continuationValidation~value, invocationGuard, continuationGuard)
  return .SecurityResult~success(prep)

::requires "SecurityEffect.cls"
::requires "AccessPermissions.cls"
