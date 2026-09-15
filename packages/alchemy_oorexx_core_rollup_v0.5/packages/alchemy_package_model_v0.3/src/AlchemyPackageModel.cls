/* Alchemy Package Model v0.2 */

::class AlchemyModelBuild public
::constant VERSION "0.3"
::constant API "alchemy.package.model/0.3"
::constant MANIFEST_SCHEMA "alchemy.autobuild.integration/0.4"

::class AlchemyPackageId subclass AlchemyCoreComponent public
::attribute name get
::attribute version get
::attribute kind get
::method init
  expose name version kind
  use strict arg name, version, kind="oorexx"
  self~initCoreComponent("AlchemyPackageId", "0.3", "Alchemy core AlchemyPackageId component")
  name=name~string~strip; version=version~string~strip; kind=kind~string~strip
  if name="" | version="" then raise syntax 88.900 array("package name/version required")
::method key
  expose name version
  return name || "@" || version
::method string
  return self~key

::class AlchemyDependencyRef subclass AlchemyCoreComponent public
::attribute name get
::attribute version get
::attribute exportName get
::method init
  expose name version exportName
  use strict arg name, version, exportName=""
  self~initCoreComponent("AlchemyDependencyRef", "0.3", "Alchemy core AlchemyDependencyRef component")
  name=name~string~strip; version=version~string~strip; exportName=exportName~string~strip~upper
  if name="" | version="" then raise syntax 88.900 array("dependency name/version required")
::method key
  expose name version
  return name || "@" || version

::class AlchemyDependencyFloorEntry subclass AlchemyCoreComponent public
::attribute packageId get
::attribute root get
::attribute exportName get
::attribute rexxEntries get
::method init
  expose packageId root exportName rexxEntries
  use strict arg packageId, root, exportName="", rexxEntries=.nil
  self~initCoreComponent("AlchemyDependencyFloorEntry", "0.3", "Alchemy core AlchemyDependencyFloorEntry component")
  root=root~string~strip; exportName=exportName~string~strip~upper
  if packageId==.nil | root="" then raise syntax 88.900 array("dependency floor package/root required")
  if rexxEntries==.nil then rexxEntries=.array~new; else rexxEntries=.AlchemyCollections~copyArray(rexxEntries)
::method key
  expose packageId
  return packageId~key

::class AlchemyDependencyFloor subclass AlchemyCoreComponent public
::method init
  expose entries
  self~initCoreComponent("AlchemyDependencyFloor", "0.3", "Alchemy core AlchemyDependencyFloor component")
  entries=.table~new
::method add
  expose entries
  use strict arg entry
  if entries~hasIndex(entry~key) then raise syntax 88.900 array("duplicate dependency floor entry: " || entry~key)
  entries[entry~key]=entry
  return self
::method resolve
  expose entries
  use strict arg ref
  return entries[ref~key]
::method size
  expose entries
  return entries~items

::class AlchemyEnvironmentSpec subclass AlchemyCoreComponent public
::attribute setVars get
::attribute prependPath get
::attribute rexxMode get
::attribute rexxEntries get
::attribute rexxRequireEntries get
::attribute requireVars get
::attribute requireDirs get
::attribute reportVars get
::method init
  expose setVars prependPath rexxMode rexxEntries rexxRequireEntries requireVars requireDirs reportVars
  use strict arg setVars=.nil, prependPath=.nil, rexxMode="prepend", rexxEntries=.nil, rexxRequireEntries=.false, requireVars=.nil, requireDirs=.nil, reportVars=.nil
  self~initCoreComponent("AlchemyEnvironmentSpec", "0.3", "Alchemy core AlchemyEnvironmentSpec component")
  if setVars==.nil then setVars=.table~new; else setVars=.AlchemyCollections~copyMap(setVars)
  if prependPath==.nil then prependPath=.array~new; else prependPath=.AlchemyCollections~copyArray(prependPath)
  rexxMode=rexxMode~string~strip~lower
  if rexxMode<>"prepend" & rexxMode<>"append" & rexxMode<>"replace" then raise syntax 88.900 array("invalid REXX_PATH mode: " || rexxMode)
  if rexxEntries==.nil then rexxEntries=.array~new; else rexxEntries=.AlchemyCollections~copyArray(rexxEntries)
  rexxRequireEntries=(rexxRequireEntries=.true)
  if requireVars==.nil then requireVars=.array~new; else requireVars=.AlchemyCollections~copyArray(requireVars)
  if requireDirs==.nil then requireDirs=.array~new; else requireDirs=.AlchemyCollections~copyArray(requireDirs)
  if reportVars==.nil then reportVars=.array~new; else reportVars=.AlchemyCollections~copyArray(reportVars)
