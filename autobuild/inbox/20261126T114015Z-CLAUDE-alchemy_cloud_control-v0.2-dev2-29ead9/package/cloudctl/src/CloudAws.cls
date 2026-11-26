/* CloudAws.cls -- AWS plug-in for Cloud Control (aws CLI v2).
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * Commands follow alchemy_cloud_control dev4 (spec of 7 Nov).  Every command ends [--region R] [--profile P]
 * (26 Nov 2026: no --no-cli-pager, which aws CLI v1 rejects; AWS_PAGER is set empty in each command's environment
 * instead, which v1 ignores and v2 honours.)  Difference from dev4: firewall allow no longer passes --description as --tag-specifications
 * (dev4 sent the raw description there, which the API rejects).
 */
::class CloudAwsProvider public subclass CloudProviderPlugin
::method init
  self~init:super('aws')
::method operations
  return .array~of('machine list', 'machine create', 'machine start', 'machine stop', 'machine reboot', 'machine destroy', 'firewall list', 'firewall allow', 'firewall revoke', 'firewall reconcile')
::method optionNames
  return .array~of('region', 'aws-profile', 'name', 'image', 'size', 'subnet', 'security-group', 'key-name', 'scope', 'rule', 'protocol', 'port', 'source', 'sources', 'description')
::method required
  use strict arg noun, verb
  select
    when noun='machine', wordpos(verb, 'start stop reboot destroy')>0 then return .array~of('machine')
    when noun verb='machine create' then return .array~of('name', 'image', 'size')
    when noun verb='firewall list' then return .array~of('scope')
    when noun verb='firewall allow' then return .array~of('scope', 'protocol', 'port', 'source')
    when noun verb='firewall reconcile' then return .array~of('scope', 'protocol', 'sources')
    when noun verb='firewall revoke' then return .array~of('scope', 'rule')
    otherwise return .array~new
  end
::method suffix
  use strict arg argv, q
  self~addOpt(argv, '--region', q~opt('region'))
  self~addOpt(argv, '--profile', q~opt('aws-profile'))
  return argv
/* Every aws command runs with AWS_PAGER empty: no pager in v2, and no flag v1 cannot parse. */
::method read
  use strict arg argv, purpose=''
  c=self~read:super(argv, purpose)
  c~env['AWS_PAGER']=''
  return c
::method change
  use strict arg argv, purpose=''
  c=self~change:super(argv, purpose)
  c~env['AWS_PAGER']=''
  return c
::method awsProto
  use strict arg q
  p=self~normalProtocol(q~opt('protocol'))
  if p='*' then return '-1'
  return p

/* reconcile: the group's current rules, parsed. */
::method observe
  use strict arg q, config, exec
  if q~noun q~verb<>'firewall reconcile' then return .nil
  a=.array~of('aws', 'ec2', 'describe-security-group-rules', '--filters', 'Name=group-id,Values='q~opt('scope'), '--output', 'json')
  r=exec~run(self~read(self~suffix(a, q), 'current rules'))
  if r~rc<>0 then self~failWith(r, 'aws describe-security-group-rules failed')
  doc=.json~new~fromJson(r~out~makeString('L', ' '))
  return doc['SecurityGroupRules']

