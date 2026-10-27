/* runner.rex
   Composition root.  No logic lives here.
   Wires shared objects into the container,
   registers event triggers, starts the lifecycle.

   Every application in the ecosystem has a runner that looks like this.
   The runner is the only place that knows about the full dependency graph.
*/
numeric digits 18

/* ── 1. Bootstrap the container ─────────────────────────────────── */
container = .Container~new

/* ── 2. Infrastructure ───────────────────────────────────────────── */
container~register('fileLoader',   .FileLoader~new)
container~register('logger',       .Logger~new('alchemy.log', 'INFO'))
container~register('tempManager',  .TempFileManager~new('/tmp/alchemy'))
container~register('bufWriter',    .BufferedWriter~new(container))
container~register('httpClient',   .HttpClient~new(container))
container~register('jsonCodec',    .JsonCodec~new(container))

/* ── 3. Configuration ────────────────────────────────────────────── */
container~register('config', .ConfigProvider~new(container, 'alchemy.config'))
container~get('config')~load

/* ── 4. Domain objects — declared in dependency order ───────────── */
container~register('cryptoCtx',    .CryptoContext~new(container))
container~register('agentBridge',  .AgentBridge~new(container))
container~register('indexBuilder', .IndexBuilder~new(container))
container~register('langPack',     .LanguagePackManager~new(container))
container~register('corrStore',    .CorrectionStoreManager~new(container))
container~register('wordIndex',    .WordIndexProvider~new(container))
container~register('scheduler',    .TimerScheduler~new(container))
container~register('preferred',     .PreferredModule~new(container))
container~register('docAgent',      .DocumentationAgent~new(container))
container~register('rulesVerifier', .BusinessRulesVerifier~new(container))
container~register('specGenerator', .GeneratorFactory~new)
/* Plan42 is a discoverable service, not a compulsory transport or runner. */
container~register('plan42', .AlchemyPlan42Service~new(container))

/* ── 4b. External call transports ───────────────────────────────── */
container~register('transport.local',    .LocalTransport~new(container))
container~register('transport.isolated', .IsolatedTransport~new(container))
container~register('transport.queue',    .QueueTransport~new(container, 'ext.work', 'ext.reply'))
/* Remote transport endpoint from config */
cfg = container~get('config')
container~register('transport.remote',  -
  .TCPTransport~new(container, cfg~get('remote.host','localhost'), cfg~get('remote.port',9100)))
/* All share the same load/evaluate/reload machinery.                 */
/* All hot-reload independently via their own sentinel file.          */
container~register('inspectorRules', .InspectorRuleEngine~new(container, 'rules/inspector.rules.json'))
container~register('policyRules',    .RTOPolicyEngine~new(container,     'rules/rto.policy.json'))
container~register('agentRules',     .AgentRoutingEngine~new(container,  'rules/agent.routing.json'))
container~register('authRules',      .AuthRuleEngine~new(container,      'rules/auth.rules.json'))
container~register('scopeRules',     .RuleEngine~new(container,          'rules/scope.rules.json'))

/* ── 5. Application objects ──────────────────────────────────────── */
container~register('librarian',    .LibrarianAgent~new(container))
container~register('linguist',     .LinguistAgent~new(container))
container~register('application',  .AlchemyApplication~new(container))

/* ── 5d. Contract registry — verified on every hot-load ─────────── */
container~contract('config',         .ConfigContract~new)
container~contract('inspectorRules', .RuleEngineContract~new)
container~contract('policyRules',    .RuleEngineContract~new)
container~contract('agentRules',     .RuleEngineContract~new)
container~contract('authRules',      .RuleEngineContract~new)
container~contract('langPack',       .LanguagePackContract~new)
container~contract('corrStore',      .CorrectionStoreContract~new)
container~contract('linguist',       .AgentContract~new)
container~contract('librarian',      .AgentContract~new)
container~register('httpServer',   .HttpServer~new(container))

/* ── 5b. UI interfaces — mounted against the HTTP server ─────────── */
httpServer = container~get('httpServer')
httpServer~mount('/health',    .HealthEndpoint~new(container))
httpServer~mount('/status',    .StatusDashboard~new(container))
httpServer~mount('/api/v1',    .RestApiInterface~new(container))
httpServer~mount('/webhook',   .WebhookReceiver~new(container))
httpServer~mount('/trainer',   .TrainerInterface~new(container))
httpServer~mount('/librarian', .LibrarianInterface~new(container))

/* ── 5c. Native UI interfaces (non-HTTP) ─────────────────────────── */
container~register('swingUI',   .AlchemySwingUI~new(container))
container~register('consoleUI', .ConsoleInterface~new(container))