::method empty class
  return self~new

::class AlchemyTestSpec subclass AlchemyCoreComponent public
::attribute name get
::attribute argv get
::attribute cwd get
::attribute timeoutSeconds get
::attribute environment get
::method init
  expose name argv cwd timeoutSeconds environment
  use strict arg name, argv, cwd=".", timeoutSeconds=60, environment=.nil
  self~initCoreComponent("AlchemyTestSpec", "0.3", "Alchemy core AlchemyTestSpec component")
  name=name~string~strip; argv=.AlchemyCollections~copyArray(argv); cwd=cwd~string; timeoutSeconds=timeoutSeconds+0
  if name="" | argv~items=0 | timeoutSeconds<=0 then raise syntax 88.900 array("invalid test specification")
  if environment==.nil then environment=.AlchemyEnvironmentSpec~empty

::class AlchemyPublishSpec subclass AlchemyCoreComponent public
::attribute source get
::attribute path get
::attribute artifactOnly get
::method init
  expose source path artifactOnly
  use strict arg source="", path="", artifactOnly=.false
  self~initCoreComponent("AlchemyPublishSpec", "0.3", "Alchemy core AlchemyPublishSpec component")
  source=source~string; path=path~string; artifactOnly=(artifactOnly=.true)
  if \artifactOnly & (source="" | path="") then raise syntax 88.900 array("publish tree source/path required")

::class AlchemyPackageSpec subclass AlchemyCoreComponent public
::attribute packageId get
::attribute workingDirectory get
::attribute environment get
::attribute dependencies get
::attribute tests get
::attribute publish get
::method init
  expose packageId workingDirectory environment dependencies tests publish
  use strict arg packageId, workingDirectory=".", environment=.nil, dependencies=.nil, tests=.nil, publish=.nil
  self~initCoreComponent("AlchemyPackageSpec", "0.3", "Alchemy core AlchemyPackageSpec component")
  if packageId==.nil then raise syntax 88.900 array("package id required")
  workingDirectory=workingDirectory~string
  if environment==.nil then environment=.AlchemyEnvironmentSpec~empty
  if dependencies==.nil then dependencies=.array~new; else dependencies=.AlchemyCollections~copyArray(dependencies)
  if tests==.nil then tests=.array~new; else tests=.AlchemyCollections~copyArray(tests)
  if tests~items=0 then raise syntax 88.900 array("package must declare tests")
  if publish==.nil then publish=.AlchemyPublishSpec~new("","",.true)

::class AlchemyPlanningContext subclass AlchemyCoreComponent public
::attribute packageRoot get
::attribute repoRoot get
::attribute baseEnvironment get
::attribute pathPolicy get
::method init
  expose packageRoot repoRoot baseEnvironment pathPolicy
  use strict arg packageRoot, repoRoot, baseEnvironment=.nil, pathPolicy=.nil
  self~initCoreComponent("AlchemyPlanningContext", "0.3", "Alchemy core AlchemyPlanningContext component")
  packageRoot=packageRoot~string; repoRoot=repoRoot~string
  if baseEnvironment==.nil then baseEnvironment=.table~new; else baseEnvironment=.AlchemyCollections~copyMap(baseEnvironment)
  baseEnvironment["ALCHEMY_PACKAGE_ROOT"]=packageRoot
  baseEnvironment["ALCHEMY_REPO_ROOT"]=repoRoot
  if pathPolicy==.nil then pathPolicy=.AlchemyFileSystemPathPolicy~new

