/* ShellHost.cls - an MU's host as shell objects: services, the MU audit,
   xtpd, and the Mu object that gathers them.
   Architecture: Tom Dyer (24 November 2026): enough objects to start an MU
   and examine its networks, so an agent on ed209g finds issues quickly.
   Coding: Claude (Opus 5.5).

   mu = .Mu~new                       -- this host
   mu~net~listening~~table            ShellNet.cls
   mu~services~failed~~table          systemctl
   mu~audit~findings~~table           the estate's MU audit (/opt/mu-tools)
   mu~xtpd~~table                     process, socket, config, log tail
   mu~xtpd~bringUp('/etc/xtpd/xtpd.conf')  PROTECTED: the policy decides
   mu~xtpd~bringDown                       PROTECTED
   (not start/stop: ~start is ooRexx's asynchronous send, which the check refuses)

   Reading is open. Starting and stopping xtpd are the only protected
   actions here; the cats1 policy denies them until Tom adds a line. */
::requires 'ShellObject.cls'
::requires 'ShellLog.cls'
::requires 'ShellNet.cls'
::requires 'Process.cls'

::class Mu public inherit ShellObject
::constant SHELL_HELP "mu~net (Network), mu~services (Services), mu~audit (MuAuditor: findings against the MU contract), mu~xtpd (Xtpd), mu~host (hostname, kernel, uptime). Start with mu~audit~findings and mu~net~listening."
::method init
  expose contract
  use strict arg contract = ''
  if contract == '' then contract = value('NEWSHELL_MU_CONTRACT',, 'ENVIRONMENT')
  if contract == '' then contract = muToolsDir()'/etc/mu_contract_cats.txt'
::method hostname
  return readOne('/proc/sys/kernel/hostname')
::method kernel
  return readOne('/proc/sys/kernel/osrelease')
::method uptimeSeconds
  return readOne('/proc/uptime')~word(1)
::method bootId
  return readOne('/proc/sys/kernel/random/boot_id')
::method net
  return .Network~new
::method services
  return .Services~new
::method audit
  expose contract
  return .MuAuditor~new(contract)
::method xtpd
  return .Xtpd~new
::method identity
  return 'mu:'self~hostname':'self~bootId
::method fields
  return .Array~of('hostname', 'kernel', 'uptimeSeconds', 'bootId')
::method relatedSamples
  expose contract
  return .Array~of(.Array~of('mu~net', .Network~new), .Array~of('mu~services', .Services~sample), -
                   .Array~of('mu~audit', .MuAuditor~sample(contract)), .Array~of('mu~xtpd', .Xtpd~new))

/* --------------------------------------------------------------- services -- */
::class Services public inherit ShellObject
::constant SHELL_HELP "svc~units: every loaded service unit (unit, load, active, sub, description). svc~failed: those whose active state is failed. svc~enabled: unit files enabled at boot. svc~unit(name) gives one. ok is 0 when systemctl could not answer (error says why)."
::method sample class
  return self~new(.true)
::method init
  expose rows error enabledRows
  use strict arg empty = .false
  rows = .Array~new; enabledRows = .nil; error = ''
  if empty then return
  out = systemctl(.Array~of('list-units', '--type=service', '--all', '--no-legend', '--plain', '--no-pager'))
  if out~isA(.String) then do; error = out; return; end
  do l over out
    parse var l unit load active sub description
    if unit == '' then iterate
    rows~append(.ServiceUnit~new(unit, load, active, sub, description~strip))
  end
::method units
  expose rows
  return .ShellCollection~new(rows~copy)
::method failed
  expose rows
  list = .Array~new
  do r over rows; if r~active == 'failed' then list~append(r); end
  return .ShellCollection~new(list)
::method unit
  expose rows
  use strict arg name
  do r over rows
    if r~unit == name | r~unit == name'.service' then return r
  end
  return .nil
::method enabled
  expose enabledRows error
  if enabledRows == .nil then do
    enabledRows = .Array~new
    out = systemctl(.Array~of('list-unit-files', '--state=enabled', '--no-legend', '--no-pager'))
    if out~isA(.String) then return .ShellCollection~new(enabledRows)
    do l over out
      parse var l unit state .
      if unit \== '' then enabledRows~append(.ServiceUnit~new(unit, 'loaded', state, '', ''))
    end
  end
  return .ShellCollection~new(enabledRows~copy)
::method ok
  expose error
  return error == ''
::method error
  expose error
  return error
::method unitCount
  expose rows
  return rows~items
::method failedCount
  return self~failed~items~items
::method fields
  return .Array~of('ok', 'unitCount', 'failedCount', 'error')
::method relatedSamples
  return .Array~of(.Array~of('each svc~units item', .ServiceUnit~new('ssh.service', 'loaded', 'active', 'running', 'OpenBSD Secure Shell server')))

::class ServiceUnit public inherit ShellObject
::method init
  expose unit load active sub description
  use strict arg unit, load, active, sub, description
::method unit
  expose unit
  return unit
::method load
  expose load
  return load
::method active
  expose active
  return active
