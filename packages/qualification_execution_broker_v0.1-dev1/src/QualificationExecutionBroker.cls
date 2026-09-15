/* ooRexx Qualification Execution Broker v0.1-dev1
 * Human-authorised, preflight-first qualification authority.
 * The server stores public verification keys only. Private signing material is
 * deliberately outside this package and outside the execution node.
 */

::class QebBuild public
::constant VERSION "0.1-dev1"
::constant API "oorexx.qualification.execution/0.1"
::constant EVENT_SCHEMA "oorexx.qualification.event/1"
::constant INTENT_SCHEMA "oorexx.qualification.intent/1"
::constant RESULT_SCHEMA "oorexx.qualification.result/1"
::constant SIGN_DOMAIN "oorexx.qeb.authorization/1:"

::class QebUtil public
::method string class
  use strict arg value, defaultValue=''
  if value == .nil then return defaultValue
  return value~string

::method optional class
  use strict arg args, name, defaultValue=''
  if args == .nil | \args~hasIndex(name) then return defaultValue
  return self~string(args[name],defaultValue)

::method required class
  use strict arg args, name
  value=self~optional(args,name,'')~strip
  return value

::method boolValue class
  use strict arg value, defaultValue=.false
  if value == .nil then return defaultValue
  text=value~string~lower~strip
  return text='1' | text='true' | text='yes' | text='on'

::method number class
  use strict arg value, defaultValue=0
  if value == .nil then return defaultValue
  text=value~string~strip
  if \text~datatype('W') then return defaultValue
  return text+0

::method copyDirectory class
  use strict arg source
  target=.directory~new
  if source == .nil then return target
  do key over source; target[key]=source[key]; end
  return target

::method nowIso class
  return .DateTime~new~utcIsoDate

::method plusSecondsIso class
  use strict arg seconds
  return .DateTime~new~addSeconds(seconds)~utcIsoDate

::method appendCanonical class
  use strict arg text, name, value
  value=self~string(value)
  return text || name || '=' || value~length || ':' || value || '0a'x

::method canonicalIntent class
  use strict arg intent
  text=''
  names=.array~of('schema','runId','requesterId','purpose','artifactId','artifactSha256', -
    'dataId','dataManifestSha256','runtimeId','runtimeManifestSha256','sandboxId','sandboxProfileSha256', -
    'testPlanId','testPlanManifestSha256','targetId','targetProfileSha256','maxRuntimeSeconds','maxWlu', -
    'networkPolicy','createdAt','authorizationExpiresAt','nonce','materialSha256')
  do name over names; text=self~appendCanonical(text,name,intent[name]); end
  commands=intent['commands']
  text=self~appendCanonical(text,'commands.count',commands~items)
  i=0
  do command over commands
    i+=1; text=self~appendCanonical(text,'commands.'||i,command)
  end
  scopes=intent['writableScopes']
  text=self~appendCanonical(text,'writableScopes.count',scopes~items)
  i=0
  do scope over scopes
    i+=1; text=self~appendCanonical(text,'writableScopes.'||i,scope)
  end
  return text

::method canonicalMaterial class
  use strict arg resolved
  text=''
  names=.array~of('artifactId','artifactSha256','dataId','dataManifestSha256','runtimeId','runtimeManifestSha256', -
    'sandboxId','sandboxProfileSha256','testPlanId','testPlanManifestSha256','targetId','targetProfileSha256', -
    'maxRuntimeSeconds','maxWlu','networkPolicy')
  do name over names; text=self~appendCanonical(text,name,resolved[name]); end
  commands=resolved['commands']; text=self~appendCanonical(text,'commands.count',commands~items)
  i=0; do command over commands; i+=1; text=self~appendCanonical(text,'commands.'||i,command); end
  scopes=resolved['writableScopes']; text=self~appendCanonical(text,'writableScopes.count',scopes~items)
  i=0; do scope over scopes; i+=1; text=self~appendCanonical(text,'writableScopes.'||i,scope); end
  return text

::method sha256 class
  use strict arg text
  return .SHA256~new(text)~digest

