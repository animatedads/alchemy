/* CloudCtl.cls -- Cloud Control core: configuration, requests, rules, plan/apply, execution, ledger, logging.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 * Replaces the bash cloudctl.sh (workstation) and alchemy_cloud_control dev4 adapters/cloudctl.sh (Codex).
 *
 * Authority (unchanged from dev4 docs/AUTHORITY.md): Cloud Control owns provider mutation syntax and
 * provider/account constraints.  It does not own user intent, allocator identity, XTP topology or credentials.
 *
 * Classes
 *   CloudCtlConfig      etc/cloudctl.conf, etc/accounts/<name>.account, etc/machines/<name>.machine
 *   CloudCtlRequest     one parsed operation: provider, noun (machine|firewall), verb, options, apply flag
 *   CloudCtlRule        one validation rule (level, name, description, routine)
 *   CloudCtlRules       registered rules; core rules plus each provider plug-in's required-field rules
 *   CloudCtlFindings    STOP / WARN / INFO buckets
 *   CloudCommand        one provider CLI invocation: argv array, display text, mutates flag
 *   CloudCtlExec        runs a CloudCommand: argv shell-quoted, output to files, rc
 *   CloudCtlLedger      ops-YYYYMM.tsv (every operation) and machines.tsv (lifecycle events -> machine-hours)
 *   CloudProviderPlugin provider plug-in base; plug-ins live in src/providers/ and register in cloudctl.conf
 *   CloudCtlEvent / CloudCtlFileTarget   oorexx_logging payload and daily events file
 *   CloudCtlSession     resolve -> rules -> plan -> (apply) -> ledger -> result
 *
 * House rules: no private methods; expose first; one call's arguments on one line; DO ... OVER; rules in buckets.
 */

::routine ccQuote public
  use strict arg s
  return "'" || s~changeStr("'", "'\''") || "'"

::routine ccUtc public
  return .DateTime~new~toTimeZone(0)~isoDate~left(19)'Z'

/* A registry value for display: .nil (absent) -> ''. */
::routine ccStr public
  use strict arg v
  if v~isNil then return ''
  return v

/* The last path segment of a provider resource id or URL. */
::routine ccLastSegment public
  use strict arg id
  id=ccStr(id)
  return id~substr(id~lastPos('/')+1)

::routine ccReadProps public
  use strict arg file
  d=.directory~new
  if \SysFileExists(file) then return d
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    l=s~linein~strip
    if l='' then iterate
    if l~left(1)='#' then iterate
    parse var l k '=' v
    k=k~strip~lower
    if k='' then iterate
    d[k]=v~strip
  end
  s~close
  return d

::routine ccReadLines public
  use strict arg file
  a=.array~new
  if \SysFileExists(file) then return a
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    a~append(s~linein)
  end
  s~close
  return a

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudCtlConfig public
::attribute home     get        /* the cloudctl directory */
::attribute base     get        /* $AUTOBUILD: the alchemy-autobuild directory */
::attribute settings get
::method init
  expose home base settings
  use strict arg home, base
  settings=ccReadProps(home'/etc/cloudctl.conf')
::method setting
  expose settings
  use strict arg key, default=''
  v=settings[key~lower]
  if v=.nil then return default
  return v
::method expand
  expose home base
  use strict arg text
  return text~changeStr('$AUTOBUILD', base)~changeStr('$CLOUDCTL', home)~changeStr('$HOME', value('HOME',,'ENVIRONMENT'))
::method path
  use strict arg key, default
  return self~expand(self~setting(key, default))
/* Named accounts: provider, the provider-native account selector, defaults (project, region, ...). */
::method account
  expose home
  use strict arg name
  if name='' then return .nil
  if name~verify('abcdefghijklmnopqrstuvwxyz0123456789-_.')>0 then return .nil
  f=home'/etc/accounts/'name'.account'
  if \SysFileExists(f) then return .nil
  p=ccReadProps(f)
  p['name']=name
  return p
::method accountNames
  expose home
  return self~namesIn(home'/etc/accounts', '.account')
/* Machine registry: a stable name -> provider, account, handle, zone/region, project, firewall scope. */
::method machine
  expose home
  use strict arg name
  if name='' then return .nil
  if name~verify('abcdefghijklmnopqrstuvwxyz0123456789-_.')>0 then return .nil
  f=home'/etc/machines/'name'.machine'
  if \SysFileExists(f) then return .nil
  p=ccReadProps(f)
  p['name']=name
  return p
::method machineNames
  expose home
  return self~namesIn(home'/etc/machines', '.machine')
