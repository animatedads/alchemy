/*
 * AlchemyPackageModel v0.1
 *
 * Transport-neutral model for Alchemy package execution planning.
 * The model resolves exact package dependencies, composes package-level and
 * per-test environments, and produces immutable-ish planned test objects.
 */

::class AlchemyModelBuild public
::constant VERSION "0.1"
::constant API "alchemy.package.model/0.1"

::class AlchemyPackageId public
::attribute name get
::attribute version get
::attribute kind get

::method init
  expose name version kind
  use strict arg name, version, kind = "oorexx"
  name = name~string~strip
  version = version~string~strip
  kind = kind~string~strip
  if name = "" then raise syntax 88.900 array("package name must not be empty")
  if version = "" then raise syntax 88.900 array("package version must not be empty")

::method key
  expose name version
  return name || "@" || version

::method string
  return self~key


::class AlchemyDependencyRef public
::attribute name get
::attribute version get
::attribute exportName get

::method init
  expose name version exportName
  use strict arg name, version, exportName = ""
  name = name~string~strip
  version = version~string~strip
  exportName = exportName~string~strip~upper
  if name = "" | version = "" then raise syntax 88.900 array("dependency name/version required")

::method key
  expose name version
  return name || "@" || version


::class AlchemyDependencyFloorEntry public
::attribute packageId get
::attribute root get
::attribute exportName get
::attribute rexxEntries get

::method init
  expose packageId root exportName rexxEntries
  use strict arg packageId, root, exportName = "", rexxEntries = .nil
  if packageId == .nil then raise syntax 88.900 array("dependency floor entry requires package id")
  root = root~string~strip
  if root = "" then raise syntax 88.900 array("dependency floor root required")
  exportName = exportName~string~strip~upper
  if rexxEntries == .nil then rexxEntries = .array~new
  else rexxEntries = .AlchemyCollections~copyArray(rexxEntries)

::method key
  expose packageId
  return packageId~key


::class AlchemyDependencyFloor public
::method init
  expose entries
  entries = .table~new

::method add
  expose entries
  use strict arg entry
  k = entry~key
  if entries~hasIndex(k) then raise syntax 88.900 array("dependency floor already contains " || k)
  entries[k] = entry
  return self

::method resolve
  expose entries
  use strict arg dependencyRef
  return entries[dependencyRef~key]

::method has
  expose entries
  use strict arg dependencyRef
  return entries~hasIndex(dependencyRef~key)

::method size
  expose entries
  return entries~items


::class AlchemyEnvironmentSpec public
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
  use strict arg setVars = .nil, prependPath = .nil, rexxMode = "prepend", rexxEntries = .nil, -
                 rexxRequireEntries = .false, requireVars = .nil, requireDirs = .nil, reportVars = .nil
  if setVars == .nil then setVars = .table~new
  else setVars = .AlchemyCollections~copyMap(setVars)
  if prependPath == .nil then prependPath = .array~new
  else prependPath = .AlchemyCollections~copyArray(prependPath)
  rexxMode = rexxMode~string~strip~lower
  if rexxMode \= "replace" & rexxMode \= "prepend" & rexxMode \= "append" then -
    raise syntax 88.900 array("invalid REXX_PATH mode: " || rexxMode)
  if rexxEntries == .nil then rexxEntries = .array~new
  else rexxEntries = .AlchemyCollections~copyArray(rexxEntries)
  if rexxRequireEntries then rexxRequireEntries = .true
  else rexxRequireEntries = .false
  if requireVars == .nil then requireVars = .array~new
  else requireVars = .AlchemyCollections~copyArray(requireVars)
  if requireDirs == .nil then requireDirs = .array~new
  else requireDirs = .AlchemyCollections~copyArray(requireDirs)
  if reportVars == .nil then reportVars = .array~new
  else reportVars = .AlchemyCollections~copyArray(reportVars)

::method empty class
  return self~new


::class AlchemyTestSpec public
::attribute name get
::attribute argv get
::attribute cwd get
::attribute timeoutSeconds get
::attribute environment get

::method init
  expose name argv cwd timeoutSeconds environment
  use strict arg name, argv, cwd = ".", timeoutSeconds = 60, environment = .nil
  name = name~string~strip
  if name = "" then raise syntax 88.900 array("test name required")
  argv = .AlchemyCollections~copyArray(argv)
  if argv~items = 0 then raise syntax 88.900 array("test argv must not be empty")
  cwd = cwd~string
  timeoutSeconds = timeoutSeconds + 0
  if timeoutSeconds <= 0 then raise syntax 88.900 array("test timeout must be positive")
  if environment == .nil then environment = .AlchemyEnvironmentSpec~empty


::class AlchemyPublishSpec public
::attribute source get
::attribute path get
::attribute artifactOnly get