::class AlchemyPlannedTest subclass AlchemyCoreComponent public
::attribute name get
::attribute argv get
::attribute cwd get
::attribute timeoutSeconds get
::attribute environment get
::attribute reportEnvironment get
::method init
  expose name argv cwd timeoutSeconds environment reportEnvironment
  use strict arg name, argv, cwd, timeoutSeconds, environment, reportEnvironment
  self~initCoreComponent("AlchemyPlannedTest", "0.3", "Alchemy core AlchemyPlannedTest component")
  argv=.AlchemyCollections~copyArray(argv); environment=.AlchemyCollections~copyMap(environment); reportEnvironment=.AlchemyCollections~copyMap(reportEnvironment)

::class AlchemyExecutionPlan subclass AlchemyCoreComponent public
::attribute packageSpec get
::attribute tests get
::attribute dependencyRoots get
::method init
  expose packageSpec tests dependencyRoots
  use strict arg packageSpec, tests, dependencyRoots
  self~initCoreComponent("AlchemyExecutionPlan", "0.3", "Alchemy core AlchemyExecutionPlan component")
  tests=.AlchemyCollections~copyArray(tests); dependencyRoots=.AlchemyCollections~copyMap(dependencyRoots)

::class AlchemyExecutionPlanner subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyExecutionPlanner", "0.3", "Alchemy core AlchemyExecutionPlanner component")
  return self

::method plan
  use strict arg packageSpec, floor, context
  depSet=.table~new; depRexx=.array~new; depRoots=.table~new
  do dep over packageSpec~dependencies
    entry=floor~resolve(dep)
    if entry==.nil then raise syntax 88.900 array("unresolved dependency: " || dep~key)
    exportName=dep~exportName; if exportName="" then exportName=entry~exportName
    if exportName<>"" then depSet[exportName]=entry~root
    depRoots[dep~key]=entry~root
    do r over entry~rexxEntries; depRexx~append(.AlchemyStrings~joinPath(entry~root,r)); end
  end
  depEnv=.AlchemyEnvironmentSpec~new(depSet,.nil,"prepend",depRexx)
  planned=.array~new
  do t over packageSpec~tests
    env=.AlchemyEnvironmentComposer~compose(depEnv,packageSpec~environment,t~environment,context)
    cwd=.AlchemyStrings~expand(t~cwd,context)
    if \ .AlchemyStrings~isAbsolute(cwd) then cwd=.AlchemyStrings~joinPath(context~packageRoot,cwd)
    if \context~pathPolicy~isDirectory(cwd) then raise syntax 88.900 array("test cwd is not a directory: " || cwd)
    report=.AlchemyEnvironmentComposer~reportFor(depEnv,packageSpec~environment,t~environment,env)
    planned~append(.AlchemyPlannedTest~new(t~name,t~argv,cwd,t~timeoutSeconds,env,report))
  end
  return .AlchemyExecutionPlan~new(packageSpec,planned,depRoots)

::class AlchemyEnvironmentComposer subclass AlchemyCoreComponent public
::method compose class
  use strict arg depSpec,pkgSpec,testSpec,context
  env=.AlchemyCollections~copyMap(context~baseEnvironment)
  self~applyOne(env,depSpec,context); self~applyOne(env,pkgSpec,context); self~applyOne(env,testSpec,context)
  self~validate(env,depSpec,pkgSpec,testSpec,context)
  return env
::method applyOne class private
  use strict arg env,spec,context
  sup=spec~setVars~supplier
  do while sup~available; env[sup~index~string~upper]=.AlchemyStrings~expand(sup~item,context); sup~next; end
  if spec~prependPath~items>0 then do
    part=.AlchemyStrings~expandAndJoin(spec~prependPath,context); old=env["PATH"]; if old==.nil then old=""
    if part<>"" then if old="" then env["PATH"]=part; else env["PATH"]=part || ":" || old
  end
  if spec~rexxEntries~items>0 then do
    part=.AlchemyStrings~expandAndJoin(spec~rexxEntries,context); old=env["REXX_PATH"]; if old==.nil then old=""
    select
      when spec~rexxMode="replace" then env["REXX_PATH"]=part
      when spec~rexxMode="prepend" then if old="" then env["REXX_PATH"]=part; else if part<>"" then env["REXX_PATH"]=part || ":" || old
      otherwise if old="" then env["REXX_PATH"]=part; else if part<>"" then env["REXX_PATH"]=old || ":" || part
    end
  end
