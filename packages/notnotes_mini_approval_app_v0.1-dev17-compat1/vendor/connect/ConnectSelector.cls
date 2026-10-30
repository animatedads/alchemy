/* ConnectSelector 0.1-dev2: application-level communication selection.
 * An intention decides semantics; no transport is silently substituted.
 * Standalone: all external connectors are injected at construction time.
 */
::class ConnectIntent public
::attribute operation get
::attribute mode get
::attribute requirement get
::attribute preferred get
::attribute destination get
::attribute options get
::method init
  expose operation mode requirement preferred destination options
  use strict arg operation, mode = 'request', requirement = 'immediate', preferred = 'auto', destination = '', options = .nil
  if operation == '' then raise syntax 93.900 additional('operation is required')
  mode = mode~string~translate
  requirement = requirement~string~translate
  preferred = preferred~string~translate
  if mode \== 'REQUEST' & mode \== 'NOTIFY' & mode \== 'ENQUEUE' then raise syntax 93.900 additional('mode must be REQUEST, NOTIFY, or ENQUEUE')
  if requirement \== 'IMMEDIATE' & requirement \== 'BEST_EFFORT' & requirement \== 'DURABLE' then raise syntax 93.900 additional('invalid guarantee requirement')
  if requirement == 'DURABLE' & mode \== 'ENQUEUE' then raise syntax 93.900 additional('durability only valid with ENQUEUE')
  if options == .nil then options = .Directory~new
  if \(options~isA(.Directory) | options~isA(.Table)) then raise syntax 93.900 additional('options must be a Directory or Table')

/* A result never equates acceptance with execution or durable delivery. */
::class ConnectResult public
::attribute ok get
::attribute provider get
::attribute accepted get
::attribute completed get
::attribute durable get
::attribute value get
::attribute code get
::attribute detail get
::method init
  expose ok provider accepted completed durable value code detail
  use strict arg ok, provider, accepted, completed, durable, value, code, detail
::method success class
  use strict arg provider, value = .nil, accepted = .true, completed = .false, durable = .false
  return self~new(.true, provider, accepted, completed, durable, value, 'OK', '')
::method failure class
  use strict arg provider, code, detail = '', value = .nil
  return self~new(.false, provider, .false, .false, .false, value, code, detail)

::class ConnectSelection public
::attribute ok get
::attribute provider get
::attribute connector get
::attribute code get
::attribute reason get
::method init
  expose ok provider connector code reason
  use strict arg ok, provider, connector, code, reason

/* Exact operation/mode/destination route governance. Registered grants, not transport hints.
 * An explicit provider cannot circumvent this policy. No provider fallback is
 * attempted after execution has begun or after an ambiguous transport result.
 * Destination may be empty to match an intention which omits destination.
 */
::class ConnectRoutePolicy public
::method init
  expose permits denials strict
  use strict arg strict = .true
  permits = .Table~new
  denials = .Table~new
::method key private
  use strict arg operation, mode, destination
  return operation~string~translate || '|' || mode~string~translate || '|' || destination~string~translate
::method allow
  expose permits
  use strict arg operation, mode, provider, destination = ''
  key = self~key(operation,mode,destination)
  providers = permits[key]
  if providers == .nil then do
    providers = .Table~new
    permits[key] = providers
  end
  providers[provider~string~translate] = .true
  return self
::method deny
  expose denials
  use strict arg operation, mode, provider, destination = ''
  key = self~key(operation,mode,destination)
  providers = denials[key]
  if providers == .nil then do
    providers = .Table~new
    denials[key] = providers
  end
  providers[provider~string~translate] = .true
  return self
::method permitted
  expose permits denials strict
  use strict arg intention, provider
  key = self~key(intention~operation,intention~mode,intention~destination)
  denied = denials[key]
  if denied \== .nil then do
    if denied~hasIndex(provider~string~translate) then return .false
  end
  allowed = permits[key]
  if allowed \== .nil then return allowed~hasIndex(provider~string~translate)
  return \strict

::class ConnectSelector public
::method init
  expose entries policy
  use strict arg policy = .nil
  if policy \== .nil then do
    if \policy~hasMethod('permitted') then raise syntax 93.900 additional('policy must implement permitted(intent,provider)')
  end
  entries = .Directory~new
::attribute policy get
::method setPolicy
  expose policy
  use strict arg newPolicy
  if newPolicy \== .nil then do
    if \newPolicy~hasMethod('permitted') then raise syntax 93.900 additional('policy must implement permitted(intent,provider)')
  end
  policy = newPolicy
  return self
::method entryKey private
  use strict arg name, destination
  return name~string~translate || '|' || destination~string~translate
::method register
  expose entries
  use strict arg name, connector, destination = ''
  name = name~string~translate
  if name == '' then raise syntax 93.900 additional('provider name required')
  if \connector~hasMethod('supports') | \connector~hasMethod('execute') then raise syntax 93.900 additional('connector requires supports(intent), execute(intent,payload)')
  entries[self~entryKey(name,destination)] = connector
  return self
