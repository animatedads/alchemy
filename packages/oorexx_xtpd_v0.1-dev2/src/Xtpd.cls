/* Xtpd.cls -- xtpd v0.1-dev2: the XTP network service daemon, one per node.
 *
 * Architecture: Tom Dyer (24 November 2026).  Coding: Claude (Opus 5.5);
 * dev2 (25 November 2026) binds ChatGPT's role component, xtpd_bootstrap v0.1-dev1.
 * Design: https://claude.ai/artifact/5xdnepoEfSABaQoCxcByNe and the xtpd sphere.
 *
 * ooRexx decides; libxtp moves XTP.  Built only from estate packages:
 *   oorexx_xtp (XtpSession.cls, XtpServiceKeys.cls)   sessions and keys
 *   oorexx_unix_socket v0.6 (unixsocket.cls)          control socket, socketpairs, fd passing
 *   oorexx_process v0.1-dev2 (Process.cls)            hooks started on a descriptor
 *   oorexx_logging v0.7 (LoggingCore.cls)             receipts and progress
 *   xtpd_bootstrap v0.1-dev1 (XtpRoleBootstrap.cls)    the role record (ChatGPT)
 *   oorexx_atomic_file v0.1-dev1 (AtomicFile.cls)     durable role-file replacement
 *   oorexx_crypto v0.8.3 (crypto.cls)                 the test-only role HMAC
 *
 * dev1 scope: registrations and peerages from local text files (the same
 * files the emergency set uses), service requests on a unix socket with
 * descriptor passing, exec hooks, the session pump, firewall-set updates
 * through a helper, receipts, clean start and stop.
 * dev2 adds the bootstrap role file: catch-up over xtp.roles, the LDAP role
 * probe over ldap.role, READY only on FRESH, and the ROLE control verb.
 * Not yet: LDAP sources, operating-state changes and reconcile(), the
 * emergency-file writer, xtp.provision peerages.  See README.md.
 */

/* ------------------------------------------------------------------ log -- */
::class XtpdLog public
::method setup class
  expose logger
  use strict arg logPath = '', echo = .true
  service = .LogService~new('xtpd')
  service~addTarget(.XtpdLogTarget~new('xtpd', .Log~INTERNAL, logPath, echo))
  rule = .LogRule~new('xtpd-events', 'xtpd', 'XtpdLog', 'event', -
    .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('xtpd'))
  service~addRule(rule)
  logger = service~loggerFor(.XtpdLog~new, 'event', .array~new, .Log~INTERNAL)
  return self
::method event class
  expose logger
  use strict arg text
  if var('logger') = 0 then self~setup
  logger~log(.Log~INFO, text)
  return .true
/* The same logger, for components that log structured events (directories). */
::method logger class
  expose logger
  if var('logger') = 0 then self~setup
  return logger

/* Appends each event, time-stamped, to the log file and echoes it on stderr. */
::class XtpdLogTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::method init
  expose name scope scopeObject enabled path echo
  use strict arg name, scopeValue, path, echo
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
::method accept
  expose enabled path echo
  use strict arg event
  if \enabled then return .false
  payload = event~payload
  if payload~isA(.directory) then do
    text = 'event'
    do k over payload~allIndexes~sort; text = text k'='payload[k]~string; end
    payload = text
  end
  line = date('S') time('L') 'xtpd' payload
  if path \== '' then do
    s = .stream~new(path)
    s~lineout(line)
    s~close
  end
  if echo then .error~lineout('[xtpd]' payload)
  return .true

/* ---------------------------------------------------------------- config -- */
/* xtpd.conf: one "key value" per line; '#' starts a comment.
 *   socket PATH            the request socket (its directory must exist)
 *   socket_mode 0660       socket_group NAME
 *   allow_uid N            allow_gid N        (root is always allowed)
 *   services PATH          peers PATH          keys PATH
 *   routes PATH            the route table xtpd writes for libxtp
 *   listen LAYER CARRIER ADDRESS              one per carrier to accept on
 *   firewall_helper PATH   (absent: the firewall is not touched, and that is logged)
 *   log PATH
 *   node NAME              this node's logical peer name (needed with role_file)
 *   role_file PATH         the bootstrap role file (xtpd_bootstrap); absent: no role
 *   role_keys PATH         TEST-ONLY role keys, "KEYID SECRETHEX" per line
 *   role_timeout_ms N      per fetch and per probe (default 3000) */