::method namesIn
  use strict arg dir, suffix
  call SysFileTree dir'/*'suffix, 'f.', 'FO'
  a=.array~new
  do i=1 to f.0
    a~append(filespec('N', f.i)~changeStr(suffix, ''))
  end
  return a~sortWith(.CaselessComparator~new)

/* ------------------------------------------------------------------------------------------------------------ */
/* One operation.  options: lower-case option names without dashes -> value (repeatable options -> array). */
::class CloudCtlRequest public
::attribute provider
::attribute noun
::attribute verb
::attribute options
::attribute apply
::attribute confirm
::attribute jobId
::attribute machine          /* the machine registry entry when --machine named one, else .nil */
::attribute account          /* the account entry, else .nil */
::attribute addOnly          /* reconcile adds missing sources and removes none (--add-only, 26 Nov 2026) */
::attribute notes            /* .array of lines a plug-in wants the operator to see in the plan (kept sources...) */
::method init
  expose options apply confirm jobId machine account addOnly notes
  options=.directory~new
  apply=.false; confirm=''; jobId=''; machine=.nil; account=.nil; addOnly=.false; notes=.array~new
::method opt
  expose options
  use strict arg name, default=''
  v=options[name~lower]
  if v=.nil then return default
  if v~isA(.array) then return v[v~items]
  return v
::method opts
  expose options
  use strict arg name
  v=options[name~lower]
  if v=.nil then return .array~new
  if v~isA(.array) then return v
  return .array~of(v)
::method has
  expose options
  use strict arg name
  return options~hasIndex(name~lower)
::method add
  expose options
  use strict arg name, value
  k=name~lower
  if \options~hasIndex(k) then do
    options[k]=value
    return
  end
  prev=options[k]
  if \prev~isA(.array) then options[k]=.array~of(prev)
  options[k]~append(value)
::method operation
  expose noun verb
  return noun verb
/* Copy registry entries (machine or account file) that the plug-in understands into options not already given. */
::method fillFrom
  use strict arg entry, plugin
  if plugin=.nil then return
  known=plugin~optionNames
  do k over entry~allIndexes
    if \known~hasItem(k) then iterate
    if \self~has(k) then self~add(k, entry[k])
  end
::method mutates
  expose noun verb
  if noun='machine', wordpos(verb, 'create start stop reboot destroy')>0 then return .true
  if noun='firewall', wordpos(verb, 'allow revoke reconcile')>0 then return .true
  return .false

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudCtlFindings public
::method init
  expose buckets
  buckets=.directory~new
  do level over .array~of('STOP', 'WARN', 'INFO')
    buckets[level]=.array~new
  end
::method add
  expose buckets
  use strict arg level, rule, text
  buckets[level]~append(left(rule,14) text)
::method bucket
  expose buckets
  use strict arg level
  return buckets[level]
::method count
  expose buckets
  use strict arg level
  return buckets[level]~items
::method absorb
  expose buckets
  use strict arg other
  do level over .array~of('STOP', 'WARN', 'INFO')
    buckets[level]~appendAll(other~bucket(level))
  end
::method lines
  expose buckets
  a=.array~new
  do level over .array~of('STOP', 'WARN', 'INFO')
    do f over buckets[level]
      a~append(left(level,4) f)
    end
  end
  return a

::class CloudCtlRule public
::attribute level       get
::attribute name        get
::attribute description get
::method init
  expose level name description check
  use strict arg level, name, description, check
::method apply
  expose check
  use strict arg request, context
  return check~call(request, context)

::class CloudCtlRules public
::method init
  expose rules
  rules=.array~new
::method add
  expose rules
  use strict arg rule
  rules~append(rule)
  return self
::method rules
  expose rules
  return rules
::method check
  expose rules
  use strict arg request, context, findings
  do r over rules
    text=r~apply(request, context)
    if text<>'' then findings~add(r~level, r~name, text)
  end
  return findings
