/* ExternalCall.cls
   Unified external execution model.
   The calling code is identical regardless of WHERE the code runs.

   No transport  → runs inline via ADDRESS SYSTEM (same process)
   LocalTransport     → ADDRESS SYSTEM with captured output
   IsolatedTransport  → subprocess fork, main process protected from crashes
   TCPTransport       → remote executor over TCP socket
   QueueTransport     → RXQUEUE submit/reply (async or sync)
   SSHTransport       → remote machine via SSH
   BsfTransport       → BSF4OORexx Java context

   Every transport returns the same ExternalResult shape:
     exitCode, stdout, stderr, elapsed, timedOut

   Example — inline:
     call = .ExternalCall~new(container)
     call~command = 'python3'
     call~args    = .Array~of('analyse.py', '--input', fileName)
     rc = call~run
     say call~result~stdout

   Example — isolated (Oracle crashes handled without killing main process):
     call = .ExternalCall~new(container)
     call~command   = 'rexx'
     call~args      = .Array~of('oracle_query.rex', queryParam)
     call~transport = container~get('transport.isolated')
     call~timeout   = 30
     rc = call~run
     if call~result~exitCode \= 0 then say 'Oracle failed:' call~result~stderr

   Example — remote:
     call~transport = container~get('transport.remote')
     rc = call~run   /* identical call */
*/
::class ExternalCall public

::attribute command      /* string: executable name */
::attribute args         /* .Array of string arguments */
::attribute transport    /* ExternalTransport instance or .nil = inline */
::attribute timeout      /* seconds, default 60 */
::attribute env          /* .Directory of env vars to set */
::attribute stdin        /* string to feed as stdin, or '' */

::method init
  expose _container _result
  use arg container
  _container = container
  self~command   = ''
  self~args      = .Array~new
  self~transport = .nil
  self~timeout   = 60
  self~env       = .Directory~new
  self~stdin     = ''
  _result        = .nil

::method run
  expose _container _result
  /* Business rules gate before execution                             */
  monitor = _container~get('businessRules')
  if monitor \= .nil then do
    evt = .Directory~new
    evt~put('EXTERNAL_CALL',      'event')
    evt~put(self~command,         'command')
    evt~put(self~transport~class~id, 'transport')
    if \monitor~check(evt) then do
      _result = .ExternalResult~newDenied('blocked by business rules')
      return 1
    end
  end
  /* Dispatch to transport                                            */
  if self~transport = .nil then
    _result = .LocalTransport~new(_container)~execute(self)
  else
    _result = self~transport~execute(self)
  return _result~exitCode

::method result
  expose _result
  return _result


/* ================================================================== */
/* ExternalResult — uniform result shape for all transports           */
/* ================================================================== */
::class ExternalResult public

::attribute exitCode
::attribute stdout
::attribute stderr
::attribute elapsed
::attribute timedOut

::method init
  self~exitCode = 0
  self~stdout   = ''
  self~stderr   = ''
  self~elapsed  = 0
  self~timedOut = .false

::method ok
  return self~exitCode = 0

::method newDenied class
  use arg reason
  r = .ExternalResult~new
  r~exitCode = 126   /* permission denied — POSIX convention */
  r~stderr   = reason
  return r


/* ================================================================== */
/* ExternalTransport — abstract base for all transports               */
/* ================================================================== */
::class ExternalTransport public

::method init
  expose _container
  use arg container
  _container = container

::method execute
  /* Subclasses override. Receives ExternalCall, returns ExternalResult */
  use arg externalCall
  r = .ExternalResult~new
  r~exitCode = 127   /* not implemented */
  r~stderr   = 'transport not implemented: '||self~class~id
  return r

::method buildCommand private
  /* Build the full command string from an ExternalCall               */
  use arg call
  cmd = call~command
  do i = 1 to call~args~items
    a = call~args~at(i)
    /* Quote args containing spaces                                   */
    if pos(' ', a) > 0 then a = '"'||a||'"'
    cmd = cmd ' ' a
  end
  return strip(cmd)


/* ================================================================== */
/* LocalTransport — ADDRESS SYSTEM with captured output via temp files*/
/* No isolation — shares the process.  Fastest.                       */
/* ================================================================== */
::class LocalTransport subclass ExternalTransport public

