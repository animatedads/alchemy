/* CloudGcp.cls -- Google Cloud plug-in for Cloud Control.  gcloud through the account wrapper (gcloud-account.sh).
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 * Commands follow alchemy_cloud_control dev4 (spec of 7 Nov), plus Spot and time-limit options on create.
 * Difference from dev4: reconcile with protocol all|any|* sends --rules all (gcloud's spelling), not '*'.
 */
::class CloudGcpProvider public subclass CloudProviderPlugin
::method init
  self~init:super('gcp')
::method operations
  return .array~of('machine list', 'machine create', 'machine start', 'machine stop', 'machine reboot', 'machine destroy', 'firewall list', 'firewall allow', 'firewall revoke', 'firewall reconcile')
::method optionNames
  return .array~of('project', 'zone', 'name', 'size', 'image', 'image-family', 'image-project', 'network', 'subnet', 'tags', 'scope', 'rule', 'protocol', 'port', 'source', 'sources', 'description', 'priority', 'target-tags', 'provisioning-model', 'max-run-duration', 'termination-time', 'instance-termination-action', 'preemption-notice-duration', 'boot-disk-size', 'boot-disk-type', 'metadata', 'metadata-from-file')
::method required
  use strict arg noun, verb
  select
    when noun='machine', wordpos(verb, 'start stop reboot destroy')>0 then return .array~of('machine')
    when noun verb='machine create' then return .array~of('name', 'zone', 'size')
    when noun verb='firewall list' then return .array~of('scope')
    when noun verb='firewall allow' then return .array~of('scope', 'rule', 'protocol', 'port', 'source')
    when noun verb='firewall reconcile' then return .array~of('scope', 'rule', 'protocol', 'sources')
    when noun verb='firewall revoke' then return .array~of('rule')
    otherwise return .array~new
  end
::method rules
  r=.array~new
  r~append(.CloudCtlRule~new('STOP', 'gcpaccount', 'gcp operations name an explicit account', .routines~gcpAccount))
  r~append(.CloudCtlRule~new('STOP', 'gcpwrapper', 'the gcloud account wrapper is executable', .routines~gcpWrapper))
  r~append(.CloudCtlRule~new('STOP', 'gcpzone', 'machine operations have a zone (--zone or a zone/name handle)', .routines~gcpZone))
  r~append(.CloudCtlRule~new('STOP', 'gcpimage', 'create names --image or --image-family', .routines~gcpImage))
  r~append(.CloudCtlRule~new('STOP', 'gcpspot', 'Spot and run-limit options are consistent', .routines~gcpSpot))
  r~append(.CloudCtlRule~new('INFO', 'gcpreset', 'reboot is a hard reset on GCP', .routines~gcpReset))
  return r

::method xtpPriority
  use strict arg kind
  return '900'
::method namedRules
  return .true
/* W ACCT ...: the wrapper and the account (configuration) name. */
::method gcloud
  use strict arg q, config
  w=value('ALCHEMY_GCLOUD_ACCOUNT_WRAPPER',,'ENVIRONMENT')
  if w='' then w=config~path('gcloud_wrapper', '$AUTOBUILD/gcloud-account.sh')
  acct=q~opt('account')
  if acct='' then acct=q~opt('configuration')
  if q~account<>.nil then do
    if q~account['configuration']<>.nil then acct=q~account['configuration']
  end
  return .array~of(w, acct)
::method withProject
  use strict arg argv, q
  return self~addOpt(argv, '--project', q~opt('project'))
/* zone/name handle: split when --zone is not given. */
::method machineAndZone
  use strict arg q
  m=self~handle(q)
  z=q~opt('zone')
  if z='', pos('/', m)>0 then parse var m z '/' m
  return .array~of(m, z)

::method observe
  use strict arg q, config, exec
  if q~noun q~verb<>'firewall reconcile' then return .nil
  a=self~gcloud(q, config)~~append('compute')~~append('firewall-rules')~~append('describe')~~append(q~opt('rule'))~~append('--format=json')~~append('--quiet')
  r=exec~run(self~read(self~withProject(a, q), 'the rule as it is now'))
  doc=self~observeRule(r, 'gcp firewall rule' q~opt('rule'))
  if doc=.nil then return .nil
  ev=.directory~new
  ev~sources=.array~new
  ranges=doc['sourceRanges']
  if ranges<>.nil then do c over ranges
    if \ev~sources~hasItem(c~string) then ev~sources~append(c~string)
  end
  spec=''
  allowed=doc['allowed']
  if allowed<>.nil then if allowed~items=1 then do
    spec=ccStr(allowed[1]['IPProtocol'])~lower
    ports=allowed[1]['ports']
    if ports<>.nil then if ports~items=1 then spec=spec':'ports[1]~string
  end
  ev~spec=spec
  return ev

