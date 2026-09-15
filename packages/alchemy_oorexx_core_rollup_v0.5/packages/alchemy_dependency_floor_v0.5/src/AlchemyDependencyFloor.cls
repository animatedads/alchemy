/*
 * AlchemyDependencyFloor v0.1
 *
 * Bootstrap model and seeder for making one visible version of each supplied
 * ooRexx component available under packages/. Seeding is explicitly NOT
 * package acceptance.
 */

::class AlchemyDependencyFloorBuild public
::constant VERSION "0.5"
::constant API "alchemy.dependency.floor/0.1"
::constant SEMANTICS "BOOTSTRAP_ONLY_NOT_ACCEPTANCE"


::class AlchemyBundleItem subclass AlchemyCoreComponent public
::attribute archivePath get
::attribute archiveName get
::attribute packageName get
::attribute wrapperName get
::attribute sha256 get

::method init
  expose archivePath archiveName packageName wrapperName sha256
  use strict arg archivePath, archiveName, packageName, wrapperName = "", sha256 = ""
  self~initCoreComponent("AlchemyBundleItem", "0.4", "Alchemy core AlchemyBundleItem component")

::method wrapped
  expose wrapperName
  return wrapperName \= ""


::class AlchemyBundleInventory subclass AlchemyCoreComponent public
::attribute bundlePath get
::attribute bundleSha256 get
::attribute extractedRoot get
::attribute packages get
::attribute sidecars get

::method init
  expose bundlePath bundleSha256 extractedRoot packages sidecars
  use strict arg bundlePath, bundleSha256, extractedRoot, packages, sidecars
  self~initCoreComponent("AlchemyBundleInventory", "0.4", "Alchemy core AlchemyBundleInventory component")
  packages = .AlchemyTransportCollections~copyArray(packages)
  sidecars = .AlchemyTransportCollections~copyArray(sidecars)


::class AlchemyBundleInspector subclass AlchemyCoreComponent public
::method init
  expose runner zip
  use strict arg runner = .nil
  self~initCoreComponent("AlchemyBundleInspector", "0.4", "Alchemy core AlchemyBundleInspector component")
  if runner == .nil then runner = .AlchemyCommandRunner~new
  zip = .AlchemyZipArchive~new(runner)

::method inspect
  expose runner zip
  use strict arg bundlePath, context
  bundleSha = .AlchemyChecksumTool~sha256(bundlePath, runner)
  outer = context~allocate("bundle")
  zip~extract(bundlePath, outer)

  found = runner~require(.array~of("find", outer, "-type", "f", "-name", "*.zip", "-print"), "", "bundle ZIP discovery")
  zipPaths = .AlchemyTransportText~lines(found~stdout)
  zipPaths~sort
  packages = .array~new
  do nested over zipPaths
    entries = zip~list(nested)
    naming = self~deriveName(filespec("N", nested), entries)
    packages~append(.AlchemyBundleItem~new(nested, filespec("N", nested), naming[1], naming[2], .AlchemyChecksumTool~sha256(nested, runner)))
  end

  sidecars = .array~new
  sideRoot = outer || "/current/testapps"
  if .AlchemyTransportFs~isDirectory(sideRoot) then do
    sc = runner~require(.array~of("find", sideRoot, "-maxdepth", "1", "-type", "f", "-name", "ourladyair_shannon_ticket_groups_v1.*", "-print"), "", "bundle sidecar discovery")
    sidecars = .AlchemyTransportText~lines(sc~stdout)
    sidecars~sort
  end
  return .AlchemyBundleInventory~new(bundlePath, bundleSha, outer, packages, sidecars)

::method deriveName
  use strict arg archiveName, entries
  top = ""
  wrapped = .true
  files = 0
  do entry over entries
    e = entry~string
    if e~right(1) = "/" then iterate
    files += 1
    slash = e~pos("/")
    if slash = 0 then do
      wrapped = .false
      leave
    end
    first = e~left(slash - 1)
    if top = "" then top = first
    else if first \= top then do
      wrapped = .false
      leave
    end
  end
  if files > 0 & wrapped & top \= "" then return .array~of(top, top)

  base = archiveName
  if base~right(4)~lower = ".zip" then base = base~left(base~length - 4)
  if base~right(1) = ")" then do
    lp = base~lastPos("(")
    if lp > 0 then do
      inside = base~substr(lp + 1, base~length - lp - 1)
      if inside \= "" & datatype(inside, "W") then base = base~left(lp - 1)
    end
  end
  return .array~of(base, "")

