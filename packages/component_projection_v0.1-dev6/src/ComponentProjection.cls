/* ComponentProjection.cls
 * Optional component reporting/control capability.
 *
 * Canonical semantics are object-valued endpoints in a hierarchical namespace.
 * Filesystem/FUSE and SQL/object renderers are optional projections; neither is
 * required by participating components and neither becomes authority.
 */

::class ComponentProjectionBuild public
::constant VERSION "0.1-dev5"
::constant API "component.projection/0.1"

::class ComponentProjectionKind public
::constant REPORT "REPORT"
::constant CONTROL "CONTROL"
::constant DIRECTORY "DIRECTORY"

/* Components implement this seam only if they opt into Component Projection.
 * keyArg is provider-local and need not resemble a filesystem path. */
::class ComponentProjectionSource public
::method read
  use strict arg keyArg
  raise syntax 88.900 array("COMPONENT_PROJECTION_READ_NOT_IMPLEMENTED",keyArg)
::method write
  use strict arg keyArg,valueArg
  raise syntax 88.900 array("COMPONENT_PROJECTION_READ_ONLY",keyArg)

::class ComponentProjectionEndpoint public
::attribute component get
::attribute path get
::attribute kind get
::attribute source get
::attribute key get
::attribute mediaType get
::attribute description get
::attribute maxWriteBytes get
::attribute readable get
::method init
  expose component path kind source key mediaType description maxWriteBytes readable
  use strict arg componentArg,pathArg,kindArg,sourceArg,keyArg="",mediaTypeArg="text/plain",descriptionArg="",readableArg=.true,maxWriteBytesArg=65536
  component=componentArg~string~strip
  path=.ComponentProjectionPath~normalize(pathArg)
  kind=kindArg~string~upper
  source=sourceArg; key=keyArg; mediaType=mediaTypeArg~string; description=descriptionArg~string
  readable=(readableArg=.true)
  maxWriteBytes=maxWriteBytesArg+0
  if component="" then raise syntax 88.900 array("COMPONENT_PROJECTION_COMPONENT_REQUIRED")
  if source==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_SOURCE_REQUIRED")
  if kind<>.ComponentProjectionKind~REPORT & kind<>.ComponentProjectionKind~CONTROL then raise syntax 88.900 array("COMPONENT_PROJECTION_KIND_INVALID",kind)
  if kind=.ComponentProjectionKind~REPORT then readable=.true
  if maxWriteBytes<1 then raise syntax 88.900 array("COMPONENT_PROJECTION_MAX_WRITE_INVALID",maxWriteBytes)
::method writable
  expose kind
  return kind=.ComponentProjectionKind~CONTROL
::method readObject
  expose source key readable
  if eadable then raise syntax 88.900 array("COMPONENT_PROJECTION_WRITE_ONLY")
  return source~read(key)
::method writeObject
  expose source key kind
  use strict arg valueArg
  if kind<>.ComponentProjectionKind~CONTROL then raise syntax 88.900 array("COMPONENT_PROJECTION_READ_ONLY")
  return source~write(key,valueArg)
::method describe
  expose component path kind key mediaType description readable maxWriteBytes
  d=.directory~new
  d["schema"]="component.projection.endpoint/1"
  d["component"]=component; d["path"]=path; d["kind"]=kind; d["key"]=key
  d["media_type"]=mediaType; d["description"]=description
  d["readable"]=readable; d["writable"]=(kind=.ComponentProjectionKind~CONTROL)
  if kind=.ComponentProjectionKind~CONTROL then d["max_write_bytes"]=maxWriteBytes
  return d
::method asDirectory
  return self~describe

::class ComponentProjectionPath public
::method normalize class
  use strict arg pathArg
  p=pathArg~string~strip
  if p="" then return "/"
  if left(p,1)<>"/" then p="/"||p
  do while pos("//",p)>0; p=changestr("//",p,"/"); end
  if length(p)>1 & right(p,1)="/" then p=left(p,length(p)-1)
  /* Semantic names are not traversal expressions. */
  rest=p
  do while rest<>""
    if left(rest,1)="/" then rest=substr(rest,2)
    if rest="" then leave
    slash=pos("/",rest)
    if slash=0 then do; part=rest; rest=""; end
    else do; part=left(rest,slash-1); rest=substr(rest,slash); end
    if part="." | part=".." then raise syntax 88.900 array("COMPONENT_PROJECTION_PATH_INVALID",p)
  end
  return p
