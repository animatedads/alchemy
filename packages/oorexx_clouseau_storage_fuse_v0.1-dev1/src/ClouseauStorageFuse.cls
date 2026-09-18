/* Inspector Clouseau -> Storage Fabric FUSE read-only projection.
 * API: storage.fabric.clouseau-observation/0.1
 *
 * Authority boundary:
 *   Inspector Clouseau owns observation of the running ooRexx object universe.
 *   Storage Fabric owns filesystem projection semantics.
 *   This bridge never writes into inspected objects and exposes no mutation API.
 */

::class ClouseauStorageFuseBuild public
::constant VERSION "0.1-dev1"
::constant API "storage.fabric.clouseau-observation/0.1"

::class ClouseauStorageFuseBridge public
::attribute inspector get
::attribute rootPath get
::attribute generation get
::attribute store get
::attribute fuse get

::method init
  expose inspector rootPath generation store fuse lastSnapshot
  use strict arg inspectorArg, rootArg="/live/clouseau"
  if inspectorArg==.nil then raise syntax 88.900 array("Inspector Clouseau instance is required")
  inspector=inspectorArg
  rootPath=self~normRoot(rootArg)
  generation=0
  store=.StorageFuseGenerationStore~new
  fuse=.StorageFuseOperationCore~new(store)
  lastSnapshot=.nil
  self~mkdirTree(rootPath)

::method refresh public
  expose inspector generation lastSnapshot
  if inspector~hasMethod("REFRESHOBSERVATION") then ignore=inspector~refreshObservation
  snap=inspector~snapshot
  lastSnapshot=snap
  generation=generation+1
  self~publishSnapshot(snap~asDirectory)
  return generation

::method lastSnapshot public
  expose lastSnapshot
  return lastSnapshot

::method publishSnapshot private
  expose rootPath generation
  use strict arg data
  self~putFile(rootPath||"/schema", self~text(data~at("schema")))
  self~putFile(rootPath||"/generated_at", self~text(data~at("generated_at")))
  self~putFile(rootPath||"/projection_generation", generation)
  self~publishRoots(data)
  self~publishObjects(data)
  self~publishClasses(data)
  self~publishTriggers(data)
  return self

::method publishRoots private
  expose rootPath
  use strict arg data
  base=rootPath||"/roots"
  self~mkdirTree(base)
  roots=data~at("roots")
  if roots==.nil then return
  do rec over roots
    if rec==.nil then iterate
    oid=self~safeName(rec~at("oid"))
    if oid="" then iterate
    p=base||"/"||oid
    self~mkdirTree(p)
    self~putFile(p||"/name",self~text(rec~at("name")))
    self~putFile(p||"/class",self~text(rec~at("class")))
  end

::method publishObjects private
  expose rootPath
  use strict arg data
  base=rootPath||"/objects"
  self~mkdirTree(base)
  objects=data~at("objects")
  if objects==.nil then return
  byOid=.directory~new
  do rec over objects
    if rec==.nil then iterate
    oid=self~safeName(rec~at("oid"))
    if oid="" then iterate
    byOid[oid]=rec
    p=base||"/"||oid
    self~mkdirTree(p)
    self~putFile(p||"/class",self~text(rec~at("class")))
    self~putFile(p||"/path",self~text(rec~at("path")))
    self~putFile(p||"/kind",self~text(rec~at("kind")))
    self~putFile(p||"/object_name",self~text(rec~at("object_name")))
    self~putFile(p||"/identity_hash",self~text(rec~at("identity_hash")))
    self~publishProbeAttributes(p,rec)
  end
  edges=data~at("edges")
  if edges==.nil then return
  do edge over edges
    if edge==.nil then iterate
    from=self~safeName(edge~at("from")); to=self~safeName(edge~at("to"))
    if from="" | to="" then iterate
    owner=byOid[from]; child=byOid[to]
    if owner==.nil | child==.nil then iterate
    ownerPath=self~text(owner~at("path")); edgePath=self~text(edge~at("path"))
    prefix=ownerPath||"."
    if left(edgePath,length(prefix))<>prefix then iterate
    attr=self~safeName(edge~at("edge"))
    if attr="" then iterate
    p=base||"/"||from||"/attributes/"||attr
    self~mkdirTree(p)
    self~putFile(p||"/oid",to)
    self~putFile(p||"/class",self~text(child~at("class")))
    self~putFile(p||"/kind",self~text(child~at("kind")))
    if child~hasIndex("value") then self~putFile(p||"/value",self~text(child~at("value")))
    else self~putFile(p||"/value","<object "||to||">")
    self~putFile(p||"/evidence_path",edgePath)
  end

::method publishProbeAttributes private
  use strict arg objectPath,rec
  base=objectPath||"/attributes"
  self~mkdirTree(base)
  probe=rec~at("probe")
  if probe==.nil then do
    self~putFile(base||"/.status","not-observed")
    return
  end
  slots=probe~at("slots")
  if slots==.nil then do
    self~putFile(base||"/.status","no-slots")
    return
  end
  count=0
  do slot over slots
    if slot==.nil then iterate
    name=self~safeName(slot~at("name"))
    if name="" then iterate
    count=count+1
    p=base||"/"||name
    self~mkdirTree(p)
    if slot~at("nil")==.true then self~putFile(p||"/value","<nil>")
    else self~putFile(p||"/value",self~text(slot~at("value")))
    self~putFile(p||"/class",self~text(slot~at("class")))
    self~putFile(p||"/kind",self~text(slot~at("kind")))
    self~putFile(p||"/oid",self~text(slot~at("oid")))
    self~putFile(p||"/assignment",self~text(slot~at("assignment")))
  end
  self~putFile(base||"/.count",count)