::method init
  expose source path artifactOnly
  use strict arg source = "", path = "", artifactOnly = .false
  source = source~string
  path = path~string
  if artifactOnly then artifactOnly = .true
  else artifactOnly = .false
  if \artifactOnly & (source = "" | path = "") then raise syntax 88.900 array("publish tree source/path required")


::class AlchemyPackageSpec public
::attribute packageId get
::attribute workingDirectory get
::attribute environment get
::attribute dependencies get
::attribute tests get
::attribute publish get

::method init
  expose packageId workingDirectory environment dependencies tests publish
  use strict arg packageId, workingDirectory = ".", environment = .nil, dependencies = .nil, tests = .nil, publish = .nil
  if packageId == .nil then raise syntax 88.900 array("package id required")
  workingDirectory = workingDirectory~string
  if environment == .nil then environment = .AlchemyEnvironmentSpec~empty
  if dependencies == .nil then dependencies = .array~new
  else dependencies = .AlchemyCollections~copyArray(dependencies)
  if tests == .nil then tests = .array~new
  else tests = .AlchemyCollections~copyArray(tests)
  if tests~items = 0 then raise syntax 88.900 array("package must declare at least one test")
  if publish == .nil then publish = .AlchemyPublishSpec~new("", "", .true)


::class AlchemyPlanningContext public
::attribute packageRoot get
::attribute repoRoot get
::attribute baseEnvironment get
::attribute pathPolicy get

::method init
  expose packageRoot repoRoot baseEnvironment pathPolicy
  use strict arg packageRoot, repoRoot, baseEnvironment = .nil, pathPolicy = .nil
  packageRoot = packageRoot~string
  repoRoot = repoRoot~string
  if baseEnvironment == .nil then baseEnvironment = .table~new
  else baseEnvironment = .AlchemyCollections~copyMap(baseEnvironment)
  if pathPolicy == .nil then pathPolicy = .AlchemyFileSystemPathPolicy~new


::class AlchemyPlannedTest public
::attribute name get
::attribute argv get
::attribute cwd get
::attribute timeoutSeconds get
::attribute environment get
::attribute reportEnvironment get

::method init
  expose name argv cwd timeoutSeconds environment reportEnvironment
  use strict arg name, argv, cwd, timeoutSeconds, environment, reportEnvironment
  argv = .AlchemyCollections~copyArray(argv)
  environment = .AlchemyCollections~copyMap(environment)
  reportEnvironment = .AlchemyCollections~copyMap(reportEnvironment)


::class AlchemyExecutionPlan public
::attribute packageSpec get
::attribute tests get
::attribute dependencyRoots get

::method init
  expose packageSpec tests dependencyRoots
  use strict arg packageSpec, tests, dependencyRoots
  tests = .AlchemyCollections~copyArray(tests)
  dependencyRoots = .AlchemyCollections~copyMap(dependencyRoots)


::class AlchemyExecutionPlanner public
::method plan
  use strict arg packageSpec, floor, context
  dependencyEnv = .AlchemyEnvironmentSpec~empty
  depSet = .table~new
  depRexx = .array~new
  depRoots = .table~new

  do dependency over packageSpec~dependencies
    entry = floor~resolve(dependency)
    if entry == .nil then raise syntax 88.900 array("unresolved dependency: " || dependency~key)
    exportName = dependency~exportName
    if exportName = "" then exportName = entry~exportName
    if exportName \= "" then depSet[exportName] = entry~root
    depRoots[dependency~key] = entry~root
    do r over entry~rexxEntries
      depRexx~append(.AlchemyStrings~joinPath(entry~root, r))
    end
  end
  dependencyEnv = .AlchemyEnvironmentSpec~new(depSet, .nil, "prepend", depRexx)

  planned = .array~new
  do testSpec over packageSpec~tests
    env = .AlchemyEnvironmentComposer~compose(dependencyEnv, packageSpec~environment, testSpec~environment, context)
    cwd = .AlchemyStrings~expand(testSpec~cwd, context)
    if \ .AlchemyStrings~isAbsolute(cwd) then cwd = .AlchemyStrings~joinPath(context~packageRoot, cwd)
    if \context~pathPolicy~isDirectory(cwd) then raise syntax 88.900 array("test cwd is not a directory: " || cwd)
    report = .AlchemyEnvironmentComposer~reportFor(dependencyEnv, packageSpec~environment, testSpec~environment, env)
    planned~append(.AlchemyPlannedTest~new(testSpec~name, testSpec~argv, cwd, testSpec~timeoutSeconds, env, report))
  end
  return .AlchemyExecutionPlan~new(packageSpec, planned, depRoots)


::class AlchemyEnvironmentComposer public
::method compose class
  use strict arg dependencySpec, packageSpec, testSpec, context
  env = .AlchemyCollections~copyMap(context~baseEnvironment)
  self~applyOne(env, dependencySpec, context)
  self~applyOne(env, packageSpec, context)
  self~applyOne(env, testSpec, context)
  self~validate(env, dependencySpec, packageSpec, testSpec, context)
  return env

