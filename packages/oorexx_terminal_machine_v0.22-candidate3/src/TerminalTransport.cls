/* Generic transport boundary: plain TCP plus an optional verified Unix TLS adapter. */

::class TerminalTransportState public
::constant CLOSED "CLOSED"
::constant OPEN "OPEN"
::constant ERROR "ERROR"

::class TcpTerminalTransport public
::attribute host get
::attribute port get
::attribute state get
::attribute lastError get

::method init
  expose host port state lastError socket
  use arg hostArg, portArg
  host = hostArg~string
  port = portArg
  state = .TerminalTransportState~CLOSED
  lastError = ""
  socket = .nil

::method open
  expose host port state lastError socket
  if state == .TerminalTransportState~OPEN then return .TerminalResult~success
  socket = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if socket~errno <> 0 then do
    state = .TerminalTransportState~ERROR
    lastError = socket~errno~string
    return .TerminalResult~failure("SOCKET_CREATE", lastError)
  end
  address = .InetAddress~new(host, port)
  rc = socket~connect(address)
  if rc < 0 then do
    state = .TerminalTransportState~ERROR
    lastError = socket~errno~string
    return .TerminalResult~failure("SOCKET_CONNECT", lastError)
  end
  state = .TerminalTransportState~OPEN
  lastError = ""
  return .TerminalResult~success

::method sendBytes
  expose state socket lastError
  use arg bytes
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  sent = socket~send(bytes)
  if sent < 0 then do
    lastError = socket~errno~string
    return .TerminalResult~failure("SOCKET_SEND", lastError)
  end
  if sent \== bytes~length then return .TerminalResult~failure("SOCKET_SHORT_SEND", sent || "/" || bytes~length)
  return .TerminalResult~success(sent)

::method receiveBytes
  expose state socket lastError
  use arg maximum = 8192
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  bytes = socket~recv(maximum)
  if bytes == .nil then do
    lastError = socket~errno~string
    return .TerminalResult~failure("SOCKET_RECV", lastError)
  end
  return .TerminalResult~success(bytes)

/* Wait without turning a lack of network activity into a blocking terminal
 * process.  A timeout is an ordinary false readiness result, not an error. */
::method waitReadable
  expose state socket lastError
  use arg timeoutSeconds = 1
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  reads = .array~new; reads~append(socket)
  writes = .array~new
  excepts = .array~new
  ready = socket~select(reads, writes, excepts, timeoutSeconds)
  if ready == .nil then do
    lastError = socket~errno~string
    return .TerminalResult~failure("SOCKET_SELECT", lastError)
  end
  return .TerminalResult~success(ready > 0)

::method receiveBytesWait
  use arg maximum = 8192, timeoutSeconds = 1
  ready = self~waitReadable(timeoutSeconds)
  if \ready~ok then return ready
  if \ready~value then return .TerminalResult~failure("TRANSPORT_TIMEOUT", timeoutSeconds)
  return self~receiveBytes(maximum)

::method close
  expose state socket lastError
  if socket \== .nil then do
    rc = socket~close
    if rc < 0 then lastError = socket~errno~string
  end
  socket = .nil
  state = .TerminalTransportState~CLOSED
  return .TerminalResult~success

::requires "TerminalCore.cls"
::requires "socket.cls"

/* Optional Unix TLS adapter v0.3.1.
 *
 * ooRexx 5.3's shipped socket.cls is a byte-stream socket interface, not a TLS
 * implementation.  On Unix we preserve that clean transport boundary by
 * asking socat/OpenSSL to provide a verified TLS tunnel on loopback and then
 * using the ordinary TcpTerminalTransport against that loopback endpoint.
 *
 * Trust-store selection is deliberately portable and fail-closed.  An
 * explicitly supplied CA file/path wins, followed by application/standard SSL
 * environment overrides, then common Unix distribution locations.  No
 * plaintext fallback and no implicit verify=0 path exists for verified mode.
 */

::class TerminalTlsTrustSelection public
::attribute mode get
::attribute path get
::attribute source get

::method init
  expose mode path source
  use arg modeArg, pathArg, sourceArg
  mode = modeArg~string~upper
  path = pathArg~string
  source = sourceArg~string

::class TerminalTlsTrustStore public