::method select
  expose entries policy
  use strict arg intention
  preferred = intention~preferred
  if preferred \== 'AUTO' then do
    connector = entries[self~entryKey(preferred,intention~destination)]
    if connector == .nil then return .ConnectSelection~new(.false,preferred,.nil,'UNREGISTERED','Provider not registered')
    if policy \== .nil then do
      if \policy~permitted(intention,preferred) then return .ConnectSelection~new(.false,preferred,.nil,'POLICY_DENIED','Provider is not authorised for this route')
    end
    if \connector~supports(intention) then return .ConnectSelection~new(.false,preferred,.nil,'UNSUPPORTED','Provider cannot meet intention')
    return .ConnectSelection~new(.true,preferred,connector,'OK','Explicit provider selected')
  end
  if intention~mode == 'ENQUEUE' then candidates = .Array~of('QUEUE')
  else candidates = .Array~of('DIRECT','RPC')
  do provider over candidates
    connector = entries[self~entryKey(provider,intention~destination)]
    if connector \== .nil then do
      permitted = .true
      if policy \== .nil then permitted = policy~permitted(intention,provider)
      if permitted then do
        if connector~supports(intention) then return .ConnectSelection~new(.true,provider,connector,'OK','Eligible provider selected')
      end
    end
  end
  return .ConnectSelection~new(.false,'',.nil,'NO_ELIGIBLE_PROVIDER','No registered provider meets requested semantics')
::method explain
  use strict arg intention
  selection = self~select(intention)
  row = .Directory~new
  row['ok'] = selection~ok
  row['provider'] = selection~provider
  row['code'] = selection~code
  row['reason'] = selection~reason
  row['mode'] = intention~mode
  row['requirement'] = intention~requirement
  row['operation'] = intention~operation
  row['destination'] = intention~destination
  row['preferred'] = intention~preferred
  return row
::method execute
  use strict arg intention, payload = .nil
  selection = self~select(intention)
  if \selection~ok then return .ConnectResult~failure(selection~provider,selection~code,selection~reason)
  /* No automatic transport retry after execution starts: its state may be uncertain. */
  return selection~connector~execute(intention,payload)

/* Both JSON-RPC and native DirectCall accept request(name, params), notify(name, params).
 * Connectors are passed by the caller; this module does not require JSON-RPC Fabric.
 */
::class ConnectCallAdapter public
::method init
  expose connector provider boundDestination
  use strict arg connector, provider, boundDestination = ''
  boundDestination = boundDestination~string~translate
  provider = provider~string~translate
  if provider \== 'DIRECT' & provider \== 'RPC' then raise syntax 93.900 additional('call provider must be DIRECT or RPC')
  if \connector~hasMethod('request') | \connector~hasMethod('notify') then raise syntax 93.900 additional('request/notify implementation required')
::method supports
  expose boundDestination
  use strict arg intention
  if intention~destination~string~translate \== boundDestination then return .false
  if intention~requirement == 'DURABLE' then return .false
  return intention~mode == 'REQUEST' | intention~mode == 'NOTIFY'
::method execute
  expose connector provider
  use strict arg intention, payload = .nil
  if \self~supports(intention) then return .ConnectResult~failure(provider,'UNSUPPORTED')
  if intention~mode == 'NOTIFY' then do
    sent = connector~notify(intention~operation,payload)
    if sent then return .ConnectResult~success(provider,.nil,.true,.false,.false)
    return .ConnectResult~failure(provider,'SEND_FAILED','Notification was not accepted')
  end
  reply = connector~request(intention~operation,payload)
  if \reply~ok then return .ConnectResult~failure(provider,'CALL_FAILED','Provider returned a call error',reply~fault)
  return .ConnectResult~success(provider,reply~result,.true,.true,.false)

/* Exact ObjectQueueManager 0.9 API: put(queueName,payload,options,principal).
 * A temporary queue or an in-memory manager cannot satisfy a durable intention.
 */
::class ConnectQueueAdapter public
::attribute manager get
::attribute queueName get
::attribute principal get
::method init
  expose manager queueName principal
  use strict arg manager, queueName, principal
  if \manager~hasMethod('put') | \manager~hasMethod('queue') | \manager~hasMethod('durableStore') then raise syntax 93.900 additional('requires ObjectQueueManager-compatible API')
::method supports
  expose manager queueName principal
  use strict arg intention
  if intention~mode \== 'ENQUEUE' then return .false
  if intention~destination \== '' then do
    if intention~destination~translate \== queueName~string~translate then return .false
  end
  q = manager~queue(queueName)
  if q == .nil then return .false
  if manager~hasMethod('accessAllowed') then do
    if \manager~accessAllowed(queueName,principal,'PUT') then return .false
  end
  if intention~requirement == 'DURABLE' then do
    if q~lifecycle \== 'PERMANENT' then return .false
    if manager~durableStore == .nil then return .false
  end
  return .true
::method execute
  expose manager queueName principal
  use strict arg intention, payload = .nil
  if \self~supports(intention) then return .ConnectResult~failure('QUEUE','UNSUPPORTED','Queue cannot meet guarantee')
  options = .Table~new
  if intention~requirement == 'DURABLE' then options['persistent'] = .true
  else options['persistent'] = .false
  if intention~options~hasIndex('headers') then options['headers'] = intention~options['headers']
  if intention~options~hasIndex('correlationId') then options['correlationId'] = intention~options['correlationId']
  if intention~options~hasIndex('routingKey') then options['routingKey'] = intention~options['routingKey']
  if intention~options~hasIndex('replyTo') then options['replyTo'] = intention~options['replyTo']
  if intention~options~hasIndex('securityDomain') then options['securityDomain'] = intention~options['securityDomain']
  if intention~options~hasIndex('expirySeconds') then options['expirySeconds'] = intention~options['expirySeconds']
  reply = manager~put(queueName,payload,options,principal)
  if \reply~ok then return .ConnectResult~failure('QUEUE',reply~code,reply~detail)
  return .ConnectResult~success('QUEUE',reply~value,.true,.false,intention~requirement == 'DURABLE')
