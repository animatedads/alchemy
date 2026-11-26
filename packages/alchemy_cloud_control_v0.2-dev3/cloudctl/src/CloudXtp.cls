/* CloudXtp.cls -- XTP intent layer for Cloud Control: the ED209 grid's XTP ingress as desired source sets.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 *
 * Replaces the workstation cloudctl.sh operations allow-xtp-peers, replace-xtp-peers, allow-workstation-xtp and
 * Azure set-sources.  Those took source lists typed on the command line and behaved differently per provider
 * (AWS only ever added; Azure kept only the last workstation source; OCI duplicated its UDP test-range rules on
 * every run).  Here the grid itself is the input:
 *
 *   etc/machines/NODE.machine   xtp_link=L3|L4, address=, provider=, scope= (the node's cloud firewall) ...
 *   etc/xtp/grid.conf           udp_port, workstation, workstation_udp, rule names
 *
 * Link levels (Tom's design): L3 is native XTP, IP protocol 36, between MUs; Google nodes are L4 only, XTP over
 * UDP on the commissioned port.  So for node N:
 *
 *   slot        rule (named providers)          sources                                   when
 *   peers-raw   ed209-xtp-peers                 every other L3 node /32                   N is L3
 *   peers-udp   ed209-xtp-udp                   every L4 node /32 (all peers if N is L4)   always
 *   ws-raw      ed209-xtp-workstation-raw36     the operator workstation                  N is L3, workstation set
 *   ws-udp      ed209-xtp-workstation-udp       the operator workstation, UDP range       workstation set
 *
 * Each non-empty slot becomes one `firewall reconcile` request run by an ordinary CloudCtlSession, so the same
 * rules, PLAN/--apply, ledger and logging apply.  Providers whose firewall is a CIDR set keyed by protocol and
 * port (AWS, OCI, Vultr) get slots with the same protocol and port merged first.  A provider that cannot select
 * IP protocol 36 (Vultr) drops the raw slots with a WARN: the host firewall must carry them.
 *
 * --add-only (26 Nov 2026): every slot's reconcile adds missing sources and removes none; sources a full reconcile
 * would remove are listed as NOTE kept (add-only).  Grid rule R8 changes are additions only, so R8 runs use it.
 *
 * Classes: CloudXtpGrid, CloudXtpSlot, CloudXtpIntent, CloudXtpRun.  Node rules are CloudCtlRule objects.
 */

::class CloudXtpGrid public
::attribute config get
::method init
  expose config settings
  use strict arg config
  settings=ccReadProps(config~home'/etc/xtp/grid.conf')
::method setting
  expose settings
  use strict arg key, default=''
  v=settings[key~lower]
  if v=.nil then return default
  if v='' then return default
  return v
/* Machines that take part in XTP: those with an xtp_link. */
::method members
  expose config
  a=.array~new
  do n over config~machineNames
    m=config~machine(n)
    link=m['xtp_link']
    if link=.nil then iterate
    if link='' then iterate
    a~append(m)
  end
  return a
::method member
  use strict arg name
  do m over self~members
    if m['name']=name then return m
  end
  return .nil
::method ruleName
  use strict arg kind
  select
    when kind='peers-raw' then return self~setting('peers_raw_rule', 'ed209-xtp-peers')
    when kind='peers-udp' then return self~setting('peers_udp_rule', 'ed209-xtp-udp')
    when kind='ws-raw' then return self~setting('workstation_raw_rule', 'ed209-xtp-workstation-raw36')
    when kind='ws-udp' then return self~setting('workstation_udp_rule', 'ed209-xtp-workstation-udp')
    otherwise return 'ed209-xtp-'kind
  end

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudXtpSlot public
::attribute kind
::attribute rule
::attribute protocol
::attribute port
::attribute sources
::attribute description
::attribute priority
::method init
  expose kind rule protocol port description priority sources
  use strict arg kind, rule, protocol, port, description, priority=''
  sources=.array~new
::method add
  expose sources
  use strict arg cidr
  if \sources~hasItem(cidr) then sources~append(cidr)
::method key
  expose protocol port
  return protocol'/'port