/* Core rules, the same for every provider.  Each plug-in adds its own (required fields, value syntax). */
::method standard class
  r=self~new
  r~add(.CloudCtlRule~new('STOP', 'provider', 'the provider has a registered plug-in', .routines~ruleProvider))
  r~add(.CloudCtlRule~new('STOP', 'operation', 'the plug-in supports the operation', .routines~ruleOperation))
  r~add(.CloudCtlRule~new('STOP', 'kit', 'the provider''s command-line tool is installed', .routines~ruleKit))
  r~add(.CloudCtlRule~new('STOP', 'secret', 'no option carries a secret value', .routines~ruleSecret))
  r~add(.CloudCtlRule~new('STOP', 'account', 'a named account exists and belongs to the provider', .routines~ruleAccount))
  r~add(.CloudCtlRule~new('STOP', 'machine', 'a named machine exists and belongs to the provider', .routines~ruleMachine))
  r~add(.CloudCtlRule~new('STOP', 'confirm', 'destroy is confirmed with the exact machine name', .routines~ruleConfirm))
  r~add(.CloudCtlRule~new('STOP', 'cidr', 'every source is an IPv4 CIDR', .routines~ruleCidr))
  r~add(.CloudCtlRule~new('STOP', 'protocol', 'protocol is tcp, udp, icmp, all or an IP protocol number', .routines~ruleProtocol))
  r~add(.CloudCtlRule~new('STOP', 'port', 'port is N or N-M within 1-65535', .routines~rulePort))
  r~add(.CloudCtlRule~new('STOP', 'sources', 'reconcile has a non-empty source set', .routines~ruleSources))
  r~add(.CloudCtlRule~new('STOP', 'option', 'every option is one the provider plug-in understands', .routines~ruleKnownOption))
  r~add(.CloudCtlRule~new('STOP', 'tcpudpport', 'tcp and udp firewall changes name a port', .routines~ruleTcpUdpPort))
  r~add(.CloudCtlRule~new('INFO', 'plan', 'mutations are PLAN until --apply', .routines~rulePlan))
  return r

::routine ruleProvider
  use arg q, c
  if c~plugins~plugin(q~provider)=.nil then return 'no plug-in for provider' q~provider
  return ''
/* Kit check: the program the plug-in runs is on PATH, so a missing tool is a STOP with a name, not rc 127. */
::routine ruleKit
  use arg q, c
  p=c~plugins~plugin(q~provider)
  if p=.nil then return ''
  cli=p~cliName
  if cli='' then return ''
  address system 'command -v' cli '>/dev/null 2>&1'
  if rc=0 then return ''
  return cli 'is not installed on this machine'
::routine ruleOperation
  use arg q, c
  p=c~plugins~plugin(q~provider)
  if p=.nil then return ''
  if p~supports(q~noun, q~verb) then return ''
  return q~provider 'does not support' q~noun q~verb
::routine ruleSecret
  use arg q, c
  bad=''
  do k over q~options~allIndexes
    do w over .array~of('secret', 'password', 'passwd', 'token', 'api-key', 'apikey', 'private-key', 'credential', 'access-key', 'client-secret')
      if pos(w, k)>0 then bad=bad k
    end
  end
  if bad<>'' then return 'secret-bearing option(s) refused:'bad
  return ''
::routine ruleAccount
  use arg q, c
  if q~opt('account')='' then return ''
  if q~account=.nil then return 'no account file for' q~opt('account')
  if q~account['provider']<>q~provider then return 'account' q~opt('account') 'belongs to' q~account['provider']
  return ''
::routine ruleMachine
  use arg q, c
  if q~opt('machine')='' then return ''
  if q~machine=.nil then return ''                      /* a raw provider handle is allowed */
  if q~machine['provider']<>q~provider then return 'machine' q~opt('machine') 'is on' q~machine['provider']
  return ''
::routine ruleConfirm
  use arg q, c
  if q~noun q~verb<>'machine destroy' then return ''
  if \q~apply then return ''
  if q~confirm<>q~opt('machine') then return 'destroy needs --confirm' q~opt('machine')
  return ''
::routine ruleCidr
  use arg q, c
  do src over q~opts('source')~copy~~appendAll(q~opts('sources'))
    do one over src~makeArray(',')
      if \ccIsCidr(one) then return 'not an IPv4 CIDR:' one
    end
  end
  return ''
::routine ruleProtocol
  use arg q, c
  p=q~opt('protocol')
  if p='' then return ''
  if wordpos(p~lower, 'tcp udp icmp all')>0 then return ''
  if p~datatype('W') then do
    if p>=0, p<=255 then return ''
  end
  return 'unknown protocol' p
::routine rulePort
  use arg q, c
  p=q~opt('port')
  if p='' then return ''
  parse var p lo '-' hi
  if hi='' then hi=lo
  if \lo~datatype('W') | \hi~datatype('W') then return 'port' p 'is not N or N-M'
  if lo<1 then return 'port' p 'out of range'
  if hi>65535 then return 'port' p 'out of range'
  if lo>hi then return 'port' p 'is reversed'
  return ''