::method fileExists class private
  use arg pathArg
  path = pathArg~string~strip
  if path == "" then return .false
  return stream(path, "c", "query exists") \= ""

::method directoryExists class private
  use arg pathArg
  path = pathArg~string~strip
  if path == "" then return .false
  hits. = 0
  call SysFileTree path, "hits.", "DO"
  return hits.0 > 0

::method firstDirectoryFromList class private
  use arg listArg, sourceArg
  rest = listArg~string
  do while rest \= ""
    parse var rest item ":" rest
    item = item~strip
    if item == "" then iterate
    if self~directoryExists(item) then return .TerminalResult~success(.TerminalTlsTrustSelection~new("DIR", item, sourceArg))
  end
  return .TerminalResult~failure("TLS_CA_DIR_NOT_FOUND", sourceArg || "=" || listArg)

::method resolve class
  use arg explicitFileArg = "", explicitPathArg = ""
  explicitFile = explicitFileArg~string~strip
  explicitPath = explicitPathArg~string~strip

  if explicitFile \= "" & explicitPath \= "" then return .TerminalResult~failure("TLS_CA_CONFLICT", "both CA file and CA path supplied")
  if explicitFile \= "" then do
    if \self~fileExists(explicitFile) then return .TerminalResult~failure("TLS_CA_NOT_FOUND", "CA file not found: " || explicitFile)
    return .TerminalResult~success(.TerminalTlsTrustSelection~new("FILE", explicitFile, "EXPLICIT_FILE"))
  end
  if explicitPath \= "" then do
    if \self~directoryExists(explicitPath) then return .TerminalResult~failure("TLS_CA_PATH_NOT_FOUND", "CA path not found: " || explicitPath)
    return .TerminalResult~success(.TerminalTlsTrustSelection~new("DIR", explicitPath, "EXPLICIT_PATH"))
  end

  /* Application-specific overrides are checked before the generic OpenSSL
   * environment names so a caller can select trust for this terminal without
   * changing unrelated TLS consumers in the process environment. */
  envFile = value("OOREXX_TERMINAL_CA_FILE",, "ENVIRONMENT")~strip
  if envFile \= "" then do
    if self~fileExists(envFile) then return .TerminalResult~success(.TerminalTlsTrustSelection~new("FILE", envFile, "ENV:OOREXX_TERMINAL_CA_FILE"))
    return .TerminalResult~failure("TLS_CA_NOT_FOUND", "OOREXX_TERMINAL_CA_FILE not found: " || envFile)
  end
  envPath = value("OOREXX_TERMINAL_CA_PATH",, "ENVIRONMENT")~strip
  if envPath \= "" then do
    selected = self~firstDirectoryFromList(envPath, "ENV:OOREXX_TERMINAL_CA_PATH")
    if selected~ok then return selected
    return .TerminalResult~failure("TLS_CA_PATH_NOT_FOUND", "OOREXX_TERMINAL_CA_PATH not found: " || envPath)
  end

  envFile = value("SSL_CERT_FILE",, "ENVIRONMENT")~strip
  if envFile \= "" & self~fileExists(envFile) then return .TerminalResult~success(.TerminalTlsTrustSelection~new("FILE", envFile, "ENV:SSL_CERT_FILE"))
  envPath = value("SSL_CERT_DIR",, "ENVIRONMENT")~strip
  if envPath \= "" then do
    selected = self~firstDirectoryFromList(envPath, "ENV:SSL_CERT_DIR")
    if selected~ok then return selected
  end

  /* Common CA bundle locations.  Ordering prefers distro-maintained aggregate
   * bundles before generic fallback files. */
  files = .array~of(,
    "/etc/ssl/certs/ca-certificates.crt",              /* Debian/Ubuntu/Alpine */,
    "/etc/ssl/ca-bundle.pem",                         /* openSUSE/SLES */,
    "/var/lib/ca-certificates/ca-bundle.pem",         /* openSUSE/SLES */,
    "/etc/pki/tls/certs/ca-bundle.crt",               /* RHEL/Fedora/CentOS */,
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", /* newer RHEL/Fedora */,
    "/etc/ca-certificates/extracted/tls-ca-bundle.pem",  /* Arch/p11-kit */,
    "/etc/ssl/certs/ca-bundle.crt",                   /* several Unix layouts */,
    "/etc/ssl/cert.pem",                              /* BSD/macOS/OpenBSD */,
    "/usr/local/share/certs/ca-root-nss.crt")         /* FreeBSD ca_root_nss */
  do candidate over files
    if self~fileExists(candidate) then return .TerminalResult~success(.TerminalTlsTrustSelection~new("FILE", candidate, "SYSTEM_BUNDLE"))
  end

  /* capath is a valid OpenSSL trust source.  If a directory exists but lacks
   * usable hashed certificates, the TLS handshake still fails verification;
   * discovery never converts that into an unverified connection. */
  dirs = .array~of("/etc/ssl/certs", "/etc/pki/tls/certs", "/etc/openssl/certs", "/usr/local/share/certs")
  do candidate over dirs
    if self~directoryExists(candidate) then return .TerminalResult~success(.TerminalTlsTrustSelection~new("DIR", candidate, "SYSTEM_CA_PATH"))
  end

  return .TerminalResult~failure("TLS_CA_NOT_FOUND", "no usable Unix CA bundle or CA directory discovered")