::method execute
  expose _container
  use arg call
  tm    = _container~get('tempManager')
  fOut  = tm~acquire('ext_out')
  fErr  = tm~acquire('ext_err')
  r     = .ExternalResult~new
  cmd   = self~buildCommand(call)
  tStart = time('S')
  /* bash handles redirection — ADDRESS SYSTEM does not support >     */
  wrapper = 'bash -c "'||self~escape(cmd)||' >"'||fOut||'" 2>"'||fErr||'"'
  if call~timeout > 0 then
    wrapper = 'timeout '||call~timeout||' '||wrapper
  wrapper = wrapper||'"'
  ADDRESS SYSTEM wrapper
  r~exitCode = RC
  r~elapsed  = time('S') - tStart
  r~timedOut = (r~exitCode = 124)   /* timeout exits 124 */
  r~stdout   = self~readFile(fOut)
  r~stderr   = self~readFile(fErr)
  tm~release(fOut); tm~release(fErr)
  return r

::method readFile private
  use arg path
  if stream(path,'c','query exists') = '' then return ''
  f = .Stream~new(path); f~open('read')
  content = f~charin(1, f~chars)
  f~close
  return content

::method escape private
  use arg s
  return changestr('"', s, '\"')


/* ================================================================== */
/* IsolatedTransport — subprocess fork for crash-prone code           */
/* Main process is protected: Oracle core dumps, BSF crashes,         */
/* segfaulting native libs — none of them kill the parent.            */
/* Exit code is still captured even when child crashes.               */
/* ================================================================== */
::class IsolatedTransport subclass ExternalTransport public

::method execute
  expose _container
  use arg call
  tm    = _container~get('tempManager')
  fOut  = tm~acquire('iso_out')
  fErr  = tm~acquire('iso_err')
  fRc   = tm~acquire('iso_rc')
  r     = .ExternalResult~new
  cmd   = self~buildCommand(call)
  tStart = time('S')
  /* Run in a fully isolated subprocess.                              */
  /* The shell writes RC explicitly so we get it even on SIGABRT.     */
  wrapper = 'bash -c "'||self~escape(cmd)||' >"'||fOut||'" 2>"'||fErr||'"; echo $? >"'||fRc||'"'
  if call~timeout > 0 then
    wrapper = 'timeout '||call~timeout||' '||wrapper
  ADDRESS SYSTEM 'bash -c "'||self~escape(wrapper)||'"'
  r~elapsed  = time('S') - tStart
  /* Read RC from file — more reliable than ADDRESS SYSTEM RC         */
  if stream(fRc,'c','query exists') \= '' then do
    f = .Stream~new(fRc); rcStr = strip(f~charin(1,10)); f~close
    if datatype(rcStr,'W') then r~exitCode = rcStr+0
    else                        r~exitCode = RC
  end
  else r~exitCode = RC
  r~timedOut = (r~exitCode = 124)
  r~stdout   = self~readFile(fOut)
  r~stderr   = self~readFile(fErr)
  tm~release(fOut); tm~release(fErr); tm~release(fRc)
  return r

::method readFile private
  use arg path
  if stream(path,'c','query exists') = '' then return ''
  f = .Stream~new(path); f~open('read')
  content = f~charin(1, f~chars)
  f~close
  return content

::method escape private
  use arg s
  return changestr('"', s, '\"')


/* ================================================================== */
/* TCPTransport — remote execution over TCP socket                    */
/* Sends the ExternalCall as JSON, receives ExternalResult as JSON.   */
/* The remote end runs the same model — same class, same runner.      */
/* ================================================================== */
::class TCPTransport subclass ExternalTransport public

::method init
  expose _container _host _port
  use arg container, host, port
  _container = container
  _host      = host
  _port      = port