::routine ruleSources
  use arg q, c
  if q~noun q~verb<>'firewall reconcile' then return ''
  n=0
  do src over q~opts('source')~copy~~appendAll(q~opts('sources'))
    do one over src~makeArray(',')
      if one<>'' then n=n+1
    end
  end
  if n=0 then return 'reconcile needs at least one source (an empty set is refused)'
  return ''
::routine ruleKnownOption
  use arg q, c
  p=c~plugins~plugin(q~provider)
  if p=.nil then return ''
  known=p~optionNames~copy
  do k over .array~of('account', 'configuration', 'machine')
    known~append(k)
  end
  bad=''
  do k over q~options~allIndexes
    if \known~hasItem(k) then bad=bad '--'k
  end
  if bad<>'' then return q~provider 'does not understand' bad~strip
  return ''
::routine ruleTcpUdpPort
  use arg q, c
  if q~noun<>'firewall' then return ''
  if wordpos(q~verb, 'reconcile allow')=0 then return ''
  if wordpos(q~opt('protocol')~lower, 'tcp udp')=0 then return ''
  if q~opt('port')='' then return 'firewall' q~verb 'protocol' q~opt('protocol')~lower 'requires --port'
  return ''
::routine rulePlan
  use arg q, c
  if q~mutates, \q~apply then return 'PLAN only: no provider change will be made (add --apply)'
  return ''

/* The reconcile source set: --sources (comma list) and --source, whitespace removed, duplicates dropped,
 * first-seen order kept. */
::routine ccSourceSet public
  use strict arg q
  out=.array~new
  do src over q~opts('sources')~copy~~appendAll(q~opts('source'))
    do one over src~makeArray(',')
      one=one~space(0)
      if one='' then iterate
      if \out~hasItem(one) then out~append(one)
    end
  end
  return out

::routine ccIsCidr public
  use strict arg s
  parse var s a '.' b '.' c '.' d '/' bits
  do o over .array~of(a, b, c, d)
    if \o~datatype('W') then return .false
    if o<0 then return .false
    if o>255 then return .false
  end
  if pos('/', s)=0 then return .true
  if \bits~datatype('W') then return .false
  if bits<0 then return .false
  if bits>32 then return .false
  return .true

/* Why a provider command failed, from its stderr (26 Nov 2026).  A Python CLI (az, gcloud, oci, aws v1) prints a
 * traceback whose first line says nothing and whose last line is the exception, so the last non-blank line is the
 * reason; the first is added when it is not a traceback header.  A read-only HOME (a sandbox) gets a plain hint,
 * because every Python provider CLI writes its own state file there on start. */
::routine ccErrReason public
  use strict arg r
  lines=.array~new
  do l over r~err
    if l~strip<>'' then lines~append(l~strip)
  end
  if lines~items=0 then return ': (nothing on stderr)'
  why=lines[lines~items]~left(240)
  if lines~items>1, \lines[1]~startsWith('Traceback') then why=lines[1]~left(120) '...' why
  if pos('Read-only file system', r~err~makeString('L', ' '))>0 then why=why '-- hint: the provider CLI cannot write its state directory under HOME (a read-only sandbox does this); run cloudctl where HOME is writable'
  return ':' why
/* The last n stderr lines of a failed command, to stderr, so the run log carries the whole cause. */
::routine ccErrTail public
  use strict arg r, n=12
  first=max(1, r~err~items-n+1)
  do i=first to r~err~items
    .error~lineout('cloudctl: | 'r~err[i])
  end

/* ------------------------------------------------------------------------------------------------------------ */
/* One provider CLI invocation.  argv[1] is the program. */
::class CloudCommand public
::attribute argv
::attribute mutates
::attribute purpose
::attribute env             /* .directory of environment variables for this command only (names -> values) */
::method init
  expose argv mutates purpose env
  use strict arg argv, mutates=.false, purpose=''
  env=.directory~new
::method text
  expose argv
  t=''
  do a over argv
    t=t ccQuote(a)
  end
  return t~strip

::class CloudCtlExec public
::attribute workDir
::method init
  expose workDir
  use strict arg workDir
  call SysMkDir workDir                             /* a fresh install has no var/ until something writes there */