::class XtpdConfig public
::attribute values get
::attribute listens get
::attribute allowUids get
::attribute allowGids get
::method init
  expose values listens allowUids allowGids
  use strict arg path
  values = .directory~new
  listens = .array~new
  allowUids = .set~of(0)
  allowGids = .set~new
  lines = .XtpdText~lines(path)
  do n = 1 to lines~items
    line = lines[n]
    if line == '' then iterate
    parse var line key rest
    key = key~lower
    rest = rest~strip
    select
      when key == 'listen' then do
        parse var rest layer carrier address extra
        if extra \== '' | address == '' then raise syntax 93.900 array(path 'line' n': listen LAYER CARRIER ADDRESS')
        listens~append(.array~of(layer, carrier, address))
      end
      when key == 'allow_uid' then allowUids~put(rest)
      when key == 'allow_gid' then allowGids~put(rest)
      when .array~of('socket', 'socket_mode', 'socket_group', 'services', 'peers', 'keys', 'routes', 'firewall_helper', 'log', 'node', 'role_file', 'role_keys', 'role_timeout_ms')~hasItem(key) then values[key] = rest
      otherwise raise syntax 93.900 array(path 'line' n': unknown key' key)
    end
  end
  do needed over .array~of('socket', 'services', 'peers', 'routes')
    if \values~hasIndex(needed) then raise syntax 93.900 array(path': missing' needed)
  end
  if values~hasIndex('role_file') then do needed over .array~of('node', 'role_keys')
    if \values~hasIndex(needed) then raise syntax 93.900 array(path': role_file needs' needed)
  end
  if values~hasIndex('node') then if \.XtpdCheck~serviceName(values['node']) then raise syntax 93.900 array(path': bad node name' values['node'])
  if values~hasIndex('role_timeout_ms') then do
    t = values['role_timeout_ms']
    if t~datatype('W') \= 1 | t < 100 | t > 60000 then raise syntax 93.900 array(path': role_timeout_ms must be 100 to 60000')
  end
::method get
  expose values
  use strict arg key, default = ''
  if values~hasIndex(key) then return values[key]
  return default

/* Reads a text file as trimmed lines, comments removed; refuses a symbolic link. */
::class XtpdText public
::method lines class
  use strict arg path
  if \SysFileExists(path) then raise syntax 93.900 array('no such file:' path)
  if SysIsFileLink(path) then raise syntax 93.900 array('refusing a symbolic link:' path)
  s = .stream~new(path)
  s~open('read')
  out = .array~new
  do while s~lines > 0
    line = s~linein
    parse var line line '#' .
    out~append(line~strip)
  end
  s~close
  return out

/* ------------------------------------------------------------- services -- */
/* services.txt: SERVICE CLASS PROTECTION exec /absolute/program [args...] */
::class XtpdServices public
::attribute byName get
::method init
  expose byName
  use strict arg path
  byName = .directory~new
  lines = .XtpdText~lines(path)
  do n = 1 to lines~items
    line = lines[n]
    if line == '' then iterate
    parse var line service class protection kind argvText
    argvText = argvText~strip
    where = path 'line' n
    if \.XtpdCheck~serviceName(service) then raise syntax 93.900 array(where': bad service name' service)
    if \.array~of('none', 'authenticate', 'encrypt')~hasItem(protection) then raise syntax 93.900 array(where': protection must be none, authenticate or encrypt')
    if kind \== 'exec' then raise syntax 93.900 array(where': hook kind must be exec in dev1')
    argv = argvText~makeArray(' ')
    clean = .array~new
    do a over argv; if a \== '' then clean~append(a); end
    if clean~items = 0 then raise syntax 93.900 array(where': exec needs a program')
    if clean[1]~left(1) \== '/' then raise syntax 93.900 array(where': the program must be an absolute path')
    entry = .directory~new
    entry['SERVICE'] = service; entry['CLASS'] = class; entry['PROTECTION'] = protection
    entry['KIND'] = kind; entry['ARGV'] = clean
    byName[service] = entry
  end
::method names
  expose byName
  return byName~allIndexes~sort
::method csv
  expose byName
  out = ''
  do name over self~names
    if out \== '' then out = out','
    out = out || name
  end
  return out

