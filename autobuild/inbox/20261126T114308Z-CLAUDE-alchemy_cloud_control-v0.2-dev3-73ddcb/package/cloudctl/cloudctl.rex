/* cloudctl.rex -- Cloud Control command line.  Called by the ../cloudctl.sh argv shim.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 *
 *   cloudctl PROVIDER machine list|create|start|stop|reboot|destroy [--option value ...] [--apply] [--confirm M]
 *   cloudctl PROVIDER firewall list|allow|revoke|reconcile [--option value ...] [--apply]
 *   cloudctl PROVIDER restart [--option value ...] HANDLE|MACHINE      (the old command: machine reboot)
 *   cloudctl providers | accounts | machines
 *   cloudctl ops [--since YYYY-MM-DD]            operations ledger
 *   cloudctl hours                                running hours per machine from the lifecycle ledger
 *   cloudctl check PROVIDER NOUN VERB [...]       rules only: print the buckets, run nothing
 *   cloudctl xtp show [NODE|all] [--workstation CIDR]          the grid's desired XTP ingress, no provider call
 *   cloudctl xtp NODE|all [--workstation CIDR] [--add-only] [--apply]   reconcile each node's cloud firewall to it
 *                                                              (--add-only: add missing sources, remove none)
 *
 * Mutations are PLAN until --apply.  destroy also needs --confirm with the exact machine name.
 * --machine NAME uses etc/machines/NAME.machine; --account NAME uses etc/accounts/NAME.account; their fields
 * fill any option not given on the command line.  --job-id ID tags the ledger and log (default cloudctl-UTC-PID).
 * Exit: provider rc for a failed step; 2 for usage errors and refusals.
 */
home=value('CLOUDCTL_HOME',,'ENVIRONMENT')
if home='' then do
  parse source . . me
  home=filespec('L', me)~strip('T', '/')
end
base=value('CLOUDCTL_BASE',,'ENVIRONMENT')
if base='' then base=home~left(home~lastPos('/')-1)
tokens=readTokens()
config=.CloudCtlConfig~new(home, base)
plugins=registerPlugins(config)
if tokens~items=0 then call usage 'no arguments'

select
  when tokens[1]='providers' then do
    do n over plugins~names
      p=plugins~plugin(n)
      say left(n,8) p~operations~makeString('L', ', ')
    end
    exit 0
  end
  when tokens[1]='accounts' then do
    d=.ColumnDisplay~new(.array~of(18, 9, 50))
    d~printRow(.array~of('account', 'provider', 'description'))
    d~printSeparator
    do n over config~accountNames
      a=config~account(n)
      d~printRow(.array~of(n, a['provider'], a['description']))
    end
    exit 0
  end
  when tokens[1]='machines' then do
    d=.ColumnDisplay~new(.array~of(8, 9, 16, 4, 15, 36))
    d~printRow(.array~of('machine', 'provider', 'account', 'link', 'address', 'handle'))
    d~printSeparator
    do n over config~machineNames
      m=config~machine(n)
      d~printRow(.array~of(n, m['provider'], m['account'], m['xtp_link'], m['address'], m['handle']))
    end
    exit 0
  end
  when tokens[1]='ops' then call opsReport config, tokens
  when tokens[1]='hours' then call hoursReport config
  when tokens[1]='xtp' then call xtpCommand config, plugins, tokens
  when tokens[1]='discover' then call discoverCommand config, plugins, tokens
  otherwise nop
end

checkOnly=.false
if tokens[1]='check' then do
  checkOnly=.true
  tokens=tokens~section(2)
  if tokens~items=0 then call usage 'check needs PROVIDER NOUN VERB'
end
q=parseRequest(tokens, config, plugins)
service=loadLogging(config)
session=.CloudCtlSession~new(config, plugins, service)
if checkOnly then do
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
  f=rules~check(q, session~context, session~findings)
  do l over f~lines
    say l
  end
  say 'STOP' f~count('STOP') 'WARN' f~count('WARN') 'INFO' f~count('INFO')
  if f~count('STOP')>0 then exit 2
  exit 0
end
code=session~run(q)
do l over session~output
  say l
end
exit code