::method sub
  expose sub
  return sub
::method description
  expose description
  return description
::method identity
  expose unit
  return 'unit:'unit
::method fields
  return .Array~of('unit', 'load', 'active', 'sub', 'description')

/* --------------------------------------------------------------- MU audit -- */
/* The estate's MU audit (NewShellMuAudit.cls in /opt/mu-tools, or
   MU_TOOLS_DIR), loaded when first used: newshell does not ship it. */
::class MuAuditor public inherit ShellObject
::constant SHELL_HELP "audit~findings: what is on this MU beyond its contract (verdict EXTRA or FORBIDDEN, kind process/listen/login/unit/package, item, where it belongs; INVOKER marks a process that is only this audit's own caller, such as sudo, and does not count). audit~thin is 1 when nothing counts. audit~contract is the contract file. Read-only."
::method sample class
  use strict arg contract
  return self~new(contract, .true)
::method init
  expose contract findings error
  use strict arg contract, lazy = .false
  findings = .nil; error = ''
::method contract
  expose contract
  return contract
::method load private
  expose contract findings error
  if findings \== .nil then return
  findings = .Array~new
  dir = muToolsDir()
  file = dir'/src/NewShellMuAudit.cls'
  if \.File~new(file)~isFile then do; error = 'the MU audit is not installed:' file 'is missing'; return; end
  if \.File~new(contract)~isFile then do; error = 'no contract file' contract; return; end
  signal on syntax name failed
  pkg = .context~package~loadPackage(file)
  cContract = pkg~findClass('MUCONTRACT'); cInventory = pkg~findClass('MUINVENTORY'); cAudit = pkg~findClass('MUAUDIT')
  .NewshellLog~event('AUDIT against' contract)
  list = cAudit~new(cContract~new(contract))~check(cInventory~fromHost)
  signal off syntax
  -- the audit reads every process, so it also sees whoever invoked it (sudo,
  -- the ssh session's shell). A process finding whose every process is an
  -- ancestor of this audit is marked INVOKER: it is the caller, not something
  -- resident on the MU. If any other process has that name, it stays EXTRA.
  tree = processTree()
  do f over list
    verdict = f~verdict; belongs = f~belongs
    if f~kind == 'process', tree~ancestors~hasIndex(f~item), \tree~others~hasIndex(f~item) then do
      verdict = 'INVOKER'
      belongs = 'only this audit''s own caller (an ancestor of the audit process): not resident on the MU'
    end
    findings~append(.MuFindingRow~new(verdict, f~kind, f~item, belongs))
  end
  .NewshellLog~event('AUDIT' findings~items 'finding(s),' self~invokerOnly 'of them only the invoker')
  return
failed:
  error = 'the MU audit failed:' condition('O')~message
::method findings
  expose findings
  self~load
  return .ShellCollection~new(findings~copy)
::method thin
  expose error
  self~load
  return error == '' & self~findingCount = 0
/* Findings that count: everything except the audit's own invoker. */
::method findingCount
  expose findings
  self~load
  n = 0
  do f over findings; if f~verdict \== 'INVOKER' then n += 1; end
  return n
::method invokerOnly
  expose findings
  self~load
  n = 0
  do f over findings; if f~verdict == 'INVOKER' then n += 1; end
  return n
::method error
  expose error
  self~load
  return error
::method fields
  return .Array~of('contract', 'thin', 'findingCount', 'invokerOnly', 'error')
::method relatedSamples
  return .Array~of(.Array~of('each audit~findings item', .MuFindingRow~new('EXTRA', 'process', 'example', 'its own MI')))

::class MuFindingRow public inherit ShellObject
::method init
  expose verdict kind item belongs
  use strict arg verdict, kind, item, belongs
::method verdict
  expose verdict
  return verdict
::method kind
  expose kind
  return kind
::method item
  expose item
  return item
::method belongs
  expose belongs
  return belongs
::method fields
  return .Array~of('verdict', 'kind', 'item', 'belongs')

/* ------------------------------------------------------------------ xtpd -- */
/* The node's XTP network service daemon (oorexx_xtpd), as the cats kit
   installs it: /opt/xtpd, config /etc/xtpd/xtpd.conf, socket /run/xtpd. */
::class Xtpd public inherit ShellObject
::constant SHELL_HELP "x~running (1 when an xtpd process is up), x~pids, x~socketPresent, x~config (path), x~listens (listen lines of the config), x~logTail(n). x~bringUp(configPath) and x~bringDown are PROTECTED: the policy decides, and on cats1 it refuses until Tom allows it."
::method init
  expose home config
  use strict arg home = '/opt/xtpd', config = '/etc/xtpd/xtpd.conf'
::method home
  expose home
  return home
::method config
  expose config
  return config
::method installed
  expose home
  return .File~new(home'/bin/xtpd.rex')~isFile
::method pids
  list = .Array~new
  procs = .File~new('/proc')~listFiles
  if procs == .nil then return list
  do f over procs
    if \f~name~datatype('W') then iterate
    cmd = cmdlineOf(f~name)      -- read here, never exposed: a command line can carry secrets
    if cmd~pos('/xtpd.rex') > 0 then list~append(f~name)
  end
  return list
::method running
  return self~pids~items > 0
::method socketPath
  expose config
  path = '/run/xtpd/xtpd.sock'
  do l over readLines(config)
    if l~word(1) == 'socket' then path = l~word(2)
  end
  return path
::method socketPresent
  return .File~new(self~socketPath)~exists
::method listens
  expose config
  list = .Array~new
  do l over readLines(config)
    if l~word(1) == 'listen' then list~append(l~subword(2))
  end
  return list
::method logPath
  expose config
  path = '/var/log/xtpd.log'
  do l over readLines(config)
    if l~word(1) == 'log' then path = l~word(2)
  end
  return path
::method logTail
  use strict arg n = 20
  lines = readLines(self~logPath)
  if lines~items <= n then return lines
  return lines~section(lines~items - n + 1)
::method fields
  return .Array~of('installed', 'running', 'pids', 'socketPresent', 'config', 'listens')
::method identity
  expose home
  return 'xtpd:'home

::method bringUp protected
  expose home
  use strict arg configPath
  if \self~installed then raise syntax 93.900 array ('xtpd is not installed under' home)
  if self~running then raise syntax 93.900 array ('xtpd is already running:' self~pids~makeString('L', ' '))
  if \.File~new(configPath)~isFile then raise syntax 93.900 array ('No config' configPath)
  .File~new('/run/xtpd')~makeDir
  rexx = whichProgram('rexx')
  spec = .ProcessSpec~new(.Array~of(home'/bin/xtpd-env', rexx, home'/bin/xtpd.rex', configPath))
  spec~detach = .true; spec~processGroup = .true
  spec~stdoutPolicy = 'DISCARD'; spec~stderrPolicy = 'DISCARD'
  x = .ProcessRunner~new~run(spec)
  if x~failedToStart then raise syntax 93.900 array ('xtpd did not start:' x~errorMessage)
  .NewshellLog~event('XTPD started, pid' x~pid', config' configPath)
  call SysSleep 1
  return self
::method bringDown protected
  list = self~pids
  if list~items = 0 then return self
  r = .ProcessRunner~new
  do p over list
    r~signal(p, 15)
    .NewshellLog~event('XTPD SIGTERM to' p)
  end
  do 30 while self~running; call SysSleep 0.5; end
  return self
::method authorityPath
  expose config
  use strict arg name, args
  if name~upper == 'BRINGUP', args~items >= 1 then return qualify(args[1])
  return config

/* -------------------------------------------------------------- helpers -- */
::routine muToolsDir public
  d = value('MU_TOOLS_DIR',, 'ENVIRONMENT')
  if d == '' then d = '/opt/mu-tools'
  return d

/* systemctl's lines, or a String saying why it could not answer */
::routine systemctl
  use strict arg args
  prog = value('NEWSHELL_SYSTEMCTL',, 'ENVIRONMENT')
  if prog == '' then prog = whichProgram('systemctl')
  if prog == '' then return 'systemctl is not installed'
  argv = .Array~of(prog)
  do a over args; argv~append(a); end
  x = runArgv(argv)
  if x == .nil then return 'systemctl could not be started'
  if x~exitCode \= 0 then return 'systemctl exit' x~exitCode':' x~stderr~string~strip~left(120)
  text = x~stdout~string
  if text == '' then return .Array~new
  return text~makeArray('0a'x)

/* Process names (as /proc/PID/stat gives them) of this process's ancestors,
   and of every other user-space process. */
::routine processTree public
  parents = .Directory~new; names = .Directory~new
  list = .File~new('/proc')~list
  if list \== .nil then do pid over list
    if \pid~datatype('W') then iterate
    line = readOne('/proc/'pid'/stat')
    if line == .nil then iterate
    openAt = line~pos('('); closeAt = line~lastPos(')')
    if openAt = 0 | closeAt = 0 then iterate
    names[pid] = line~substr(openAt + 1, closeAt - openAt - 1)
    parse value line~substr(closeAt + 1) with . ppid .
    parents[pid] = ppid
  end
  me = readOne('/proc/self/stat')~word(1)
  chain = .Set~new
  p = me
  do 64 while p \== '' & p \== '0'
    chain~put(p)
    p = parents[p]
    if p == .nil then leave
  end
  ancestors = .Set~new; others = .Set~new
  do pid over names~allIndexes
    if pid = 2 | parents[pid] = 2 then iterate          -- kernel threads
    if chain~hasIndex(pid) then ancestors~put(names[pid])
    else others~put(names[pid])
  end
  t = .Directory~new
  t['ANCESTORS'] = ancestors; t['OTHERS'] = others
  return t

::routine cmdlineOf
  use strict arg pid
  s = .Stream~new('/proc/'pid'/cmdline')
  if s~open('READ') \= 'READY:' then return ''
  text = s~charIn(1, 4096)
  s~close
  if text == '' then return ''
  return text~translate(' ', '00'x)