::method signatureMessage class
  use strict arg intentHash
  return .QebBuild~SIGN_DOMAIN || intentHash

::class QebAuthorityCatalog public
::method init
  expose kinds
  kinds=.directory~new

::method add
  expose kinds
  use strict arg kind, id, descriptor
  kind=kind~lower; id=id~string
  if \kinds~hasIndex(kind) then kinds[kind]=.directory~new
  copy=.QebUtil~copyDirectory(descriptor)
  copy['id']=id
  kinds[kind][id]=copy
  return copy

::method get
  expose kinds
  use strict arg kind,id
  kind=kind~lower; id=id~string
  if \kinds~hasIndex(kind) then return .nil
  if \kinds[kind]~hasIndex(id) then return .nil
  return kinds[kind][id]

::method has
  use strict arg kind,id
  return self~get(kind,id)<>.nil

::class QebApproverRegistry public
::method init
  expose keys
  keys=.directory~new

::method add
  expose keys
  use strict arg keyId, publicKeyHex, label='Human approver', active=.true
  d=.directory~new
  d['keyId']=keyId~string
  d['publicKeyHex']=publicKeyHex~string~lower
  d['label']=label~string
  d['active']=active
  d['fingerprintSha256']=.QebUtil~sha256(x2c(publicKeyHex))
  keys[keyId~string]=d
  return d

::method get
  expose keys
  use strict arg keyId
  if keys~hasIndex(keyId) then return keys[keyId]
  return .nil

::method publicList
  expose keys
  out=.array~new
  do keyId over keys
    key=keys[keyId]
    if \.QebUtil~boolValue(key['active']) then iterate
    d=.directory~new
    d['keyId']=key['keyId']; d['label']=key['label']; d['fingerprintSha256']=key['fingerprintSha256']
    d['algorithm']='Ed25519'
    d['publicKeyHex']=key['publicKeyHex']
    out~append(d)
  end
  return out

::class QebMemoryJournal public
::method init
  expose entries
  entries=.array~new
::method append
  expose entries
  use strict arg event
  entries~append(event); return event
::method events
  expose entries
  out=.array~new; do event over entries; out~append(event); end; return out

::class QebJsonlJournal public
::attribute path get
::method init
  expose path
  use strict arg path
  if path='' then raise syntax 40.900 array('Qualification journal path is required')
::method append
  expose path
  use strict arg event
  result=stream(path,'c','open write append')
  if result~left(5)<>'READY' & result~left(6)<>'NORMAL' then raise syntax 40.900 array('Unable to open qualification journal',path,result)
  call lineout path,.json~toJSON(event)
  call stream path,'c','close'
  return event
::method events
  expose path
  out=.array~new
  if stream(path,'c','query exists')='' then return out
  result=stream(path,'c','open read')
  if result~left(5)<>'READY' & result~left(6)<>'NORMAL' then raise syntax 40.900 array('Unable to read qualification journal',path,result)
  lineNumber=0
  do while lines(path)>0
    line=linein(path); lineNumber+=1
    if line~strip='' then iterate
    signal on syntax name badLine
    event=.json~fromJSON(line)
    signal off syntax
    if event==.nil | \event~isA(.Directory) | \event~hasIndex('schema') | \event~hasIndex('eventType') then raise syntax 40.900 array('Invalid qualification journal event',lineNumber)
    if event['schema']<>.QebBuild~EVENT_SCHEMA then raise syntax 40.900 array('Unsupported qualification event schema',event['schema'])
    out~append(event)
  end
  call stream path,'c','close'
  return out
badLine:
  call stream path,'c','close'
  raise syntax 40.900 array('Malformed qualification journal JSON',path,lineNumber)

::class QebEd25519Verifier public
::method verify
  use strict arg message, signatureHex, publicKeyHex
  if signatureHex~length<>128 | publicKeyHex~length<>64 then return .false
  signal on syntax name badSignature
  result=.Ed25519~verify(message,signatureHex,publicKeyHex)
  signal off syntax
  return result
badSignature:
  return .false

::class QualificationExecutionBroker public
::attribute catalog get
::attribute journal get
::attribute approvers get