::method execute
  expose _container _host _port
  use arg call
  r = .ExternalResult~new
  /* Serialise call as JSON                                           */
  payload = .Directory~new
  payload~put(call~command,   'command')
  payload~put(call~args,      'args')
  payload~put(call~timeout,   'timeout')
  payload~put(call~stdin,     'stdin')
  json = .json~new~toJson(payload)||'0a'x
  /* Send and receive via native rxsock                              */
  call rxfuncadd 'SockLoadFuncs', 'rxsock', 'SockLoadFuncs'
  call SockLoadFuncs
  sock = SockSocket('AF_INET', 'SOCK_STREAM', 0)
  addr.family = 'AF_INET'; addr.port = _port; addr.addr = _host
  if SockConnect(sock, 'addr.') \= 0 then do
    r~exitCode = 128; r~stderr = 'transport connect failed: '||_host||':'||_port
    call SockClose sock; return r
  end
  call SockSend sock, json, length(json), ''
  raw = ''; tBuf = ''
  do while SockRecv(sock, 'tBuf', 65536, '') > 0
    raw = raw||tBuf
  end
  call SockClose sock
  signal on syntax name ParseFail
  parsed = .json~new~fromJson(raw)
  r~exitCode = parsed~at('exitCode')+0
  r~stdout   = parsed~at('stdout')
  r~stderr   = parsed~at('stderr')
  r~elapsed  = parsed~at('elapsed')+0
  r~timedOut = (parsed~at('timedOut') = 'true')
  return r
ParseFail:
  signal off syntax
  r~exitCode = 128; r~stderr = 'transport response parse failed'
  return r


/* ================================================================== */
/* QueueTransport — RXQUEUE submit/reply                              */
/* ================================================================== */
::class QueueTransport subclass ExternalTransport public

::method init
  expose _container _workQueue _replyQueue
  use arg container, workQueue, replyQueue
  _container  = container
  _workQueue  = workQueue
  _replyQueue = replyQueue

::method execute
  expose _container _workQueue _replyQueue
  use arg call
  r = .ExternalResult~new
  payload = .Directory~new
  payload~put(call~command,  'command')
  payload~put(call~args,     'args')
  payload~put(call~timeout,  'timeout')
  payload~put(_replyQueue,   'replyQueue')
  json = .json~new~toJson(payload)
  /* Push to work queue                                               */
  old = rxqueue('Set', _workQueue)
  push json
  call rxqueue 'Set', old
  /* Wait for reply                                                   */
  deadline = time('S') + call~timeout
  do while time('S') < deadline
    old = rxqueue('Set', _replyQueue)
    cnt = queued()
    if cnt > 0 then do
      pull raw
      call rxqueue 'Set', old
      /* Label forbidden inside DO — parse in private method          */
      return self~_parseQueueReply(raw, r)
    end
    call rxqueue 'Set', old
    call SysSleep 0.1
  end
  r~exitCode = 124; r~timedOut = .true
  r~stderr = 'queue transport timeout after' call~timeout 'seconds'
  return r

::method _parseQueueReply private
  use arg raw, r
  signal on syntax name QParseErr
  parsed = .json~new~fromJson(raw)
  r~exitCode = parsed~at('exitCode')+0
  r~stdout   = parsed~at('stdout')
  r~stderr   = parsed~at('stderr')
  signal off syntax
  return r
QParseErr:
  signal off syntax
  r~exitCode = 128; r~stderr = 'queue reply parse failed'
  return r


/* ================================================================== */
/* SSHTransport — remote execution via SSH                            */
/* ================================================================== */
::class SSHTransport subclass ExternalTransport public

::method init
  expose _container _user _host _keyFile
  use arg container, user, host, keyFile
  _container = container
  _user      = user
  _host      = host
  _keyFile   = keyFile

::method execute
  expose _container _user _host _keyFile
  use arg call
  /* Delegate to IsolatedTransport with SSH as the outer command      */
  remoteCmd = self~buildCommand(call)
  sshCall   = .ExternalCall~new(_container)
  sshCall~command = 'ssh'
  args = .Array~of('-i', _keyFile, '-o', 'BatchMode=yes', _user||'@'||_host, remoteCmd)
  sshCall~args      = args
  sshCall~timeout   = call~timeout
  sshCall~transport = .IsolatedTransport~new(_container)
  rc = sshCall~run
  return sshCall~result

::requires 'json.cls'
::requires 'monitors/BusinessRulesMonitor.cls'
