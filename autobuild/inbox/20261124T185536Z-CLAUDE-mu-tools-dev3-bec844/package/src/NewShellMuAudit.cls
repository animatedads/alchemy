/* NewShellMuAudit.cls - how fat is this MU?
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  23 Nov 2026.
 * Target: ooRexx 5.3.0 trunk.
 *
 * An MU runs MIs, carries XTP, enforces compiled per-box tables, attests and
 * reports.  Everything else on an MU is drift: a service that should be in an
 * MI.  MuInventory reads a live host or a recording; MuAudit compares it with
 * an MuContract and returns findings, each saying where the thing belongs.
 */

::class MuContract public
::attribute processes get
::attribute listens get
::attribute logins get
::attribute forbidden get
::attribute units get
::attribute exempt get
::attribute witnesses get
::attribute execDirs get       -- dev3: directories whose executables are checked; empty = no exec check
::attribute execs get          -- dev3: executables allowed by name
::attribute execPackages get   -- dev3: packages whose executables are all allowed
::attribute execForbidden get  -- dev3: (category, name) pairs; beats any allow
::attribute watchDirs get      -- dev3: trees in which every file must belong to a package or a witness
::attribute fileAllowed get    -- dev3: path prefixes allowed without a package
::method init
  expose processes listens logins forbidden units exempt witnesses execDirs execs execPackages execForbidden watchDirs fileAllowed
  use strict arg path
  execDirs = .array~new
  execs = .array~new
  execPackages = .array~new
  execForbidden = .array~new
  watchDirs = .array~new
  fileAllowed = .array~new
  processes = .array~new
  listens = .array~new
  logins = .array~new
  forbidden = .array~new
  units = .array~new
  exempt = .array~new
  witnesses = .directory~new
  s = .stream~new(path)
  lines = s~arrayIn
  s~close
  do line over lines
    line = line~strip
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    /* allow KIND ITEMS... | witness text  (the witness is kept for the report) */
    parse var line verb kind rest '|' witnessText
    rest = rest~strip
    witnessText = witnessText~strip
    select
      when verb == 'allow' & kind == 'process' then call addAllowed processes, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'listen' then call addAllowed listens, .array~of(rest~space), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'login' then call addAllowed logins, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'unit' then call addAllowed units, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'package' then call addAllowed exempt, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'check' & kind == 'exec' then call addAllowed execDirs, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'exec' then call addAllowed execs, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'allow' & kind == 'exec-package' then call addAllowed execPackages, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'watch' then call addAllowed watchDirs, (kind rest)~space~makeArray(' '), 'watch', witnessText, witnesses
      when verb == 'allow' & kind == 'file' then call addAllowed fileAllowed, rest~makeArray(' '), kind, witnessText, witnesses
      when verb == 'forbid' & kind == 'exec' then do
        parse var rest category names
        do n over names~makeArray(' ')
          execForbidden~append(.array~of(category, n))
        end
      end
      when verb == 'forbid' & kind == 'package' then do
        parse var rest category patterns
        do p over patterns~makeArray(' ')
          forbidden~append(.array~of(category, p))
        end
      end
      otherwise throw user badContract description ('cannot read contract line:' line)
    end
  end
::method module_version
  return '0.1-dev3'
::method module_lastChanged
  return '2026-11-24'

/* What is on an MU: processes, listening sockets, login accounts, packages,
   and units enabled to start at boot. */
::class MuInventory public
::attribute processes get
::attribute listens get
::attribute logins get
::attribute packages get
::attribute units get
::attribute source get
::attribute execs get        -- dev3: (package, name) pairs; package '' when no package owns it
::attribute essential get    -- dev3: names of installed packages marked Essential
::attribute unowned get      -- dev3: files in watched trees that no package owns
::method init
  expose processes listens logins packages units source execs essential unowned
  use strict arg source
  execs = .array~new
  essential = .array~new
  unowned = .array~new
  processes = .array~new
  listens = .array~new
  logins = .array~new
  packages = .array~new
  units = .array~new