::method init
  expose catalog journal approvers verifier runs sequence authorizationTtlSeconds
  use strict arg catalog, journal, approvers, verifier=.nil, authorizationTtlSeconds=3600
  if catalog==.nil | journal==.nil | approvers==.nil then raise syntax 40.900 array('Qualification catalog, journal and approver registry are required')
  if verifier==.nil then verifier=.QebEd25519Verifier~new
  runs=.directory~new; sequence=0
  self~replay

::method dispatch
  use strict arg operation,args=.nil,actorId=''
  operation=operation~upper
  select
    when operation='QUALIFICATION.PLAN' then return self~plan(args,actorId)
    when operation='QUALIFICATION.REQUEST' then return self~request(args,actorId)
    when operation='QUALIFICATION.AUTHORIZATION.CHALLENGE' then return self~authorizationChallenge(args,actorId)
    when operation='QUALIFICATION.AUTHORIZATION.SUBMIT' then return self~authorizationSubmit(args,actorId)
    when operation='QUALIFICATION.STATUS' then return self~status(args,actorId)
    when operation='QUALIFICATION.RESULTS' then return self~results(args,actorId)
    when operation='QUALIFICATION.CANCEL' then return self~cancel(args,actorId)
    otherwise return .WireUIResult~failure('UNKNOWN_OPERATION','Unknown qualification operation: '||operation)
  end

::method plan
  use strict arg args,actorId=''
  if actorId='' then return .WireUIResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED','Qualification planning requires an authenticated requesting principal')
  resolvedResult=self~resolvePlan(args)
  if \resolvedResult~ok then return resolvedResult
  value=.directory~new
  value['schema']='oorexx.qualification.plan/1'
  value['runnable']=.json~true
  value['authorizationRequired']=.json~false
  value['resolved']=resolvedResult~value
  value['detail']='Preflight passed. No authorization challenge has been generated.'
  return .WireUIResult~success(value,'PREFLIGHT_VALIDATED')

::method request
  expose authorizationTtlSeconds
  use strict arg args,actorId=''
  if actorId='' then return .WireUIResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED','Qualification requests require an authenticated requesting principal')
  resolvedResult=self~resolvePlan(args)
  if \resolvedResult~ok then return resolvedResult
  resolved=resolvedResult~value
  runId=self~nextId('RUN')
  now=.QebUtil~nowIso
  expires=.QebUtil~plusSecondsIso(authorizationTtlSeconds)
  intent=.directory~new
  intent['schema']=.QebBuild~INTENT_SCHEMA; intent['runId']=runId; intent['requesterId']=actorId
  intent['purpose']=.QebUtil~optional(args,'purpose','')
  copyNames=.array~of('artifactId','artifactSha256','dataId','dataManifestSha256','runtimeId','runtimeManifestSha256', -
    'sandboxId','sandboxProfileSha256','testPlanId','testPlanManifestSha256','targetId','targetProfileSha256', -
    'maxRuntimeSeconds','maxWlu','networkPolicy','commands','writableScopes')
  do name over copyNames; intent[name]=resolved[name]; end
  intent['createdAt']=now; intent['authorizationExpiresAt']=expires
  intent['nonce']=self~nextId('NONCE')
  intent['materialSha256']=.QebUtil~sha256(.QebUtil~canonicalMaterial(resolved))
  intentHash=.QebUtil~sha256(.QebUtil~canonicalIntent(intent))

  pre=.directory~new; pre['schema']=.QebBuild~EVENT_SCHEMA; pre['eventType']='RUN_PREFLIGHT_VALIDATED'; pre['eventId']=self~nextId('EVT')
  pre['runId']=runId; pre['requesterId']=actorId; pre['occurredAt']=now; pre['materialSha256']=intent['materialSha256']
  self~record(pre)
  frozen=.directory~new; frozen['schema']=.QebBuild~EVENT_SCHEMA; frozen['eventType']='RUN_INTENT_FROZEN'; frozen['eventId']=self~nextId('EVT')
  frozen['runId']=runId; frozen['requesterId']=actorId; frozen['occurredAt']=now; frozen['intent']=intent; frozen['intentHash']=intentHash
  self~record(frozen)

  value=self~runPublic(runId)
  value['authorizationRequired']=.json~true
  value['preflightPassed']=.json~true
  return .WireUIResult~success(value,'QUALIFICATION_AWAITING_AUTHORIZATION')