::class SocatTlsTerminalTransport public
::attribute host get
::attribute port get
::attribute state get
::attribute lastError get
::attribute verifyPeer get
::attribute caFile get
::attribute caPath get
::attribute trustSource get
::attribute helperPid get

::method init
  expose host port state lastError verifyPeer caFile caPath trustSource localPort pidFile logFile helperPid inner
  use arg hostArg, portArg, verifyPeerArg = .true, caFileArg = "", caPathArg = ""
  host = hostArg~string~strip
  port = portArg
  verifyPeer = verifyPeerArg == .true
  caFile = caFileArg~string~strip
  caPath = caPathArg~string~strip
  trustSource = ""
  state = .TerminalTransportState~CLOSED
  lastError = ""
  localPort = 0
  pidFile = ""
  logFile = ""
  helperPid = ""
  inner = .nil

::method shellSafe private
  use arg valueArg
  value = valueArg~string
  if value == "" then return .false
  /* Restrict helper arguments instead of trying to build a general shell
   * quoting language inside a network transport. */
  allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-/:"
  return value~verify(allowed) = 0

::method allocateLoopbackPort private
  s = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if s~errno <> 0 then return .TerminalResult~failure("TLS_PORT_SOCKET", s~errno)
  rc = s~bind(.InetAddress~new("127.0.0.1", 0))
  if rc < 0 then do
    err = s~errno
    s~close
    return .TerminalResult~failure("TLS_PORT_BIND", err)
  end
  a = s~getSockName
  if a == .nil then do
    err = s~errno
    s~close
    return .TerminalResult~failure("TLS_PORT_NAME", err)
  end
  p = a~port
  s~close
  return .TerminalResult~success(p)

::method readLog private
  expose logFile
  if logFile == "" | stream(logFile, "c", "query exists") == "" then return ""
  s = .stream~new(logFile)
  s~open("READ")
  text = s~charin(, s~chars)
  s~close
  return text~strip

::method readHelperPid private
  expose pidFile
  if pidFile == "" then return ""
  if stream(pidFile, "c", "query exists") == "" then return ""
  s = .stream~new(pidFile)
  opened = s~open("READ")
  if opened \= "READY:" then nop
  pid = s~linein~strip
  s~close
  if pid == "" then return ""
  if \pid~datatype("W") then return ""
  return pid

::method helperProcessAlive private
  use arg pidArg
  pid = pidArg~string~strip
  if pid == "" then return .false
  if \pid~datatype("W") then return .false
  /* kill -0 also succeeds for zombies.  A defunct socat cannot retain the
   * network session and must be treated as already stopped. */
  address command "ps -p " || pid || " -o stat= 2>/dev/null | grep -Eq '^[[:space:]]*[^Z]'"
  return rc = 0

/* Never signal an arbitrary reused PID.  The helper is considered ours only
 * while its command line still names both our unique loopback listener and the
 * requested TLS peer.  /proc is used on Linux; ps is the portable Unix
 * fallback. */
