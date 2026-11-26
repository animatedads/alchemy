/* CloudOci.cls -- Oracle Cloud plug-in for Cloud Control (oci CLI).
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 * Commands follow alchemy_cloud_control dev4 (spec of 7 Nov).  Every command ends [--profile P] [--region R]
 * [--auth A].  Rule JSON is built with json.cls, not python3, and the source is escaped (dev4 inserted it raw).
 *
 * Firewall scope is either a Network Security Group (rules added and removed one by one) or a security list
 * (ocid1.securitylist...; the workstation script's XTP operations used these): the whole ingress list is read,
 * changed and written back in one update.  Rules that `get` returns in the CLI's kebab-case are written back in
 * the camelCase the update expects; the bash script mixed the two.
 * Protocols are JSON strings ("6"), as the OCI model requires; json.cls would otherwise emit a bare number.
 */
::class CloudOciProvider public subclass CloudProviderPlugin
::method init
  self~init:super('oci')
::method operations
  return .array~of('machine list', 'machine create', 'machine start', 'machine stop', 'machine reboot', 'machine destroy', 'firewall list', 'firewall allow', 'firewall revoke', 'firewall reconcile')
::method optionNames
  return .array~of('region', 'oci-profile', 'oci-auth', 'compartment', 'availability-domain', 'subnet', 'image', 'size', 'name', 'ssh-key', 'scope', 'rule', 'protocol', 'port', 'source', 'sources', 'description')
::method required
  use strict arg noun, verb
  select
    when noun verb='machine list' then return .array~of('compartment')
    when noun='machine', wordpos(verb, 'start stop reboot destroy')>0 then return .array~of('machine')
    when noun verb='machine create' then return .array~of('compartment', 'availability-domain', 'subnet', 'image', 'size', 'name')
    when noun verb='firewall list' then return .array~of('scope')
    when noun verb='firewall allow' then return .array~of('scope', 'protocol', 'source')
    when noun verb='firewall reconcile' then return .array~of('scope', 'protocol', 'sources')
    when noun verb='firewall revoke' then return .array~of('scope', 'rule')
    otherwise return .array~new
  end
::method rules
  r=.array~new
  r~append(.CloudCtlRule~new('STOP', 'ociprotocol', 'protocol is tcp, udp, icmp, all or an IP protocol number', .routines~ociProtocol))
  r~append(.CloudCtlRule~new('STOP', 'ociseclist', 'a security list scope supports list and reconcile only', .routines~ociSecList))
  return r
::method suffix
  use strict arg argv, q
  self~addOpt(argv, '--profile', q~opt('oci-profile'))
  self~addOpt(argv, '--region', q~opt('region'))
  self~addOpt(argv, '--auth', q~opt('oci-auth'))
  return argv
::method ociProto
  use strict arg q
  p=self~normalProtocol(q~opt('protocol'))
  select
    when p='tcp' then return '6'
    when p='udp' then return '17'
    when p='icmp' then return '1'
    when p='*' then return 'all'
    otherwise return p
  end
::method isSecList
  use strict arg q
  return q~opt('scope')~startsWith('ocid1.securitylist.')
/* One ingress rule in the camelCase model; NSG rules also carry direction. */
::method ruleObject
  use strict arg proto, cidr, port, desc
  d=.directory~new
  d['protocol']=.JsonString~new(proto)
  d['source']=cidr
  d['sourceType']='CIDR_BLOCK'
  d['isStateless']=.json~false
  d['description']=desc
  if wordpos(proto, '6 17')>0 then do
    r=self~portRange(port)
    range=.directory~new
    range['min']=r[1]
    range['max']=r[2]
    opts=.directory~new
    opts['destinationPortRange']=range
    key='tcpOptions'
    if proto='17' then key='udpOptions'
    d[key]=opts
  end
  return d
::method nsgRuleJson
  use strict arg proto, cidr, port, desc
  d=self~ruleObject(proto, cidr, port, desc)
  d['direction']='INGRESS'
  return .json~new~toJson(.array~of(d))

::method observe
  use strict arg q, config, exec
  if q~noun q~verb<>'firewall reconcile' then return .nil
  if self~isSecList(q) then do
    r=exec~run(self~read(self~suffix(.array~of('oci', 'network', 'security-list', 'get', '--security-list-id', q~opt('scope'), '--output', 'json'), q), 'current security list'))
    if r~rc<>0 then self~failWith(r, 'oci security-list get failed')
    doc=.json~new~fromJson(r~out~makeString('L', ' '))
    return doc['data']
  end
  r=exec~run(self~read(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'list', '--nsg-id', q~opt('scope'), '--all', '--output', 'json'), q), 'current rules'))
  if r~rc<>0 then self~failWith(r, 'oci nsg rules list failed')
  doc=.json~new~fromJson(r~out~makeString('L', ' '))
  return doc['data']