::method authorizationChallenge
  expose approvers
  use strict arg args,actorId=''
  runResult=self~ownedRun(args,actorId)
  if \runResult~ok then return runResult
  run=runResult~value
  if run['state']<>'AWAITING_AUTHORIZATION' then return .WireUIResult~failure('AUTHORIZATION_NOT_AVAILABLE','Run is not awaiting authorization')
  if .QebUtil~nowIso > run['intent']['authorizationExpiresAt'] then return .WireUIResult~failure('AUTHORIZATION_EXPIRED','Authorization window has expired')
  value=.directory~new
  value['schema']='oorexx.qualification.authorization.challenge/1'
  value['runId']=run['runId']; value['intent']=run['intent']; value['intentHash']=run['intentHash']
  value['messageToSign']=.QebUtil~signatureMessage(run['intentHash'])
  value['algorithm']='Ed25519'; value['approverKeys']=approvers~publicList
  value['instructions']='Verify the canonical intent locally, render it locally for the human, and sign only after explicit approval. Private key material must never be sent to the server.'
  return .WireUIResult~success(value,'AUTHORIZATION_CHALLENGE_READY')

::method authorizationSubmit
  expose approvers verifier
  use strict arg args,actorId=''
  runResult=self~ownedRun(args,actorId)
  if \runResult~ok then return runResult
  run=runResult~value
  if run['state']<>'AWAITING_AUTHORIZATION' then return .WireUIResult~failure('AUTHORIZATION_NOT_AVAILABLE','Run is not awaiting authorization')
  if .QebUtil~nowIso > run['intent']['authorizationExpiresAt'] then return .WireUIResult~failure('AUTHORIZATION_EXPIRED','Authorization window has expired')
  keyId=.QebUtil~required(args,'approverKeyId'); signature=.QebUtil~required(args,'signature')~lower
  if keyId='' | signature='' then return .WireUIResult~failure('INVALID_ARGUMENT','approverKeyId and signature are required')
  key=approvers~get(keyId)
  if key==.nil | \.QebUtil~boolValue(key['active']) then return .WireUIResult~failure('APPROVER_KEY_UNAVAILABLE','Approver public key is unknown or inactive')
  message=.QebUtil~signatureMessage(run['intentHash'])
  if \verifier~verify(message,signature,key['publicKeyHex']) then return .WireUIResult~failure('AUTHORIZATION_SIGNATURE_INVALID','Detached Ed25519 signature did not verify')
  event=.directory~new; event['schema']=.QebBuild~EVENT_SCHEMA; event['eventType']='RUN_AUTHORIZED'; event['eventId']=self~nextId('EVT')
  event['runId']=run['runId']; event['occurredAt']=.QebUtil~nowIso; event['grantId']=self~nextId('GRANT')
  event['approverKeyId']=keyId; event['approverFingerprintSha256']=key['fingerprintSha256']; event['signature']=signature; event['intentHash']=run['intentHash']
  self~record(event)
  return .WireUIResult~success(self~runPublic(run['runId']),'QUALIFICATION_AUTHORIZED')

::method status
  use strict arg args,actorId=''
  runResult=self~ownedRun(args,actorId)
  if \runResult~ok then return runResult
  return .WireUIResult~success(self~runPublic(runResult~value['runId']),'QUALIFICATION_STATUS')

::method results
  use strict arg args,actorId=''
  runResult=self~ownedRun(args,actorId)
  if \runResult~ok then return runResult
  run=runResult~value
  if \run~hasIndex('result') then return .WireUIResult~failure('RESULT_NOT_AVAILABLE','Qualification result has not been sealed')
  return .WireUIResult~success(run['result'],'QUALIFICATION_RESULTS')

