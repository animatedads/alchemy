/* CloudAzure.cls -- Azure plug-in for Cloud Control (az CLI).  Firewall = NSG rules; --scope GROUP:NSG.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 * Commands follow alchemy_cloud_control dev4 (spec of 7 Nov).  stop = deallocate (a stopped VM still bills).
 * Reconcile replaces the named rule's whole source list (Azure NSG rules carry the list), creating it if absent.
 */
::class CloudAzureProvider public subclass CloudProviderPlugin
::method init
  self~init:super('azure')
::method operations
  return .array~of('machine list', 'machine create', 'machine start', 'machine stop', 'machine reboot', 'machine destroy', 'firewall list', 'firewall allow', 'firewall revoke', 'firewall reconcile')
::method optionNames
  return .array~of('subscription', 'group', 'name', 'image', 'size', 'region', 'zone', 'admin-user', 'ssh-key', 'security-group', 'scope', 'rule', 'protocol', 'port', 'source', 'sources', 'description', 'priority')
::method required
  use strict arg noun, verb
  select
    when noun='machine', wordpos(verb, 'start stop reboot destroy')>0 then return .array~of('machine')
    when noun verb='machine create' then return .array~of('group', 'name', 'image', 'size')
    when noun verb='firewall list' then return .array~of('scope')
    when noun verb='firewall allow' then return .array~of('scope', 'rule', 'protocol', 'port', 'source')
    when noun verb='firewall reconcile' then return .array~of('scope', 'rule', 'protocol', 'sources')
    when noun verb='firewall revoke' then return .array~of('scope', 'rule')
    otherwise return .array~new
  end
::method rules
  return .array~of(.CloudCtlRule~new('STOP', 'azscope', 'firewall --scope is GROUP:NSG', .routines~azScope))
/* Azure NSG rules cannot select IP protocol 36: raw XTP is admitted by a source-scoped any-protocol rule. */
::method xtpProtocol
  use strict arg kind
  if kind='raw' then return 'all'
  return 'udp'
::method xtpPriority
  use strict arg kind
  select
    when kind='peers-raw' then return '250'
    when kind='peers-udp' then return '249'
    when kind='ws-raw' then return '248'
    when kind='ws-udp' then return '247'
    otherwise return ''
  end
::method namedRules
  return .true
::method sub
  use strict arg argv, q
  return self~addOpt(argv, '--subscription', q~opt('subscription'))
::method scopeParts
  use strict arg q
  parse value q~opt('scope') with g ':' n
  return .array~of(g, n)
::method azProto
  use strict arg q
  p=self~normalProtocol(q~opt('protocol'))
  select
    when p='tcp' then return 'Tcp'
    when p='udp' then return 'Udp'
    when p='icmp' then return 'Icmp'
    when p='ah' then return 'Ah'
    when p='esp' then return 'Esp'
    otherwise return p
  end

::method observe
  use strict arg q, config, exec
  if q~noun q~verb<>'firewall reconcile' then return .nil
  s=self~scopeParts(q)
  a=.array~of('az', 'network', 'nsg', 'rule', 'show', '--resource-group', s[1], '--nsg-name', s[2], '--name', q~opt('rule'), '--output', 'json', '--only-show-errors')
  r=exec~run(self~read(self~sub(a, q), 'the rule as it is now'))
  doc=self~observeRule(r, 'azure NSG rule' q~opt('rule'))
  if doc=.nil then return .nil
  ev=.directory~new
  ev~sources=.array~new
  one=ccStr(doc['sourceAddressPrefix'])
  if one<>'' then ev~sources~append(one)
  many=doc['sourceAddressPrefixes']
  if many<>.nil then do c over many
    if \ev~sources~hasItem(c~string) then ev~sources~append(c~string)
  end
  ev~protocol=ccStr(doc['protocol'])~lower
  ports=ccStr(doc['destinationPortRange'])
  more=doc['destinationPortRanges']
  if more<>.nil then do c over more
    ports=(ports c~string)~strip
  end
  ev~ports=ports~space(1)~changeStr(' ', ',')
  ev~priority=ccStr(doc['priority'])
  return ev