::method helperProcessOwned private
  expose localPort host port
  use arg pidArg
  pid = pidArg~string~strip
  if pid == "" then return .false
  if \pid~datatype("W") then return .false

  /* ps is used instead of /proc/<pid>/cmdline because procfs reports a zero
   * file size and ooRexx stream~chars therefore cannot portably read it.  All
   * interpolated values were validated before helper launch. */
  listenNeedle = "TCP-LISTEN:" || localPort || ",bind=127.0.0.1,reuseaddr"
  peerNeedle = "OPENSSL:" || host || ":" || port || ","
  command = "ps -p " || pid || " -o args= 2>/dev/null | grep -F -- '" || listenNeedle || "' | grep -F -- '" || peerNeedle || "' >/dev/null 2>&1"
  address command command
  return rc = 0

::method stopHelper private
  expose helperPid pidFile lastError
  pid = helperPid~string~strip
  if pid == "" then pid = self~readHelperPid
  if pid == "" then do
    if pidFile \= "" then call SysFileDelete pidFile
    helperPid = ""
    return .TerminalResult~success
  end

  if \self~helperProcessAlive(pid) then do
    if pidFile \= "" then call SysFileDelete pidFile
    helperPid = ""
    return .TerminalResult~success
  end

  if \self~helperProcessOwned(pid) then do
    /* The helper may have exited between the liveness and ownership probes.
     * Re-check before treating this as a PID-reuse/ownership failure. */
    if \self~helperProcessAlive(pid) then do
      if pidFile \= "" then call SysFileDelete pidFile
      helperPid = ""
      return .TerminalResult~success
    end
    lastError = "refusing to signal unowned TLS helper pid " || pid
    return .TerminalResult~failure("TLS_HELPER_OWNERSHIP_LOST", lastError)
  end

  address command "kill -TERM " || pid || " >/dev/null 2>&1"
  do i = 1 to 20
    if \self~helperProcessAlive(pid) then leave
    address command "sleep 0.05"
  end

  if self~helperProcessAlive(pid) then do
    /* A helper that ignores graceful shutdown must not be allowed to retain an
     * IBM i device session indefinitely. */
    if \self~helperProcessOwned(pid) then do
      if \self~helperProcessAlive(pid) then do
        if pidFile \= "" then call SysFileDelete pidFile
        helperPid = ""
        return .TerminalResult~success
      end
      lastError = "TLS helper ownership changed before forced shutdown pid " || pid
      return .TerminalResult~failure("TLS_HELPER_OWNERSHIP_LOST", lastError)
    end
    address command "kill -KILL " || pid || " >/dev/null 2>&1"
    do i = 1 to 20
      if \self~helperProcessAlive(pid) then leave
      address command "sleep 0.05"
    end
  end

  if self~helperProcessAlive(pid) then do
    lastError = "TLS helper survived TERM and KILL pid " || pid
    return .TerminalResult~failure("TLS_HELPER_STOP_FAILED", lastError)
  end

  if pidFile \= "" then call SysFileDelete pidFile
  helperPid = ""
  return .TerminalResult~success