::method plan
  use strict arg q, config, current
  steps=.array~new
  select
    when q~noun q~verb='machine list' then steps~append(self~read(self~suffix(.array~of('oci', 'compute', 'instance', 'list', '--compartment-id', q~opt('compartment'), '--all', '--output', 'json'), q)))
    when q~noun='machine', wordpos(q~verb, 'start stop reboot')>0 then do
      act=.array~of('START', 'SOFTSTOP', 'SOFTRESET')[wordpos(q~verb, 'start stop reboot')]
      steps~append(self~change(self~suffix(.array~of('oci', 'compute', 'instance', 'action', '--instance-id', self~handle(q), '--action', act), q)))
    end
    when q~noun q~verb='machine destroy' then steps~append(self~change(self~suffix(.array~of('oci', 'compute', 'instance', 'terminate', '--instance-id', self~handle(q), '--force'), q)))
    when q~noun q~verb='machine create' then do
      a=.array~of('oci', 'compute', 'instance', 'launch', '--compartment-id', q~opt('compartment'), '--availability-domain', q~opt('availability-domain'), '--subnet-id', q~opt('subnet'), '--image-id', q~opt('image'), '--shape', q~opt('size'), '--display-name', q~opt('name'))
      self~addOpt(a, '--ssh-authorized-keys-file', q~opt('ssh-key'))
      steps~append(self~change(self~suffix(a, q)))
    end
    when q~noun q~verb='firewall list' then do
      if self~isSecList(q) then steps~append(self~read(self~suffix(.array~of('oci', 'network', 'security-list', 'get', '--security-list-id', q~opt('scope'), '--output', 'json'), q)))
      else steps~append(self~read(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'list', '--nsg-id', q~opt('scope'), '--all', '--output', 'json'), q)))
    end
    when q~noun q~verb='firewall allow' then do
      desc=q~opt('description', q~opt('rule', 'cloudctl rule'))
      j=self~nsgRuleJson(self~ociProto(q), q~opt('source'), q~opt('port'), desc)
      steps~append(self~change(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'add', '--nsg-id', q~opt('scope'), '--security-rules', j), q)))
    end
    when q~noun q~verb='firewall revoke' then steps~append(self~change(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'remove', '--nsg-id', q~opt('scope'), '--security-rule-ids', '["'q~opt('rule')'"]', '--force'), q)))
    when q~noun q~verb='firewall reconcile' then do
      if self~isSecList(q) then steps=self~planSecList(q, current)
      else steps=self~planNsg(q, current)
    end
    otherwise nop
  end
  return steps

::method planNsg
  use strict arg q, current
  steps=.array~new
  proto=self~ociProto(q)
  port=q~opt('port')
  want=ccSourceSet(q)
  have=.array~new
  if current<>.nil then do rule over current
    if rule['direction']<>'INGRESS' then iterate
    if \self~matches(rule, proto, port) then iterate
    rid=rule['id']
    src=rule['source']
    if rid=.nil then iterate
    if src=.nil then iterate
    have~append(src)
    if want~hasItem(src) then iterate
    if q~addOnly then q~notes~append('kept (add-only):' src)
    else steps~append(self~change(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'remove', '--nsg-id', q~opt('scope'), '--security-rule-ids', '["'rid'"]', '--force'), q), 'REMOVE' src))
  end
  desc=q~opt('description', q~opt('rule', 'cloudctl reconciled source'))
  do cidr over want
    if have~hasItem(cidr) then iterate
    j=self~nsgRuleJson(proto, cidr, port, desc)
    steps~append(self~change(self~suffix(.array~of('oci', 'network', 'nsg', 'rules', 'add', '--nsg-id', q~opt('scope'), '--security-rules', j), q), 'add' cidr))
  end
  return steps

/* Security list: every rule outside this protocol/port slot is kept as it is; inside it, wanted sources are kept
 * once, the rest dropped, missing ones added.  One update, or no step at all when nothing changes. */
::method planSecList
  use strict arg q, current
  proto=self~ociProto(q)
  port=q~opt('port')
  want=ccSourceSet(q)
  keep=.array~new
  have=.array~new
  removed=0
  gone=.array~new
  rules=.nil
  if current<>.nil then rules=current['ingress-security-rules']
  if rules<>.nil then do rule over rules
    if self~matches(rule, proto, port) then do
      src=rule['source']
      if q~addOnly then do                        /* add-only: every current entry stays, duplicates too */
        if \want~hasItem(src), \have~hasItem(src) then q~notes~append('kept (add-only):' src)
        if \have~hasItem(src) then have~append(src)
        keep~append(ociCamel(rule))
        iterate
      end
      if \want~hasItem(src) then do
        removed=removed+1
        gone~append(src)
        iterate
      end
      if have~hasItem(src) then do
        removed=removed+1                         /* a duplicate of a wanted source */
        gone~append(src '(duplicate)')
        iterate
      end
      have~append(src)
    end
    keep~append(ociCamel(rule))
  end
  added=0
  desc=q~opt('description', q~opt('rule', 'cloudctl reconciled source'))
  do cidr over want
    if have~hasItem(cidr) then iterate
    keep~append(self~ruleObject(proto, cidr, port, desc))
    added=added+1
  end
  if added+removed=0 then return .array~new
  j=.json~new~toJson(keep)
  a=.array~of('oci', 'network', 'security-list', 'update', '--security-list-id', q~opt('scope'), '--ingress-security-rules', j, '--force', '--output', 'json')
  what='add' added 'remove' removed
  if removed>0 then what=what '-- REMOVE' gone~makeString('L', ',')
  return .array~of(self~change(self~suffix(a, q), what))

