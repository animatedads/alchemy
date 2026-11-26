/* CloudVultr.cls -- Vultr plug-in for Cloud Control, on the Vultr API v2 (REST).
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * 26 Nov 2026, Claude (Opus 5.5): --add-only; removals named in every plan; error reasons from the end of stderr.
 * Tom's decision (7 Nov): REST, as the workstation cloudctl.sh did, not vultr-cli (which may not be installed).
 * Every call goes through bin/vultr-api.rex: METHOD PATH [JSON body, base64].  The helper finds the API key
 * (VULTR_API_KEY_FILE, VULTR_API_KEY, ~/.config/vultr/api-key) and gives it to curl on stdin, so the key is
 * never in argv, the ledger or the log.  cloudctl.conf vultr_api_key_file= sets VULTR_API_KEY_FILE per command.
 * The kit rule checks curl; the vultrkey rule asks the helper whether a usable key exists before any call.
 *
 *   machine list         GET    /instances?per_page=500
 *   machine start|stop   POST   /instances/ID/start | /instances/ID/halt
 *   machine reboot       POST   /instances/ID/reboot
 *   machine destroy      DELETE /instances/ID
 *   machine create       POST   /instances  {region, plan, label, os_id|image_id, sshkey_id[], firewall_group_id, tags[]}
 *   firewall list        GET    /firewalls/G/rules?per_page=500
 *   firewall allow       POST   /firewalls/G/rules  {ip_type, protocol, subnet, subnet_size, port, notes}
 *   firewall revoke      DELETE /firewalls/G/rules/RULE
 *   firewall reconcile   list, then the deletes and creates that make the source set exact
 *   discover             GET    /instances?main_ip=ADDR&per_page=500
 *
 * Firewall groups select tcp, udp, icmp, gre, esp and ah only: raw XTP (IP protocol 36) is the host firewall's.
 * A port range is written N:M.
 */
::class CloudVultrProvider public subclass CloudProviderPlugin
::method init
  self~init:super('vultr')
::method operations
  return .array~of('machine list', 'machine create', 'machine start', 'machine stop', 'machine reboot', 'machine destroy', 'firewall list', 'firewall allow', 'firewall revoke', 'firewall reconcile')
::method optionNames
  return .array~of('region', 'size', 'name', 'os', 'image', 'ssh-keys', 'firewall-group', 'tags', 'scope', 'rule', 'protocol', 'port', 'source', 'sources', 'description')
::method required
  use strict arg noun, verb
  select
    when noun='machine', wordpos(verb, 'start stop reboot destroy')>0 then return .array~of('machine')
    when noun verb='machine create' then return .array~of('name', 'region', 'size')
    when noun verb='firewall list' then return .array~of('scope')
    when noun verb='firewall allow' then return .array~of('scope', 'protocol', 'source')
    when noun verb='firewall reconcile' then return .array~of('scope', 'protocol', 'sources')
    when noun verb='firewall revoke' then return .array~of('scope', 'rule')
    otherwise return .array~new
  end
::method rules
  r=.array~new
  r~append(.CloudCtlRule~new('STOP', 'vultros', 'create names --os or --image', .routines~vultrOs))
  r~append(.CloudCtlRule~new('STOP', 'vultrcidr', 'firewall allow source is a CIDR with a prefix length', .routines~vultrCidr))
  r~append(.CloudCtlRule~new('STOP', 'vultrkey', 'a usable Vultr API key exists', .routines~vultrKey))
  return r
::method cliName
  return 'curl'
::method xtpProtocol
  use strict arg kind
  if kind='raw' then return ''
  return 'udp'
::method vultrPort
  use strict arg port
  return port~changeStr('-', ':')

/* One API call as a command: rexx bin/vultr-api.rex METHOD PATH [BODY]. */
::method api
  use strict arg config, method, path, body=.nil
  a=.array~of('rexx', config~home'/bin/vultr-api.rex', method, path)
  if body<>.nil then a~append(.json~new~toJson(body)~encodeBase64)
  return a