::method cancel
  use strict arg args,actorId=''
  runResult=self~ownedRun(args,actorId)
  if \runResult~ok then return runResult
  run=runResult~value
  if run['state']='RUNNING' | run['state']='SEALED' then return .WireUIResult~failure('CANCEL_NOT_ALLOWED','Running or sealed qualification cannot be cancelled through the LLM control surface')
  if run['state']='CANCELLED' then return .WireUIResult~success(self~runPublic(run['runId']),'ALREADY_CANCELLED')
  event=.directory~new; event['schema']=.QebBuild~EVENT_SCHEMA; event['eventType']='RUN_CANCELLED'; event['eventId']=self~nextId('EVT')
  event['runId']=run['runId']; event['occurredAt']=.QebUtil~nowIso; event['cancelledBy']=actorId
  self~record(event)
  return .WireUIResult~success(self~runPublic(run['runId']),'QUALIFICATION_CANCELLED')

/* Worker-only methods. They are intentionally not dispatched through MCP. */
::method workerStart
  expose catalog
  use strict arg runId,workerId
  run=self~getRun(runId)
  if run==.nil then return .WireUIResult~failure('RUN_NOT_FOUND','Unknown qualification run')
  if run['state']<>'AUTHORIZED' then return .WireUIResult~failure('RUN_NOT_AUTHORIZED','Run is not in AUTHORIZED state')
  if .QebUtil~nowIso > run['intent']['authorizationExpiresAt'] then return .WireUIResult~failure('AUTHORIZATION_EXPIRED','Authorization expired before execution')
  revalidated=self~resolveFrozen(run['intent'])
  if \revalidated~ok then do
    self~recordStale(run,revalidated~code||':'||revalidated~detail)
    return .WireUIResult~failure('INTENT_STALE','Pre-execution revalidation failed: '||revalidated~detail)
  end
  currentMaterial=.QebUtil~sha256(.QebUtil~canonicalMaterial(revalidated~value))
  if currentMaterial<>run['intent']['materialSha256'] then do
    self~recordStale(run,'material fingerprint changed')
    return .WireUIResult~failure('INTENT_STALE','Artifact/data/runtime/sandbox/test-plan/target material changed after authorization')
  end
  event=.directory~new; event['schema']=.QebBuild~EVENT_SCHEMA; event['eventType']='RUN_EXECUTION_STARTED'; event['eventId']=self~nextId('EVT')
  event['runId']=runId; event['occurredAt']=.QebUtil~nowIso; event['workerId']=workerId; event['grantId']=run['grantId']; event['intentHash']=run['intentHash']
  self~record(event)
  return .WireUIResult~success(self~runPublic(runId),'QUALIFICATION_RUNNING')

::method workerSeal
  use strict arg runId,workerId,outcome,evidenceManifestSha256,summary=''
  run=self~getRun(runId)
  if run==.nil then return .WireUIResult~failure('RUN_NOT_FOUND','Unknown qualification run')
  if run['state']<>'RUNNING' then return .WireUIResult~failure('RUN_NOT_RUNNING','Run is not executing')
  if run['workerId']<>workerId then return .WireUIResult~failure('WORKER_MISMATCH','Only the worker that started the run may seal it')
  outcome=outcome~upper
  if outcome<>'QUALIFIED' & outcome<>'FAILED' & outcome<>'INCONCLUSIVE' then return .WireUIResult~failure('INVALID_OUTCOME','Outcome must be QUALIFIED, FAILED or INCONCLUSIVE')
  if evidenceManifestSha256='' then return .WireUIResult~failure('INVALID_ARGUMENT','evidenceManifestSha256 is required')
  resultSet=.directory~new
  resultSet['schema']=.QebBuild~RESULT_SCHEMA
  resultSet['runId']=runId
  resultSet['intentHash']=run['intentHash']
  resultSet['grantId']=run['grantId']
  resultSet['workerId']=workerId
  resultSet['outcome']=outcome
  resultSet['evidenceManifestSha256']=evidenceManifestSha256
  resultSet['summary']=summary
  resultSet['completedAt']=.QebUtil~nowIso
  canonical='runId='||runId||'0a'x||'intentHash='||run['intentHash']||'0a'x||'grantId='||run['grantId']||'0a'x|| -
    'workerId='||workerId||'0a'x||'outcome='||outcome||'0a'x||'evidenceManifestSha256='||evidenceManifestSha256||'0a'x||'summary='||summary
  resultSet['resultSetSha256']=.QebUtil~sha256(canonical)
  event=.directory~new
  event['schema']=.QebBuild~EVENT_SCHEMA
  event['eventType']='RUN_RESULT_SEALED'
  event['eventId']=self~nextId('EVT')
  event['runId']=runId
  event['occurredAt']=resultSet['completedAt']
  event['result']=resultSet
  self~record(event)
  return .WireUIResult~success(resultSet,'QUALIFICATION_RESULT_SEALED')