/* ---------------------------------------------------------------- peers -- */
/* peers.txt: PEER LAYER CARRIER ADDRESS   (layer 3 raw36 IPv4; layer 4 udp IPv4:port) */
::class XtpdPeers public
::attribute byName get
::method init
  expose byName
  use strict arg path
  byName = .directory~new
  lines = .XtpdText~lines(path)
  do n = 1 to lines~items
    line = lines[n]
    if line == '' then iterate
    parse var line peer layer carrier address extra
    where = path 'line' n
    if extra \== '' | address == '' then raise syntax 93.900 array(where': PEER LAYER CARRIER ADDRESS')
    if \.XtpdCheck~serviceName(peer) then raise syntax 93.900 array(where': bad peer name' peer)
    if \.XtpdCheck~route(layer, carrier, address) then raise syntax 93.900 array(where': bad route' layer carrier address)
    entry = .directory~new
    entry['PEER'] = peer; entry['LAYER'] = layer; entry['CARRIER'] = carrier; entry['ADDRESS'] = address
    entry['HOST'] = address~changeStr(':', ' ')~word(1)
    byName[peer] = entry
  end
::method hosts
  expose byName
  out = .set~new
  do name over byName~allIndexes; out~put(byName[name]['HOST']); end
  return out
::method peerForHost
  expose byName
  use strict arg host
  do name over byName~allIndexes
    if byName[name]['HOST'] == host then return name
  end
  return ''
/* Writes the libxtp route table: every peer, plus one listen route per carrier. */
::method writeRoutes
  expose byName
  use strict arg path, listens
  tab = '09'x
  temp = path'.new'
  call SysFileDelete temp
  s = .stream~new(temp)
  s~open('write replace')
  s~lineout('#peer' || tab || 'layer' || tab || 'carrier' || tab || 'destination' || tab || 'interface' || tab || 'metric' || tab || 'enabled' || tab || 'wire_filters' || tab || 'multicast')
  do name over byName~allIndexes~sort
    p = byName[name]
    s~lineout(name || tab || p['LAYER'] || tab || p['CARRIER'] || tab || p['ADDRESS'] || tab || tab || '100' || tab || '1' || tab || tab || '0')
  end
  do i = 1 to listens~items
    l = listens[i]
    s~lineout('xtpd.listen.'i || tab || l[1] || tab || l[2] || tab || l[3] || tab || tab || '100' || tab || '1' || tab || tab || '0')
  end
  s~close
  call SysFileMove temp, path
  return path

::class XtpdCheck public
::method serviceName class
  use strict arg name
  if name == '' | name~length > 128 then return .false
  return name~verify('abcdefghijklmnopqrstuvwxyz0123456789.-_') = 0
::method ipv4 class
  use strict arg text
  parse var text a '.' b '.' c '.' d
  if text~countStr('.') \= 3 then return .false
  do part over .array~of(a, b, c, d)
    if part == '' | part~datatype('W') \= 1 | part~length > 3 | part < 0 | part > 255 then return .false
  end
  return .true
::method route class
  use strict arg layer, carrier, address
  if layer = 3 & carrier == 'raw36' then return self~ipv4(address)
  if layer = 4 & carrier == 'udp' then do
    parse var address host ':' port
    return self~ipv4(host) & port~datatype('W') = 1 & port > 0 & port < 65536
  end
  return .false

/* ------------------------------------------------------------- firewall -- */
/* Peerages are the only thing that puts an address into the fence.  The helper
 * is run argv-first through oorexx_process: HELPER add|remove|flush [IPV4]. */
::class XtpdFirewall public
::method init
  expose helper runner added
  use strict arg helper
  runner = .ProcessRunner~new
  added = .set~new
::method run private
  expose helper runner
  use strict arg verb, address = ''
  if helper == '' then do
    .XtpdLog~event('firewall: no helper configured; not changed ('verb address')')
    return .true
  end
  /* the helper setting is an argv prefix, e.g. "rexx /opt/xtpd/libexec/xtpd_firewall.rex" */
  argv = .array~new
  do word over helper~makeArray(' '); if word \== '' then argv~append(word); end
  argv~append(verb)
  if address \== '' then argv~append(address)
  spec = .ProcessSpec~new(argv)
  spec~timeoutMs = 10000
  r = runner~run(spec)
  if r~succeeded then do
    .XtpdLog~event('firewall:' verb address 'ok')
    return .true
  end
  .XtpdLog~event('firewall:' verb address 'FAILED rc='r~exitCode r~stderr~strip r~errorMessage)
  return .false
::method flush
  expose added
  added~empty
  return self~run('flush')
::method add
  expose added
  use strict arg address
  if \.XtpdCheck~ipv4(address) then return .false
  if self~run('add', address) then added~put(address)
  return .true
::method withdrawAll
  expose added
  do a over added~allIndexes; self~run('remove', a); end
  added~empty

/* ----------------------------------------------------------------- pump -- */
/* Joins one XTP session to one local stream socket until both directions end.
 * Two threads: socket -> session (recvMessage is unguarded) and
 * session -> socket.  End of file on either side closes that direction on the
 * Receipts count from the network side: sent = local socket to peer,
 * received = peer to local socket.
 * other; a failure on either side aborts both. */