::method text
  expose kind rule protocol port sources
  p=protocol
  if port<>'' then p=p':'port
  return left(kind,10) left(rule,28) left(p,16) sources~makeString('L', ',')

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudXtpIntent public
::attribute findings get
::method init
  expose grid plugins findings
  use strict arg grid, plugins
  findings=.CloudCtlFindings~new
/* The desired ingress slots for one node.  When other members share its firewall scope (OCI nodes on one subnet
 * share its security list), their slots are united into these: reconciling each node to its own set would make
 * the nodes undo each other.  Skipped or empty slots are explained in the findings buckets. */
::method slotsFor
  expose grid plugins findings
  use strict arg node, workstation
  slots=self~ownSlots(node, workstation, findings)
  scope=ccStr(node['scope'])
  if scope='' then return slots
  if scope='none' then return slots
  p=plugins~plugin(node['provider'])
  quiet=.CloudCtlFindings~new
  do other over grid~members
    if other['name']=node['name'] then iterate
    if ccStr(other['provider'])<>ccStr(node['provider']) then iterate
    if ccStr(other['scope'])<>scope then iterate
    findings~add('INFO', 'shared', node['name'] 'shares its firewall scope with' other['name']': source sets united')
    do o over self~ownSlots(other, workstation, quiet)
      matched=.false
      do s over slots
        if \self~sameSlot(s, o, p) then iterate
        do c over o~sources
          s~add(c)
        end
        matched=.true
      end
      if \matched then slots~append(o)
    end
  end
  return slots
/* Same rule on a named-rule provider; same protocol and port on a CIDR-set provider. */
::method sameSlot
  use strict arg a, b, p
  if p=.nil then return (a~rule=b~rule)
  if p~namedRules then return (a~rule=b~rule)
  return (a~key=b~key)
/* One node's own slots, findings into f. */
::method ownSlots
  expose grid plugins
  use strict arg node, workstation, findings
  name=node['name']
  link=node['xtp_link']~upper
  p=plugins~plugin(node['provider'])
  udpPort=grid~setting('udp_port', '62801')
  wsRange=grid~setting('workstation_udp', '62000-63000')
  rawProto='36'
  if p<>.nil then rawProto=p~xtpProtocol('raw')
  udpProto='udp'
  if p<>.nil then udpProto=p~xtpProtocol('udp')
  all=.array~new
  peersRaw=self~newSlot(p, 'peers-raw', rawProto, '', 'ED209 XTP raw36 peers (cloudctl xtp)')
  peersUdp=self~newSlot(p, 'peers-udp', udpProto, udpPort, 'ED209 XTP over UDP, commissioned port (cloudctl xtp)')
  wsRaw=self~newSlot(p, 'ws-raw', rawProto, '', 'ED209 XTP raw36 from the operator workstation (cloudctl xtp)')
  wsUdp=self~newSlot(p, 'ws-udp', udpProto, wsRange, 'ED209 XTP UDP qualification range from the operator workstation (cloudctl xtp)')
  do peer over grid~members
    if peer['name']=name then iterate
    addr=peer['address']
    if addr=.nil then addr=''
    if addr='' then do
      findings~add('WARN', 'peeraddr', peer['name'] 'has no address= : left out of' name"'s peer sets")
      iterate
    end
    cidr=addr
    if pos('/', cidr)=0 then cidr=cidr'/32'
    if link='L3', peer['xtp_link']~upper='L3' then peersRaw~add(cidr)
    else peersUdp~add(cidr)
  end
  if workstation<>'' then do
    if link='L3' then wsRaw~add(workstation)
    wsUdp~add(workstation)
  end
  else findings~add('INFO', 'workstation', 'no workstation CIDR (grid.conf workstation= or --workstation): workstation slots left as they are')
  do s over .array~of(peersRaw, peersUdp, wsRaw, wsUdp)
    if s~sources~items=0 then do
      if s~kind='peers-udp' then findings~add('INFO', 'empty', name s~kind 'has no sources: rule' s~rule 'left as it is')
      if s~kind='peers-raw', link='L3' then findings~add('INFO', 'empty', name s~kind 'has no sources: rule' s~rule 'left as it is')
      iterate
    end
    if s~protocol='' then do
      findings~add('WARN', 'xtpraw', node['provider'] 'cannot filter IP protocol 36:' name s~kind 'must be admitted by the host firewall ('s~sources~items 'source(s))')
      iterate
    end
    all~append(s)
  end
  if p=.nil then do
    findings~add('INFO', 'hostonly', 'no cloud firewall plug-in for' node['provider']': these slots are for the host firewall')
    return all
  end
  if p~namedRules then return all
  return self~merge(all)