/* ── 6. External event triggers ─────────────────────────────────── */
trigger = .EventTrigger~new(container)
trigger~onFileTouch('/tmp/alchemy.reload.config',       'config',         'reload')
trigger~onFileTouch('/tmp/alchemy.reload.langpack',      'langPack',       'reload')
trigger~onFileTouch('/tmp/alchemy.reload.corrstore',     'corrStore',      'reload')
trigger~onFileTouch('/tmp/alchemy.reload.inspector',     'inspectorRules', 'reload')
trigger~onFileTouch('/tmp/alchemy.reload.policy',        'policyRules',    'reload')
trigger~onFileTouch('/tmp/alchemy.reload.agentrules',    'agentRules',     'reload')
trigger~onFileTouch('/tmp/alchemy.reload.auth',          'authRules',      'reload')
trigger~onSignal('HUP',                                  'config',         'reload')
container~register('trigger', trigger)

/* ── 7. Lifecycle ────────────────────────────────────────────────── */
lifecycle = .LifecycleManager~new(container)
lifecycle~onStartup('logger',      'open')
lifecycle~onStartup('tempManager', 'init')
lifecycle~onStartup('config',      'validate')
lifecycle~onStartup('langPack',    'loadAll')
lifecycle~onStartup('corrStore',   'loadAll')
lifecycle~onStartup('scheduler',   'start')
lifecycle~onStartup('workQueue',   'start')
lifecycle~onStartup('trigger',     'start')
lifecycle~onStartup('application', 'run')
lifecycle~onStartup('httpServer',  'listen')
lifecycle~onStartup('swingUI',     'show')

lifecycle~onShutdown('application', 'stop')
lifecycle~onShutdown('swingUI',     'hide')
lifecycle~onShutdown('httpServer',  'stop')
lifecycle~onShutdown('workQueue',   'drain')
lifecycle~onShutdown('scheduler',   'stop')
lifecycle~onShutdown('trigger',     'stop')
lifecycle~onShutdown('tempManager', 'cleanup')
lifecycle~onShutdown('bufWriter',   'flush')
lifecycle~onShutdown('logger',      'close')

/* ── 8. Go ───────────────────────────────────────────────────────── */
lifecycle~start
exit lifecycle~exitCode


/* ================================================================== */
/* Container                                                          */
/* ================================================================== */
::class Container public

::method init
  expose _registry _contracts _log
  _registry  = .Directory~new
  _contracts = .Directory~new
  _log       = .nil

::method register
  expose _registry
  use arg name, obj
  _registry~put(obj, name)

::method contract
  /* Register a contract that a named object must satisfy.            */
  /* Verified on reload before the swap is accepted.                  */
  expose _contracts
  use arg name, contractObj
  _contracts~put(contractObj, name)

::method get
  expose _registry
  use arg name
  obj = _registry~at(name)
  if obj = .nil then do
    say '[CONTAINER] WARNING: unknown dependency:' name
    return .nil
  end
  return obj

::method reload
  /* Ask the named object to reload itself.                           */
  /* If a contract is registered: verify BEFORE swapping in.         */
  /* On contract failure: keep old instance, log the violations.      */
  expose _registry _contracts
  use arg name
  old = _registry~at(name)
  if old = .nil then return .false
  if \old~hasMethod('reload') then return .false
  /* Create a fresh instance via the same class, pass container       */
  signal on syntax name ReloadError
  fresh = old~class~new(self)
  if fresh~hasMethod('load') then fresh~load
  signal off syntax
  /* Contract check before swap                                        */
  contract = _contracts~at(name)
  if contract \= .nil then do
    if \contract~verify(fresh) then do
      say '[CONTAINER] HOT-LOAD REJECTED:' name
      say contract~report
      return .false   /* old instance stays live */
    end
  end
  _registry~put(fresh, name)
  say '[CONTAINER] reloaded:' name
  return .true
ReloadError:
  signal off syntax
  say '[CONTAINER] reload error:' name rc
  return .false

::method swap
  /* Direct swap — used when caller has already verified externally.  */
  expose _registry
  use arg name, obj
  _registry~put(obj, name)


/* ================================================================== */
/* LifecycleManager                                                   */
/* ================================================================== */
::class LifecycleManager public

::method init
  expose _container _startupSteps _shutdownSteps _exitCode
  use arg container
  _container     = container
  _startupSteps  = .Array~new
  _shutdownSteps = .Array~new
  _exitCode      = 0

::method onStartup
  expose _startupSteps
  use arg name, method
  _startupSteps~append(.Array~of(name, method))