::method add
  expose processes listens logins packages units execs essential unowned
  use strict arg kind, value
  select
    when kind == 'exec' then do
      parse var value pkg name
      if pkg == '-' then pkg = ''
      execs~append(.array~of(pkg, name~strip))
    end
    when kind == 'essential' then do
      if \essential~hasItem(value) then essential~append(value)
    end
    when kind == 'unowned' then unowned~append(value)
    when kind == 'process' then do
      if \processes~hasItem(value) then processes~append(value)
    end
    when kind == 'listen' then do
      if \listens~hasItem(value) then listens~append(value)
    end
    when kind == 'login' then do
      if \logins~hasItem(value) then logins~append(value)
    end
    when kind == 'package' then packages~append(value)
    when kind == 'unit' then do
      if \units~hasItem(value) then units~append(value)
    end
    otherwise throw user badRecording description ('unknown inventory kind' kind)
  end
  return self
/* A recording: one "kind value" per line.  The same format a capture on a
 * real MU writes, so a node can be audited without ooRexx installed on it. */
::method fromRecording class
  use strict arg path
  inv = self~new('recording' path)
  s = .stream~new(path)
  lines = s~arrayIn
  s~close
  do line over lines
    line = line~strip
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    parse var line kind value
    inv~add(kind, value~strip)
  end
  return inv
::method fromHost class
  use strict arg execDirs = (.array~new), watchDirs = (.array~new)
  inv = self~new('live host')
  .NewShellLog~progress('reading processes from /proc')
  /* /proc, not ps: the audit must not see its own child processes */
  do entry over .File~new('/proc')~list
    if \entry~dataType('W') then iterate
    statPath = '/proc/'entry'/stat'
    if \.File~new(statPath)~exists then iterate
    s = .stream~new(statPath)
    statLine = s~lineIn
    s~close
    /* pid (comm) state ppid ...: comm may hold spaces, so cut at the last ')' */
    openAt = statLine~pos('(')
    closeAt = statLine~lastPos(')')
    if openAt = 0 then iterate
    if closeAt = 0 then iterate
    comm = statLine~substr(openAt + 1, closeAt - openAt - 1)
    parse value statLine~substr(closeAt + 1) with . ppid .
    /* kernel threads are kthreadd (pid 2) and its children */
    if entry = 2 then iterate
    if ppid = 2 then iterate
    inv~add('process', comm)
  end
  .NewShellLog~progress('reading listening sockets from /proc/net')
  do proto over .array~of('tcp', 'tcp6', 'udp', 'udp6')
    if \.File~new('/proc/net/'proto)~exists then iterate
    s = .stream~new('/proc/net/'proto)
    rows = s~arrayIn
    s~close
    do row over rows
      parse var row slot local remote state .
      if slot == 'sl' then iterate
      wantState = '0A'
      if proto~left(3) == 'udp' then wantState = '07'
      if state \== wantState then iterate
      port = x2d(local~substr(local~pos(':') + 1))
      inv~add('listen', proto~strip('T', '6') port)
    end
  end
  .NewShellLog~progress('reading login accounts')
  pw = .HostCommand~run('getent passwd')
  do line over pw~out
    parse var line name ':' . ':' . ':' . ':' . ':' . ':' shell
    if shell~endsWith('nologin') then iterate
    if shell~endsWith('false') then iterate
    /* sync, shutdown and halt have a program, not a shell, as their "shell" */
    if wordpos(filespec('name', shell), 'sync shutdown halt') > 0 then iterate
    if shell == '' then iterate
    inv~add('login', name)
  end
  .NewShellLog~progress('reading installed packages')
  pk = .HostCommand~run("dpkg-query -W -f='${Package}\n'")
  do line over pk~out
    inv~add('package', line~strip)
  end
  .NewShellLog~progress('reading units enabled at boot')
  un = .HostCommand~run('systemctl list-unit-files --state=enabled --no-pager --no-legend')
  do line over un~out
    parse var line unitName .
    if unitName \== '' then inv~add('unit', unitName)
  end
  inv~addFiles(execDirs, watchDirs, '')
  return inv