/* ------------------------------------------------------------------------------------------------------------ */
readTokens: procedure
  f=value('CLOUDCTL_ARGFILE',,'ENVIRONMENT')
  t=.array~new
  if f='' then do
    parse arg line
    do w over line~makeArray(' ')
      if w<>'' then t~append(w)
    end
    return t
  end
  do l over ccReadLines(f)
    t~append(l~decodeBase64)
  end
  return t

/* Built-in provider plug-ins, then any provider.<name>=<file>:<Class> in cloudctl.conf (loaded on demand). */
registerPlugins: procedure
  use strict arg config
  p=.CloudProviderPlugins~new(config)
  do name over .array~of('gcp', 'aws', 'azure', 'oci', 'vultr')
    spec=config~setting('provider.'name)
    if spec='' then iterate
    plugin=p~plugin(name)
    if plugin=.nil then .error~lineout('cloudctl: provider plug-in for' name 'did not load:' spec)
  end
  return p

parseRequest: procedure
  use strict arg tokens, config, plugins
  q=.CloudCtlRequest~new
  q~provider=tokens[1]~lower
  if tokens~items<2 then call usage 'missing operation'
  i=2
  if tokens[2]='restart' then do
    q~noun='machine'; q~verb='reboot'
    i=3
  end
  else do
    if tokens~items<3 then call usage 'expected NOUN VERB'
    q~noun=tokens[2]~lower; q~verb=tokens[3]~lower
    i=4
  end
  positional=.array~new
  do while i<=tokens~items
    t=tokens[i]
    select
      when t='--add-only' then do
        q~addOnly=.true
        i=i+1
      end
      when t='--apply' then do
        q~apply=.true
        i=i+1
      end
      when t='--confirm' then do
        if i=tokens~items then call usage '--confirm needs a value'
        q~confirm=tokens[i+1]
        i=i+2
      end
      when t='--job-id' then do
        if i=tokens~items then call usage '--job-id needs a value'
        q~jobId=tokens[i+1]
        i=i+2
      end
      when t~startsWith('--') then do
        if i=tokens~items then call usage t 'needs a value'
        q~add(t~substr(3), tokens[i+1])
        i=i+2
      end
      otherwise do
        positional~append(t)
        i=i+1
      end
    end
  end
  if positional~items>1 then call usage 'one positional argument at most (the machine)'
  if positional~items=1 then do
    if q~has('machine') then call usage 'machine given twice'
    q~add('machine', positional[1])
  end
  if q~jobId='' then q~jobId='cloudctl-'ccUtc()~changeStr('-','')~changeStr(':','')'-'SysQueryProcess('PID')
  /* registry entries fill options not given */
  q~machine=config~machine(q~opt('machine'))
  if q~machine<>.nil then do
    if \q~has('account') then do
      if q~machine['account']<>'' then q~add('account', q~machine['account'])
    end
    q~fillFrom(q~machine, plugins~plugin(q~provider))
  end
  q~account=config~account(q~opt('account'))
  if q~account<>.nil then q~fillFrom(q~account, plugins~plugin(q~provider))
  return q

loadLogging: procedure
  use strict arg config
  pkgFile=config~path('logging_package', '$AUTOBUILD/repo/packages/oorexx_logging_v0.7/src/LoggingCore.cls')
  if \SysFileExists(pkgFile) then do
    if config~setting('require_logging', 'yes')='yes' then do
      .error~lineout('cloudctl: STOP logging package missing:' pkgFile)
      exit 2
    end
    return .nil
  end
  .context~package~loadPackage(pkgFile)
  service=.LogService~new('cloudctl')
  service~addTarget(.CloudCtlFileTarget~new('events', config~path('log_dir', '$CLOUDCTL/var')))
  rule=.LogRule~new('cloudctl-run', 'cloudctl', 'CloudCtlSession', 'RUN', .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of('events'), .array~new)
  service~addRule(rule)
  return service

opsReport: procedure
  use strict arg config, tokens
  since='0000-00-00'
  if tokens~items>=3 then do
    if tokens[2]<>'--since' then call usage 'ops takes --since YYYY-MM-DD'
    since=tokens[3]
  end
  dir=config~path('log_dir', '$CLOUDCTL/var')
  call SysFileTree dir'/ops-*.tsv', 'f.', 'FO'
  files=.array~new
  do i=1 to f.0
    files~append(f.i)
  end
  do f over files~sortWith(.CaselessComparator~new)
    do l over ccReadLines(f)
      if l~left(4)='time' then iterate
      if l~left(10)<<since then iterate
      say l~changeStr('09'x, '  ')
    end
  end
  exit 0