/* Runs one command; stdout and stderr to files (no pipes); returns a .directory rc, out (array), err (array). */
::method run
  expose workDir
  use strict arg command
  outF=workDir'/cloudctl.'SysQueryProcess('PID')'.out'
  errF=workDir'/cloudctl.'SysQueryProcess('PID')'.err'
  prefix=''
  do k over command~env~allIndexes
    prefix=prefix k'='ccQuote(command~env[k])
  end
  if prefix<>'' then prefix='env'prefix
  tag='READ  '
  if command~mutates then tag='CHANGE'
  what=command~purpose
  if what<>'' then what=' ('what')'
  shown=command~text
  if \command~mutates, shown~length>160 then shown=shown~left(157)'...'   /* a CHANGE is shown in full */
  .error~lineout('cloudctl: >' tag shown||what)
  t0=.DateTime~new                                  /* not time('R'): the session times the whole run */
  address system prefix command~text '</dev/null >'ccQuote(outF) '2>'ccQuote(errF)
  r=.directory~new
  r~rc=rc
  .error~lineout('cloudctl: < rc='rc format((.DateTime~new-t0)~totalSeconds,,1)'s')
  r~out=ccReadLines(outF)
  r~err=ccReadLines(errF)
  call SysFileDelete outF
  call SysFileDelete errF
  return r

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudCtlLedger public
::attribute dir get
::method init
  expose dir
  use strict arg dir
  call SysMkDir dir
::method opColumns class
  return .array~of('time', 'job_id', 'user', 'provider', 'account', 'operation', 'target', 'mode', 'rc', 'seconds', 'findings')
/* Every operation, PLAN or APPLY, refused or run. */
::method recordOp
  expose dir
  use strict arg fields
  f=dir'/ops-'fields[1]~left(4)fields[1]~substr(6,2)'.tsv'
  if \SysFileExists(f) then call lineout f, .CloudCtlLedger~opColumns~makeString('L', '09'x)
  call lineout f, fields~makeString('L', '09'x)
  call lineout f
::method machineColumns class
  return .array~of('time', 'provider', 'account', 'machine', 'handle', 'event', 'job_id')
/* Machine lifecycle events after a successful APPLY: CREATED, STARTED, STOPPED, REBOOTED, DESTROYED. */
::method recordMachine
  expose dir
  use strict arg fields
  f=dir'/machines.tsv'
  if \SysFileExists(f) then call lineout f, .CloudCtlLedger~machineColumns~makeString('L', '09'x)
  call lineout f, fields~makeString('L', '09'x)
  call lineout f
/* Machine-hours per machine: running intervals between CREATED/STARTED and STOPPED/DESTROYED; an open interval
 * runs to `now`.  Returns .directory machine -> .directory(hours, events, last, state). */
::method machineHours
  expose dir
  use strict arg now
  out=.directory~new
  do l over ccReadLines(dir'/machines.tsv')
    parse var l t '09'x prov '09'x acct '09'x m '09'x h '09'x ev '09'x .
    if t='time' then iterate
    r=out[m]
    if r=.nil then do
      r=.directory~new
      r~hours=0; r~events=0; r~since=''; r~state='?'; r~provider=prov
      out[m]=r
    end
    r~events=r~events+1
    r~last=t ev
    select
      when wordpos(ev, 'CREATED STARTED')>0 then do
        if r~since='' then r~since=t
        r~state='RUNNING'
      end
      when wordpos(ev, 'STOPPED DESTROYED')>0 then do
        if r~since<>'' then r~hours=r~hours+ccHoursBetween(r~since, t)
        r~since=''
        r~state=ev
      end
      when ev='REBOOTED' then r~state='RUNNING'     /* running, but hours count only from CREATED/STARTED */
      otherwise nop
    end
  end
  do m over out~allIndexes
    r=out[m]
    if r~since<>'' then r~hours=r~hours+ccHoursBetween(r~since, now)
  end
  return out

::routine ccHoursBetween public
  use strict arg a, b
  ta=.DateTime~fromIsoDate(a~left(19)'.000000')     /* fromIsoDate needs the microseconds */
  tb=.DateTime~fromIsoDate(b~left(19)'.000000')
  return (tb-ta)~totalSeconds/3600

/* ------------------------------------------------------------------------------------------------------------ */
/* Provider plug-in base.  A plug-in declares its operations and required fields and builds CloudCommands. */
::class CloudProviderPlugin public
::attribute name get
::method init
  expose name
  use strict arg name
::method operations                     /* .array of 'noun verb' strings */
  return .array~new
::method supports
  use strict arg noun, verb
  return self~operations~hasItem(noun verb)
::method required                       /* (noun, verb) -> .array of option names that must be present */
  use strict arg noun, verb
  return .array~new
::method rules                          /* plug-in specific CloudCtlRule objects */
  return .array~new