/* dev3: executables and files, read from the package database's own files
 * (/var/lib/dpkg), not from dpkg: root is '' on a host and a directory in tests. */
::method addFiles
  use strict arg execDirs, watchDirs, root
  if execDirs~items = 0, watchDirs~items = 0 then return self
  .NewShellLog~progress('reading the package database')
  index = .DpkgIndex~new(root)
  do p over index~essentialPackages
    self~add('essential', p)
  end
  seen = .set~new
  do d over execDirs
    .NewShellLog~progress('reading executables in' d)
    call SysFileTree root || d'/*', 'found.', 'F'
    do i = 1 to found.0
      parse var found.i . . . attrs fullPath
      fullPath = fullPath~strip
      if attrs~pos('x') = 0 then iterate
      name = filespec('name', fullPath)
      if seen~hasIndex(name) then iterate
      seen~put(name)
      pkg = index~owner(d'/'name)
      if pkg == '' then pkg = '-'
      self~add('exec', pkg name)
    end
  end
  do d over watchDirs
    .NewShellLog~progress('looking for files no package owns in' d)
    do f over walkFiles(root || d)
      path = f~substr(root~length + 1)
      if index~owner(path) == '' then self~add('unowned', path)
    end
  end
  return self
::method toRecording
  expose processes listens logins packages units source execs essential unowned
  use strict arg path
  s = .stream~new(path)
  s~open('write replace')
  s~lineout('# MU inventory recording from' source 'at' date('S') time())
  do p over processes
    s~lineout('process' p)
  end
  do l over listens
    s~lineout('listen' l)
  end
  do u over logins
    s~lineout('login' u)
  end
  do k over packages
    s~lineout('package' k)
  end
  do n over units
    s~lineout('unit' n)
  end
  do e over essential
    s~lineout('essential' e)
  end
  do x over execs
    pkg = x[1]
    if pkg == '' then pkg = '-'
    s~lineout('exec' pkg x[2])
  end
  do f over unowned
    s~lineout('unowned' f)
  end
  s~close
  return path
::method module_version
  return '0.1-dev3'
::method module_lastChanged
  return '2026-11-24'

::class MuFinding public
::attribute kind get
::attribute item get
::attribute verdict get
::attribute belongs get
::method init
  expose kind item verdict belongs
  use strict arg kind, item, verdict, belongs
::method string
  expose kind item verdict belongs
  -- dev3: a path longer than the column is kept whole, not cut
  if item~length < 28 then return left(verdict, 9) left(kind, 8) left(item, 28) belongs
  return left(verdict, 9) left(kind, 8) item belongs
::method module_version
  return '0.1-dev3'
::method module_lastChanged
  return '2026-11-24'

::class MuAudit public
::method init
  expose contract
  use strict arg contract
::method check
  expose contract
  use strict arg inventory
  findings = .array~new
  do p over inventory~processes
    if \contract~processes~hasItem(p) then findings~append(.MuFinding~new('process', p, 'EXTRA', 'no witness in the MU contract: cut it, or move it to an MI'))
  end
  do l over inventory~listens
    if \contract~listens~hasItem(l) then findings~append(.MuFinding~new('listen', l, 'EXTRA', 'a listening service on the MU: put it behind an XTP named service in an MI'))
  end
  do u over inventory~logins
    if \contract~logins~hasItem(u) then findings~append(.MuFinding~new('login', u, 'EXTRA', 'an account on the iron: give the service its own principal in its MI'))
  end
  do n over inventory~units
    if \contract~units~hasItem(n) then findings~append(.MuFinding~new('unit', n, 'EXTRA', 'starts at boot with no witness: disable or mask it'))
  end
  do pkg over inventory~packages
    category = self~forbiddenCategory(pkg)
    if category \== '' then findings~append(.MuFinding~new('package', pkg, 'FORBIDDEN', self~home(category)))
  end
  if contract~execDirs~items > 0 then self~checkExecs(inventory, findings)
  do f over inventory~unowned
    if \underAny(f, contract~fileAllowed) then findings~append(.MuFinding~new('file', f, 'UNOWNED', 'no package owns it and it has no witness: remove it, or write its witness'))
  end
  .NewShellLog~progress(findings~items 'findings for' inventory~source)
  return findings