::method resolvePlan private
  use strict arg args
  if args==.nil then return .WireUIResult~failure('INVALID_ARGUMENT','Qualification plan arguments are required')
  ids=.array~of('artifactId','dataId','runtimeId','sandboxId','testPlanId','targetId')
  do idName over ids
    if .QebUtil~required(args,idName)='' then return .WireUIResult~failure('INVALID_ARGUMENT',idName||' is required')
  end
  return self~resolveMaterial(.QebUtil~required(args,'artifactId'),.QebUtil~required(args,'dataId'),.QebUtil~required(args,'runtimeId'), -
    .QebUtil~required(args,'sandboxId'),.QebUtil~required(args,'testPlanId'),.QebUtil~required(args,'targetId'), -
    .QebUtil~optional(args,'maxRuntimeSeconds',''),.QebUtil~optional(args,'maxWlu',''))

::method resolveFrozen private
  use strict arg intent
  return self~resolveMaterial(intent['artifactId'],intent['dataId'],intent['runtimeId'],intent['sandboxId'],intent['testPlanId'],intent['targetId'],intent['maxRuntimeSeconds'],intent['maxWlu'])

::method resolveMaterial private
  expose catalog
  use strict arg artifactId,dataId,runtimeId,sandboxId,testPlanId,targetId,maxRuntimeArg='',maxWluArg=''
  artifact=catalog~get('artifact',artifactId); if artifact==.nil then return .WireUIResult~failure('ARTIFACT_NOT_FOUND','Unknown artifact identity: '||artifactId)
  if \.QebUtil~boolValue(artifact['signed']) | \.QebUtil~boolValue(artifact['checked']) | \.QebUtil~boolValue(artifact['deployed']) then return .WireUIResult~failure('ARTIFACT_NOT_RUNNABLE','Artifact must already be signed, checked and deployed')
  artifactSha=.QebUtil~optional(artifact,'sha256',''); if artifactSha='' then return .WireUIResult~failure('ARTIFACT_HASH_MISSING','Artifact SHA-256 is required')

  data=catalog~get('data',dataId); if data==.nil then return .WireUIResult~failure('DATA_NOT_FOUND','Unknown authorised data identity: '||dataId)
  if \.QebUtil~boolValue(data['authorized']) | \.QebUtil~boolValue(data['available']) then return .WireUIResult~failure('DATA_NOT_RUNNABLE','Data must be authorised and available')
  dataSha=.QebUtil~optional(data,'manifestSha256',''); if dataSha='' then return .WireUIResult~failure('DATA_HASH_MISSING','Data manifest SHA-256 is required')

  runtime=catalog~get('runtime',runtimeId); if runtime==.nil then return .WireUIResult~failure('RUNTIME_NOT_FOUND','Unknown runtime identity: '||runtimeId)
  if \.QebUtil~boolValue(runtime['available']) then return .WireUIResult~failure('RUNTIME_NOT_AVAILABLE','Requested runtime is not available')
  runtimeSha=.QebUtil~optional(runtime,'manifestSha256',''); if runtimeSha='' then return .WireUIResult~failure('RUNTIME_HASH_MISSING','Runtime manifest SHA-256 is required')

  sandbox=catalog~get('sandbox',sandboxId); if sandbox==.nil then return .WireUIResult~failure('SANDBOX_NOT_FOUND','Unknown sandbox profile: '||sandboxId)
  if \.QebUtil~boolValue(sandbox['available']) | \.QebUtil~boolValue(sandbox['constructible']) then return .WireUIResult~failure('SANDBOX_NOT_RUNNABLE','Sandbox profile is not constructible')
  sandboxSha=.QebUtil~optional(sandbox,'profileSha256',''); if sandboxSha='' then return .WireUIResult~failure('SANDBOX_HASH_MISSING','Sandbox profile SHA-256 is required')

  plan=catalog~get('testplan',testPlanId); if plan==.nil then return .WireUIResult~failure('TEST_PLAN_NOT_FOUND','Unknown test plan identity: '||testPlanId)
  if \.QebUtil~boolValue(plan['valid']) then return .WireUIResult~failure('TEST_PLAN_INVALID','Test plan is not qualification-valid')
  planSha=.QebUtil~optional(plan,'manifestSha256',''); if planSha='' then return .WireUIResult~failure('TEST_PLAN_HASH_MISSING','Test plan manifest SHA-256 is required')
  if \plan~hasIndex('commands') | plan['commands']==.nil | \plan['commands']~isA(.Array) | plan['commands']~items=0 then return .WireUIResult~failure('TEST_PLAN_EMPTY','Test plan must contain pre-authorised command entries')

  target=catalog~get('target',targetId); if target==.nil then return .WireUIResult~failure('TARGET_NOT_FOUND','Unknown qualification target: '||targetId)
  if \.QebUtil~boolValue(target['eligible']) | \.QebUtil~boolValue(target['available']) then return .WireUIResult~failure('TARGET_NOT_ELIGIBLE','Qualification target is not currently eligible and available')
  targetSha=.QebUtil~optional(target,'profileSha256',''); if targetSha='' then return .WireUIResult~failure('TARGET_HASH_MISSING','Target profile SHA-256 is required')

  maxRuntime=.QebUtil~number(maxRuntimeArg,0); sandboxMax=.QebUtil~number(sandbox['maxRuntimeSeconds'],0)
  if maxRuntime<=0 then maxRuntime=sandboxMax
  if maxRuntime<=0 | (sandboxMax>0 & maxRuntime>sandboxMax) then return .WireUIResult~failure('RESOURCE_LIMIT_INVALID','Requested runtime exceeds sandbox policy')
  maxWlu=.QebUtil~number(maxWluArg,0); sandboxWlu=.QebUtil~number(sandbox['maxWlu'],0)
  if maxWlu<=0 then maxWlu=sandboxWlu
  if maxWlu<=0 | (sandboxWlu>0 & maxWlu>sandboxWlu) then return .WireUIResult~failure('RESOURCE_LIMIT_INVALID','Requested WLU exceeds sandbox policy')

  resolved=.directory~new
  resolved['artifactId']=artifactId; resolved['artifactSha256']=artifactSha
  resolved['dataId']=dataId; resolved['dataManifestSha256']=dataSha
  resolved['runtimeId']=runtimeId; resolved['runtimeManifestSha256']=runtimeSha
  resolved['sandboxId']=sandboxId; resolved['sandboxProfileSha256']=sandboxSha
  resolved['testPlanId']=testPlanId; resolved['testPlanManifestSha256']=planSha
  resolved['targetId']=targetId; resolved['targetProfileSha256']=targetSha
  resolved['maxRuntimeSeconds']=maxRuntime; resolved['maxWlu']=maxWlu
  resolved['networkPolicy']=.QebUtil~optional(sandbox,'networkPolicy','DENY')
  resolved['commands']=plan['commands']
  if sandbox~hasIndex('writableScopes') & sandbox['writableScopes']<>.nil then resolved['writableScopes']=sandbox['writableScopes']
  else resolved['writableScopes']=.array~new
  return .WireUIResult~success(resolved,'PREFLIGHT_VALIDATED')