::method plan
  use strict arg q, config, exists
  steps=.array~new
  g=self~gcloud(q, config)
  select
    when q~noun q~verb='machine list' then do
      a=g~~append('compute')~~append('instances')~~append('list')~~append('--format=json')~~append('--quiet')
      steps~append(self~read(self~withProject(a, q)))
    end
    when q~noun='machine', wordpos(q~verb, 'start stop reboot destroy')>0 then do
      gv=q~verb
      if gv='reboot' then gv='reset'
      if gv='destroy' then gv='delete'
      mz=self~machineAndZone(q)
      a=g~~append('compute')~~append('instances')~~append(gv)~~append(mz[1])~~append('--zone')~~append(mz[2])~~append('--quiet')
      steps~append(self~change(self~withProject(a, q)))
    end
    when q~noun q~verb='machine create' then do
      a=g~~append('compute')~~append('instances')~~append('create')~~append(q~opt('name'))
      a~~append('--zone')~~append(q~opt('zone'))~~append('--machine-type')~~append(q~opt('size'))~~append('--quiet')
      do f over .array~of('image', 'image-family', 'image-project', 'network', 'subnet', 'tags', 'provisioning-model', 'max-run-duration', 'termination-time', 'instance-termination-action', 'preemption-notice-duration', 'boot-disk-size', 'boot-disk-type', 'metadata', 'metadata-from-file')
        self~addOpt(a, '--'f, q~opt(f))
      end
      steps~append(self~change(self~withProject(a, q)))
    end
    when q~noun q~verb='firewall list' then do
      a=g~~append('compute')~~append('firewall-rules')~~append('list')~~append('--format=json')~~append('--filter=network:'q~opt('scope'))~~append('--quiet')
      steps~append(self~read(self~withProject(a, q)))
    end
    when q~noun q~verb='firewall allow' then do
      a=g~~append('compute')~~append('firewall-rules')~~append('create')~~append(q~opt('rule'))
      a~~append('--network')~~append(q~opt('scope'))~~append('--direction')~~append('INGRESS')~~append('--action')~~append('ALLOW')
      a~~append('--rules')~~append(q~opt('protocol')':'q~opt('port'))~~append('--source-ranges')~~append(q~opt('source'))~~append('--quiet')
      self~addOpt(a, '--description', q~opt('description'))
      self~addOpt(a, '--priority', q~opt('priority'))
      self~addOpt(a, '--target-tags', q~opt('target-tags'))
      steps~append(self~change(self~withProject(a, q)))
    end
    when q~noun q~verb='firewall revoke' then do
      a=g~~append('compute')~~append('firewall-rules')~~append('delete')~~append(q~opt('rule'))~~append('--quiet')
      steps~append(self~change(self~withProject(a, q)))
    end
    when q~noun q~verb='firewall reconcile' then do
      p=self~normalProtocol(q~opt('protocol'))
      if p='*' then p='all'
      spec=p
      if wordpos(p, 'tcp udp')>0 then spec=p':'q~opt('port')
      ns=self~namedSources(q, exists)
      if exists<>.nil, ns~added~items=0, ns~removed~items=0, exists~spec=spec then return steps
      if ns~final~items=0 then return steps
      csv=ns~final~makeString('L', ',')
      if exists<>.nil then do
        a=g~~append('compute')~~append('firewall-rules')~~append('update')~~append(q~opt('rule'))
        a~~append('--rules')~~append(spec)~~append('--source-ranges')~~append(csv)~~append('--quiet')
        self~addOpt(a, '--priority', q~opt('priority'))
        self~addOpt(a, '--target-tags', q~opt('target-tags'))
      end
      else do
        a=g~~append('compute')~~append('firewall-rules')~~append('create')~~append(q~opt('rule'))
        a~~append('--network')~~append(q~opt('scope'))~~append('--direction')~~append('INGRESS')~~append('--action')~~append('ALLOW')
        a~~append('--rules')~~append(spec)~~append('--source-ranges')~~append(csv)~~append('--quiet')
        self~addOpt(a, '--priority', q~opt('priority'))
        self~addOpt(a, '--target-tags', q~opt('target-tags'))
      end
      self~addOpt(a, '--description', q~opt('description'))
      steps~append(self~change(self~withProject(a, q), ns~purpose))
    end
    otherwise nop
  end
  return steps