/* dev3: an executable needs a witness, by name or by its package; a forbidden
   name is reported even when its package is allowed.  The ones with no witness
   are grouped by package, so the report says what to remove. */
::method checkExecs
  expose contract
  use strict arg inventory, findings
  byPackage = .table~new
  order = .array~new
  do x over inventory~execs
    pkg = x[1]
    name = x[2]
    category = ''
    do rule over contract~execForbidden
      if rule[2] == name then category = rule[1]
    end
    if category \== '' then do
      text = self~home(category)
      if inventory~essential~hasItem(pkg) then text = text '(in' pkg', an Essential package: only the stripped image removes it)'
      else if pkg \== '' then text = text '(package' pkg')'
      findings~append(.MuFinding~new('exec', name, 'FORBIDDEN', text))
      iterate
    end
    if contract~execs~hasItem(name) then iterate
    if pkg \== '', contract~execPackages~hasItem(pkg) then iterate
    if \byPackage~hasIndex(pkg) then do
      byPackage[pkg] = .array~new
      order~append(pkg)
    end
    byPackage[pkg]~append(name)
  end
  do pkg over order~sort                       -- by package, so two runs compare line by line
    names = byPackage[pkg]~sort
    shown = names~section(1, min(names~items, 8))~makeString('L', ' ')
    if names~items > 8 then shown = shown '...'
    if pkg == '' then label = '(no package)'
    else label = pkg
    text = names~items 'with no witness:' shown
    if inventory~essential~hasItem(pkg) then text = text '[Essential: only the stripped image removes it]'
    findings~append(.MuFinding~new('exec', label, 'EXTRA', text))
  end
  return findings

::method forbiddenCategory
  expose contract
  use strict arg pkg
  /* an explicit "allow package" beats a forbid pattern (gcc-12-base is a runtime, not a compiler) */
  if contract~exempt~hasItem(pkg) then return ''
  do rule over contract~forbidden
    pattern = rule[2]
    if pattern~endsWith('*') then do
      if pkg~startsWith(pattern~left(pattern~length - 1)) then return rule[1]
    end
    else if pkg == pattern then return rule[1]
  end
  return ''
::method home
  use strict arg category
  select
    when category == 'workload' then return 'workload: its own MI'
    when category == 'platform' then return 'platform service: a system MI, reached as an XTP named service'
    when category == 'build' then return 'build tooling: a build MI; MIs receive finished images'
    when category == 'container' then return 'a second box runtime: the MU already runs MIs'
    when category == 'toolkit' then return "an intruder's toolkit: no witness on an MU"
    when category == 'debug' then return 'a debugger or tracer: no witness on an MU'
    when category == 'editor' then return 'an editor: an MU is changed by kits and policy, not by hand'
    when category == 'bus' then return 'a D-Bus poking tool: nothing on an MU is driven over the bus by hand'
    when category == 'personality' then return 'changes the kernel personality (setarch -R turns off address randomisation)'
    when category == 'recorder' then return 'records or replays a terminal: no human sessions on an MU'
    when category == 'dumper' then return 'a byte dumper: no witness on an MU'
    when category == 'packaging' then return 'a second package system: an MU gets its software from its image'
    otherwise return 'not on an MU'
  end