/* Same protocol and, for tcp/udp, the same destination port or range.  Reads kebab-case (CLI output). */
::method matches
  use strict arg rule, proto, port
  if rule['protocol']~string<>proto then return .false
  if wordpos(proto, '6 17')=0 then return .true
  opts=rule['tcp-options']
  if opts=.nil then opts=rule['udp-options']
  if opts=.nil then return .false
  range=opts['destination-port-range']
  if range=.nil then return .false
  r=self~portRange(port)
  if range['min']~string<>r[1] then return .false
  if range['max']~string<>r[2] then return .false
  return .true

/* kebab-case keys (CLI output) -> camelCase keys (CLI input model), recursively. */
/* Discovery: the compartment's instances -> the VNIC with this public address -> its NSGs or its subnet's
 * security lists.  One call per instance for its VNICs: compartments here are small. */
::method cliName
  return 'oci'
::method discoverNeeds
  return .array~of('region', 'compartment')
::method discover
  use strict arg q, config, exec, d
  addr=d~node['address']
  doc=self~readJson(exec, self~suffix(.array~of('oci', 'compute', 'instance', 'list', '--compartment-id', q~opt('compartment'), '--all', '--output', 'json'), q), 'instances in the compartment')
  do i over doc['data']
    if i['lifecycle-state']='TERMINATED' then iterate
    v=self~readJson(exec, self~suffix(.array~of('oci', 'compute', 'instance', 'list-vnics', '--instance-id', i['id'], '--output', 'json'), q), 'VNICs of' i['display-name'])
    do n over v['data']
      if ccStr(n['public-ip'])<>addr then iterate
      d~set('handle', i['id'])
      d~note('INFO', 'instance', 'instance' i['display-name'] 'is' i['lifecycle-state'])
      nsgs=n['nsg-ids']
      if \nsgs~isNil, nsgs~items>0 then do
        if nsgs~items=1 then d~set('scope', nsgs[1])
        else d~note('WARN', 'scope', nsgs~items 'NSGs on the VNIC:' nsgs~makeString('L', ' ')': set scope= to the one XTP belongs in')
        return
      end
      sub=self~readJson(exec, self~suffix(.array~of('oci', 'network', 'subnet', 'get', '--subnet-id', n['subnet-id'], '--output', 'json'), q), 'subnet')
      lists=sub['data']['security-list-ids']
      d~note('INFO', 'subnet', 'subnet' sub['data']['display-name'] sub['data']['cidr-block']': its security lists cover every machine on it')
      if lists~items=1 then d~set('scope', lists[1])
      else d~note('WARN', 'scope', lists~items 'security lists on the subnet:' lists~makeString('L', ' ')': set scope= to the one XTP belongs in')
      return
    end
  end
  d~note('STOP', 'notfound', 'no instance in the compartment has public address' addr)

::routine ociCamel public
  use strict arg v
  if v~isA(.array) then do
    out=.array~new
    do e over v
      out~append(ociCamel(e))
    end
    return out
  end
  if \v~isA(.MapCollection) then return v
  out=.directory~new
  do k over v~allIndexes
    if v[k]~isNil then iterate                     /* nulls from get are not written back */
    n=''
    up=.false
    do i=1 to k~length
      ch=k~subchar(i)
      if ch='-' then do
        up=.true
        iterate
      end
      if up then ch=ch~upper
      up=.false
      n=n||ch
    end
    out[n]=ociCamel(v[k])
  end
  return out

::routine ociProtocol
  use arg q, c
  if q~noun<>'firewall' then return ''
  if wordpos(q~verb, 'allow reconcile')=0 then return ''
  p=q~opt('protocol')~lower
  if wordpos(p, 'tcp udp icmp all any *')>0 then return ''
  if p~datatype('W') then do
    if p>=0, p<=255 then return ''
  end
  return 'oci protocol must be tcp, udp, icmp, all or 0-255 (got' p')'
::routine ociSecList
  use arg q, c
  if q~noun<>'firewall' then return ''
  if \q~opt('scope')~startsWith('ocid1.securitylist.') then return ''
  if wordpos(q~verb, 'list reconcile')>0 then return ''
  return 'oci firewall' q~verb 'on a security list is not supported: use reconcile'

::requires 'CloudCtl.cls'
::requires 'json.cls'