hoursReport: procedure
  use strict arg config
  l=.CloudCtlLedger~new(config~path('log_dir', '$CLOUDCTL/var'))
  h=l~machineHours(ccUtc())
  say left('machine',14) left('provider',8) right('hours',9) ' state      last event'
  do m over h~allIndexes~sortWith(.CaselessComparator~new)
    r=h[m]
    say left(m,14) left(r~provider,8) right(format(r~hours,,2),9) ' 'left(r~state,10) r~last
  end
  exit 0

/* discover [NODE|all] [--write] [--job-id ID]: read-only lookups by address; --write fills blank fields only */
discoverCommand: procedure
  use strict arg config, plugins, tokens
  spec='all'
  named=.false
  write=.false
  jobId=''
  i=2
  do while i<=tokens~items
    t=tokens[i]
    select
      when t='--write' then do
        write=.true
        i=i+1
      end
      when t='--job-id' then do
        if i=tokens~items then call usage '--job-id needs a value'
        jobId=tokens[i+1]
        i=i+2
      end
      when t~startsWith('--') then call usage 'discover does not take' t
      otherwise do
        if named then call usage 'discover takes one NODE or all'
        spec=t
        named=.true
        i=i+1
      end
    end
  end
  if jobId='' then jobId='discover-'ccUtc()~changeStr('-','')~changeStr(':','')'-'SysQueryProcess('PID')
  run=.CloudDiscoverRun~new(config, plugins, loadLogging(config))
  exit run~run(spec, write, jobId)

/* xtp show [NODE|all] | xtp NODE|all, with --workstation CIDR, --apply, --job-id ID */
xtpCommand: procedure
  use strict arg config, plugins, tokens
  if tokens~items<2 then call usage 'xtp needs show, NODE or all'
  showOnly=.false
  i=2
  if tokens[2]='show' then do
    showOnly=.true
    i=3
  end
  spec='all'
  named=.false
  apply=.false
  addOnly=.false
  ws=''
  jobId=''
  do while i<=tokens~items
    t=tokens[i]
    select
      when t='--add-only' then do
        addOnly=.true
        i=i+1
      end
      when t='--apply' then do
        apply=.true
        i=i+1
      end
      when t='--workstation' then do
        if i=tokens~items then call usage '--workstation needs a CIDR'
        ws=tokens[i+1]
        i=i+2
      end
      when t='--job-id' then do
        if i=tokens~items then call usage '--job-id needs a value'
        jobId=tokens[i+1]
        i=i+2
      end
      when t~startsWith('--') then call usage 'xtp does not take' t
      otherwise do
        if named then call usage 'xtp takes one NODE or all'
        spec=t
        named=.true
        i=i+1
      end
    end
  end
  if \showOnly, \named then call usage 'xtp needs NODE or all (or show)'
  run=.CloudXtpRun~new(config, plugins, .nil)
  if ws='' then ws=run~grid~setting('workstation', '')
  if ws<>'' then do
    if \ccIsCidr(ws) then call usage 'workstation is not an IPv4 CIDR:' ws
    if pos('/', ws)=0 then ws=ws'/32'
  end
  if showOnly then do
    code=run~show(spec, ws)
    exit code
  end
  if jobId='' then jobId='xtp-'ccUtc()~changeStr('-','')~changeStr(':','')'-'SysQueryProcess('PID')
  run=.CloudXtpRun~new(config, plugins, loadLogging(config))
  code=run~run(spec, apply, ws, jobId, addOnly)
  exit code

usage:
  .error~lineout('cloudctl:' arg(1))
  .error~lineout('usage: cloudctl PROVIDER machine|firewall VERB [--option value ...] [--apply] [--confirm M] | PROVIDER restart HANDLE | providers | accounts | machines | ops [--since D] | hours | check PROVIDER NOUN VERB ... | xtp show [NODE|all] | xtp NODE|all [--workstation CIDR] [--add-only] [--apply] | discover [NODE|all] [--write]')
  exit 2

::requires 'src/CloudCtl.cls'
::requires 'src/CloudXtp.cls'
::requires 'src/ColumnDisplay.cls'
::requires 'src/CloudDiscover.cls'