::method module_version
  return '0.1-dev3'
::method module_lastChanged
  return '2026-11-24'

/* dev3: which package owns a path, read from /var/lib/dpkg itself:
 * info/PACKAGE.list for files, status for Essential, alternatives/NAME for the links
 * update-alternatives makes.  Ubuntu 22.04 merges /bin into /usr/bin, and its
 * packages still list /bin/x: both spellings are looked up. */
::class DpkgIndex public
::attribute essentialPackages get
::method init
  expose owners essentialPackages
  use strict arg root = ''
  owners = .directory~new
  essentialPackages = .array~new
  db = root'/var/lib/dpkg'
  call SysFileTree db'/info/*.list', 'lists.', 'FO'
  do i = 1 to lists.0
    pkg = filespec('name', lists.i)
    pkg = pkg~left(pkg~length - 5)
    parse var pkg pkg ':' .                       -- libc6:amd64.list is libc6
    s = .stream~new(lists.i)
    do line over s~arrayIn
      if line \== '' then owners[line] = pkg
    end
    s~close
  end
  call SysFileTree db'/alternatives/*', 'alts.', 'FO'
  do i = 1 to alts.0
    s = .stream~new(alts.i)
    do line over s~arrayIn
      -- a target is usually listed by its package (perhaps as /bin/x); only the rest are links
      if line~left(1) == '/', self~owner(line) == '' then owners[line] = 'alternatives'
    end
    s~close
  end
  if .File~new(db'/status')~exists then do
    s = .stream~new(db'/status')
    current = ''
    do line over s~arrayIn
      if line~startsWith('Package: ') then current = line~substr(10)~strip
      if line == 'Essential: yes', current \== '' then essentialPackages~append(current)
    end
    s~close
  end
::method owner
  expose owners
  use strict arg path
  do spelling over mergedUsrSpellings(path)
    if owners~hasIndex(spelling) then return owners[spelling]
  end
  return ''
::method module_version
  return '0.1-dev3'
::method module_lastChanged
  return '2026-11-24'

::routine mergedUsrSpellings
  use strict arg path
  out = .array~of(path)
  do pair over .array~of('/usr/bin/ /bin/', '/usr/sbin/ /sbin/', '/usr/lib/ /lib/', '/usr/lib64/ /lib64/')
    parse var pair long short
    if path~startsWith(long) then out~append(short || path~substr(long~length + 1))
    if path~startsWith(short) then out~append(long || path~substr(short~length + 1))
  end
  return out

/* Every file under dir, symbolic links included; a linked directory is not followed.
 * dev3: an empty directory is listed too: /root/snap/lxd/41283 on cats1 held no
 * files, and was still the trace of a snap install. */
::routine walkFiles
  use strict arg dir
  out = .array~new
  pending = .array~of(dir)
  do while pending~items > 0
    here = pending[1]
    pending~delete(1)
    call SysFileTree here'/*', 'dirs.', 'DO'
    do i = 1 to dirs.0
      if SysIsFileLink(dirs.i) then out~append(dirs.i)
      else pending~append(dirs.i)
    end
    call SysFileTree here'/*', 'files.', 'FO'
    do i = 1 to files.0
      out~append(files.i)
    end
    if dirs.0 = 0, files.0 = 0, here \== dir then out~append(here)
  end
  return out

/* Is path one of the prefixes, or under one (on a / boundary)? */
::routine underAny
  use strict arg path, prefixes
  do p over prefixes
    if path == p then return .true
    if path~startsWith(p~strip('T', '/')'/') then return .true
  end
  return .false

/* Append allowed items and remember the witness each one was allowed for. */
::routine addAllowed
  use strict arg target, items, kind, witnessText, witnesses
  do item over items
    if item == '' then iterate
    if \target~hasItem(item) then target~append(item)
    if witnessText \== '' then witnesses[kind item] = witnessText
  end

::requires 'NewShellIdentity.cls'
