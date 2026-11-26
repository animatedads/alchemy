/* CloudDiscover.cls -- "cloudctl discover": find each machine's instance and cloud firewall from its address.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 *
 * The machine file's address= is the key.  Each provider plug-in's discover(q, config, exec, d) makes read-only
 * calls and records what it found in a CloudDiscovery (values: handle, scope, zone ...; findings: STOP/WARN/INFO).
 * The run compares every value with the machine file:
 *
 *   same      the file already says this
 *   fill      the file is blank here: --write fills it
 *   DIFFERS   the file says something else: never overwritten; reported for a person to decide
 *
 * --write changes only "fill" lines, keeps every comment, and copies the old file to var/machines-backup/ first.
 * Every node's discovery is a ledger row (operation "machine discover", mode READ or WRITE).
 *
 * Classes: CloudDiscovery, CloudMachineFile, CloudDiscoverRun.
 */

::class CloudDiscovery public
::attribute node     get
::attribute values   get
::attribute findings get
::method init
  expose node values findings
  use strict arg node
  values=.directory~new
  findings=.CloudCtlFindings~new
::method set
  expose values
  use strict arg key, value
  values[key]=value
::method note
  expose findings
  use strict arg level, id, text
  findings~add(level, id, text)

/* ------------------------------------------------------------------------------------------------------------ */
/* A machine file edited in place: key=value lines replaced or appended; comments and order kept. */
::class CloudMachineFile public
::attribute path get
::method init
  expose path lines
  use strict arg path
  lines=ccReadLines(path)
::method set
  expose lines
  use strict arg key, value
  do i=1 to lines~items
    l=lines[i]~strip('L')
    if l~left(1)='#' then iterate
    if l~left(key~length+1)~lower<>key~lower'=' then iterate
    lines[i]=key'='value
    return
  end
  lines~append(key'='value)
::method save
  expose path lines
  use strict arg backupDir
  call SysMkDir backupDir
  stamp=ccUtc()~changeStr('-', '')~changeStr(':', '')
  call SysFileCopy path, backupDir'/'filespec('N', path)'.'stamp
  s=.stream~new(path)
  s~open('write replace')
  do l over lines
    s~lineout(l)
  end
  s~close

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudDiscoverRun public
::method init
  expose config plugins service
  use strict arg config, plugins, service
::method names
  expose config
  use strict arg spec
  if spec='all' then return config~machineNames
  return .array~of(spec)

::method run
  expose config plugins service
  use strict arg spec, write, jobId
  worst=0
  exec=.CloudCtlExec~new(config~path('work_dir', '$CLOUDCTL/var'))
  table=.ColumnDisplay~new(.array~of(2, 7, 7))
  do n over self~names(spec)
    node=config~machine(n)
    if node=.nil then do
      say '==' n 'STOP: no etc/machines/'n'.machine'
      worst=max(worst, 2)
      iterate
    end
    say '==' n ccStr(node['provider']) ccStr(node['address'])
    p=plugins~plugin(ccStr(node['provider']))
    if p=.nil then do
      say '   INFO nodiscover     no cloud plug-in for' ccStr(node['provider'])': nothing to discover'
      iterate
    end
    call time 'R'
    q=self~request(node, p, jobId)
    d=.CloudDiscovery~new(node)
    self~check(node, p, d)
    if d~findings~count('STOP')=0 then self~discoverStep(p, q, exec, d)
    do l over d~findings~lines
      say '   'l
    end
    rows=self~compare(node, d)
    do r over rows                                  /* values in full: an OCI id is ~95 characters */
      say table~format(.array~of('', r[4], r[1]))' =' r[3]
      if r[4]='DIFFERS' then say table~format(.array~of('', '', ''))'   machine file says' r[2]
    end
    mode='READ'
    code=0
    if d~findings~count('STOP')>0 then code=2
    if write, code=0 then do
      fills=0
      f=.CloudMachineFile~new(config~home'/etc/machines/'n'.machine')
      do r over rows
        if r[4]<>'fill' then iterate
        f~set(r[1], r[3])
        fills=fills+1
      end
      if fills>0 then do
        f~save(config~path('log_dir', '$CLOUDCTL/var')'/machines-backup')
        say '   WROTE' fills 'field(s) to etc/machines/'n'.machine (old copy in var/machines-backup/)'
        mode='WRITE'
      end
    end
    worst=max(worst, code)
    self~record(q, mode, code, d)
  end
  if \write then say 'Nothing written. Add --write to fill the blank fields marked "fill".'
  return worst

/* Rules that must hold before any provider call. */
::method check
  expose config
  use strict arg node, p, d
  a=ccStr(node['address'])
  if a='' then d~note('STOP', 'address', 'no address= : discovery looks machines up by public address')
  else if \ccIsCidr(a) then d~note('STOP', 'address', 'address= is not IPv4:' a)
  do k over p~discoverNeeds
    if ccStr(node[k])='' then d~note('STOP', 'needs', p~name 'discovery needs' k'= in the machine file')
  end
  cli=p~cliName
  if cli<>'' then do
    address system 'command -v' cli '>/dev/null 2>&1'
    if rc<>0 then d~note('STOP', 'kit', cli 'is not installed on this machine')
  end

/* The plug-in's discover, with a provider failure turned into a STOP finding instead of a traceback. */
::method discoverStep
  expose config
  use strict arg p, q, exec, d
  signal on syntax name failed
  p~discover(q, config, exec, d)
  return
failed:
  c=condition('O')
  t=c['ADDITIONAL']
  msg=c['ERRORTEXT']
  if t~isA(.array), t~items>0 then msg=t[t~items]~string
  d~note('STOP', 'provider', msg)
  return

/* rows: .array of .array(field, file value, discovered value, result) */
::method compare
  use strict arg node, d
  rows=.array~new
  keys=d~values~allIndexes~sortWith(.CaselessComparator~new)
  do k over keys
    new=d~values[k]
    cur=ccStr(node[k])
    select
      when cur==new then res='same'
      when cur='' then res='fill'
      otherwise res='DIFFERS'
    end
    rows~append(.array~of(k, cur, new, res))
  end
  return rows

::method request
  expose config
  use strict arg node, p, jobId
  q=.CloudCtlRequest~new
  q~provider=node['provider']
  q~noun='machine'
  q~verb='discover'
  q~jobId=jobId
  q~add('machine', node['name'])
  if ccStr(node['account'])<>'' then q~add('account', node['account'])
  q~fillFrom(node, p)
  q~account=config~account(q~opt('account'))
  if q~account<>.nil then q~fillFrom(q~account, p)
  q~machine=node
  return q

::method record
  expose config plugins service
  use strict arg q, mode, code, d
  session=.CloudCtlSession~new(config, plugins, service)
  session~findings~absorb(d~findings)
  session~recordOp(ccUtc(), q, mode, code)

::requires 'CloudCtl.cls'
::requires 'ColumnDisplay.cls'