::method newSlot
  expose grid
  use strict arg p, kind, protocol, port, description
  pri=''
  if p<>.nil then pri=p~xtpPriority(kind)
  return .CloudXtpSlot~new(kind, grid~ruleName(kind), protocol, port, description, pri)
/* CIDR-set firewalls: one slot per protocol/port, sources united. */
::method merge
  use strict arg slots
  out=.array~new
  byKey=.directory~new
  do s over slots
    first=byKey[s~key]
    if first=.nil then do
      byKey[s~key]=s
      out~append(s)
      iterate
    end
    do c over s~sources
      first~add(c)
    end
    first~kind=first~kind'+'s~kind
  end
  return out

/* ------------------------------------------------------------------------------------------------------------ */
::class CloudXtpRun public
::attribute output get
::method init
  expose config plugins service grid output
  use strict arg config, plugins, service
  grid=.CloudXtpGrid~new(config)
  output=.array~new
::method grid
  expose grid
  return grid
/* Lines go to stdout as they happen, so a node's header and findings come before its provider calls (whose
 * progress is on stderr), and are kept in output for callers that want the record. */
::method put
  expose output
  use strict arg line
  output~append(line)
  say line
/* Node-level rules: what has to be true of a machine before its firewall can be reconciled. */
::method nodeRules
  r=.CloudCtlRules~new
  r~add(.CloudCtlRule~new('STOP', 'xtplink', 'xtp_link is L3 or L4', .routines~xtpLink))
  r~add(.CloudCtlRule~new('STOP', 'xtpplugin', 'the provider has a cloud firewall plug-in', .routines~xtpPlugin))
  r~add(.CloudCtlRule~new('STOP', 'xtpscope', 'scope= names the cloud firewall', .routines~xtpScope))
  r~add(.CloudCtlRule~new('STOP', 'xtpregion', 'aws and oci nodes name their region', .routines~xtpRegion))
  r~add(.CloudCtlRule~new('STOP', 'xtpaccount', 'gcp nodes name their account', .routines~xtpAccount))
  r~add(.CloudCtlRule~new('WARN', 'xtpaddress', 'address= is an IPv4 address', .routines~xtpAddress))
  r~add(.CloudCtlRule~new('WARN', 'xtptags', 'gcp nodes name target-tags', .routines~xtpTags))
  return r
::method context
  expose config plugins
  c=.directory~new
  c~config=config
  c~plugins=plugins
  return c
/* names: .array of machine names, or 'all'.  Returns the worst exit code. */
::method names
  expose grid
  use strict arg spec
  a=.array~new
  if spec='all' then do
    do m over grid~members
      a~append(m['name'])
    end
    return a
  end
  a~append(spec)
  return a

/* show: the desired slots, no provider call. */
::method show
  expose grid plugins output
  use strict arg spec, workstation
  rc=0
  do n over self~names(spec)
    node=grid~member(n)
    if node=.nil then do
      self~put('==' n 'is not an XTP member (no etc/machines/'n'.machine with xtp_link=)')
      rc=2
      iterate
    end
    intent=.CloudXtpIntent~new(grid, plugins)
    slots=intent~slotsFor(node, workstation)
    self~put('==' n node['provider'] node['xtp_link'] node['address'])
    do s over slots
      self~put('   ' s~text)
    end
    do f over intent~findings~lines
      self~put('   ' f)
    end
  end
  return rc