::method withKey
  use strict arg command, config
  f=config~setting('vultr_api_key_file', '')
  if f<>'' then command~env['VULTR_API_KEY_FILE']=config~expand(f)
  return command
::method get
  use strict arg config, path, purpose=''
  return self~withKey(self~read(self~api(config, 'GET', path), purpose), config)
/* A change; the body travels base64-encoded, so its JSON is shown in the purpose for review. */
::method call
  use strict arg config, method, path, body=.nil, purpose=''
  if body<>.nil then purpose=(purpose 'body' .json~new~toJson(body))~strip
  return self~withKey(self~change(self~api(config, method, path, body), purpose), config)

::method ruleBody
  use strict arg q, cidr
  parse var cidr addr '/' bits
  if bits='' then bits='32'
  b=.directory~new
  b['ip_type']='v4'
  if pos(':', addr)>0 then b['ip_type']='v6'
  b['protocol']=q~opt('protocol')~lower
  b['subnet']=.JsonString~new(addr)
  b['subnet_size']=bits
  if q~opt('port')<>'' then b['port']=.JsonString~new(self~vultrPort(q~opt('port')))
  notes=q~opt('description', q~opt('rule'))
  if notes<>'' then b['notes']=.JsonString~new(notes)
  return b

::method observe
  use strict arg q, config, exec
  if q~noun q~verb<>'firewall reconcile' then return .nil
  r=exec~run(self~get(config, '/firewalls/'q~opt('scope')'/rules?per_page=500', 'current rules'))
  if r~rc<>0 then self~failWith(r, 'vultr firewall rule list failed')
  doc=.json~new~fromJson(r~out~makeString('L', ' '))
  return doc['firewall_rules']

::method plan
  use strict arg q, config, current
  steps=.array~new
  select
    when q~noun q~verb='machine list' then steps~append(self~get(config, '/instances?per_page=500'))
    when q~noun='machine', wordpos(q~verb, 'start stop reboot')>0 then do
      act=.array~of('start', 'halt', 'reboot')[wordpos(q~verb, 'start stop reboot')]
      steps~append(self~call(config, 'POST', '/instances/'self~handle(q)'/'act))
    end
    when q~noun q~verb='machine destroy' then steps~append(self~call(config, 'DELETE', '/instances/'self~handle(q)))
    when q~noun q~verb='machine create' then steps~append(self~call(config, 'POST', '/instances', self~createBody(q)))
    when q~noun q~verb='firewall list' then steps~append(self~get(config, '/firewalls/'q~opt('scope')'/rules?per_page=500'))
    when q~noun q~verb='firewall allow' then steps~append(self~call(config, 'POST', '/firewalls/'q~opt('scope')'/rules', self~ruleBody(q, q~opt('source'))))
    when q~noun q~verb='firewall revoke' then steps~append(self~call(config, 'DELETE', '/firewalls/'q~opt('scope')'/rules/'q~opt('rule')))
    when q~noun q~verb='firewall reconcile' then do
      want=ccSourceSet(q)
      have=.array~new
      if current<>.nil then do rule over current
        if \self~matches(rule, q~opt('protocol'), q~opt('port')) then iterate
        cidr=self~cidrOf(rule)
        rid=rule['id']
        if rid=.nil then iterate
        have~append(cidr)
        if want~hasItem(cidr) then iterate
        if q~addOnly then q~notes~append('kept (add-only):' cidr)
        else steps~append(self~call(config, 'DELETE', '/firewalls/'q~opt('scope')'/rules/'rid, .nil, 'REMOVE' cidr))
      end
      do cidr over want
        if have~hasItem(cidr) then iterate
        steps~append(self~call(config, 'POST', '/firewalls/'q~opt('scope')'/rules', self~ruleBody(q, cidr), 'add' cidr))
      end
    end
    otherwise nop
  end
  return steps

