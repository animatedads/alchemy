/* Security Effect v0.13 optional adapter into ooRexx Access Permissions v0.1.
 *
 * Security Effect remains non-authoritative.  The bridge can require a fresh,
 * exact invocation binding before it creates PermissionRequest evidence, but
 * PermissionAuthority still decides whether the method may execute.
 */

::class SecurityPermissionInvocationPreparation public
::attribute request get
::attribute binding get
::attribute validation get
::attribute guard get
::method init
  expose request binding validation guard
  use arg requestArg, bindingArg, validationArg, guardArg
  request = requestArg
  binding = bindingArg
  validation = validationArg
  guard = guardArg
::method commitIfAllowed
  expose guard validation
  use arg permissionResult
  if permissionResult == .nil then return .SecurityResult~failure("PERMISSION_RESULT_REQUIRED")
  if permissionResult~hasMethod("OK") then do
    if \permissionResult~ok then return .SecurityResult~failure("PERMISSION_EVALUATION_FAILED", permissionResult~code)
    envelope = permissionResult~value
  end
  else envelope = permissionResult
  if envelope == .nil | \envelope~hasMethod("DECISION") then return .SecurityResult~failure("PERMISSION_DECISION_REQUIRED")
  if \envelope~decision~allowed then return .SecurityResult~failure("PERMISSION_DENIED", envelope~decision~code)
  consumed = guard~consume(validation)
  if \consumed~ok then return consumed
  return .SecurityResult~success(envelope)

::class SecurityAccessPermissionsBridge public
::method permissionRequest
  use arg requestId, assessment
  bindingResult = .SecurityPermissionBindingFactory~fromAssessment(assessment)
  if bindingResult~ok = .false then return bindingResult
  binding = bindingResult~value
  request = .PermissionRequest~new(requestId, binding~subjectId, binding~objectId, binding~objectClass, binding~methodName, binding~intendedAt)
  if request~bindSecurityAssessment(assessment) = .false then return .SecurityResult~failure("PERMISSION_SECURITY_BINDING_REJECTED")
  request~seal
  return .SecurityResult~success(request)
::method permissionRequestForInvocation
  use arg requestId, assessment, invocationEvidence, invocationPolicy, invocationGuard, validatedAt = .nil
  if invocationGuard == .nil then return .SecurityResult~failure("SECURITY_INVOCATION_GUARD_REQUIRED")
  bindingResult = .SecurityPermissionBindingFactory~fromInvocationAssessment(assessment)
  if \bindingResult~ok then return bindingResult
  binding = bindingResult~value
  validation = invocationGuard~validate(binding, invocationEvidence, invocationPolicy, validatedAt)
  if \validation~ok then return validation
  request = .PermissionRequest~new(requestId, binding~subjectId, binding~objectId, binding~objectClass, binding~methodName, binding~intendedAt)
  if \request~bindSecurityAssessment(assessment) then return .SecurityResult~failure("PERMISSION_SECURITY_BINDING_REJECTED")
  request~seal
  return .SecurityResult~success(.SecurityPermissionInvocationPreparation~new(request, binding, validation~value, invocationGuard))

::requires "SecurityEffect.cls"
::requires "AccessPermissions.cls"