::class XtpdPump public
::attribute done get
::attribute label get
::method init
  expose session sock label done failed toSession fromSession left why child
  use strict arg session, sock, label, child = ''
  done = .false; failed = .false; toSession = 0; fromSession = 0; left = 2; why = ''
::method run
  self~start('up')
  self~start('down')
  return self
::method child
  expose child
  return child
::method up unguarded
  expose session sock toSession
  signal on syntax name broken
  do forever
    msg = sock~recvMessage(16384, 0)
    if msg == .nil then do
      self~fail('socket read errno' sock~errno)
      leave
    end
    data = msg~data
    if data == '' then do
      session~shutdown
      leave
    end
    session~write(data)
    toSession = toSession + data~length
  end
  self~finish
  return
broken:
  self~fail('up:' condition('O')['ADDITIONAL']~makeString)
  self~finish
  return
::method down unguarded
  expose session sock fromSession
  signal on syntax name broken
  do forever
    chunk = session~read(65536, -1)
    if session~lastFlag == 'END' then do
      sock~shutdown(1)                       /* SHUT_WR */
      leave
    end
    if chunk == '' then iterate
    if sock~sendAll(chunk) < 0 then do
      self~fail('socket write errno' sock~errno)
      leave
    end
    fromSession = fromSession + chunk~length
  end
  self~finish
  return
broken:
  self~fail('down:' condition('O')['ADDITIONAL']~makeString)
  self~finish
  return
::method fail
  expose session sock failed why
  use strict arg reason
  if failed then return
  failed = .true; why = reason
  signal on syntax name ignore
  session~abort
  sock~shutdown(2)                           /* SHUT_RDWR */
ignore:
  return
::method finish
  expose session sock left failed done label toSession fromSession why
  left = left - 1
  if left > 0 then return
  clean = .false
  if \failed then do
    signal on syntax name closeFailed
    clean = session~close(5000)
  end
closeFailed:
  sock~close
  outcome = 'clean'
  if \clean then outcome = 'not clean:' why
  .XtpdLog~event('receipt:' label 'sent' toSession 'received' fromSession '-' outcome)
  done = .true

/* -------------------------------------------------------------- listener -- */
/* Accepts sessions for registered services on one carrier and runs their hooks. */
::class XtpdListener public
::method init
  expose daemon routePeer services peers listener runner stopping
  use strict arg daemon, routePeer, services, peers
  runner = .ProcessRunner~new
  stopping = .false
  listener = .XtpSessionListener~new(routePeer, services~csv, .false)
  .XtpdLog~event('listening on' routePeer 'for' services~csv)
::method stop
  expose stopping listener
  stopping = .true
  listener~close
::method loop unguarded
  expose stopping listener
  signal on syntax name broken
  do while \stopping
    session = listener~accept(500)
    if session == .nil then iterate
    self~admit(session)
  end
  return
broken:
  if \stopping then .XtpdLog~event('listener failed:' condition('O')['ADDITIONAL']~makeString)
  return
::method admit
  expose daemon services peers runner
  use strict arg session
  info = session~info
  service = info['SERVICE']
  host = info['PEER']~changeStr(':', ' ')~word(1)
  peer = peers~peerForHost(host)
  if peer == '' then do
    .XtpdLog~event('refused: session for' service 'from' info['PEER'] '- not a peerage')
    session~abort
    return
  end
  reg = services~byName[service]
  if reg == .nil then do
    .XtpdLog~event('refused: session for unregistered service' service 'from' peer)
    session~abort
    return
  end
  if reg['PROTECTION'] \== 'none' & info['PROTECTION'] \== reg['PROTECTION'] & \(reg['PROTECTION'] == 'authenticate' & info['PROTECTION'] == 'encrypt') then do
    .XtpdLog~event('refused:' service 'from' peer 'at protection' info['PROTECTION'] '(needs' reg['PROTECTION']')')
    session~abort
    return
  end
  pair = .UnixSocket~socketPair('SOCK_STREAM')
  if pair == .nil then do
    .XtpdLog~event('refused:' service 'from' peer '- no socketpair')
    session~abort
    return
  end
  spec = .ProcessSpec~new(reg['ARGV'])
  spec~stdinDescriptor = pair[2]~fd
  spec~stdoutPolicy = 'DESCRIPTOR'
  spec~stdoutDescriptor = pair[2]~fd
  spec~stderrPolicy = 'DISCARD'
  spec~detach = .true
  spec~processGroup = .true
  started = runner~run(spec)
  pair[2]~close
  if \started~started then do
    .XtpdLog~event('hook failed to start for' service 'from' peer':' started~errorStage started~errorMessage)
    pair[1]~close
    session~abort
    return
  end
  label = service 'from' peer 'key' info['KEYID'] 'protection' info['PROTECTION'] 'hook pid' started~pid
  .XtpdLog~event('accepted:' label)
  daemon~track(.XtpdPump~new(session, pair[1], label, started~pid)~run)