::method ownedRun private
  use strict arg args,actorId
  if actorId='' then return .WireUIResult~failure('AUTHENTICATED_PRINCIPAL_REQUIRED','Authenticated requester is required')
  runId=.QebUtil~required(args,'runId'); if runId='' then return .WireUIResult~failure('INVALID_ARGUMENT','runId is required')
  run=self~getRun(runId); if run==.nil then return .WireUIResult~failure('RUN_NOT_FOUND','Unknown qualification run: '||runId)
  if run['requesterId']<>actorId then return .WireUIResult~failure('RUN_ACCESS_FORBIDDEN','Run belongs to another requesting principal')
  return .WireUIResult~success(run,'RUN_RESOLVED')

::method getRun private
  expose runs
  use strict arg runId
  if runs~hasIndex(runId) then return runs[runId]
  return .nil

::method runPublic private
  use strict arg runId
  run=self~getRun(runId)
  d=.directory~new
  d['schema']='oorexx.qualification.run/1'; d['runId']=runId; d['requesterId']=run['requesterId']; d['state']=run['state']
  if run~hasIndex('intentHash') then d['intentHash']=run['intentHash']
  if run~hasIndex('intent') then d['intent']=run['intent']
  if run~hasIndex('grantId') then do d['grantId']=run['grantId']; d['approverKeyId']=run['approverKeyId']; end
  if run~hasIndex('workerId') then d['workerId']=run['workerId']
  if run~hasIndex('staleReason') then d['staleReason']=run['staleReason']
  if run~hasIndex('result') then d['result']=run['result']
  return d