::method materializeItem
  expose runner zip
  use strict arg item, context
  target = context~allocate("nested")
  zip~extract(item~archivePath, target)
  if item~wrapped then return target || "/" || item~wrapperName
  return target


::class AlchemySeedResult subclass AlchemyCoreComponent public
::attribute seedId get
::attribute bundleSha256 get
::attribute seeded get
::attribute preserved get
::attribute ledgerPath get
::attribute commit get
::attribute dryRun get

::method init
  expose seedId bundleSha256 seeded preserved ledgerPath commit dryRun
  use strict arg seedId, bundleSha256, seeded, preserved, ledgerPath = "", commit = "", dryRun = .false
  self~initCoreComponent("AlchemySeedResult", "0.4", "Alchemy core AlchemySeedResult component")
  seeded = .AlchemyTransportCollections~copyArray(seeded)
  preserved = .AlchemyTransportCollections~copyArray(preserved)


::class AlchemyDependencyFloorSeeder subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner = .nil
  self~initCoreComponent("AlchemyDependencyFloorSeeder", "0.4", "Alchemy core AlchemyDependencyFloorSeeder component")
  if runner == .nil then runner = .AlchemyCommandRunner~new

::method seed
  expose runner
  use strict arg repoRoot, bundlePath, dryRun = .false
  if dryRun then dryRun = .true; else dryRun = .false
  workspace = SysTempFileName("/tmp/alchemy-floor-??????")
  if workspace = "" | SysMkDir(workspace) \= 0 then raise syntax 88.900 array("unable to create dependency floor workspace")
  context = .AlchemyTransportContext~new(workspace, repoRoot, runner)
  inventory = .AlchemyBundleInspector~new(runner)~inspect(bundlePath, context)

  seedId = date("S") || "T" || time()~changeStr(":", "") || "Z-crypto-consolidated"
  tx = .AlchemyGitMainTransaction~new(repoRoot, runner)~begin
  seeded = .array~new
  preserved = .array~new
  entries = .array~new
  packagesRoot = tx~root || "/packages"
  if \ .AlchemyTransportFs~isDirectory(packagesRoot) then runner~require(.array~of("mkdir", "-p", packagesRoot), "", "packages directory")

  do item over inventory~packages
    rel = "packages/" || item~packageName
    target = tx~root || "/" || rel
    entry = .directory~new
    entry["source"] = item~archiveName
    entry["source_sha256"] = item~sha256
    entry["package_path"] = rel
    if .AlchemyTransportFs~isDirectory(target) then do
      entry["status"] = "EXISTING_PRESERVED"
      preserved~append(rel)
    end
    else do
      entry["status"] = "SEEDED"
      seeded~append(rel)
      if \dryRun then do
        sourceTree = .AlchemyBundleInspector~new(runner)~materializeItem(item, context)
        if item~wrapped then runner~require(.array~of("cp", "-a", "--", sourceTree, target), "", "package seed copy")
        else do
          runner~require(.array~of("mkdir", "-p", target), "", "package seed target")
          runner~require(.array~of("cp", "-a", "--", sourceTree || "/.", target || "/"), "", "package seed copy")
        end
      end
    end
    entries~append(entry)
  end

  if inventory~sidecars~items > 0 then do
    sideRel = "packages/ourladyair_shannon_ticket_groups_v1"
    sideTarget = tx~root || "/" || sideRel
    entry = .directory~new
    entry["source"] = "current/testapps/ourladyair_shannon_ticket_groups_v1.*"
    entry["package_path"] = sideRel
    if .AlchemyTransportFs~isDirectory(sideTarget) then do
      entry["status"] = "EXISTING_PRESERVED"
      preserved~append(sideRel)
    end
    else do
      entry["status"] = "SEEDED"
      seeded~append(sideRel)
      if \dryRun then do
        runner~require(.array~of("mkdir", "-p", sideTarget), "", "sidecar seed target")
        do sourceFile over inventory~sidecars
          runner~require(.array~of("cp", "-a", "--", sourceFile, sideTarget || "/"), "", "sidecar seed copy")
        end
      end
    end
    entries~append(entry)
  end

  seeded = self~uniqueSorted(seeded)
  preserved = self~uniqueSorted(preserved)
  if dryRun then do
    tx~close
    runner~run(.array~of("rm", "-rf", "--", workspace))
    return .AlchemySeedResult~new(seedId, inventory~bundleSha256, seeded, preserved, "", "", .true)
  end

  bootstrap = tx~root || "/bootstrap"
  if \ .AlchemyTransportFs~isDirectory(bootstrap) then runner~require(.array~of("mkdir", "-p", bootstrap), "", "bootstrap directory")
  ledgerRel = "bootstrap/dependency-seed-" || seedId || ".json"
  ledgerPath = tx~root || "/" || ledgerRel
  ledger = .directory~new
  ledger["schema"] = "alchemy.bootstrap.dependency-seed/0.1"
  ledger["seed_id"] = seedId
  ledger["source_bundle"] = filespec("N", bundlePath)
  ledger["source_bundle_sha256"] = inventory~bundleSha256
  ledger["status_semantics"] = .AlchemyDependencyFloorBuild~SEMANTICS
  ledger["entries"] = entries
  .JSON~toJsonFile(ledgerPath, ledger, .true)

  commit = tx~commitAndPush(.array~of("packages", ledgerRel), "bootstrap: seed ooRexx dependency floor " || seedId)
  tx~close
  runner~run(.array~of("rm", "-rf", "--", workspace))
  return .AlchemySeedResult~new(seedId, inventory~bundleSha256, seeded, preserved, ledgerRel, commit, .false)