/* --------------------------------------------------------------- control -- */
/* The request socket.  One line per connection:
 *   OPEN SERVICE PEER   -> one byte 'K' carrying a connected descriptor, or "ERR reason\n"
 *   STATUS              -> one line (root only)
 *   ROLE                -> catch up and resolve again, then one line (root only) */
::class XtpdControl public
::method init
  expose daemon config sock path stopping peers services
  use strict arg daemon, config, peers, services
  stopping = .false
  path = config~get('socket')
  .UnixSocket~unlinkSocketPath(path)
  sock = .UnixSocket~new('SOCK_STREAM')
  if sock~bind(.UnixAddress~pathname(path)) \= 0 then raise syntax 93.900 array('cannot bind' path':' sock~errorText)
  if .UnixSocket~chmodSocketPath(path, config~get('socket_mode', '0660')) < 0 then raise syntax 93.900 array('cannot chmod' path)
  group = config~get('socket_group')
  if group \== '' then do
    gid = .XtpdControl~gidOf(group)
    if gid < 0 | .UnixSocket~chownSocketPath(path, .nil, gid) < 0 then raise syntax 93.900 array('cannot set group' group 'on' path)
  end
  sock~listen(16)
  .XtpdLog~event('requests on' path)
::method gidOf class
  use strict arg group
  lines = .XtpdText~lines('/etc/group')
  do line over lines
    parse var line name ':' . ':' gid ':' .
    if name == group then return gid
  end
  return -1
::method stop
  expose stopping sock path
  stopping = .true
  sock~close
  .UnixSocket~unlinkSocketPath(path)
::method loop unguarded
  expose stopping sock
  watch = .array~of(.UnixPollWatch~read(sock))
  do while \stopping
    ready = .UnixPoll~wait(watch, 500)
    if stopping then leave
    if ready == .nil | ready~items = 0 then iterate
    conn = sock~accept
    if conn == .nil then iterate
    self~serve(conn)
  end
::method serve
  expose daemon config peers services
  use strict arg conn
  signal on syntax name broken
  cred = conn~peerCredentials
  if cred == .nil then do; conn~close; return; end
  who = 'uid' cred['UID'] 'gid' cred['GID'] 'pid' cred['PID']
  if \(config~allowUids~hasIndex(cred['UID']) | config~allowGids~hasIndex(cred['GID'])) then do
    .XtpdLog~event('request refused:' who 'is not allowed')
    conn~sendAll('ERR not allowed' || '0a'x)
    conn~close
    return
  end
  line = self~readLine(conn)
  parse var line verb service peer extra
  select
    when verb == 'OPEN' & extra == '' & peer \== '' then self~open(conn, service, peer, who)
    when verb == 'STATUS' & cred['UID'] = 0 then do
      conn~sendAll('OK' daemon~status || '0a'x)
      conn~close
    end
    when verb == 'ROLE' & service == '' & cred['UID'] = 0 then do
      conn~sendAll('OK' daemon~roleCheck || '0a'x)
      conn~close
    end
    otherwise do
      .XtpdLog~event('request refused:' who 'sent' line~left(80))
      conn~sendAll('ERR bad request' || '0a'x)
      conn~close
    end
  end
  return
broken:
  .XtpdLog~event('request failed:' condition('O')['ADDITIONAL']~makeString)
  signal on syntax name gone
  conn~close
gone:
  return
::method readLine private
  use strict arg conn
  line = ''
  do 64 while line~pos('0a'x) = 0
    ready = .UnixPoll~wait(.array~of(.UnixPollWatch~read(conn)), 5000)
    if ready == .nil | ready~items = 0 then leave
    msg = conn~recvMessage(512, 0)
    if msg == .nil | msg~data == '' then leave
    line = line || msg~data
  end
  parse var line line '0a'x .
  return line~strip