::method applyOne class private
  use strict arg env, spec, context
  supplier = spec~setVars~supplier
  do while supplier~available
    key = supplier~index~string~upper
    env[key] = .AlchemyStrings~expand(supplier~item, context)
    supplier~next
  end

  if spec~prependPath~items > 0 then do
    prefix = .AlchemyStrings~expandAndJoin(spec~prependPath, context)
    old = env["PATH"]
    if old == .nil | old = "" then env["PATH"] = prefix
    else if prefix = "" then nop
    else env["PATH"] = prefix || ":" || old
  end

  if spec~rexxEntries~items > 0 then do
    part = .AlchemyStrings~expandAndJoin(spec~rexxEntries, context)
    old = env["REXX_PATH"]
    if old == .nil then old = ""
    select
      when spec~rexxMode = "replace" then env["REXX_PATH"] = part
      when spec~rexxMode = "prepend" then do
        if old = "" then env["REXX_PATH"] = part
        else if part = "" then env["REXX_PATH"] = old
        else env["REXX_PATH"] = part || ":" || old
      end
      otherwise do
        if old = "" then env["REXX_PATH"] = part
        else if part = "" then env["REXX_PATH"] = old
        else env["REXX_PATH"] = old || ":" || part
      end
    end
  end
  return

::method validate class private
  use strict arg env, dependencySpec, packageSpec, testSpec, context
  specs = .array~of(dependencySpec, packageSpec, testSpec)
  do spec over specs
    do key over spec~requireVars
      key = key~string~upper
      value = env[key]
      if value == .nil | value~string = "" then raise syntax 88.900 array("required environment variable missing: " || key)
    end
    do key over spec~requireDirs
      key = key~string~upper
      value = env[key]
      if value == .nil | value~string = "" then raise syntax 88.900 array("required directory export missing: " || key)
      if \context~pathPolicy~isDirectory(value) then raise syntax 88.900 array("required directory export is not a directory: " || key || "=" || value)
    end
    if spec~rexxRequireEntries then do item over spec~rexxEntries
      p = .AlchemyStrings~expand(item, context)
      if \context~pathPolicy~isDirectory(p) then raise syntax 88.900 array("REXX_PATH entry is not a directory: " || p)
    end
  end
  return

::method reportFor class
  use strict arg dependencySpec, packageSpec, testSpec, env
  keys = .table~new
  keys["PATH"] = .true
  keys["REXX_PATH"] = .true
  keys["ALCHEMY_PACKAGE_ROOT"] = .true
  keys["ALCHEMY_REPO_ROOT"] = .true
  do spec over .array~of(dependencySpec, packageSpec, testSpec)
    supplier = spec~setVars~supplier
    do while supplier~available
      keys[supplier~index~string~upper] = .true
      supplier~next
    end
    do key over spec~requireVars; keys[key~string~upper] = .true; end
    do key over spec~requireDirs; keys[key~string~upper] = .true; end
    do key over spec~reportVars; keys[key~string~upper] = .true; end
  end
  out = .table~new
  supplier = keys~supplier
  do while supplier~available
    key = supplier~index
    value = env[key]
    if value == .nil then out[key] = ""
    else out[key] = value
    supplier~next
  end
  return out


::class AlchemyFileSystemPathPolicy public
::method isDirectory
  use strict arg path
  stem = "ALCHEMY_PATH_CHECK."
  call SysFileTree path, stem, "DO"
  return value(stem || "0") > 0


::class AlchemyFakePathPolicy public
::method init
  expose dirs
  use strict arg initial = .nil
  dirs = .table~new
  if initial \== .nil then do p over initial
    dirs[p~string] = .true
  end

::method addDirectory
  expose dirs
  use strict arg path
  dirs[path~string] = .true
  return self

::method isDirectory
  expose dirs
  use strict arg path
  return dirs~hasIndex(path~string)


::class AlchemyCollections public
::method copyArray class
  use strict arg source
  out = .array~new
  do item over source
    out~append(item)
  end
  return out

::method copyMap class
  use strict arg source
  out = .table~new
  supplier = source~supplier
  do while supplier~available
    out[supplier~index] = supplier~item
    supplier~next
  end
  return out


::class AlchemyStrings public
::method expand class
  use strict arg value, context
  out = value~string
  out = out~changeStr("${PACKAGE_ROOT}", context~packageRoot)
  out = out~changeStr("${REPO_ROOT}", context~repoRoot)
  return out

::method expandAndJoin class
  use strict arg values, context
  out = ""
  do value over values
    e = self~expand(value, context)
    if out = "" then out = e
    else out = out || ":" || e
  end
  return out

::method isAbsolute class
  use strict arg path
  if path = "" then return .false
  return path~left(1) = "/"

::method joinPath class
  use strict arg left, right
  left = left~string
  right = right~string
  if right = "" | right = "." then return left
  if self~isAbsolute(right) then return right
  if left~right(1) = "/" then return left || right
  return left || "/" || right