::method validate class private
  use strict arg env,depSpec,pkgSpec,testSpec,context
  do spec over .array~of(depSpec,pkgSpec,testSpec)
    do key over spec~requireVars
      k=key~string~upper; v=env[k]; if v==.nil | v="" then raise syntax 88.900 array("required environment variable missing: " || k)
    end
    do key over spec~requireDirs
      k=key~string~upper; v=env[k]; if v==.nil | v="" then raise syntax 88.900 array("required directory export missing: " || k)
      if \context~pathPolicy~isDirectory(v) then raise syntax 88.900 array("required directory export is not a directory: " || k || "=" || v)
    end
    if spec~rexxRequireEntries then do p over spec~rexxEntries
      e=.AlchemyStrings~expand(p,context); if \context~pathPolicy~isDirectory(e) then raise syntax 88.900 array("REXX_PATH entry is not a directory: " || e)
    end
  end
::method reportFor class
  use strict arg depSpec,pkgSpec,testSpec,env
  keys=.table~new; keys["PATH"]=1; keys["REXX_PATH"]=1; keys["ALCHEMY_PACKAGE_ROOT"]=1; keys["ALCHEMY_REPO_ROOT"]=1
  do spec over .array~of(depSpec,pkgSpec,testSpec)
    sup=spec~setVars~supplier; do while sup~available; keys[sup~index~string~upper]=1; sup~next; end
    do k over spec~requireVars; keys[k~string~upper]=1; end
    do k over spec~requireDirs; keys[k~string~upper]=1; end
    do k over spec~reportVars; keys[k~string~upper]=1; end
  end
  out=.table~new; sup=keys~supplier
  do while sup~available; k=sup~index; v=env[k]; if v==.nil then out[k]=""; else out[k]=v; sup~next; end
  return out

::class AlchemyIntegrationCodec subclass AlchemyCoreComponent public
::method decodeFile class
  use strict arg path
  return self~decode(.JSON~fromJsonFile(path))
::method decode class
  use strict arg doc
  schema=self~s(doc["schema"])
  supported=.array~of("alchemy.autobuild.integration/0.1","alchemy.autobuild.integration/0.2","alchemy.autobuild.integration/0.3",.AlchemyModelBuild~MANIFEST_SCHEMA)
  if \supported~hasItem(schema) then raise syntax 88.900 array("unsupported integration schema: " || schema)
  p=doc["package"]; id=.AlchemyPackageId~new(self~s(p["name"]),self~s(p["version"]),self~optS(p,"kind","oorexx"))
  wd=self~optS(doc,"working_directory",".")
  env=self~decodeEnv(doc["environment"])
  deps=.array~new
  if doc~hasIndex("dependencies") & doc["dependencies"]<>.nil then do d over doc["dependencies"]
    deps~append(.AlchemyDependencyRef~new(self~s(d["name"]),self~s(d["version"]),self~optS(d,"export","")))
  end
  tests=.array~new
  do t over doc["tests"]
    argv=.array~new; do a over t["argv"]; argv~append(self~s(a)); end
    tests~append(.AlchemyTestSpec~new(self~s(t["name"]),argv,self~optS(t,"cwd","."),self~optN(t,"timeout_seconds",60),self~decodeEnv(t["environment"])))
  end
  pub=.AlchemyPublishSpec~new("","",.true)
  if doc~hasIndex("publish") & doc["publish"]<>.nil then do
    pd=doc["publish"]
    if pd~hasIndex("artifact_only") & self~b(pd["artifact_only"]) then pub=.AlchemyPublishSpec~new("","",.true)
    else if pd~hasIndex("tree") then do; tr=pd["tree"]; pub=.AlchemyPublishSpec~new(self~s(tr["source"]),self~s(tr["path"]),.false); end
  end
  return .AlchemyPackageSpec~new(id,wd,env,deps,tests,pub)