::method plan
  use strict arg q, config, exists
  steps=.array~new
  select
    when q~noun q~verb='machine list' then do
      a=.array~of('az', 'vm', 'list', '--show-details', '--output', 'json', '--only-show-errors')
      self~sub(a, q)
      self~addOpt(a, '--resource-group', q~opt('group'))
      steps~append(self~read(a))
    end
    when q~noun='machine', wordpos(q~verb, 'start stop reboot destroy')>0 then do
      v=.array~of('start', 'deallocate', 'restart', 'delete')[wordpos(q~verb, 'start stop reboot destroy')]
      a=.array~of('az', 'vm', v, '--ids', self~handle(q), '--only-show-errors')
      if q~verb='destroy' then a~append('--yes')
      steps~append(self~change(self~sub(a, q)))
    end
    when q~noun q~verb='machine create' then do
      a=.array~of('az', 'vm', 'create', '--resource-group', q~opt('group'), '--name', q~opt('name'), '--image', q~opt('image'), '--size', q~opt('size'), '--only-show-errors')
      self~addOpt(a, '--location', q~opt('region'))
      self~addOpt(a, '--zone', q~opt('zone'))
      self~addOpt(a, '--admin-username', q~opt('admin-user'))
      self~addOpt(a, '--ssh-key-values', q~opt('ssh-key'))
      self~addOpt(a, '--nsg', q~opt('security-group'))
      steps~append(self~change(self~sub(a, q)))
    end
    when q~noun q~verb='firewall list' then do
      s=self~scopeParts(q)
      steps~append(self~read(self~sub(.array~of('az', 'network', 'nsg', 'rule', 'list', '--resource-group', s[1], '--nsg-name', s[2], '--output', 'json', '--only-show-errors'), q)))
    end
    when q~noun q~verb='firewall allow' then do
      s=self~scopeParts(q)
      a=.array~of('az', 'network', 'nsg', 'rule', 'create', '--resource-group', s[1], '--nsg-name', s[2], '--name', q~opt('rule'), '--priority', q~opt('priority', '3000'), '--access', 'Allow', '--direction', 'Inbound', '--protocol', q~opt('protocol'), '--source-address-prefixes', q~opt('source'), '--destination-port-ranges', q~opt('port'), '--only-show-errors')
      self~addOpt(a, '--description', q~opt('description'))
      steps~append(self~change(self~sub(a, q)))
    end
    when q~noun q~verb='firewall revoke' then do
      s=self~scopeParts(q)
      steps~append(self~change(self~sub(.array~of('az', 'network', 'nsg', 'rule', 'delete', '--resource-group', s[1], '--nsg-name', s[2], '--name', q~opt('rule'), '--only-show-errors'), q)))
    end
    when q~noun q~verb='firewall reconcile' then do
      s=self~scopeParts(q)
      ns=self~namedSources(q, exists)
      verb='create'
      if exists<>.nil then do
        verb='update'
        same=(ns~added~items=0 & ns~removed~items=0)
        if same, exists~protocol=self~azProto(q)~lower, exists~ports=q~opt('port', '*') then return steps
      end
      if ns~final~items=0 then return steps
      a=.array~of('az', 'network', 'nsg', 'rule', verb, '--resource-group', s[1], '--nsg-name', s[2], '--name', q~opt('rule'), '--priority', q~opt('priority', '3000'), '--access', 'Allow', '--direction', 'Inbound', '--protocol', self~azProto(q), '--source-address-prefixes')
      do cidr over ns~final
        a~append(cidr)
      end
      a~append('--destination-port-ranges')
      a~append(q~opt('port', '*'))
      a~append('--only-show-errors')
      self~addOpt(a, '--description', q~opt('description'))
      steps~append(self~change(self~sub(a, q), ns~purpose))
    end
    otherwise nop
  end
  return steps

/* Discovery: the public IP -> its NIC -> the VM and the NSG.  An NSG on the NIC is the scope; an NSG on the
 * subnet as well also filters the same traffic, so it is reported. */
::method cliName
  return 'az'
::method discover
  use strict arg q, config, exec, d
  addr=d~node['address']
  a=.array~of('az', 'network', 'public-ip', 'list', '--query', "[?ipAddress=='"addr"']", '--output', 'json', '--only-show-errors')
  ips=self~readJson(exec, self~sub(a, q), 'public IP' addr)
  if ips~items=0 then do
    d~note('STOP', 'notfound', 'no public IP resource has address' addr)
    return
  end
  ipc=ips[1]['ipConfiguration']
  if ipc~isNil then do
    d~note('STOP', 'detached', 'public IP' addr 'is not attached to anything')
    return
  end
  ipcId=ipc['id']
  at=pos('/ipConfigurations/', ipcId)
  if at=0 then do
    d~note('STOP', 'notnic', 'public IP' addr 'is attached to' ipcId)
    return
  end
  nicId=ipcId~left(at-1)
  if pos('/networkInterfaces/', nicId)=0 then do
    d~note('STOP', 'notnic', 'public IP' addr 'is attached to' nicId '(not a VM network interface)')
    return
  end
  nic=self~readJson(exec, self~sub(.array~of('az', 'network', 'nic', 'show', '--ids', nicId, '--output', 'json', '--only-show-errors'), q), 'network interface')
  vm=nic['virtualMachine']
  if \vm~isNil then d~set('handle', vm['id'])
  nicNsg=nic['networkSecurityGroup']
  subNsg=.nil
  cfgs=nic['ipConfigurations']
  if \cfgs~isNil, cfgs~items>0 then do
    subnetId=cfgs[1]['subnet']['id']
    sub=self~readJson(exec, self~sub(.array~of('az', 'network', 'vnet', 'subnet', 'show', '--ids', subnetId, '--output', 'json', '--only-show-errors'), q), 'subnet')
    subNsg=sub['networkSecurityGroup']
  end
  select
    when \nicNsg~isNil then do
      d~set('scope', azScopeOf(nicNsg['id']))
      if \subNsg~isNil then d~note('WARN', 'subnetnsg', 'the subnet NSG' azScopeOf(subNsg['id']) 'filters the same traffic: XTP must be allowed there too')
    end
    when \subNsg~isNil then do
      d~set('scope', azScopeOf(subNsg['id']))
      d~note('INFO', 'subnetnsg', 'the NSG is on the subnet, so a change there covers every machine on it')
    end
    otherwise do
      d~set('scope', 'none')
      d~note('WARN', 'nonsg', 'no NSG on the NIC or the subnet: Azure filters nothing inbound here')
    end
  end

/* .../resourceGroups/G/providers/Microsoft.Network/networkSecurityGroups/N -> G:N */
::routine azScopeOf
  use strict arg id
  parse var id . '/resourceGroups/' g '/' .
  if g='' then parse var id . '/resourcegroups/' g '/' .
  return g':'ccLastSegment(id)
::routine azScope
  use arg q, c
  if q~noun<>'firewall' then return ''
  s=q~opt('scope')
  if s='' then return ''
  parse var s g ':' n
  if g='' | n='' then return 'azure firewall --scope must be GROUP:NSG (got' s')'
  return ''

::requires 'CloudCtl.cls'
::requires 'json.cls'
