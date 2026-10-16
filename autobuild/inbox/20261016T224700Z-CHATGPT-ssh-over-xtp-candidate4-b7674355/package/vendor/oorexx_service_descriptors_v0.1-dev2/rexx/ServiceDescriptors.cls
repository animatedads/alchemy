/* ServiceDescriptors.cls
 * Transport-neutral named-service registry for ooRexx.
 *
 * The registry intentionally contains no IP address fields.  A service names
 * the thing an application wants (ssh.management, radar.primary, etc.).
 * routePeer is a logical peer/route key consumed by a transport adapter.
 */

::class ServiceDescriptor public
::method init
  expose name operationalClass routePeer servicePoint enabled description
  use strict arg canonicalName, registeredClass, logicalRoutePeer='', namedServicePoint='', isEnabled=.true, text=''
  self~validateName(canonicalName)
  self~validateLogicalPeer(logicalRoutePeer)
  name=canonicalName
  if registeredClass~string~strip='' then raise syntax 93.900 array('Registered operational class must not be empty',canonicalName)
  operationalClass=registeredClass~string~strip
  routePeer=logicalRoutePeer
  if namedServicePoint='' then servicePoint=canonicalName
  else do
    self~validateName(namedServicePoint)
    servicePoint=namedServicePoint
  end
  enabled=isEnabled
  description=text
::attribute name get
::attribute operationalClass
::attribute routePeer
::attribute servicePoint
::attribute enabled
::attribute description

::method validateName
  use strict arg value
  if value='' then raise syntax 93.900 array('Service name must not be empty')
  if pos('09'x,value)>0 | pos('0a'x,value)>0 | pos('0d'x,value)>0 then raise syntax 93.900 array('Service name contains control separator',value)
  if self~looksLikeIp(value) then raise syntax 93.900 array('IP addresses are not service names',value)
  return 0

::method validateLogicalPeer
  use strict arg value
  if value='' then return 0
  if pos('09'x,value)>0 | pos('0a'x,value)>0 | pos('0d'x,value)>0 then raise syntax 93.900 array('Logical route peer contains control separator',value)
  if self~looksLikeIp(value) then raise syntax 93.900 array('IP addresses belong in the transport route table, not service descriptors',value)
  return 0

::method looksLikeIp private
  use strict arg value
  /* IPv4 dotted-decimal candidate. */
  dots=value~countstr('.')
  if dots=3 then do
    rest=value
    numeric=.true
    do 4
      parse var rest part '.' rest
      if part='' | datatype(part,'W')=0 | part<0 | part>255 then numeric=.false
    end
    if numeric then return .true
  end
  /* Service names use dotted symbolic labels.  Colon/bracket address literals
   * are reserved here so IPv6 never leaks into the service registry. */
  if pos('[',value)>0 | pos(']',value)>0 | value~countstr(':')>1 then return .true
  return .false

::method encode
  expose name operationalClass routePeer servicePoint enabled description
  tab='09'x
  state='0'; if enabled then state='1'
  return name||tab||operationalClass||tab||routePeer||tab||servicePoint||tab||state||tab||description

::method fromLine class
  use strict arg line
  tab='09'x
  parse var line name (tab) opClass (tab) routePeer (tab) servicePoint (tab) enabled (tab) description
  if name='' then return .nil
  return self~new(name,opClass,routePeer,servicePoint,enabled='1',description)


::class ServiceRegistry public
::method init
  expose path entries
  use strict arg registryPath=''
  if registryPath='' then do
    registryPath=value('OOREXX_SERVICE_REGISTRY',,'ENVIRONMENT')
    if registryPath='' then registryPath='services.tsv'
  end
  path=registryPath
  entries=.directory~new
  self~reload
::attribute path get

::method reload
  expose path entries
  entries=.directory~new
  if stream(path,'c','query exists')='' then return self
  call stream path,'c','open read'
  do while lines(path)>0
    line=linein(path)
    if line='' then iterate
    if line~left(1)='#' then iterate
    d=.ServiceDescriptor~fromLine(line)
    if d<>.nil then entries[d~name]=d
  end
  call stream path,'c','close'
  return self

::method save
  expose path entries
  tmp=path'.tmp'
  call stream tmp,'c','open write replace'
  call lineout tmp,'# oorexx.service.registry/1 - no IP addresses; routePeer is logical'
  names=.array~new
  do k over entries
    names~append(k)
  end
  names~sort
  do k over names
    call lineout tmp,entries[k]~encode
  end
  call stream tmp,'c','close'
  address command 'mv' self~quote(tmp) self~quote(path)
  if rc<>0 then raise syntax 93.900 array('Unable to replace service registry',path)
  return self

::method register
  expose entries
  use strict arg descriptor
  entries[descriptor~name]=descriptor
  self~save
  return descriptor

::method remove
  expose entries
  use strict arg name
  if \entries~hasIndex(name) then return .false
  entries~remove(name)
  self~save
  return .true

::method resolve
  expose entries
  use strict arg name, requireEnabled=.true
  if \entries~hasIndex(name) then return .nil
  d=entries[name]
  if requireEnabled then do
    if \d~enabled then return .nil
  end
  return d

::method enable
  use strict arg name
  d=self~resolve(name,.false); if d=.nil then return .false
  d~enabled=.true; self~save; return .true

::method disable
  use strict arg name
  d=self~resolve(name,.false); if d=.nil then return .false
  d~enabled=.false; self~save; return .true


::method setClass
  use strict arg name, className
  d=self~resolve(name,.false); if d==.nil then return .false
  if className~string~strip='' then raise syntax 93.900 array('Operational class must not be empty',name)
  d~operationalClass=className~string~strip; self~save; return .true

::method setPeer
  use strict arg name, logicalPeer
  d=self~resolve(name,.false); if d==.nil then return .false
  d~validateLogicalPeer(logicalPeer)
  d~routePeer=logicalPeer~string~strip; self~save; return .true

::method setPoint
  use strict arg name, point
  d=self~resolve(name,.false); if d==.nil then return .false
  d~validateName(point)
  d~servicePoint=point~string~strip; self~save; return .true

::method list
  expose entries
  a=.array~new
  names=.array~new
  do k over entries; names~append(k); end
  names~sort
  do k over names; a~append(entries[k]); end
  return a

::method servicesForPeer
  use strict arg logicalPeer, enabledOnly=.true
  a=.array~new
  do d over self~list
    if d~routePeer=logicalPeer then do
      if \enabledOnly | d~enabled then a~append(d)
    end
  end
  return a

::method quote private
  use strict arg value
  q=value~string~changestr("'", "'\\''")
  return "'"q"'"