::method onShutdown
  expose _shutdownSteps
  use arg name, method
  _shutdownSteps~append(.Array~of(name, method))

::method start
  expose _container _startupSteps _shutdownSteps _exitCode
  /* Run startup sequence                                             */
  /* Labels forbidden inside DO/LOOP — signal handling in _runStep   */
  do step over _startupSteps
    name   = step~at(1)
    method = step~at(2)
    obj    = _container~get(name)
    if obj = .nil then iterate
    say '[LIFECYCLE] startup:' name '~'||method
    ok = self~_runStep(obj, method)
    if \ok then do
      say '[LIFECYCLE] STARTUP FAILED:' name '~'||method
      _exitCode = 1
      self~_runShutdown
      return
    end
  end
  /* Startup complete — application~run is blocking                  */
  /* Shutdown sequence runs after application~run returns            */
  self~_runShutdown

::method _runStep private
  /* Signal handler must be outside any DO/LOOP block — own method.  */
  use arg obj, method
  signal on syntax name StepErr
  obj~send(method)
  signal off syntax
  return .true
StepErr:
  signal off syntax
  return .false

::method _runShutdown private
  expose _container _shutdownSteps
  /* Labels forbidden inside DO/LOOP — signal handling in _runShutStep */
  do step over _shutdownSteps
    name   = step~at(1)
    method = step~at(2)
    obj    = _container~get(name)
    if obj = .nil then iterate
    say '[LIFECYCLE] shutdown:' name '~'||method
    ok = self~_runShutStep(obj, method)
    if \ok then
      say '[LIFECYCLE] shutdown error (continuing):' name
  end

::method _runShutStep private
  use arg obj, method
  signal on syntax name ShutStepErr
  obj~send(method)
  signal off syntax
  return .true
ShutStepErr:
  signal off syntax
  return .false

::method exitCode
  expose _exitCode
  return _exitCode


/* ================================================================== */
/* EventTrigger                                                       */
/* ================================================================== */
::class EventTrigger public

::method init
  expose _container _watches _running
  use arg container
  _container = container
  _watches   = .Array~new
  _running   = 0

::method onFileTouch
  /* Watch for a sentinel file being created/touched.                */
  /* When detected: delete it, call container~reload(name).          */
  expose _watches
  use arg filePath, targetName, targetMethod
  _watches~append(.Directory~new~~put(filePath,'file')~~put(targetName,'target')~~put(targetMethod,'method'))

::method onSignal
  /* UNIX signal → reload.  Implemented as a named queue listener.   */
  use arg sigName, targetName, targetMethod
  /* Wire via RXQUEUE signal bridge — implementation platform-specific */

::method start unguarded
  expose _container _watches _running
  _running = 1
  do while _running = 1
    do watch over _watches
      fp = watch~at('file')
      if stream(fp,'c','query exists') \= '' then do
        say '[TRIGGER] event:' fp '->' watch~at('target')
        ADDRESS SYSTEM 'rm -f "'||fp||'"'
        _container~reload(watch~at('target'))
      end
    end
    call SysSleep 2
  end

::method stop
  expose _running
  _running = 0


/* ================================================================== */
/* HttpServer                                                         */
/* Single shared HTTP server — all UI interfaces mount against it.    */
/* Uses BSF4OORexx Java ServerSocket; one thread per connection.      */
/* ================================================================== */
::class HttpServer public

::method init
  expose _container _mounts _port _running _serverSocket
  use arg container
  _container    = container
  _mounts       = .Array~new   /* Array of [prefix, handler] pairs   */
  _running      = 0
  _serverSocket = .nil
  cfg   = container~get('config')
  _port = cfg~get('http.port', 8080)

::method mount
  /* Register a UI interface against a URL prefix.                    */
  /* Longer prefixes win — sorted at dispatch time.                   */
  expose _mounts
  use arg prefix, handler
  _mounts~append(.Array~of(prefix, handler))
  say '[HTTP] mounted:' prefix '->' handler~class~id

::method listen unguarded
  expose _container _mounts _port _running _serverSock
  log = _container~get('logger')
  /* Native OORexx socket — no BSF4OORexx required                    */
  call rxfuncadd 'SockLoadFuncs', 'rxsock', 'SockLoadFuncs'
  call SockLoadFuncs
  _serverSock = SockSocket('AF_INET', 'SOCK_STREAM', 0)
  call SockSetSockOpt _serverSock, 'SOL_SOCKET', 'SO_REUSEADDR', 1
  addr.family = 'AF_INET'
  addr.port   = _port
  addr.addr   = '0.0.0.0'
  call SockBind   _serverSock, 'addr.'
  call SockListen _serverSock, 10
  _running = 1
  log~info('[HTTP] listening on port' _port)
  do while _running = 1
    clientSock = SockAccept(_serverSock)
    if clientSock < 0 then iterate
    .Message~new(self, 'dispatch', 'a', clientSock)~start
  end
  call SockClose _serverSock

