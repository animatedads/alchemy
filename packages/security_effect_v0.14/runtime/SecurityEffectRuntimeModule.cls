::class SecurityEffectRuntimeModule public
::attribute moduleId get
::attribute state get
::method init
  expose moduleId state engine evidenceStore policySource policyId
  use arg policyArg, storeArg = .nil, policyIdArg = 'SECURITY-POLICY-CORE'
  moduleId = 'SECURITY_EFFECT_RUNTIME'
  state = 'CREATED'
  policySource = policyArg
  policyId = policyIdArg~string~upper
  if storeArg == .nil then evidenceStore = .SecurityEvidenceStore~new
  else evidenceStore = storeArg
  engine = .SecurityEffectEngine~new
::method runtimeStart
  expose state policySource
  if policySource == .nil then return .SecurityResult~failure('POLICY_REQUIRED')
  if policySource~hasMethod('RESOLVE') = .false then do
    if policySource~sealed = .false then return .SecurityResult~failure('POLICY_NOT_SEALED')
  end
  state = 'LIVE'
  return .SecurityResult~success(self)
::method runtimeQuiesce
  expose state
  state = 'QUIESCED'
  return .SecurityResult~success(self)
::method runtimeStop
  expose state
  state = 'STOPPED'
  return .SecurityResult~success(self)
::method assess
  expose state engine evidenceStore policySource policyId
  use arg action, deploymentPoint = .nil
  if state <> 'LIVE' then return .SecurityResult~failure('RUNTIME_NOT_LIVE')
  snap = evidenceStore~snapshotFor(action~subjectId, action~intendedAt)
  if policySource~hasMethod('RESOLVE') then do
    if policySource~hasMethod('RESOLVEFORCONTEXT') then resolved = policySource~resolveForContext(policyId, deploymentPoint, action~intendedAt)
    else resolved = policySource~resolve(policyId, action~intendedAt)
    if resolved~ok = .false then return resolved
    return engine~evaluate(action, snap, resolved~value)
  end
  return engine~evaluate(action, snap, policySource)
::method evidenceStore
  expose evidenceStore
  return evidenceStore
::method moduleKind
  return 'SECURITY_RULES'
::method apiVersion
  return .SecurityEffectBuild~API_VERSION
::requires 'SecurityEffect.cls'