::method open private
  expose daemon peers services
  use strict arg conn, service, peer, who
  if peers~byName[peer] == .nil then do
    .XtpdLog~event('request refused:' who 'OPEN' service peer '- not a peerage')
    conn~sendAll('ERR unknown peer' peer || '0a'x); conn~close
    return
  end
  signal on syntax name refused
  session = .XtpSession~open(peer, service, 5000)
  signal off syntax
  pair = .UnixSocket~socketPair('SOCK_STREAM')
  info = session~info
  label = service 'to' peer 'for' who 'key' info['KEYID'] 'protection' info['PROTECTION']
  daemon~track(.XtpdPump~new(session, pair[1], label)~run)
  conn~sendDescriptors('K', .array~of(pair[2]))
  pair[2]~close
  conn~close
  .XtpdLog~event('opened:' label)
  return
refused:
  why = condition('O')['ADDITIONAL']~makeString
  .XtpdLog~event('request failed:' who 'OPEN' service peer '-' why)
  conn~sendAll('ERR' why~left(200) || '0a'x)
  conn~close
  return

/* ---------------------------------------------------------------- daemon -- */
::class Xtpd public
::method init
  expose config services peers firewall keys listeners control pumps stopping runner roles
  use strict arg confPath
  roles = .nil
  config = .XtpdConfig~new(confPath)
  .XtpdLog~setup(config~get('log'), .true)
  .XtpdLog~event('starting: xtpd' .Xtpd~version 'config' confPath)
  services = .XtpdServices~new(config~get('services'))
  peers = .XtpdPeers~new(config~get('peers'))
  runner = .ProcessRunner~new
  pumps = .array~new
  stopping = .false
  listeners = .array~new
::constant version '0.1-dev2'
::method run
  expose config services peers firewall keys listeners control roles
  /* routes first: libxtp reads them from XTP_ROUTE_FILE */
  routes = peers~writeRoutes(config~get('routes'), config~listens)
  call value 'XTP_ROUTE_FILE', routes, 'ENVIRONMENT'
  .XtpdLog~event('routes:' peers~byName~items 'peers,' config~listens~items 'listen carriers ->' routes)
  /* keys: the file source; a service that names a protection gets that profile */
  keyPath = config~get('keys')
  if keyPath \== '' then do
    keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyPath)))
    outcome = keys~refresh
    .XtpdLog~event('keys:' outcome['COUNT'] 'from' outcome['SOURCE'] outcome['ERRORS'])
    do name over services~names
      p = services~byName[name]['PROTECTION']
      if p \== 'none' then keys~require(name, p)
    end
  end
  /* clean at start: empty the fence set, then admit every peerage */
  firewall = .XtpdFirewall~new(config~get('firewall_helper'))
  firewall~flush
  do name over peers~byName~allIndexes~sort
    firewall~add(peers~byName[name]['HOST'])
  end
  do i = 1 to config~listens~items
    if services~names~items = 0 then leave
    l = .XtpdListener~new(self, 'xtpd.listen.'i, services, peers)
    listeners~append(l)
    l~start('loop')
  end
  control = .XtpdControl~new(self, config, peers, services)
  control~start('loop')
  .XtpdLog~event('running:' services~names~items 'services,' peers~byName~items 'peerages')
  return self
/* The role, after run.  Unguarded, and so is everything it calls on this
 * object: the listener and control threads call track() (guarded) for every
 * session, so a role check that held this object's guard would stop the node
 * accepting sessions -- including the probes other nodes send it -- for as
 * long as its own fetches and probes wait (found in dev2 qualification). */
::method startRoles unguarded
  expose config roles
  if config~get('role_file') == '' then return self
  host = .XtpdRoleHost~new(config)
  roles = host
  host~start
  return self
::method roleCheck unguarded
  expose roles
  if roles == .nil then return 'role none'
  roles~start
  return 'role' roles~line
::method track
  expose pumps
  use strict arg pump
  pumps~append(pump)
::method status
  expose pumps services peers roles   /* roles~line is unguarded: never waits for a role check */
  role = 'role none'
  if roles \== .nil then role = 'role' roles~line
  return 'xtpd' .Xtpd~version 'services' services~names~items 'peerages' peers~byName~items 'sessions' pumps~items role
/* Reap finished hooks and pumps; call every half second from the main loop. */
::method housekeep
  expose pumps runner
  keep = .array~new
  do p over pumps
    if \p~done then do; keep~append(p); iterate; end
    if p~child \== '' then do
      r = runner~reap(p~child)
      if r~termination == 'RUNNING' then do
        runner~signal(p~child, 15, .true)
        keep~append(p)               /* reaped next round */
        iterate
      end
      .XtpdLog~event('hook pid' p~child 'ended:' r~termination r~exitCode)
    end
  end
  pumps = keep