::method uniqueSorted private
  use strict arg values
  seen = .table~new
  out = .array~new
  do value over values
    if \seen~hasIndex(value) then do
      seen[value] = .true
      out~append(value)
    end
  end
  out~sort
  return out


::class AlchemyCatalogDependencyFloorEntry subclass AlchemyDependencyFloorEntry public
::attribute identitySource get
::attribute manifestPath get

::method init
  expose identitySource manifestPath
  use strict arg packageId, root, exportName="", rexxEntries=.nil, identitySource="DIRECTORY_FALLBACK", manifestPath=""
  self~init:super(packageId, root, exportName, rexxEntries)
  identitySource=identitySource~string~strip~upper
  manifestPath=manifestPath~string
  if identitySource<>"MANIFEST" & identitySource<>"DIRECTORY_FALLBACK" then -
    raise syntax 88.900 array("invalid dependency identity source: " || identitySource)


::class AlchemyRepositoryDependencyCatalog subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyRepositoryDependencyCatalog", "0.4", "Manifest-first accepted dependency catalog")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method build
  expose runner
  use strict arg repoRoot
  packagesRoot=repoRoot || "/packages"
  floor=.AlchemyDependencyFloor~new
  if \.AlchemyTransportFs~isDirectory(packagesRoot) then return floor
  listed=runner~require(.array~of("find",packagesRoot,"-mindepth","1","-maxdepth","1","-type","d","-print"),"","dependency catalog scan")
  paths=.AlchemyTransportText~lines(listed~stdout); paths~sort
  do root over paths
    manifest=root || "/integration.json"
    identitySource=""
    manifestPath=""
    if .AlchemyTransportFs~isFile(manifest) then do
      /* A present manifest is authoritative.  Decode failure is corruption. */
      spec=.AlchemyIntegrationCodec~decodeFile(manifest)
      parsed=spec~packageId
      identitySource="MANIFEST"
      manifestPath=manifest
    end
    else do
      leaf=filespec("N",root)
      parsed=self~parseVersionedDirectory(leaf)
      if parsed==.nil then iterate
      identitySource="DIRECTORY_FALLBACK"
    end

    rexx=.array~new
    if .AlchemyTransportFs~isDirectory(root || "/src") then rexx~append("src")
    rexx~append(".")
    entry=.AlchemyCatalogDependencyFloorEntry~new(parsed,root,self~conventionalExport(parsed~name),rexx,identitySource,manifestPath)
    floor~add(entry)
  end
  return floor

::method parseVersionedDirectory
  use strict arg leaf
  marker=leaf~lastPos("_v")
  if marker<=1 then return .nil
  name=leaf~left(marker-1)
  version=leaf~substr(marker+2)
  if name="" | version="" then return .nil
  if \datatype(version~left(1), "W") then return .nil
  return .AlchemyPackageId~new(name,version)

::method conventionalExport
  use strict arg name
  src=name~string~upper
  out=""
  allowed="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
  do i=1 to src~length
    ch=src~substr(i,1)
    if allowed~pos(ch)>0 then out ||= ch
    else out ||= "_"
  end
  return out || "_ROOT"

::requires "AlchemyTransport.cls"
::requires "AlchemyPackageModel.cls"
::requires "json.cls"
::requires "AlchemyCoreComponent.cls"