/* (request, config) -> .array of CloudCommand.  For reconcile a plug-in may first observe (read commands run
 * during PLAN as well) and then return the mutation steps; see observe(). */
::method plan abstract
::method observe                        /* (request, config, exec) -> evidence object or .nil; read-only */
  return .nil
::method optionNames                    /* every option this plug-in understands (besides the core ones) */
  return .array~new
/* Discovery (CloudDiscover.cls).  cliName: the program this plug-in runs, checked before any call ('' = none).
 * discoverNeeds: machine-file fields discovery cannot work without.  discover(q, config, exec, d): read-only
 * calls that find the machine by d~node['address'] and record values and findings in d. */
::method cliName
  return ''
::method discoverNeeds
  return .array~new
::method discover
  use strict arg q, config, exec, d
  d~note('INFO', 'nodiscover', self~name 'has no discovery')
/* Runs a read command and parses its JSON; a failed command is a syntax error carrying the reason. */
::method readJson
  use strict arg exec, argv, what
  r=exec~run(self~read(argv, what))
  if r~rc<>0 then self~failWith(r, what 'failed')
  text=r~out~makeString('L', ' ')
  if text~strip='' then return .array~new
  return .json~new~fromJson(text)
/* The provider handle for --machine: the registry entry's handle, else the value as given. */
::method handle
  use strict arg q
  if q~machine<>.nil then do
    if q~machine['handle']<>.nil then return q~machine['handle']
  end
  return q~opt('machine')
/* A show/describe result: rc 0 -> .true; a not-found message -> .false; anything else (auth, wrapper, network)
 * -> a syntax error, so a failure is never read as "absent" and planned as a create. */
::method existsFrom
  use strict arg r, what
  if r~rc=0 then return .true
  e=r~err~makeString('L', ' ')~lower
  do w over .array~of('was not found', 'not found', 'notfound', 'could not be found', 'does not exist')
    if pos(w, e)>0 then return .false
  end
  self~failWith(r, 'cannot tell whether' what 'exists')
/* A failed read: its stderr tail to the run log, then a syntax error carrying the reason (observeStep turns it
 * into a STOP line).  Never returns. */
::method failWith
  use strict arg r, text
  call ccErrTail r
  raise syntax 40.900 array(text': rc='r~rc||ccErrReason(r))
/* A named rule's current state (Azure, GCP): .nil when the rule does not exist, else its parsed JSON document. */
::method observeRule
  use strict arg r, what
  if \self~existsFrom(r, what) then return .nil
  text=r~out~makeString('L', ' ')
  if text~strip='' then return .directory~new
  return .json~new~fromJson(text)
/* Named-rule reconcile (Azure, GCP): the source list the update must send, and what it adds and removes.
 * ev is the plug-in's evidence (.nil when the rule does not exist) with ev~sources.  Without --add-only the rule
 * ends up holding exactly the wanted sources; with it, every current source is kept and only missing ones added.
 * A full replace names every source it removes, so a plan never hides a removal (26 Nov 2026). */
::method namedSources
  use strict arg q, ev
  want=ccSourceSet(q)
  have=.array~new
  if ev<>.nil then have=ev~sources
  d=.directory~new
  d~final=.array~new
  d~added=.array~new
  d~removed=.array~new
  if q~addOnly then do c over have
    if \d~final~hasItem(c) then d~final~append(c)
  end
  if q~addOnly, have~hasItem('*') then nop          /* already open to every source: nothing to add */
  else do c over want
    if \d~final~hasItem(c) then d~final~append(c)
  end
  do c over d~final
    if \have~hasItem(c) then d~added~append(c)
  end
  do c over have
    if \d~final~hasItem(c) then d~removed~append(c)
    else if q~addOnly, \want~hasItem(c) then q~notes~append('kept (add-only):' c)
  end
  d~purpose=('add' d~added~makeString('L', ',')~strip)~strip
  if d~added~items=0 then d~purpose='add none'
  if d~removed~items>0 then d~purpose=d~purpose 'REMOVE' d~removed~makeString('L', ',')
  return d
/* Append FLAG VALUE only when VALUE is not empty. */
::method addOpt
  use strict arg argv, flag, val
  if val<>'' then do
    argv~append(flag)
    argv~append(val)
  end
  return argv
::method read
  use strict arg argv, purpose=''
  return .CloudCommand~new(argv, .false, purpose)
::method change
  use strict arg argv, purpose=''
  return .CloudCommand~new(argv, .true, purpose)
/* lower-cased protocol with all|any|* -> '*' */
::method normalProtocol
  use strict arg p
  p=p~lower
  if wordpos(p, 'all any *')>0 then return '*'
  return p