::method dispatch unguarded
  /* Called in a background activity per connection.                  */
  expose _mounts
  use arg clientSock
  signal on syntax name DispatchError
  raw = ''
  call SockRecv clientSock, 'raw', 65536, ''
  request  = .HttpRequest~new(raw)
  request~parse
  handler  = self~route(request~path)
  response = .HttpResponse~new
  if handler = .nil then do
    response~status = 404
    response~json(.Directory~new~~put('not found','error')~~put(request~path,'path'))
  end
  else do
    handler~handle(request, response)
  end
  out = response~serialise
  call SockSend clientSock, out, length(out), ''
  call SockClose clientSock
  return
DispatchError:
  signal off syntax
  call SockClose clientSock

::method route private
  expose _mounts
  use arg path
  bestLen     = -1
  bestHandler = .nil
  do mount over _mounts
    prefix = mount~at(1)
    if left(path, length(prefix)) = prefix then do
      if length(prefix) > bestLen then do
        bestLen     = length(prefix)
        bestHandler = mount~at(2)
      end
    end
  end
  return bestHandler

::method writeNotFound private
  use arg outStream, path
  body = '{"error":"not found","path":"'||path||'"}'
  self~writeRaw(outStream, 404, 'Not Found', body)

::method writeRaw private
  use arg outStream, code, status, body
  lf   = '0d0a'x
  resp = 'HTTP/1.1 '||code||' '||status||lf -
       ||'Content-Type: application/json'||lf -
       ||'Content-Length: '||length(body)||lf -
       ||'Connection: close'||lf||lf -
       ||body
  outStream~write(resp~makeArray('')[1])  /* BSF byte write */

::method stop
  expose _running _serverSock
  _running = 0
  if _serverSock \= .nil then call SockClose _serverSock


/* ================================================================== */
/* UIInterface — base contract all HTTP UI interfaces implement        */
/* ================================================================== */
::class UIInterface public

::method init
  expose _container
  use arg container
  _container = container

::method handle
  /* Subclasses override this.                                        */
  /* request  : .HttpRequest                                          */
  /* response : .HttpResponse                                         */
  use arg request, response
  response~json(.Directory~new~~put('ok','status'))


/* ================================================================== */
/* HttpRequest / HttpResponse — thin wrappers                         */
/* ================================================================== */
::class HttpRequest public

::method init
  expose _method _path _headers _body
  use arg raw
  _method  = ''
  _path    = ''
  _headers = .Directory~new
  _body    = ''
  self~parse(raw)

::method parse
  expose _method _path _headers _body
  /* Parse raw HTTP request string — native OORexx string operations   */
  use arg raw
  crlf = '0d0a'x
  parse var raw requestLine (crlf) rest
  parse var requestLine _method _path .
  do while rest \= '' & left(rest, 2) \= crlf
    parse var rest hLine (crlf) rest
    parse var hLine hName ': ' hVal
    _headers~put(strip(hVal), translate(strip(hName)))
  end
  _body = substr(rest, 3)   /* skip the blank line CRLF */

::method method;  expose _method;  return _method
::method path;    expose _path;    return _path
::method header;  expose _headers; use arg n; return _headers~at(translate(n))
::method body;    expose _body;    return _body


::class HttpResponse public

::method init
  expose _stream _status _headers _body
  use arg stream
  _stream  = stream
  _status  = 200
  _headers = .Directory~new
  _body    = ''

::method "status=";  expose _status;  use arg s;    _status = s
::method "body=";    expose _body;    use arg b;    _body   = b

::method json
  expose _body _headers
  use arg obj
  _headers~put('application/json', 'CONTENT-TYPE')
  _body = .json~new~toJson(obj)

::method serialise
  expose _status _body _headers
  statusText = 'OK'
  if _status = 404 then statusText = 'Not Found'
  if _status = 500 then statusText = 'Internal Server Error'
  crlf = '0d0a'x
  out  = 'HTTP/1.1 '||_status||' '||statusText||crlf
  sup  = _headers~supplier
  do while sup~available
    out = out||sup~index||': '||sup~item||crlf
    sup~next
  end
  out = out||'Content-Type: application/json'||crlf
  out = out||'Content-Length: '||length(_body)||crlf
  out = out||'Connection: close'||crlf||crlf
  out = out||_body
  return out

::requires 'plan42/AlchemyPlan42Service.cls'
::requires 'json.cls'