::method open
  expose host port state lastError verifyPeer caFile caPath trustSource localPort pidFile logFile helperPid inner
  if state == .TerminalTransportState~OPEN then return .TerminalResult~success
  if \self~shellSafe(host) then return .TerminalResult~failure("TLS_HOST_UNSAFE", host)
  if \port~string~datatype("W") then return .TerminalResult~failure("TLS_PORT_INVALID", port)
  if port < 1 then return .TerminalResult~failure("TLS_PORT_INVALID", port)
  if port > 65535 then return .TerminalResult~failure("TLS_PORT_INVALID", port)
  address command 'command -v socat >/dev/null 2>&1'
  if rc <> 0 then do
    state = .TerminalTransportState~ERROR
    lastError = "socat not available"
    return .TerminalResult~failure("TLS_HELPER_UNAVAILABLE", lastError)
  end

  tlsOpts = "verify=0"
  if verifyPeer then do
    trust = .TerminalTlsTrustStore~resolve(caFile, caPath)
    if \trust~ok then do
      state = .TerminalTransportState~ERROR
      lastError = trust~detail
      return trust
    end
    selection = trust~value
    trustSource = selection~source
    if selection~mode == "FILE" then do
      caFile = selection~path
      caPath = ""
      if \self~shellSafe(caFile) then return .TerminalResult~failure("TLS_CAFILE_UNSAFE", caFile)
      tlsOpts = "verify=1,snihost=" || host || ",cafile=" || caFile
    end
    else do
      caPath = selection~path
      caFile = ""
      if \self~shellSafe(caPath) then return .TerminalResult~failure("TLS_CAPATH_UNSAFE", caPath)
      tlsOpts = "verify=1,snihost=" || host || ",capath=" || caPath
    end
  end

  allocated = self~allocateLoopbackPort
  if \allocated~ok then return allocated
  localPort = allocated~value
  pidFile = "/tmp/oorexx_terminal_tls_" || localPort || ".pid"
  logFile = "/tmp/oorexx_terminal_tls_" || localPort || ".log"
  call SysFileDelete pidFile
  call SysFileDelete logFile

  command = "sh -c 'socat TCP-LISTEN:" || localPort || ",bind=127.0.0.1,reuseaddr OPENSSL:" || host || ":" || port || "," || tlsOpts || " >" || logFile || " 2>&1 & echo $! >" || pidFile || "'"
  address command command
  if rc <> 0 then do
    state = .TerminalTransportState~ERROR
    lastError = "unable to start socat TLS helper"
    return .TerminalResult~failure("TLS_HELPER_START", lastError)
  end
  helperPid = self~readHelperPid
  if helperPid == "" then do
    state = .TerminalTransportState~ERROR
    lastError = "socat started without a readable helper pid"
    return .TerminalResult~failure("TLS_HELPER_PID_MISSING", lastError)
  end
  if \self~helperProcessOwned(helperPid) then do
    state = .TerminalTransportState~ERROR
    lastError = "started TLS helper does not match expected command pid " || helperPid
    return .TerminalResult~failure("TLS_HELPER_OWNERSHIP_LOST", lastError)
  end

  /* Let the loopback listener enter accept(2).  TLS itself starts only after
   * the local socket connects. */
  address command 'sleep 0.05'

  inner = .TcpTerminalTransport~new("127.0.0.1", localPort)
  opened = inner~open
  if \opened~ok then do
    lastError = self~readLog
    if lastError == "" then lastError = opened~code || ":" || opened~detail
    self~close
    state = .TerminalTransportState~ERROR
    return .TerminalResult~failure("TLS_TUNNEL_CONNECT", lastError)
  end
  state = .TerminalTransportState~OPEN
  lastError = ""
  return .TerminalResult~success

::method sendBytes
  expose state inner lastError
  use arg bytes
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  sent = inner~sendBytes(bytes)
  if \sent~ok then lastError = sent~code || ":" || sent~detail
  return sent

::method receiveBytes
  expose state inner lastError
  use arg maximum = 8192
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  received = inner~receiveBytes(maximum)
  if \received~ok then do
    detail = self~readLog
    if detail == "" then detail = received~code || ":" || received~detail
    lastError = detail
    return .TerminalResult~failure("TLS_RECEIVE", detail)
  end
  return received

::method waitReadable
  expose state inner lastError
  use arg timeoutSeconds = 1
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  waited = inner~waitReadable(timeoutSeconds)
  if \waited~ok then do
    detail = self~readLog
    if detail == "" then detail = waited~code || ":" || waited~detail
    lastError = detail
    return .TerminalResult~failure("TLS_WAIT", detail)
  end
  return waited

::method receiveBytesWait
  expose state inner lastError
  use arg maximum = 8192, timeoutSeconds = 1
  if state \== .TerminalTransportState~OPEN then return .TerminalResult~failure("TRANSPORT_CLOSED")
  waited = self~waitReadable(timeoutSeconds)
  if \waited~ok then return waited
  if \waited~value then return .TerminalResult~failure("TRANSPORT_TIMEOUT", timeoutSeconds)
  return self~receiveBytes(maximum)

::method close
  expose state inner pidFile logFile lastError
  if inner \== .nil then ignore = inner~close
  inner = .nil

  stopped = self~stopHelper
  if \stopped~ok then do
    state = .TerminalTransportState~ERROR
    return stopped
  end

  if logFile \= "" then call SysFileDelete logFile
  state = .TerminalTransportState~CLOSED
  return .TerminalResult~success

/* ooRexx sockets already use UNINIT as the last-resort close boundary.  The
 * TLS adapter must do the same because its helper is an OS process capable of
 * retaining a remote IBM i session after the Rexx object is abandoned. */
::method uninit
  expose state helperPid
  if state \== .TerminalTransportState~CLOSED then ignore = self~close
  else if helperPid \= "" then ignore = self~close
  return