/* 'N' or 'N-M' -> .array(lo, hi); '' -> .array('', '') */
::method portRange
  use strict arg port
  parse var port lo '-' hi
  if hi='' then hi=lo
  return .array~of(lo, hi)
/* XTP intent support (CloudXtp.cls).  kind is raw (IP protocol 36) or udp.  Returns the protocol this provider's
 * firewall uses for that traffic, or '' when it cannot select it (the host firewall must carry it). */
::method xtpProtocol
  use strict arg kind
  if kind='raw' then return '36'
  return 'udp'
::method xtpPriority                    /* (slot kind) -> priority for named-rule providers, or '' */
  use strict arg kind
  return ''
/* .true when firewall rules are named objects (GCP, Azure): each XTP slot is its own rule.  .false when the
 * firewall is a set of CIDR entries keyed by protocol and port (AWS, OCI, Vultr): slots with the same protocol and
 * port are merged into one source set, or one reconcile would remove the other's sources. */
::method namedRules
  return .false

::class CloudProviderPlugins public
::method init
  expose byName config
  use strict arg config
  byName=.directory~new
::method register
  expose byName
  use strict arg plugin
  byName[plugin~name]=plugin
  return self
::method names
  expose byName
  return byName~allIndexes~sortWith(.CaselessComparator~new)
::method plugin
  expose byName config
  use strict arg name
  p=byName[name]
  if p<>.nil then return p
  spec=config~setting('provider.'name)
  if spec='' then return .nil
  parse var spec file ':' className
  pkg=.context~package~loadPackage(config~expand(file))
  cls=pkg~findClass(className)
  if cls=.nil then return .nil
  p=cls~new
  byName[name]=p
  return p

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudCtlEvent public
::attribute kind get
::attribute text get
::method init
  expose kind text
  use strict arg kind, text
::method string
  expose kind text
  return kind text

::class CloudCtlFileTarget public
::attribute name get
::attribute dir
::method init
  expose name dir
  use strict arg name, dir
::method scope
  return 'INTERNAL'
::method accept
  expose dir
  use strict arg event
  f=dir'/events-'date('S')'.log'
  call lineout f, ccUtc() left(event~levelName,5) event~payload~string
  call lineout f
  return .true

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudCtlSession public
::attribute findings get
::attribute exitCode get
::attribute output   get            /* lines for stdout */
::method init
  expose config plugins ledger exec service findings exitCode output
  use strict arg config, plugins, service=.nil
  ledger=.CloudCtlLedger~new(config~path('log_dir', '$CLOUDCTL/var'))
  exec=.CloudCtlExec~new(config~path('work_dir', '$CLOUDCTL/var'))
  service=service
  findings=.CloudCtlFindings~new
  exitCode=0
  output=.array~new
::method context
  expose config plugins
  c=.directory~new
  c~config=config
  c~plugins=plugins
  return c
::method ledger
  expose ledger
  return ledger