::method stop
  expose listeners control firewall stopping
  if stopping then return
  stopping = .true
  .XtpdLog~event('stopping')
  do l over listeners; l~stop; end
  if var('control') then control~stop
  if var('firewall') then firewall~withdrawAll
  .XtpdLog~event('stopped')

/* ---------------------------------------------------------------- roles -- */
/* dev2: the role bootstrap bound into xtpd.
 * Coding: Claude (Opus 5.5), 25 November 2026.
 * The role component itself (XtpRoleBootstrap.cls, packages/xtpd_bootstrap_v0.1-dev1)
 * was coded by ChatGPT and qualified by Claude (Opus 5.5); it is used unchanged.
 *
 * This file is the host side the component's README asks for:
 *   XtpdRoleKeys      the test-key file for XtpTestRoleVerifier
 *   XtpdRoleExchange  roleExchange~fetchRole(peer) over the xtp.roles service
 *   XtpdLdapProbe     ldapRoleProbe~confirms(peer, role, epoch, version) over ldap.role
 *   XtpdRoleHost      loads the role file at xtpd start and answers STATUS/ROLE
 *
 * The two services are ordinary xtpd exec hooks (libexec/xtp_roles.rex and
 * libexec/ldap_role.rex), registered in services.txt like any other.
 */

/* role_keys file: one "KEYID SECRETHEX" per line; '#' comments.  TEST KEYS ONLY:
 * a shared-key HMAC, not the real Auth.  Refuses a symbolic link. */
::class XtpdRoleKeys public
::method load class
  use strict arg path
  keys = .directory~new
  lines = .XtpdText~lines(path)
  do n = 1 to lines~items
    line = lines[n]
    if line == '' then iterate
    parse var line keyId secret extra
    where = path 'line' n
    if extra \== '' | secret == '' then raise syntax 93.900 array(where': KEYID SECRETHEX')
    if keyId~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-') \= 0 then raise syntax 93.900 array(where': bad key id')
    if secret~length < 32 | secret~length // 2 \= 0 | secret~verify('0123456789abcdefABCDEF') \= 0 then raise syntax 93.900 array(where': secret must be even-length hex, 32 or more digits')
    if keys~hasIndex(keyId) then raise syntax 93.900 array(where': duplicate key id' keyId)
    keys[keyId] = secret~lower
  end
  if keys~items = 0 then raise syntax 93.900 array(path': no keys')
  return keys

/* fetchRole(peer): the exact signed envelope a peer's xtp.roles hook serves, or
 * .nil after a bounded failure.  Never asks this node itself. */
::class XtpdRoleExchange public
::method init
  expose node timeoutMs
  use strict arg node, timeoutMs
::method fetchRole
  expose node timeoutMs
  use strict arg peer
  if peer == node then return .nil
  signal on syntax name failed
  session = .XtpSession~open(peer, 'xtp.roles', timeoutMs)
  session~shutdown                       /* nothing to send */
  bytes = ''
  do forever
    chunk = session~read(8193, timeoutMs)
    flag = session~lastFlag
    if flag == 'END' then leave
    if flag == 'TIMEOUT' then do
      session~abort
      .XtpdLog~event('role: fetch from' peer 'timed out')
      return .nil
    end
    bytes = bytes || chunk
    if bytes~length > 8192 then do
      session~abort
      .XtpdLog~event('role: fetch from' peer 'refused - over 8192 bytes')
      return .nil
    end
  end
  session~close(timeoutMs)
  .XtpdLog~event('role: fetched' bytes~length 'bytes from' peer)
  return bytes
failed:
  if condition('O')['CODE']~left(2) == '4.' then raise propagate   /* HALT: never swallowed */
  .XtpdLog~event('role: fetch from' peer 'failed -' condition('O')['ADDITIONAL']~makeString~left(160))
  signal on syntax name gone
  if symbol('session') == 'VAR' then session~abort
gone:
  return .nil

/* confirms(peer, role, epoch, version): .true only when the peer's ldap.role
 * hook answers exactly "CONFIRM peer role epoch version" on an authenticated
 * session.  Authenticated means: by a holder of the ldap.role service key, not
 * by that one node (per-node proof needs the real Auth). */
::class XtpdLdapProbe public
::method init
  expose node timeoutMs
  use strict arg node, timeoutMs