::method parent class
  use strict arg pathArg
  p=self~normalize(pathArg)
  if p="/" then return "/"
  q=lastpos("/",p)
  if q<=1 then return "/"
  return left(p,q-1)
::method name class
  use strict arg pathArg
  p=self~normalize(pathArg)
  if p="/" then return "/"
  q=lastpos("/",p)
  return substr(p,q+1)
::method join class
  use strict arg leftArg,rightArg
  l=self~normalize(leftArg); r=rightArg~string~strip
  do while r<>"" & left(r,1)="/"; r=substr(r,2); end
  if l="/" then return self~normalize("/"||r)
  return self~normalize(l||"/"||r)
::method under class
  use strict arg pathArg,rootArg
  p=self~normalize(pathArg); r=self~normalize(rootArg)
  if r="/" then return .true
  if p=r then return .true
  return left(p,length(r)+1)=r||"/"
::method relative class
  use strict arg pathArg,rootArg
  p=self~normalize(pathArg); r=self~normalize(rootArg)
  if .ComponentProjectionPath~under(p,r) then return .nil
  if p=r then return "/"
  return substr(p,length(r)+1)

::class ComponentProjectionRegistry public
::attribute generation get
::method init
  expose endpointMap directories generation
  endpointMap=.directory~new; directories=.directory~new; directories["/"]=.true; generation=0
::method registerReport
  use strict arg componentArg,pathArg,sourceArg,keyArg="",mediaTypeArg="text/plain",descriptionArg=""
  return self~register(.ComponentProjectionEndpoint~new(componentArg,pathArg,.ComponentProjectionKind~REPORT,sourceArg,keyArg,mediaTypeArg,descriptionArg,.true,65536))
::method registerControl
  use strict arg componentArg,pathArg,sourceArg,keyArg="",mediaTypeArg="text/plain",descriptionArg="",readableArg=.false,maxWriteBytesArg=65536
  return self~register(.ComponentProjectionEndpoint~new(componentArg,pathArg,.ComponentProjectionKind~CONTROL,sourceArg,keyArg,mediaTypeArg,descriptionArg,readableArg,maxWriteBytesArg))
::method register
  expose endpointMap directories generation
  use strict arg endpointArg
  p=endpointArg~path
  if endpointMap[p]<>.nil | directories[p]<>.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_PATH_EXISTS",p)
  endpointMap[p]=endpointArg
  self~rebuildDirectories
  generation=generation+1
  return endpointArg
::method unregister
  expose endpointMap generation
  use strict arg pathArg
  p=.ComponentProjectionPath~normalize(pathArg)
  if endpointMap[p]==.nil then return .false
  endpointMap~remove(p)
  self~rebuildDirectories
  generation=generation+1
  return .true
::method unregisterTree
  expose endpointMap generation
  use strict arg rootArg,componentArg=""
  root=.ComponentProjectionPath~normalize(rootArg); wanted=componentArg~string~strip
  remove=.array~new
  do p over endpointMap
    ep=endpointMap[p]
    if .ComponentProjectionPath~under(p,root) then do
      if wanted="" | ep~component=wanted then remove~append(p)
    end
  end
  if remove~items=0 then return 0
  do p over remove; endpointMap~remove(p); end
  self~rebuildDirectories
  generation=generation+1
  return remove~items
::method unregisterComponent
  expose endpointMap generation
  use strict arg componentArg
  wanted=componentArg~string~strip; remove=.array~new
  do p over endpointMap
    if endpointMap[p]~component=wanted then remove~append(p)
  end
  if remove~items=0 then return 0
  do p over remove; endpointMap~remove(p); end
  self~rebuildDirectories
  generation=generation+1
  return remove~items
::method rebuildDirectories private
  expose endpointMap directories
  directories=.directory~new; directories["/"]=.true
  do p over endpointMap
    parent=.ComponentProjectionPath~parent(p)
    do forever
      directories[parent]=.true
      if parent="/" then leave
      parent=.ComponentProjectionPath~parent(parent)
    end
  end
::method paths
  expose endpointMap
  a=.array~new
  keys=.array~new
  do p over endpointMap; keys~append(p); end
  keys~sort
  do p over keys; a~append(p); end
  return a
::method endpoint
  expose endpointMap
  use strict arg pathArg
  return endpointMap[.ComponentProjectionPath~normalize(pathArg)]
::method isDirectory
  expose directories
  use strict arg pathArg
  return directories[.ComponentProjectionPath~normalize(pathArg)]<>.nil