::method plan
  use strict arg q, config, current
  steps=.array~new
  select
    when q~noun q~verb='machine list' then steps~append(self~read(self~suffix(.array~of('aws', 'ec2', 'describe-instances', '--output', 'json'), q)))
    when q~noun='machine', wordpos(q~verb, 'start stop reboot destroy')>0 then do
      v=.array~of('start-instances', 'stop-instances', 'reboot-instances', 'terminate-instances')[wordpos(q~verb, 'start stop reboot destroy')]
      steps~append(self~change(self~suffix(.array~of('aws', 'ec2', v, '--instance-ids', self~handle(q), '--output', 'json'), q)))
    end
    when q~noun q~verb='machine create' then do
      tag='ResourceType=instance,Tags=[{Key=Name,Value='q~opt('name')'}]'
      a=.array~of('aws', 'ec2', 'run-instances', '--image-id', q~opt('image'), '--instance-type', q~opt('size'), '--min-count', '1', '--max-count', '1', '--tag-specifications', tag, '--output', 'json')
      self~addOpt(a, '--subnet-id', q~opt('subnet'))
      self~addOpt(a, '--security-group-ids', q~opt('security-group'))
      self~addOpt(a, '--key-name', q~opt('key-name'))
      steps~append(self~change(self~suffix(a, q)))
    end
    when q~noun q~verb='firewall list' then steps~append(self~read(self~suffix(.array~of('aws', 'ec2', 'describe-security-group-rules', '--filters', 'Name=group-id,Values='q~opt('scope'), '--output', 'json'), q)))
    when q~noun q~verb='firewall allow' then steps~append(self~change(self~suffix(.array~of('aws', 'ec2', 'authorize-security-group-ingress', '--group-id', q~opt('scope'), '--protocol', q~opt('protocol'), '--port', q~opt('port'), '--cidr', q~opt('source'), '--output', 'json'), q)))
    when q~noun q~verb='firewall revoke' then steps~append(self~change(self~suffix(.array~of('aws', 'ec2', 'revoke-security-group-ingress', '--group-id', q~opt('scope'), '--security-group-rule-ids', q~opt('rule'), '--output', 'json'), q)))
    when q~noun q~verb='firewall reconcile' then do
      proto=self~awsProto(q)
      port=q~opt('port')
      want=ccSourceSet(q)
      have=.array~new
      if current<>.nil then do rule over current
        if \self~matches(rule, proto, port) then iterate
        cidr=self~cidrOf(rule)
        rid=rule['SecurityGroupRuleId']
        if rid=.nil | cidr='' then iterate
        have~append(cidr)
        if want~hasItem(cidr) then iterate
        if q~addOnly then q~notes~append('kept (add-only):' cidr)
        else steps~append(self~change(self~suffix(.array~of('aws', 'ec2', 'revoke-security-group-ingress', '--group-id', q~opt('scope'), '--security-group-rule-ids', rid, '--output', 'json'), q), 'REMOVE' cidr))
      end
      do cidr over want
        if have~hasItem(cidr) then iterate
        a=.array~of('aws', 'ec2', 'authorize-security-group-ingress', '--group-id', q~opt('scope'), '--protocol', proto, '--cidr', cidr, '--output', 'json')
        if wordpos(proto, 'tcp udp')>0 then self~addOpt(a, '--port', port)
        steps~append(self~change(self~suffix(a, q), 'add' cidr))
      end
    end
    otherwise nop
  end
  return steps

/* Ingress, same protocol, and for tcp/udp the exact port or port range. */
::method matches
  use strict arg rule, proto, port
  if rule['IsEgress']<>0 then return .false          /* a JsonBoolean compares as 0/1; its ~string does not */
  if rule['IpProtocol']~string<>proto then return .false
  if wordpos(proto, 'tcp udp')=0 then return .true
  r=self~portRange(port)
  if rule['FromPort']~string<>r[1] then return .false
  if rule['ToPort']~string<>r[2] then return .false
  return .true
::method cidrOf
  use strict arg rule
  if rule['CidrIpv4']<>.nil then return rule['CidrIpv4']
  if rule['CidrIpv6']<>.nil then return rule['CidrIpv6']
  return ''

/* Discovery: the instance with this public address in the machine's region, and its security group. */
::method cliName
  return 'aws'
::method discoverNeeds
  return .array~of('region')
::method discover
  use strict arg q, config, exec, d
  addr=d~node['address']
  a=.array~of('aws', 'ec2', 'describe-instances', '--filters', 'Name=ip-address,Values='addr, '--output', 'json')
  doc=self~readJson(exec, self~suffix(a, q), 'instance with public address' addr)
  found=.array~new
  do res over doc['Reservations']
    do i over res['Instances']
      found~append(i)
    end
  end
  if found~items=0 then do
    d~note('STOP', 'notfound', 'no instance has public address' addr 'in' q~opt('region'))
    return
  end
  if found~items>1 then do
    d~note('STOP', 'ambiguous', found~items 'instances have public address' addr)
    return
  end
  i=found[1]
  d~set('handle', i['InstanceId'])
  d~note('INFO', 'state', 'instance' i['InstanceId'] 'is' i['State']['Name'])
  sgs=i['SecurityGroups']
  if sgs~items=1 then do
    d~set('scope', sgs[1]['GroupId'])
    return
  end
  ids=''
  do g over sgs
    ids=ids g['GroupId']'('g['GroupName']')'
  end
  d~note('WARN', 'scope', sgs~items 'security groups:'ids': set scope= to the one XTP belongs in')

::requires 'CloudCtl.cls'
::requires 'json.cls'