::method recordStale private
  use strict arg run,reason
  event=.directory~new; event['schema']=.QebBuild~EVENT_SCHEMA; event['eventType']='RUN_INTENT_STALE'; event['eventId']=self~nextId('EVT')
  event['runId']=run['runId']; event['occurredAt']=.QebUtil~nowIso; event['reason']=reason
  self~record(event)

::method nextId private
  expose sequence
  use strict arg prefix
  sequence+=1
  return prefix||'-'||sequence~string~right(8,'0')

::method record private
  expose journal
  use strict arg event
  journal~append(event); self~apply(event); return event

::method replay private
  expose journal sequence
  sequence=0
  do event over journal~events
    self~observeIds(event); self~apply(event)
  end

::method observeIds private
  expose sequence
  use strict arg event
  do key over event
    value=.QebUtil~string(event[key]); parse var value . '-' suffix
    if suffix~datatype('W') & suffix>sequence then sequence=suffix
  end

::method apply private
  expose runs
  use strict arg event
  type=event['eventType']; runId=.QebUtil~optional(event,'runId','')
  select
    when type='RUN_PREFLIGHT_VALIDATED' then do
      if \runs~hasIndex(runId) then runs[runId]=.directory~new
      runs[runId]['runId']=runId; runs[runId]['requesterId']=event['requesterId']; runs[runId]['state']='PREFLIGHT_VALIDATED'
      runs[runId]['materialSha256']=event['materialSha256']
    end
    when type='RUN_INTENT_FROZEN' then do
      run=runs[runId]; run['intent']=event['intent']; run['intentHash']=event['intentHash']; run['state']='AWAITING_AUTHORIZATION'
    end
    when type='RUN_AUTHORIZED' then do
      run=runs[runId]; run['state']='AUTHORIZED'; run['grantId']=event['grantId']; run['approverKeyId']=event['approverKeyId']; run['signature']=event['signature']
    end
    when type='RUN_INTENT_STALE' then do
      runs[runId]['state']='INTENT_STALE'
      runs[runId]['staleReason']=event['reason']
    end
    when type='RUN_EXECUTION_STARTED' then do
      runs[runId]['state']='RUNNING'
      runs[runId]['workerId']=event['workerId']
    end
    when type='RUN_RESULT_SEALED' then do
      runs[runId]['state']='SEALED'
      runs[runId]['result']=event['result']
    end
    when type='RUN_CANCELLED' then runs[runId]['state']='CANCELLED'
    otherwise raise syntax 40.900 array('Unsupported qualification journal event',type)
  end

::requires 'WireUIProtocol.cls'
::requires 'crypto.cls'
::requires 'json.cls'