/* Discovery: the instance whose external NAT address matches, in the account's project. */
::method cliName
  return 'gcloud'
::method discoverNeeds
  return .array~of('account')
::method discover
  use strict arg q, config, exec, d
  addr=d~node['address']
  a=self~gcloud(q, config)~~append('compute')~~append('instances')~~append('list')~~append('--format=json')~~append('--quiet')
  list=self~readJson(exec, self~withProject(a, q), 'instances in the project')
  do i over list
    do n over i['networkInterfaces']
      cfgs=n['accessConfigs']
      if cfgs~isNil then iterate
      do c over cfgs
        if ccStr(c['natIP'])<>addr then iterate
        d~set('handle', i['name'])
        d~set('zone', ccLastSegment(i['zone']))
        d~set('scope', ccLastSegment(n['network']))
        tags=''
        if \i['tags']~isNil then do
          t=i['tags']['items']
          if \t~isNil then tags=t~makeString('L', ',')
        end
        d~note('INFO', 'tags', 'instance' i['name'] 'carries network tags:' tags)
        d~note('INFO', 'state', 'instance' i['name'] 'is' i['status'])
        return
      end
    end
  end
  d~note('STOP', 'notfound', 'no instance in project' q~opt('project') 'has external address' addr)

::routine gcpAccount
  use arg q, c
  acct=q~opt('account')
  if acct='' then acct=q~opt('configuration')
  if acct='' then return 'gcp operations require explicit --account (an etc/accounts/NAME.account with provider=gcp)'
  if q~account=.nil then return 'no account file for' acct
  return ''
::routine gcpWrapper
  use arg q, c
  w=value('ALCHEMY_GCLOUD_ACCOUNT_WRAPPER',,'ENVIRONMENT')
  if w='' then w=c~config~path('gcloud_wrapper', '$AUTOBUILD/gcloud-account.sh')
  address system 'test -x' ccQuote(w)
  if rc<>0 then return 'gcloud account wrapper not executable:' w
  return ''
::routine gcpZone
  use arg q, c
  if q~noun<>'machine' then return ''
  if wordpos(q~verb, 'start stop reboot destroy')=0 then return ''
  if q~opt('zone')<>'' then return ''
  m=q~opt('machine')
  if q~machine<>.nil then do
    if q~machine['handle']<>.nil then m=q~machine['handle']
  end
  if pos('/', m)>0 then return ''
  return 'gcp machine' q~verb 'requires --zone or a zone/name handle'
::routine gcpImage
  use arg q, c
  if q~noun q~verb<>'machine create' then return ''
  if q~opt('image')<>'' then return ''
  if q~opt('image-family')<>'' then return ''
  return 'gcp machine create requires --image or --image-family'
/* Google: --instance-termination-action is required for a run limit on a standard VM (optional on Spot, default
 * STOP); --preemption-notice-duration only on Spot and only 0s or 120s; one of max-run-duration/termination-time. */
::routine gcpSpot
  use arg q, c
  if q~noun q~verb<>'machine create' then return ''
  spot=(q~opt('provisioning-model')~upper='SPOT')
  if q~opt('provisioning-model')<>'' then do
    if wordpos(q~opt('provisioning-model')~upper, 'SPOT STANDARD')=0 then return 'provisioning-model must be SPOT or STANDARD'
  end
  limit=(q~opt('max-run-duration')<>'' | q~opt('termination-time')<>'')
  if q~opt('max-run-duration')<>'', q~opt('termination-time')<>'' then return 'give --max-run-duration or --termination-time, not both'
  act=q~opt('instance-termination-action')~upper
  if act<>'', wordpos(act, 'STOP DELETE')=0 then return 'instance-termination-action must be STOP or DELETE'
  if limit, \spot, act='' then return 'a run limit on a standard VM needs --instance-termination-action STOP|DELETE'
  pn=q~opt('preemption-notice-duration')
  if pn<>'' then do
    if \spot then return '--preemption-notice-duration applies to Spot VMs only'
    if wordpos(pn, '0s 120s')=0 then return '--preemption-notice-duration must be 0s or 120s'
  end
  return ''
::routine gcpReset
  use arg q, c
  if q~noun q~verb='machine reboot' then return 'GCP reboot is "compute instances reset": a hard reset'
  return ''

::requires 'CloudCtl.cls'
::requires 'json.cls'