::method exists
  use strict arg pathArg
  return self~endpoint(pathArg)<>.nil | self~isDirectory(pathArg)
::method list
  expose endpointMap directories
  use strict arg pathArg
  p=.ComponentProjectionPath~normalize(pathArg)
  if directories[p]==.nil then return .nil
  seen=.directory~new; out=.array~new
  do child over directories
    if child=p then iterate
    if .ComponentProjectionPath~parent(child)=p then seen[.ComponentProjectionPath~name(child)]=.true
  end
  do epPath over endpointMap
    if .ComponentProjectionPath~parent(epPath)=p then seen[.ComponentProjectionPath~name(epPath)]=.true
  end
  do n over seen; out~append(n); end
  if out~items>1 then out~sort
  return out
::method endpoints
  expose endpointMap
  paths=.array~new; a=.array~new
  do p over endpointMap; paths~append(p); end
  if paths~items>1 then paths~sort
  do p over paths; a~append(endpointMap[p]); end
  return a
::method readObject
  use strict arg pathArg
  ep=self~endpoint(pathArg)
  if ep==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_NOT_FOUND",pathArg)
  return ep~readObject
::method writeObject
  use strict arg pathArg,valueArg
  ep=self~endpoint(pathArg)
  if ep==.nil then raise syntax 88.900 array("COMPONENT_PROJECTION_NOT_FOUND",pathArg)
  return ep~writeObject(valueArg)

/* Projection-neutral relation facade for SQL / object database adapters.
 * describeRows() never invokes component reads. snapshotRows()/row(...,.true)
 * explicitly materialise values, preserving typed objects. */
::class ComponentProjectionRelation public
::attribute registry get
::method init
  expose registry
  use strict arg registryArg
  registry=registryArg
::method schema
  d=.directory~new
  d["relation"]="component_projection"
  cols=.array~new
  cols~append("component"); cols~append("path"); cols~append("kind"); cols~append("readable"); cols~append("writable"); cols~append("media_type"); cols~append("value")
  d["columns"]=cols
  return d
::method describeRows
  expose registry
  a=.array~new
  do ep over registry~endpoints; a~append(ep~describe); end
  return a
::method snapshotRows
  expose registry
  a=.array~new
  do ep over registry~endpoints
    r=ep~describe
    if ep~readable then do; r["value"]=ep~readObject; r["value_available"]=.true; end
    else do; r["value"]=.nil; r["value_available"]=.false; end
    a~append(r)
  end
  return a
::method rows
  return self~snapshotRows
::method row
  expose registry
  use strict arg pathArg,includeValueArg=.true
  ep=registry~endpoint(pathArg)
  if ep==.nil then return .nil
  r=ep~describe
  if includeValueArg=.true & ep~readable then do; r["value"]=ep~readObject; r["value_available"]=.true; end
  else do; r["value"]=.nil; r["value_available"]=.false; end
  return r

/* Deterministic text renderer for Unix-like byte streams.  Typed object values
 * remain canonical; this is only the filesystem presentation. */
::class ComponentProjectionText public
::method render class
  use strict arg valueArg
  if valueArg==.nil then return ""||d2c(10)
  if valueArg~isA(.Directory) then do
    keys=.array~new; out=""
    do k over valueArg; keys~append(k~string); end
    if keys~items>1 then keys~sort
    do k over keys; out=out||k||"="||self~scalar(valueArg[k])||d2c(10); end
    return out
  end
  if valueArg~isA(.Array) then do
    out=""
    do v over valueArg; out=out||self~scalar(v)||d2c(10); end
    return out
  end
  return valueArg~string||d2c(10)
::method scalar class private
  use strict arg v
  if v==.nil then return ""
  return v~string

/* Convenience source for already-resident Directory-backed facts.  Production
 * adapters should normally resolve against the component's authoritative object
 * or existing operation seam instead of duplicating state here. */
::class ComponentProjectionDirectorySource subclass ComponentProjectionSource public
::attribute values get
::attribute writes get
::method init
  expose values writes
  use arg initialArg=.nil
  if initialArg==.nil then values=.directory~new; else values=initialArg
  writes=.array~new
::method read
  expose values
  use strict arg keyArg
  return values[keyArg]
::method write
  expose values writes
  use strict arg keyArg,valueArg
  values[keyArg]=valueArg
  writes~append(keyArg||"="||valueArg~string)
  return .true