::method run
  expose config plugins ledger exec service findings exitCode output
  use strict arg q
  log=.nil
  if service<>.nil then log=service~loggerFor(self, 'RUN', .array~new, 'INTERNAL')
  start=ccUtc()
  call time 'R'
  mode='PLAN'
  if q~apply then mode='APPLY'
  if q~mutates=.false then mode='READ'
  /* rules: core, then the plug-in's required fields and its own rules */
  rules=.CloudCtlRules~standard
  p=plugins~plugin(q~provider)
  if p<>.nil then do
    do f over p~required(q~noun, q~verb)
      rules~add(.CloudCtlRule~new('STOP', 'required', 'option --'f 'is required', .CloudCtlRequiredRule~new(f)))
    end
    do r over p~rules
      rules~add(r)
    end
  end
  rules~check(q, self~context, findings)
  do f over findings~lines
    lvl=f~word(1)
    if lvl='STOP' then lvl='ERROR'
    self~emit(log, lvl, 'RULE', 'job='q~jobId f)
  end
  if findings~count('STOP')>0 then do
    do f over findings~bucket('STOP')
      .error~lineout('cloudctl: STOP' f)
    end
    exitCode=2
    self~recordOp(start, q, 'REFUSED', exitCode)
    return exitCode
  end
  ob=self~observeStep(p, q, config, exec)
  if \ob~ok then do
    .error~lineout('cloudctl: STOP cannot read the current state:' ob~text)
    self~emit(log, 'ERROR', 'OBSERVE', 'job='q~jobId ob~text)
    exitCode=2
    self~recordOp(start, q, 'FAILED', exitCode)
    return exitCode
  end
  evidence=ob~value
  steps=p~plan(q, config, evidence)
  shape=''
  if q~addOnly then shape=' add-only'
  self~emit(log, 'INFO', 'PLAN', 'job='q~jobId q~provider q~operation steps~items 'step(s)'shape)
  do n over q~notes
    output~append('NOTE' n)
    self~emit(log, 'INFO', 'NOTE', 'job='q~jobId n)
  end
  if q~mutates, steps~items=0 then do
    output~append('NO CHANGE: already as wanted')
    self~recordOp(start, q, 'NOCHANGE', 0)
    return 0
  end
  if q~mutates, \q~apply then do s over steps        /* PLAN lists the steps; APPLY announces each on stderr */
    tag='READ  '
    if s~mutates then tag='CHANGE'
    what=''
    if s~purpose<>'' then what=' ('s~purpose')'
    output~append(tag s~text||what)
  end
  if mode='PLAN' then do
    output~append('PLANNED: nothing changed. Add --apply to run the CHANGE steps.')
    self~recordOp(start, q, mode, 0)
    return 0
  end
  do s over steps
    if mode='READ', s~mutates then iterate
    self~emit(log, 'INFO', 'EXEC', 'job='q~jobId s~text~left(300))
    r=exec~run(s)
    do l over r~out
      output~append(l)
    end
    do l over r~err
      .error~lineout(l)
    end
    if r~rc<>0 then do
      exitCode=r~rc
      .error~lineout('cloudctl: FAILED rc='r~rc s~text~left(200))
      if r~err~items=0 then .error~lineout('cloudctl: (the command wrote nothing on stderr; for gcp, check gcloud-account.sh ACCOUNT config get-value account)')
      self~emit(log, 'ERROR', 'FAILED', 'job='q~jobId 'rc='r~rc s~text~left(300))
      leave
    end
  end
  if exitCode=0, q~noun='machine', mode='APPLY' then self~recordMachineEvent(q)
  self~recordOp(start, q, mode, exitCode)
  lvl='INFO'
  if exitCode<>0 then lvl='ERROR'
  self~emit(log, lvl, 'END', 'job='q~jobId q~provider q~operation 'mode='mode 'rc='exitCode 'seconds='format(time('E'),,1))
  return exitCode

/* Runs the plug-in's read-only observe; a failure becomes a reason, not a traceback. */
::method observeStep
  use strict arg p, q, config, exec
  r=.directory~new
  r~ok=.false
  r~text=''
  r~value=.nil
  signal on syntax name observeFailed
  r~value=p~observe(q, config, exec)
  r~ok=.true
  return r
observeFailed:
  c=condition('O')
  t=c['ADDITIONAL']
  if t~isA(.array), t~items>0 then r~text=t[t~items]~string
  else r~text=c['ERRORTEXT']
  return r

::method recordOp
  expose ledger findings
  use strict arg start, q, mode, rc
  acct=q~opt('account')
  target=q~opt('machine', q~opt('rule', q~opt('scope')))
  counts='S'findings~count('STOP')'W'findings~count('WARN')'I'findings~count('INFO')
  ledger~recordOp(.array~of(start, q~jobId, value('USER',,'ENVIRONMENT'), q~provider, acct, q~operation, target, mode, rc, format(time('E'),,1), counts))

::method recordMachineEvent
  expose ledger
  use strict arg q
  ev=''
  select
    when q~verb='create' then ev='CREATED'
    when q~verb='start' then ev='STARTED'
    when q~verb='stop' then ev='STOPPED'
    when q~verb='reboot' then ev='REBOOTED'
    when q~verb='destroy' then ev='DESTROYED'
    otherwise nop
  end
  if ev='' then return
  name=q~opt('machine', q~opt('name'))
  handle=name
  if q~machine<>.nil then handle=q~machine['handle']
  ledger~recordMachine(.array~of(ccUtc(), q~provider, q~opt('account'), name, handle, ev, q~jobId))

::method emit
  use strict arg log, level, kind, text
  if log=.nil then return
  log~log(log~send(level), .CloudCtlEvent~new(kind, text))

/* A rule object for one required option (used by the session for each plug-in's required list). */
::class CloudCtlRequiredRule public
::method init
  expose field
  use strict arg field
::method call
  expose field
  use strict arg q, c
  if q~opt(field)<>'' then return ''
  if field='machine', q~machine<>.nil then return ''
  return 'missing --'field
::requires 'json.cls'