::method createBody
  use strict arg q
  b=.directory~new
  b['region']=q~opt('region')
  b['plan']=q~opt('size')
  b['label']=.JsonString~new(q~opt('name'))
  if q~opt('os')<>'' then b['os_id']=q~opt('os')
  if q~opt('image')<>'' then b['image_id']=.JsonString~new(q~opt('image'))
  if q~opt('firewall-group')<>'' then b['firewall_group_id']=.JsonString~new(q~opt('firewall-group'))
  if q~opt('ssh-keys')<>'' then b['sshkey_id']=self~list(q~opt('ssh-keys'))
  if q~opt('tags')<>'' then b['tags']=self~list(q~opt('tags'))
  return b
::method list
  use strict arg csv
  a=.array~new
  do while csv<>''
    parse var csv item ',' csv
    if item~strip<>'' then a~append(.JsonString~new(item~strip))
  end
  return a

::method matches
  use strict arg rule, proto, port
  if rule['protocol']=.nil then return .false
  if rule['protocol']~string~lower<>proto~lower then return .false
  if wordpos(proto~lower, 'tcp udp')=0 then return .true
  if ccStr(rule['port'])<>self~vultrPort(port) then return .false
  return .true
::method cidrOf
  use strict arg rule
  return ccStr(rule['subnet'])'/'ccStr(rule['subnet_size'])

/* Discovery: the instance whose main IP matches, and its firewall group ('none' when it has none). */
::method discover
  use strict arg q, config, exec, d
  addr=d~node['address']
  r=exec~run(self~get(config, '/instances?main_ip='addr'&per_page=500', 'instance with main IP' addr))
  if r~rc<>0 then raise syntax 40.900 array('vultr instance list failed rc='r~rc)
  doc=.json~new~fromJson(r~out~makeString('L', ' '))
  do i over doc['instances']
    if ccStr(i['main_ip'])<>addr then iterate
    d~set('handle', i['id'])
    fg=ccStr(i['firewall_group_id'])
    if fg='' then do
      d~set('scope', 'none')
      d~note('WARN', 'nofirewall', 'no firewall group: Vultr filters nothing inbound here; the host firewall carries XTP')
    end
    else d~set('scope', fg)
    d~note('INFO', 'instance', 'instance' ccStr(i['label']) 'in' ccStr(i['region']) 'is' ccStr(i['power_status']))
    return
  end
  d~note('STOP', 'notfound', 'no instance has main IP' addr)

::routine vultrOs
  use arg q, c
  if q~noun q~verb<>'machine create' then return ''
  if q~opt('os')<>'' then return ''
  if q~opt('image')<>'' then return ''
  return 'vultr machine create requires --os or --image'
::routine vultrCidr
  use arg q, c
  if q~noun q~verb<>'firewall allow' then return ''
  if pos('/', q~opt('source'))=0 then return 'vultr firewall source must be CIDR'
  return ''
/* The helper's --check: a key file of mode 600/400, or VULTR_API_KEY.  The helper's reason comes back. */
::routine vultrKey
  use arg q, c
  helper=c~config~home'/bin/vultr-api.rex'
  f=c~config~setting('vultr_api_key_file', '')
  prefix=''
  if f<>'' then prefix='env VULTR_API_KEY_FILE='ccQuote(c~config~expand(f))
  whyFile=c~config~path('work_dir', '$CLOUDCTL/var')'/.vultrkey.'SysQueryProcess('PID')
  call SysMkDir filespec('L', whyFile)
  address system prefix 'rexx' ccQuote(helper) '--check </dev/null >/dev/null 2>'ccQuote(whyFile)
  ok=(rc=0)
  why=ccReadLines(whyFile)
  call SysFileDelete whyFile
  if ok then return ''
  if why~items>0 then return why[1]
  return 'no usable Vultr API key'

::requires 'CloudCtl.cls'
::requires 'json.cls'