::method confirms
  expose node timeoutMs
  use strict arg peer, role, epoch, version
  if peer == node then do
    .XtpdLog~event('role: probe of' role peer '- this node; not confirmed by itself')
    return .false
  end
  signal on syntax name failed
  session = .XtpSession~open(peer, 'ldap.role', timeoutMs, 'authenticate')
  session~write('PROBE' role epoch version || '0a'x)
  session~shutdown
  reply = ''
  do forever
    chunk = session~read(256, timeoutMs)
    flag = session~lastFlag
    if flag == 'END' then leave
    if flag == 'TIMEOUT' then do
      session~abort
      .XtpdLog~event('role: probe of' role peer 'timed out')
      return .false
    end
    reply = reply || chunk
    if reply~length > 256 then do
      session~abort
      .XtpdLog~event('role: probe of' role peer 'refused - reply too long')
      return .false
    end
  end
  info = session~info
  session~close(timeoutMs)
  parse var reply reply '0a'x .
  expected = 'CONFIRM' peer role epoch version
  ok = (reply == expected)
  .XtpdLog~event('role: probe of' role peer 'at' epoch'.'version 'protection' info['PROTECTION'] '->' reply~left(80))
  return ok
failed:
  if condition('O')['CODE']~left(2) == '4.' then raise propagate   /* HALT: never swallowed */
  .XtpdLog~event('role: probe of' role peer 'failed -' condition('O')['ADDITIONAL']~makeString~left(160))
  signal on syntax name gone
  if symbol('session') == 'VAR' then session~abort
gone:
  return .false

/* Loads the role file once at xtpd start, catches up from the role's peers,
 * resolves LDAP.main, and keeps the answer for STATUS.  Any failure leaves xtpd
 * running in degraded mode: READY is false, never FRESH from the file alone. */
::class XtpdRoleHost public
::method last unguarded
  expose last
  return last
::method init
  expose bootstrap exchange probe last
  use strict arg config
  bootstrap = .nil
  last = .directory~new
  last['SOURCE'] = 'NONE'; last['STATUS'] = 'NOT_LOADED'; last['PEER'] = ''; last['READY'] = .false
  node = config~get('node')
  path = config~get('role_file')
  timeoutMs = config~get('role_timeout_ms', 3000)
  exchange = .XtpdRoleExchange~new(node, timeoutMs)
  probe = .XtpdLdapProbe~new(node, timeoutMs)
  signal on syntax name refused
  if SysIsFileLink(path) then raise syntax 93.900 array('refusing a symbolic link:' path)
  keys = .XtpdRoleKeys~load(config~get('role_keys'))
  verifier = .XtpTestRoleVerifier~new(keys)
  .XtpdLog~event('role: verifier' verifier~mode '('keys~items 'test keys) - not the real Auth')
  store = .XtpRoleFile~new(path, .AtomicFile~new, .AtomicFileOptions~new)
  bootstrap = .XtpRoleBootstrap~new(store, verifier, .XtpdLog~logger)
  r = bootstrap~record
  .XtpdLog~event('role: loaded' r~name 'main' r~main 'spare' r~spare 'epoch' r~epoch 'version' r~version 'from' path)
  return
refused:
  if condition('O')['CODE']~left(2) == '4.' then raise propagate   /* HALT: never swallowed */
  last['STATUS'] = 'BOOT_REFUSED'
  .XtpdLog~event('role: boot refused -' condition('O')['ADDITIONAL']~makeString~left(200) '(degraded: not READY)')
  return
::method start
  expose bootstrap exchange probe last
  if bootstrap == .nil then return last
  signal on syntax name failed
  out = bootstrap~start(exchange, probe)
  r = bootstrap~record
  out['EPOCH'] = r~epoch; out['VERSION'] = r~version
  last = out
  .XtpdLog~event('role:' self~line)
  return last
failed:
  if condition('O')['CODE']~left(2) == '4.' then raise propagate   /* HALT: never swallowed */
  last = .directory~new
  last['SOURCE'] = 'NONE'; last['STATUS'] = 'FAILED'; last['PEER'] = ''; last['READY'] = .false
  .XtpdLog~event('role: start failed -' condition('O')['ADDITIONAL']~makeString~left(200))
  return last
::method line unguarded
  expose last
  e = ''
  if last~hasIndex('EPOCH') then e = 'epoch' last['EPOCH'] 'version' last['VERSION']
  ready = 'no'
  if last['READY'] == .true then ready = 'yes'
  return ('source' last['SOURCE'] 'status' last['STATUS'] 'peer' last['PEER'] e 'ready' ready)~space

::requires 'XtpSession.cls'
::requires 'XtpServiceKeys.cls'
::requires 'unixsocket.cls'
::requires 'Process.cls'
::requires 'LoggingCore.cls'
::requires 'XtpRoleBootstrap.cls'
::requires 'AtomicFile.cls'