::method publishClasses private
  expose rootPath
  use strict arg data
  base=rootPath||"/classes"
  self~mkdirTree(base)
  classes=data~at("classes")
  if classes<>.nil then do crec over classes
    if crec==.nil then iterate
    cname=self~safeName(crec~at("name"))
    if cname="" then iterate
    p=base||"/"||cname
    self~mkdirTree(p)
    self~putFile(p||"/super_class",self~text(crec~at("super_class")))
    self~putFile(p||"/super_classes",self~joinArray(crec~at("super_classes"),"\n"))
    self~putFile(p||"/subclasses",self~joinArray(crec~at("subclasses"),"\n"))
    self~putFile(p||"/inferred_slots",self~joinArray(crec~at("inferred_slots"),"\n"))
    self~mkdirTree(p||"/methods")
  end
  methods=data~at("methods")
  if methods<>.nil then do mrec over methods
    if mrec==.nil then iterate
    cname=self~safeName(mrec~at("class"))
    mname=self~safeMethodName(mrec~at("method"))
    if cname="" | mname="" then iterate
    p=base||"/"||cname||"/methods/"||mname
    self~mkdirTree(p)
    self~putFile(p||"/origin_kind",self~text(mrec~at("origin_kind")))
    self~putFile(p||"/origin_class",self~text(mrec~at("origin_from_class")))
    self~putFile(p||"/origin_relation",self~text(mrec~at("origin_from_relation")))
    self~putFile(p||"/origin_package",self~text(mrec~at("origin_from_package")))
    self~putFile(p||"/source_available",self~boolText(mrec~at("source_available")))
    self~putFile(p||"/source_line_count",self~text(mrec~at("source_line_count")))
    self~putFile(p||"/guarded",self~boolText(mrec~at("guarded")))
    self~putFile(p||"/private",self~boolText(mrec~at("private")))
    self~putFile(p||"/protected",self~boolText(mrec~at("protected")))
    self~putFile(p||"/signals",self~joinArray(mrec~at("signal_names"),"\n"))
  end
  self~publishInheritance(data,base)

::method publishInheritance private
  use strict arg data,base
  maps=data~at("inheritance_maps")
  if maps==.nil then return
  classes=maps~at("classes")
  if classes==.nil then return
  do crec over classes
    if crec==.nil then iterate
    cname=self~safeName(crec~at("class"))
    if cname="" then iterate
    p=base||"/"||cname||"/inheritance"
    self~mkdirTree(p)
    self~putFile(p||"/lineage",self~joinArray(crec~at("lineage"),"\n"))
    self~putFile(p||"/direct_superclass",self~text(crec~at("direct_superclass")))
    self~putFile(p||"/live_object_count",self~text(crec~at("live_object_count")))
  end

::method publishTriggers private
  expose rootPath
  use strict arg data
  base=rootPath||"/triggers"
  self~mkdirTree(base)
  events=data~at("trigger_events")
  if events==.nil then do; self~putFile(base||"/.count",0); return; end
  n=0
  do e over events
    n=n+1
    p=base||"/"||n
    self~mkdirTree(p)
    do key over e
      val=e~at(key)
      if self~isScalar(val) then self~putFile(p||"/"||self~safeName(key),self~text(val))
    end
  end
  self~putFile(base||"/.count",n)

::method fuseCore public
  expose fuse
  return fuse

::method readVirtual public
  expose fuse
  use strict arg pathArg
  r=fuse~open(pathArg,"READ")
  if \r~ok then return .nil
  h=r~value
  rr=fuse~read(h,0,1048576)
  ignore=fuse~release(h)
  if \rr~ok then return .nil
  return rr~value

::method listVirtual public
  expose fuse
  use strict arg pathArg
  r=fuse~readdir(pathArg)
  if \r~ok then return .nil
  return r~value

::method putFile private
  expose store
  use strict arg pathArg,valueArg
  data=self~text(valueArg)
  if store~fileExists(pathArg) then do
    h=store~open(pathArg,"WRITE")
    if h<>.nil then do
      ignore=store~truncateHandle(h,0)
      ignore=store~write(h,0,data)
      ignore=store~close(h)
    end
  end
  else ignore=store~createFile(pathArg,data)
  return self

::method mkdirTree private
  expose store
  use strict arg pathArg
  p=.StoragePath~normalize(pathArg)
  ignore=store~mkdir(p)
  return self

::method normRoot private
  use strict arg value
  p=.StoragePath~normalize(value)
  if p="/" then return "/live/clouseau"
  return p

::method text private
  use arg value
  if value==.nil then return ""
  return value~string

::method boolText private
  use arg value
  if value==.true then return "true"
  if value==.false then return "false"
  if value==.nil then return "unknown"
  return value~string

::method joinArray private
  use arg arr,sep=" "
  if arr==.nil then return ""
  out=""; first=.true
  signal on syntax name notIterable
  do v over arr
    if \first then out=out||sep
    out=out||self~text(v)
    first=.false
  end
  signal off syntax
  return out
notIterable:
  signal off syntax
  return self~text(arr)

::method safeName private
  use arg value
  s=self~text(value)~strip
  if s="" then return "_"
  bad=" /\:;*?[]{}()<>|=+!@#$%^&,"
  do i=1 to length(bad)
    s=changestr(substr(bad,i,1),s,"_")
  end
  return s

::method safeMethodName private
  use arg value
  s=self~safeName(value)
  if s="_" then return "unnamed"
  return s

::method isScalar private
  use arg value
  if value==.nil then return .true
  c=value~class~id~upper
  return c="STRING" | c="INTEGER" | c="NUMBERSTRING"

::requires "StorageFuse.cls"