::method run
  expose config plugins service grid output
  use strict arg spec, apply, workstation, jobId, addOnly=.false
  worst=0
  do n over self~names(spec)
    node=grid~member(n)
    if node=.nil then do
      self~put('==' n 'STOP: not an XTP member (no etc/machines/'n'.machine with xtp_link=)')
      worst=max(worst, 2)
      iterate
    end
    f=.CloudCtlFindings~new
    self~nodeRules~check(node, self~context, f)
    self~put('==' n node['provider'] node['xtp_link'] node['address'])
    do l over f~lines
      self~put('   ' l)
    end
    if f~count('STOP')>0 then do
      self~put('   SKIPPED: fix the STOP findings in etc/machines/'n'.machine')
      worst=max(worst, 2)
      iterate
    end
    if ccStr(node['scope'])='none' then do
      self~put('   SKIPPED: scope=none (no cloud firewall in front of this machine): the host firewall carries XTP')
      iterate
    end
    intent=.CloudXtpIntent~new(grid, plugins)
    slots=intent~slotsFor(node, workstation)
    do l over intent~findings~lines
      self~put('   ' l)
    end
    p=plugins~plugin(node['provider'])
    do s over slots
      self~put('-- ' s~text)
      q=self~request(node, s, p, apply, jobId)
      q~addOnly=addOnly
      session=.CloudCtlSession~new(config, plugins, service)
      rc=session~run(q)
      do l over session~output
        self~put('   ' l)
      end
      if rc<>0 then self~put('   rc='rc)
      worst=max(worst, rc)
    end
  end
  return worst

/* One slot -> one firewall reconcile request; the machine and its account fill the provider options. */
::method request
  expose config
  use strict arg node, s, p, apply, jobId
  q=.CloudCtlRequest~new
  q~provider=node['provider']
  q~noun='firewall'
  q~verb='reconcile'
  q~apply=apply
  q~jobId=jobId
  q~add('rule', s~rule)
  q~add('protocol', s~protocol)
  if s~port<>'' then q~add('port', s~port)
  q~add('sources', s~sources~makeString('L', ','))
  q~add('description', s~description)
  if s~priority<>'' then q~add('priority', s~priority)
  if node['account']<>.nil then do
    if node['account']<>'' then q~add('account', node['account'])
  end
  q~fillFrom(node, p)
  q~account=config~account(q~opt('account'))
  if q~account<>.nil then q~fillFrom(q~account, p)
  return q

::routine xtpLink
  use arg node, c
  l=node['xtp_link']~upper
  if wordpos(l, 'L3 L4')>0 then return ''
  return 'xtp_link must be L3 or L4 (got' node['xtp_link']')'
::routine xtpPlugin
  use arg node, c
  if c~plugins~plugin(node['provider'])<>.nil then return ''
  return 'no cloud firewall plug-in for provider' node['provider']': its XTP ingress is the host firewall''s job'
::routine xtpScope
  use arg node, c
  s=node['scope']
  if s<>.nil then do
    if s<>'' then return ''
  end
  select
    when node['provider']='aws' then what='the security group id (sg-...)'
    when node['provider']='azure' then what='RESOURCE_GROUP:NSG_NAME'
    when node['provider']='oci' then what='the security list or NSG OCID'
    when node['provider']='gcp' then what='the VPC network name (usually default)'
    when node['provider']='vultr' then what='the firewall group id'
    otherwise what='the firewall scope'
  end
  return 'set scope= to' what
::routine xtpRegion
  use arg node, c
  if wordpos(node['provider'], 'aws oci')=0 then return ''
  r=node['region']
  if r<>.nil then do
    if r<>'' then return ''
  end
  return node['provider'] 'needs region='
::routine xtpAccount
  use arg node, c
  if node['provider']<>'gcp' then return ''
  a=node['account']
  if a<>.nil then do
    if a<>'' then return ''
  end
  return 'gcp needs account= (an etc/accounts/NAME.account)'
::routine xtpAddress
  use arg node, c
  a=node['address']
  if a=.nil then a=''
  if a='' then return 'no address=: this node is left out of every other node''s peer set'
  if ccIsCidr(a) then return ''
  return 'address= is not IPv4:' a
::routine xtpTags
  use arg node, c
  if node['provider']<>'gcp' then return ''
  t=node['target-tags']
  if t<>.nil then do
    if t<>'' then return ''
  end
  return 'no target-tags=: on create the rule applies to every instance in the network'

::requires 'CloudCtl.cls'