::method decodeEnv class
  use strict arg d
  if d==.nil then return .AlchemyEnvironmentSpec~empty
  set=.table~new; prepend=.array~new; mode="prepend"; entries=.array~new; reqEntries=.false; req=.array~new; reqDirs=.array~new; report=.array~new
  if d~hasIndex("set") & d["set"]<>.nil then do; sup=d["set"]~supplier; do while sup~available; set[sup~index]=self~s(sup~item); sup~next; end; end
  if d~hasIndex("prepend_path") & d["prepend_path"]<>.nil then do a over d["prepend_path"]; prepend~append(self~s(a)); end
  if d~hasIndex("rexx_path") & d["rexx_path"]<>.nil then do
    rp=d["rexx_path"]; mode=self~optS(rp,"mode","prepend"); if rp~hasIndex("entries") then do a over rp["entries"]; entries~append(self~s(a)); end
    if rp~hasIndex("require_entries") then reqEntries=self~b(rp["require_entries"])
  end
  if d~hasIndex("require") then do a over d["require"]; req~append(self~s(a)); end
  if d~hasIndex("require_dirs") then do a over d["require_dirs"]; reqDirs~append(self~s(a)); end
  if d~hasIndex("report") then do a over d["report"]; report~append(self~s(a)); end
  return .AlchemyEnvironmentSpec~new(set,prepend,mode,entries,reqEntries,req,reqDirs,report)
::method s class private
  use strict arg v
  if v==.nil then return ""
  return v~string
::method b class private
  use strict arg v
  if v==.nil then return .false
  s=v~string~lower
  return s="true" | s="1"
::method optS class private
  use strict arg d,key,default
  if d==.nil | \d~hasIndex(key) | d[key]==.nil then return default
  return self~s(d[key])
::method optN class private
  use strict arg d,key,default
  if d==.nil | \d~hasIndex(key) | d[key]==.nil then return default
  return self~s(d[key])+0

::class AlchemyFileSystemPathPolicy subclass AlchemyCoreComponent public
::method isDirectory
  use strict arg path
  stem="ALCHEMY_MODEL_DIR."; call SysFileTree path,stem,"DO"; return value(stem || "0")>0

::class AlchemyFakePathPolicy subclass AlchemyCoreComponent public
::method init
  expose dirs
  use strict arg initial=.nil
  self~initCoreComponent("AlchemyFakePathPolicy", "0.3", "Alchemy core AlchemyFakePathPolicy component")
  dirs=.table~new; if initial<>.nil then do p over initial; dirs[p~string]=1; end
::method addDirectory
  expose dirs
  use strict arg p
  dirs[p~string]=1; return self
::method isDirectory
  expose dirs
  use strict arg p
  return dirs~hasIndex(p~string)

::class AlchemyCollections subclass AlchemyCoreComponent public
::method copyArray class
  use strict arg source
  out=.array~new; do x over source; out~append(x); end; return out
::method copyMap class
  use strict arg source
  out=.table~new; sup=source~supplier; do while sup~available; out[sup~index]=sup~item; sup~next; end; return out

::class AlchemyStrings subclass AlchemyCoreComponent public
::method expand class
  use strict arg value,context
  out=value~string~changeStr("${PACKAGE_ROOT}",context~packageRoot)~changeStr("${REPO_ROOT}",context~repoRoot); return out
::method expandAndJoin class
  use strict arg values,context
  out=""; do v over values; e=self~expand(v,context); if out="" then out=e; else out ||= ":" || e; end; return out
::method joinPath class
  use strict arg l,r
  if r="" | r="." then return l
  if r~left(1)="/" then return r
  if l~right(1)="/" then return l || r
  return l || "/" || r
::method isAbsolute class
  use strict arg p
  return p~left(1)="/"

::requires "json.cls"

::requires "AlchemyCoreComponent.cls"
