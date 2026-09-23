/* Governed package release creation.
 *
 * A release is not "zip the current directory".  The service creates a new
 * immutable snapshot, applies a bounded hygiene policy, writes a fresh
 * MANIFEST.sha256, verifies the snapshot, creates one ZIP artifact, verifies
 * that ZIP, and writes a durable external receipt.  The caller never supplies
 * shell text and the source working tree is never cleaned or modified.
 */

::class LlmPaPackageReleaseRunner public

::method hash
  use arg pathArg
  path = pathArg~string
  if path = "" | path~pos("'") > 0 then return .LlmPaResult~failure("HASH_PATH_INVALID", path)
  return self~execute("sha256sum " || self~quote(path))

::method makeArchive
  use arg parentArg, packageNameArg, archiveArg
  parent = parentArg~string
  packageName = packageNameArg~string
  archive = archiveArg~string
  if parent = "" | archive = "" | packageName = "" then return .LlmPaResult~failure("ARCHIVE_ARGUMENT_REQUIRED")
  if parent~pos("'") > 0 | archive~pos("'") > 0 | packageName~pos("'") > 0 then return .LlmPaResult~failure("ARCHIVE_ARGUMENT_INVALID")
  /* -X strips nonessential host-specific extra attributes.  The package name
   * is a validated single path component, so no caller shell syntax is used. */
  return self~execute("zip -q -X -r " || self~quote(archive) || " " || self~quote(packageName), parent)

::method unsafeNodes
  use arg rootArg
  root = rootArg~string
  if root = "" | root~pos("'") > 0 then return .LlmPaResult~failure("RELEASE_SOURCE_PATH_INVALID", root)
  return self~execute("find " || self~quote(root) || " \( -type l -o -type b -o -type c -o -type p -o -type s \) -print")

::method testArchive
  use arg archiveArg
  archive = archiveArg~string
  if archive = "" | archive~pos("'") > 0 then return .LlmPaResult~failure("ARCHIVE_PATH_INVALID", archive)
  return self~execute("unzip -tqq " || self~quote(archive))

::method archiveNames
  use arg archiveArg
  archive = archiveArg~string
  if archive = "" | archive~pos("'") > 0 then return .LlmPaResult~failure("ARCHIVE_PATH_INVALID", archive)
  return self~execute("unzip -Z1 " || self~quote(archive))

::method execute private
  use arg commandArg, cwdArg = ""
  commandText = commandArg~string
  cwd = cwdArg~string
  out = .array~new
  err = .array~new
  previous = directory()
  if cwd \= "" then do
    changed = directory(cwd)
    if changed = "" then return .LlmPaResult~failure("RELEASE_CWD_FAILED", cwd)
  end
  address system commandText with output using (out) error using (err)
  commandRc = rc
  if cwd \= "" then ignore = directory(previous)
  d = .directory~new
  d["rc"] = commandRc
  d["stdout"] = out
  d["stderr"] = err
  return .LlmPaResult~success(d)

::method quote private
  use arg text
  return "'" || text || "'"


::class LlmPaPackageReleasePolicy public

/* Return a stable reason string for material that is source/build/runtime
 * detritus and therefore must not enter a release snapshot.  The source tree
 * itself remains untouched. */
::method excludeReason
  use arg relativeArg
  relative = relativeArg~string~changestr("\\", "/")
  lower = relative~lower
  base = self~baseName(lower)

  if relative = "" then return "INVALID_EMPTY_PATH"
  if relative~left(1) = "/" | relative~pos("../") > 0 | relative~pos("/..") > 0 then return "INVALID_RELATIVE_PATH"
  if relative~pos("0a"x) > 0 | relative~pos("0d"x) > 0 | relative~pos("09"x) > 0 then return "INVALID_CONTROL_CHARACTER"

  /* Release-generated or live-state files. */
  if lower = "manifest.sha256" then return "REGENERATED_MANIFEST"
  if lower = "release_receipt.json" then return "REGENERATED_RELEASE_RECEIPT"
  if lower = "ledgerpath" then return "RUNTIME_ACCOUNTING_LEDGER"
  if lower~left(8) = "runtime/" then return "RUNTIME_STATE"
  if lower = "runtime" then return "RUNTIME_STATE"
  if lower~left(23) = "tests/live-gemma-store-" then return "LIVE_TEST_STATE"
  if lower~left(10) = "tests/tmp-" then return "TEST_SCRATCH"
  if lower~left(14) = "tests/runtime-" then return "TEST_RUNTIME_STATE"

  /* Source-control/editor/cache directories. */
  if self~hasSegment(lower, ".git") then return "SOURCE_CONTROL_METADATA"
  if self~hasSegment(lower, ".hg") then return "SOURCE_CONTROL_METADATA"
  if self~hasSegment(lower, ".svn") then return "SOURCE_CONTROL_METADATA"
  if self~hasSegment(lower, "__pycache__") then return "PYTHON_BYTECODE_CACHE"
  if self~hasSegment(lower, ".pytest_cache") then return "PYTHON_TEST_CACHE"
  if self~hasSegment(lower, ".mypy_cache") then return "PYTHON_TYPE_CACHE"
  if self~hasSegment(lower, ".ruff_cache") then return "PYTHON_LINT_CACHE"
  if self~hasSegment(lower, ".tox") then return "TEST_ENVIRONMENT"
  if self~hasSegment(lower, ".nox") then return "TEST_ENVIRONMENT"
  if self~hasSegment(lower, "node_modules") then return "DEPENDENCY_BUILD_TREE"
  if self~hasSegment(lower, "htmlcov") then return "COVERAGE_OUTPUT"

  /* Compiled objects, transient output and editor debris. */
  if self~endsWith(base, ".pyc") | self~endsWith(base, ".pyo") then return "PYTHON_COMPILED_ARTIFACT"
  if self~endsWith(base, ".class") then return "COMPILED_CLASS_ARTIFACT"
  if self~endsWith(base, ".o") | self~endsWith(base, ".obj") then return "COMPILED_OBJECT_ARTIFACT"
  if self~endsWith(base, ".swp") | self~endsWith(base, ".swo") | self~endsWith(base, "~") then return "EDITOR_SCRATCH"
  if self~endsWith(base, ".tmp") | self~endsWith(base, ".temp") | self~endsWith(base, ".bak") then return "TEMPORARY_FILE"
  if self~endsWith(base, ".orig") | self~endsWith(base, ".rej") then return "PATCH_DETRITUS"
  if self~endsWith(base, ".log") | self~endsWith(base, ".pid") | self~endsWith(base, ".sock") then return "RUNTIME_DETRITUS"
  if base = ".coverage" | base = "coverage.xml" then return "COVERAGE_OUTPUT"
  if base = ".ds_store" | base = "thumbs.db" | base = "nohup.out" then return "PLATFORM_DETRITUS"
  if base = "core" | base~left(5) = "core." then return "CRASH_DUMP"
  return ""

::method mandatoryFiles
  return .array~of("VERSION.txt", "README.md", "integration.json")

::method hasSegment private
  use arg path, wanted
  padded = "/" || path || "/"
  return padded~pos("/" || wanted || "/") > 0

::method baseName private
  use arg path
  p = path~lastpos("/")
  if p = 0 then return path
  return path~substr(p + 1)

::method endsWith private
  use arg text, suffix
  if suffix~length > text~length then return .false
  return text~right(suffix~length) = suffix


::class LlmPaPackageReleaseQualifier public

::method qualify
  use arg snapshotArg, policyArg
  snapshot = snapshotArg~string
  policy = policyArg
  mandatory = policy~mandatoryFiles
  missing = .array~new
  do relative over mandatory
    if stream(snapshot || "/" || relative, "C", "QUERY EXISTS") = "" then missing~append(relative)
  end
  if missing~items > 0 then return .LlmPaResult~failure("RELEASE_REQUIRED_FILE_MISSING", self~join(missing))

  integrationPath = snapshot || "/integration.json"
  integrationText = self~readText(integrationPath)
  if integrationText = "" then return .LlmPaResult~failure("RELEASE_INTEGRATION_EMPTY", integrationPath)
  signal on syntax name integrationBad
  integration = .JSON~fromJSON(integrationText)
  signal off syntax
  if \integration~isa(.Directory) then return .LlmPaResult~failure("RELEASE_INTEGRATION_INVALID", "integration.json must be a JSON object")

  d = .directory~new
  d["status"] = "QUALIFIED_RELEASE_STRUCTURE"
  d["mandatory_files"] = mandatory
  d["integration_schema"] = self~field(integration, "schema")
  d["package"] = self~field(integration, "package")
  d["api"] = self~field(integration, "api")
  return .LlmPaResult~success(d)

integrationBad:
  signal off syntax
  return .LlmPaResult~failure("RELEASE_INTEGRATION_INVALID", "integration.json could not be parsed")

::method field private
  use arg d, key
  if d~hasIndex(key) then return d[key]
  return ""

::method readText private
  use arg path
  text = ""
  call stream path, "C", "OPEN READ"
  do while lines(path) > 0
    line = linein(path)
    if text \= "" then text = text || "0a"x
    text = text || line
  end
  call stream path, "C", "CLOSE"
  return text

::method join private
  use arg values
  text = ""
  do value over values
    if text \= "" then text = text || ", "
    text = text || value
  end
  return text



/* Cognitive release decisions are data, not filename heuristics.  Hygiene is
 * objective and remains policy-owned.  Pruning/version selection/conflict
 * disposition is an explicit decision with authority and reason. */
::class LlmPaPackageReleaseDecisionSet public
::attribute rows get

::method init
  expose rows
  rows = .array~new

::method fromFile class
  use arg pathArg
  path = pathArg~string~strip
  if path = "" | stream(path, "C", "QUERY EXISTS") = "" then return .LlmPaResult~failure("RELEASE_DECISIONS_NOT_FOUND", path)
  text = ""
  call stream path, "C", "OPEN READ"
  do while lines(path) > 0
    line = linein(path)
    if text \= "" then text = text || "0a"x
    text = text || line
  end
  call stream path, "C", "CLOSE"
  signal on syntax name decisionsBad
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .LlmPaResult~failure("RELEASE_DECISIONS_INVALID", "decision file must be a JSON object")
  if \data~hasIndex("decisions") then return .LlmPaResult~failure("RELEASE_DECISIONS_INVALID", "decision file has no decisions array")
  entries = data["decisions"]
  if \entries~isa(.Array) then return .LlmPaResult~failure("RELEASE_DECISIONS_INVALID", "decisions must be an array")
  set = self~new
  do row over entries
    if \row~isa(.Directory) then return .LlmPaResult~failure("RELEASE_DECISION_INVALID", "decision entry must be an object")
    scope = self~field(row, "scope")~upper~strip
    action = self~field(row, "action")~upper~strip
    reason = self~field(row, "reason")~strip
    authority = self~field(row, "authority")~strip
    if authority = "" then authority = "architect"
    if scope = "PATH" then do
      pathValue = self~field(row, "path")
      if action = "PRUNE" then ignore = set~prune(pathValue, reason, authority)
      else if action = "KEEP" then ignore = set~keep(pathValue, reason, authority)
      else return .LlmPaResult~failure("RELEASE_DECISION_INVALID", "unsupported path action " || action)
    end
    else if scope = "CONFLICT" then do
      conflictId = self~field(row, "conflict_id")
      if action = "KEEP_BOTH" then ignore = set~keepBoth(conflictId, reason, authority)
      else if action = "QUARANTINE_CONFLICT" then ignore = set~quarantineConflict(conflictId, reason, authority)
      else return .LlmPaResult~failure("RELEASE_DECISION_INVALID", "unsupported conflict action " || action)
    end
    else return .LlmPaResult~failure("RELEASE_DECISION_INVALID", "unsupported scope " || scope)
  end
  return .LlmPaResult~success(set)

decisionsBad:
  signal off syntax
  return .LlmPaResult~failure("RELEASE_DECISIONS_INVALID", "decision file could not be parsed")

::method field class private
  use arg row, key
  if row~hasIndex(key) then return row[key]~string
  return ""

::method prune
  use arg pathArg, reasonArg, authorityArg = "architect"
  return self~addPath("PRUNE", pathArg, reasonArg, authorityArg)

::method keep
  use arg pathArg, reasonArg, authorityArg = "architect"
  return self~addPath("KEEP", pathArg, reasonArg, authorityArg)

::method keepBoth
  use arg conflictIdArg, reasonArg, authorityArg = "architect"
  return self~addConflict("KEEP_BOTH", conflictIdArg, reasonArg, authorityArg)

::method quarantineConflict
  use arg conflictIdArg, reasonArg, authorityArg = "architect"
  return self~addConflict("QUARANTINE_CONFLICT", conflictIdArg, reasonArg, authorityArg)

::method addPath private
  expose rows
  use arg actionArg, pathArg, reasonArg, authorityArg
  action = actionArg~string~upper~strip
  path = self~relative(pathArg)
  reason = reasonArg~string~strip
  authority = authorityArg~string~strip
  if path = "" then raise syntax 88.900 array("release path decision requires a safe relative path")
  if reason = "" then raise syntax 88.900 array("release path decision requires a reason")
  if authority = "" then raise syntax 88.900 array("release path decision requires an authority")
  row = .directory~new
  row["scope"] = "PATH"
  row["action"] = action
  row["path"] = path
  row["reason"] = reason
  row["authority"] = authority
  rows~append(row)
  return row

::method addConflict private
  expose rows
  use arg actionArg, conflictIdArg, reasonArg, authorityArg
  action = actionArg~string~upper~strip
  conflictId = conflictIdArg~string~strip
  reason = reasonArg~string~strip
  authority = authorityArg~string~strip
  if conflictId = "" then raise syntax 88.900 array("release conflict decision requires a conflict id")
  if reason = "" then raise syntax 88.900 array("release conflict decision requires a reason")
  if authority = "" then raise syntax 88.900 array("release conflict decision requires an authority")
  row = .directory~new
  row["scope"] = "CONFLICT"
  row["action"] = action
  row["conflict_id"] = conflictId
  row["reason"] = reason
  row["authority"] = authority
  rows~append(row)
  return row

::method pathAction
  expose rows
  use arg pathArg
  wanted = self~relative(pathArg)
  found = .nil
  do row over rows
    if row["scope"] = "PATH" & row["path"] = wanted then found = row
  end
  return found

::method conflictAction
  expose rows
  use arg conflictIdArg
  wanted = conflictIdArg~string~strip
  found = .nil
  do row over rows
    if row["scope"] = "CONFLICT" & row["conflict_id"] = wanted then found = row
  end
  return found

::method asArray
  expose rows
  return rows

::method relative private
  use arg pathArg
  path = pathArg~string~changestr("\\", "/")~strip
  do while path~left(2) = "./"
    path = path~substr(3)
  end
  if path = "" | path~left(1) = "/" then return ""
  if ("/" || path || "/")~pos("/../") > 0 then return ""
  if path~pos("0a"x) > 0 | path~pos("0d"x) > 0 | path~pos("09"x) > 0 then return ""
  return path


/* Analyse the assembled source as evidence.  It does NOT decide that a newer
 * looking filename supersedes an older one.  It reports relationships that a
 * PA/operator may use when making a release decision. */
::class LlmPaPackageReleaseAnalyzer public
::attribute runner get

::method init
  expose runner
  use arg runnerArg = .nil
  runner = runnerArg
  if runner == .nil then runner = .LlmPaPackageReleaseRunner~new

::method analyse
  expose runner
  use arg sourceRootArg, includedArg
  sourceRoot = sourceRootArg~string
  included = includedArg
  digests = .directory~new
  identities = .directory~new
  basenames = .directory~new
  archives = .directory~new
  observations = .array~new
  conflicts = .array~new
  logicalGroups = .directory~new

  do relative over included
    full = sourceRoot || "/" || relative
    hashed = self~hashPath(full)
    if \hashed~ok then return hashed
    digest = hashed~value
    digests[relative] = digest
    zone = self~zone(relative)
    lower = relative~lower
    if self~isRexxSource(lower) then do
      ids = self~publicIdentities(full)
      do identity over ids
        key = identity~upper
        self~appendOwner(identities, key, relative)
      end
      if zone = "SRC" | zone = "DEPS" then self~appendOwner(basenames, self~baseName(lower), relative)
    end
    if self~endsWith(lower, ".zip") then self~appendOwner(archives, self~baseName(lower), relative)
  end

  supplier = identities~supplier
  do while supplier~available
    key = supplier~index
    owners = supplier~item
    supplier~next
    if owners~items < 2 then iterate
    prod = self~productionOwners(owners)
    if prod~items < 2 then do
      if owners~items > 1 then observations~append(self~observation("TEST_OR_LOCAL_IDENTITY_DUPLICATE", key, owners, digests))
      iterate
    end
    unique = self~uniqueDigestCount(prod, digests)
    if unique > 1 then do
      conflicts~append(self~conflict("PRODUCTION_LOGICAL_SHADOW", key, prod, digests, .true, "different production files export the same public ooRexx identity"))
      logicalGroups[self~ownerKey(prod)] = .true
    end
    else observations~append(self~observation("IDENTICAL_PRODUCTION_IDENTITY", key, prod, digests))
  end

  supplier = basenames~supplier
  do while supplier~available
    key = supplier~index
    owners = supplier~item
    supplier~next
    if owners~items < 2 then iterate
    if \self~crossesSrcDeps(owners) then iterate
    if logicalGroups~hasIndex(self~ownerKey(owners)) then iterate
    if self~uniqueDigestCount(owners, digests) > 1 then conflicts~append(self~conflict("SRC_DEPS_BASENAME_SHADOW", key, owners, digests, .true, "src and deps contain different ooRexx sources with the same basename"))
    else observations~append(self~observation("IDENTICAL_SRC_DEPS_BASENAME", key, owners, digests))
  end

  supplier = archives~supplier
  do while supplier~available
    key = supplier~index
    owners = supplier~item
    supplier~next
    if owners~items < 2 then iterate
    if self~uniqueDigestCount(owners, digests) > 1 then conflicts~append(self~conflict("COMPETING_ARCHIVE_CUT", key, owners, digests, .true, "same archive name exists with different bytes"))
    else observations~append(self~observation("IDENTICAL_ARCHIVE_COPY", key, owners, digests))
  end

  /* Give deterministic ids after deterministic path inventory.  We do not use
   * ids as authority; they are stable handles for an explicit decision. */
  index = 0
  do row over conflicts
    index = index + 1
    row["conflict_id"] = "conflict-" || index~right(4, "0")
  end

  d = .directory~new
  d["conflicts"] = conflicts
  d["observations"] = observations
  d["blocking_count"] = conflicts~items
  return .LlmPaResult~success(d)

::method hashPath private
  expose runner
  use arg path
  hashed = runner~hash(path)
  if \hashed~ok then return hashed
  if hashed~value["rc"] \= 0 | hashed~value["stdout"]~items = 0 then return .LlmPaResult~failure("RELEASE_ANALYSIS_HASH_FAILED", path)
  digest = word(hashed~value["stdout"][1], 1)
  if digest~length \= 64 then return .LlmPaResult~failure("RELEASE_ANALYSIS_HASH_INVALID", path)
  return .LlmPaResult~success(digest)

::method publicIdentities private
  use arg path
  out = .array~new
  call stream path, "C", "OPEN READ"
  do while lines(path) > 0
    source = linein(path)~strip
    upper = source~upper
    if upper~left(8) = "::CLASS " then do
      if upper~pos(" PUBLIC") > 0 then out~append("CLASS:" || word(source, 2)~upper)
    end
    else if upper~left(10) = "::ROUTINE " then do
      if upper~pos(" PUBLIC") > 0 then out~append("ROUTINE:" || word(source, 2)~upper)
    end
  end
  call stream path, "C", "CLOSE"
  return out

::method appendOwner private
  use arg table, keyArg, pathArg
  key = keyArg~string
  if \table~hasIndex(key) then table[key] = .array~new
  paths = table[key]
  do existing over paths
    if existing = pathArg then return
  end
  paths~append(pathArg)
  return

::method productionOwners private
  use arg owners
  out = .array~new
  do path over owners
    z = self~zone(path)
    if z = "SRC" | z = "DEPS" then out~append(path)
  end
  return out

::method crossesSrcDeps private
  use arg owners
  src = .false
  deps = .false
  do path over owners
    z = self~zone(path)
    if z = "SRC" then src = .true
    if z = "DEPS" then deps = .true
  end
  return src & deps

::method zone private
  use arg relativeArg
  lower = relativeArg~string~lower~changestr("\\", "/")
  if lower~left(6) = "tests/" | lower~pos("/tests/") > 0 then return "TEST"
  if lower~left(4) = "src/" then return "SRC"
  if lower~left(5) = "deps/" then return "DEPS"
  return "OTHER"

::method isRexxSource private
  use arg lower
  return self~endsWith(lower, ".cls") | self~endsWith(lower, ".rex")

::method uniqueDigestCount private
  use arg owners, digests
  seen = .directory~new
  do path over owners
    digest = digests[path]
    seen[digest] = .true
  end
  return seen~items

::method ownerKey private
  use arg owners
  text = ""
  do path over owners
    if text \= "" then text = text || "|"
    text = text || path
  end
  return text

::method conflict private
  use arg kind, key, owners, digests, blocking, reason
  row = .directory~new
  row["kind"] = kind
  row["key"] = key
  row["paths"] = owners
  row["digests"] = self~digestRows(owners, digests)
  row["blocking"] = blocking
  row["reason"] = reason
  return row

::method observation private
  use arg kind, key, owners, digests
  row = .directory~new
  row["kind"] = kind
  row["key"] = key
  row["paths"] = owners
  row["digests"] = self~digestRows(owners, digests)
  return row

::method digestRows private
  use arg owners, digests
  rows = .array~new
  do path over owners
    row = .directory~new
    row["path"] = path
    row["sha256"] = digests[path]
    rows~append(row)
  end
  return rows

::method baseName private
  use arg path
  p = path~lastpos("/")
  if p = 0 then return path
  return path~substr(p + 1)

::method endsWith private
  use arg text, suffix
  if suffix~length > text~length then return .false
  return text~right(suffix~length) = suffix


::class LlmPaPackageRelease public
::attribute releaseRoot get
::attribute runner get
::attribute policy get
::attribute qualifier get
::attribute approvedSourceRoot get
::attribute analyzer get

::method init
  expose releaseRoot runner policy qualifier approvedSourceRoot analyzer
  use arg rootArg = "", runnerArg = .nil, policyArg = .nil, qualifierArg = .nil, approvedSourceRootArg = "", analyzerArg = .nil
  releaseRoot = rootArg~string~strip
  if releaseRoot = "" then releaseRoot = "/tmp/llmpa-releases"
  if \self~safeAbsolutePath(releaseRoot) then raise syntax 88.900 array("package release root must be a safe absolute path")
  runner = runnerArg
  if runner == .nil then runner = .LlmPaPackageReleaseRunner~new
  policy = policyArg
  if policy == .nil then policy = .LlmPaPackageReleasePolicy~new
  qualifier = qualifierArg
  if qualifier == .nil then qualifier = .LlmPaPackageReleaseQualifier~new
  analyzer = analyzerArg
  if analyzer == .nil then analyzer = .LlmPaPackageReleaseAnalyzer~new(runner)
  approvedSourceRoot = approvedSourceRootArg~string~strip
  if approvedSourceRoot = "" then approvedSourceRoot = directory()
  approvedSourceRoot = self~canonicalDirectory(self~absolutePath(approvedSourceRoot))
  if approvedSourceRoot = "" | \self~safeAbsolutePath(approvedSourceRoot) then raise syntax 88.900 array("package release approved source root must be a readable directory")

::method analyse
  expose releaseRoot runner policy qualifier approvedSourceRoot analyzer
  use arg sourceArg, decisionsArg = .nil
  requestedSource = self~absolutePath(sourceArg)
  sourceRoot = self~canonicalDirectory(requestedSource)
  if sourceRoot = "" then return self~failure("RELEASE_SOURCE_NOT_FOUND", requestedSource)
  sourceRoot = self~stripTrailingSlash(sourceRoot)
  if \self~safeAbsolutePath(sourceRoot) then return self~failure("RELEASE_SOURCE_PATH_INVALID", sourceRoot)
  if \self~pathWithin(sourceRoot, approvedSourceRoot) then return self~failure("RELEASE_SOURCE_NOT_APPROVED", sourceRoot)
  unsafeNodes = runner~unsafeNodes(sourceRoot)
  if \unsafeNodes~ok | unsafeNodes~value["rc"] \= 0 then return self~failure("RELEASE_SOURCE_TYPE_CHECK_FAILED", self~commandDetail(unsafeNodes))
  if unsafeNodes~value["stdout"]~items > 0 then return self~failure("RELEASE_SOURCE_SPECIAL_FILE", unsafeNodes~value["stdout"][1])

  decisions = .nil
  if decisionsArg == .nil then decisions = .LlmPaPackageReleaseDecisionSet~new
  else if decisionsArg~isa(.LlmPaPackageReleaseDecisionSet) then decisions = decisionsArg
  else return self~failure("RELEASE_DECISION_SET_INVALID", "expected LlmPaPackageReleaseDecisionSet")

  inventory = self~inventory(sourceRoot)
  if \inventory~ok then return inventory
  originalIncluded = inventory~value["included"]
  originalExcluded = inventory~value["excluded"]
  sourceFileCount = originalIncluded~items + originalExcluded~items

  prepared = self~applyPathDecisions(originalIncluded, originalExcluded, decisions)
  included = prepared["included"]
  excluded = prepared["excluded"]
  decisionEffects = prepared["effects"]
  if included~items = 0 then return self~failure("RELEASE_SOURCE_EMPTY", sourceRoot)

  analysed = analyzer~analyse(sourceRoot, included)
  if \analysed~ok then return analysed
  resolved = self~resolveConflicts(included, analysed~value["conflicts"], decisions)

  d = .directory~new
  d["schema"] = "llm.pa.package.release.analysis/0.1"
  d["source_root"] = sourceRoot
  d["source_file_count"] = sourceFileCount
  d["included"] = resolved["included"]
  d["excluded"] = excluded
  d["quarantined"] = resolved["quarantined"]
  d["decision_effects"] = decisionEffects
  d["decisions"] = decisions~asArray
  d["conflicts"] = analysed~value["conflicts"]
  d["observations"] = analysed~value["observations"]
  d["conflict_resolutions"] = resolved["resolutions"]
  d["unresolved_conflicts"] = resolved["unresolved"]
  d["review_required"] = resolved["unresolved"]~items > 0
  return .LlmPaResult~success(d)

::method release
  expose releaseRoot runner policy qualifier approvedSourceRoot analyzer
  use arg sourceArg, releaseNameArg = "", decisionsArg = .nil
  analysed = self~analyse(sourceArg, decisionsArg)
  if \analysed~ok then return analysed
  analysis = analysed~value
  sourceRoot = analysis["source_root"]
  unresolved = analysis["unresolved_conflicts"]
  if unresolved~items > 0 then return self~failure("RELEASE_REVIEW_REQUIRED", .JSON~toJSON(unresolved))

  releaseName = releaseNameArg~string~strip
  if releaseName = "" then releaseName = self~baseName(sourceRoot)
  if \self~safeName(releaseName) then return self~failure("RELEASE_NAME_INVALID", releaseName)

  ready = self~ensureLayout
  if \ready~ok then return ready

  included = analysis["included"]
  excluded = analysis["excluded"]
  quarantined = analysis["quarantined"]
  entries = self~buildEntries(included, quarantined)
  targets = self~entryTargets(entries)
  if targets~items = 0 then return self~failure("RELEASE_SOURCE_EMPTY", sourceRoot)

  releaseId = "release-attempt-" || .LlmPaUtil~requestId~changestr("pa-", "")
  attemptRoot = releaseRoot || "/attempts/" || releaseName || "-" || releaseId
  snapshot = attemptRoot || "/" || releaseName
  if \self~ensureDir(snapshot) then return self~failure("RELEASE_ATTEMPT_CREATE_FAILED", attemptRoot)

  copied = self~copyEntries(sourceRoot, snapshot, entries)
  if \copied~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, "COPY_FAILED", copied~detail)

  manifest = self~writeManifest(snapshot, targets)
  if \manifest~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, manifest~code, manifest~detail)
  manifestPath = snapshot || "/MANIFEST.sha256"
  manifestHash = self~hashPath(manifestPath)
  if \manifestHash~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, manifestHash~code, manifestHash~detail)
  treeHash = manifestHash~value

  verified = self~verifyManifest(snapshot)
  if \verified~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, verified~code, verified~detail)
  clean = self~verifySnapshotHygiene(snapshot)
  if \clean~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, clean~code, clean~detail)
  qualified = qualifier~qualify(snapshot, policy)
  if \qualified~ok then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, qualified~code, qualified~detail)

  generationParent = releaseRoot || "/generations/" || releaseName
  if \self~ensureDir(generationParent) then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, "GENERATION_PARENT_CREATE_FAILED", generationParent)
  generation = generationParent || "/" || treeHash
  if self~directoryExists(generation) then do
    publishedSnapshot = generation || "/" || releaseName
    generationManifest = self~hashPath(publishedSnapshot || "/MANIFEST.sha256")
    if \generationManifest~ok | generationManifest~value \= treeHash then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, "GENERATION_COLLISION", generation)
  end
  else do
    moveRc = SysFileMove(attemptRoot, generation)
    if moveRc \= 0 then return self~failureReceipt(attemptRoot, releaseName, sourceRoot, targets, excluded, "GENERATION_PUBLISH_FAILED", generation)
    publishedSnapshot = generation || "/" || releaseName
  end

  archivePath = releaseRoot || "/artifacts/" || releaseName || "-" || treeHash~left(16) || ".zip"
  if stream(archivePath, "C", "QUERY EXISTS") = "" then do
    archived = runner~makeArchive(generation, releaseName, archivePath)
    if \archived~ok | archived~value["rc"] \= 0 then return self~failure("RELEASE_ARCHIVE_FAILED", self~commandDetail(archived))
  end
  tested = runner~testArchive(archivePath)
  if \tested~ok | tested~value["rc"] \= 0 then return self~failure("RELEASE_ARCHIVE_INVALID", self~commandDetail(tested))
  archiveInventory = self~verifyArchiveInventory(archivePath, releaseName, targets)
  if \archiveInventory~ok then return archiveInventory
  archiveHashResult = self~hashPath(archivePath)
  if \archiveHashResult~ok then return archiveHashResult
  archiveHash = archiveHashResult~value

  receiptPath = releaseRoot || "/receipts/" || releaseName || "-" || treeHash || ".json"
  existingReceipt = self~readReceipt(receiptPath)
  if existingReceipt \== .nil then do
    if existingReceipt~hasIndex("tree_manifest_sha256") & existingReceipt~hasIndex("artifact_sha256") then do
      if existingReceipt["tree_manifest_sha256"] = treeHash & existingReceipt["artifact_sha256"] = archiveHash then return .LlmPaResult~success(existingReceipt)
    end
    return self~failure("RELEASE_RECEIPT_COLLISION", receiptPath)
  end

  receipt = .directory~new
  receipt["schema"] = "llm.pa.package.release/0.2"
  receipt["release_id"] = "release-" || treeHash~left(16)
  if quarantined~items > 0 then receipt["status"] = "RELEASE_READY_WITH_QUARANTINE"
  else receipt["status"] = "RELEASE_READY"
  receipt["created_at"] = .LlmPaUtil~timestamp
  receipt["source_root"] = sourceRoot
  receipt["release_name"] = releaseName
  receipt["source_file_count"] = analysis["source_file_count"]
  receipt["released_file_count"] = targets~items + 1
  receipt["excluded_count"] = excluded~items
  receipt["excluded"] = excluded
  receipt["quarantined"] = quarantined
  receipt["decision_effects"] = analysis["decision_effects"]
  receipt["decisions"] = analysis["decisions"]
  receipt["conflicts"] = analysis["conflicts"]
  receipt["conflict_resolutions"] = analysis["conflict_resolutions"]
  receipt["observations"] = analysis["observations"]
  receipt["tree_manifest_sha256"] = treeHash
  receipt["generation"] = generation
  receipt["snapshot"] = publishedSnapshot
  receipt["artifact"] = archivePath
  receipt["artifact_sha256"] = archiveHash
  receipt["source_tree_modified"] = .false
  receipt["qualification"] = qualified~value
  receipt["manifest_verified"] = .true
  receipt["archive_verified"] = .true
  receipt["archive_inventory_verified"] = .true

  written = self~writeReceipt(receiptPath, receipt)
  if \written~ok then return written
  return .LlmPaResult~success(receipt)

::method applyPathDecisions private
  use arg includedArg, excludedArg, decisions
  included = .array~new
  excluded = .array~new
  effects = .array~new
  do row over excludedArg
    excluded~append(row)
  end
  do relative over includedArg
    decision = decisions~pathAction(relative)
    if decision \== .nil then do
      if decision["action"] = "PRUNE" then do
      row = .directory~new
      row["path"] = relative
      row["reason"] = "COGNITIVE_PRUNE"
      row["decision_reason"] = decision["reason"]
      row["authority"] = decision["authority"]
      excluded~append(row)
      effect = .directory~new
      effect["action"] = "PRUNE"
      effect["path"] = relative
      effect["reason"] = decision["reason"]
      effect["authority"] = decision["authority"]
      effects~append(effect)
      end
      else do
        included~append(relative)
        effect = .directory~new
        effect["action"] = decision["action"]
        effect["path"] = relative
        effect["reason"] = decision["reason"]
        effect["authority"] = decision["authority"]
        effects~append(effect)
      end
    end
    else included~append(relative)
  end
  d = .directory~new
  d["included"] = included
  d["excluded"] = excluded
  d["effects"] = effects
  return d

::method resolveConflicts private
  use arg includedArg, conflicts, decisions
  active = .directory~new
  do path over includedArg
    active[path] = .true
  end
  quarantined = .array~new
  resolutions = .array~new
  unresolved = .array~new
  quarantineSeen = .directory~new

  do conflict over conflicts
    decision = decisions~conflictAction(conflict["conflict_id"])
    if decision == .nil then do
      unresolved~append(conflict)
      iterate
    end
    action = decision["action"]
    if action = "KEEP_BOTH" then do
      if conflict["kind"] = "PRODUCTION_LOGICAL_SHADOW" then do
        rejected = self~copyConflict(conflict)
        rejected["decision_rejected"] = "KEEP_BOTH_NOT_ALLOWED_FOR_PUBLIC_IDENTITY_SHADOW"
        unresolved~append(rejected)
        iterate
      end
      row = .directory~new
      row["conflict_id"] = conflict["conflict_id"]
      row["action"] = action
      row["reason"] = decision["reason"]
      row["authority"] = decision["authority"]
      resolutions~append(row)
      iterate
    end
    if action = "QUARANTINE_CONFLICT" then do
      do path over conflict["paths"]
        if active~hasIndex(path) then active~remove(path)
        key = conflict["conflict_id"] || "|" || path
        if \quarantineSeen~hasIndex(key) then do
          q = .directory~new
          q["conflict_id"] = conflict["conflict_id"]
          q["path"] = path
          q["target_path"] = "_release_conflicts/" || conflict["conflict_id"] || "/" || path
          q["reason"] = decision["reason"]
          q["authority"] = decision["authority"]
          quarantined~append(q)
          quarantineSeen[key] = .true
        end
      end
      row = .directory~new
      row["conflict_id"] = conflict["conflict_id"]
      row["action"] = action
      row["reason"] = decision["reason"]
      row["authority"] = decision["authority"]
      resolutions~append(row)
      iterate
    end
    rejected = self~copyConflict(conflict)
    rejected["decision_rejected"] = "UNSUPPORTED_CONFLICT_ACTION:" || action
    unresolved~append(rejected)
  end

  included = .array~new
  do path over includedArg
    if active~hasIndex(path) then included~append(path)
  end
  d = .directory~new
  d["included"] = included
  d["quarantined"] = quarantined
  d["resolutions"] = resolutions
  d["unresolved"] = unresolved
  return d

::method copyConflict private
  use arg source
  target = .directory~new
  supplier = source~supplier
  do while supplier~available
    target[supplier~index] = supplier~item
    supplier~next
  end
  return target

::method buildEntries private
  use arg included, quarantined
  entries = .array~new
  do relative over included
    row = .directory~new
    row["source_path"] = relative
    row["target_path"] = relative
    entries~append(row)
  end
  do q over quarantined
    row = .directory~new
    row["source_path"] = q["path"]
    row["target_path"] = q["target_path"]
    entries~append(row)
  end
  return entries

::method entryTargets private
  use arg entries
  targets = .array~new
  do row over entries
    targets~append(row["target_path"])
  end
  targets~sort
  return targets

::method copyEntries private
  use arg sourceRoot, snapshot, entries
  do row over entries
    source = sourceRoot || "/" || row["source_path"]
    target = snapshot || "/" || row["target_path"]
    if \self~ensureParent(target) then return .LlmPaResult~failure("RELEASE_PARENT_CREATE_FAILED", row["target_path"])
    copyRc = SysFileCopy(source, target)
    if copyRc \= 0 then return .LlmPaResult~failure("RELEASE_COPY_FAILED", row["source_path"] || " -> " || row["target_path"] || " rc=" || copyRc)
  end
  return .LlmPaResult~success(.true)

::method verifyArchiveInventory private
  expose runner
  use arg archivePath, releaseName, targets
  listed = runner~archiveNames(archivePath)
  if \listed~ok | listed~value["rc"] \= 0 then return self~failure("RELEASE_ARCHIVE_INVENTORY_FAILED", self~commandDetail(listed))
  actual = .directory~new
  do member over listed~value["stdout"]
    text = member~string
    if text = "" | text~right(1) = "/" then iterate
    actual[text] = .true
  end
  expected = .directory~new
  do relative over targets
    expected[releaseName || "/" || relative] = .true
  end
  expected[releaseName || "/MANIFEST.sha256"] = .true
  if actual~items \= expected~items then return self~failure("RELEASE_ARCHIVE_MEMBER_COUNT_MISMATCH", "actual=" || actual~items || " expected=" || expected~items)
  supplier = expected~supplier
  do while supplier~available
    wanted = supplier~index
    supplier~next
    if \actual~hasIndex(wanted) then return self~failure("RELEASE_ARCHIVE_MEMBER_MISSING", wanted)
  end
  return .LlmPaResult~success(.true)

::method inventory private
  expose policy
  use arg sourceRoot
  files = .array~new
  call SysFileTree sourceRoot || "/*", files, "FOS"
  included = .array~new
  excluded = .array~new
  do fullPath over files
    relative = fullPath~substr(sourceRoot~length + 2)~changestr("\\", "/")
    reason = policy~excludeReason(relative)
    if reason = "" then included~append(relative)
    else do
      row = .directory~new
      row["path"] = relative
      row["reason"] = reason
      excluded~append(row)
    end
  end
  included~sort
  d = .directory~new
  d["included"] = included
  d["excluded"] = excluded
  return .LlmPaResult~success(d)

::method copyInventory private
  use arg sourceRoot, snapshot, included
  do relative over included
    source = sourceRoot || "/" || relative
    target = snapshot || "/" || relative
    if \self~ensureParent(target) then return .LlmPaResult~failure("RELEASE_PARENT_CREATE_FAILED", relative)
    copyRc = SysFileCopy(source, target)
    if copyRc \= 0 then return .LlmPaResult~failure("RELEASE_COPY_FAILED", relative || " rc=" || copyRc)
  end
  return .LlmPaResult~success(.true)

::method writeManifest private
  expose runner
  use arg snapshot, included
  linesOut = .array~new
  do relative over included
    hashed = self~hashPath(snapshot || "/" || relative)
    if \hashed~ok then return hashed
    linesOut~append(hashed~value || "  " || relative)
  end
  path = snapshot || "/MANIFEST.sha256"
  call stream path, "C", "OPEN WRITE REPLACE"
  do line over linesOut
    call lineout path, line
  end
  call stream path, "C", "CLOSE"
  return .LlmPaResult~success(linesOut)

::method verifyManifest private
  use arg snapshot
  path = snapshot || "/MANIFEST.sha256"
  if stream(path, "C", "QUERY EXISTS") = "" then return self~failure("RELEASE_MANIFEST_MISSING", path)
  call stream path, "C", "OPEN READ"
  do while lines(path) > 0
    line = linein(path)
    if line = "" then iterate
    expected = word(line, 1)
    relative = line~substr(expected~length + 3)
    if relative = "" then do
      call stream path, "C", "CLOSE"
      return self~failure("RELEASE_MANIFEST_INVALID", line)
    end
    hashed = self~hashPath(snapshot || "/" || relative)
    if \hashed~ok | hashed~value \= expected then do
      call stream path, "C", "CLOSE"
      return self~failure("RELEASE_MANIFEST_MISMATCH", relative)
    end
  end
  call stream path, "C", "CLOSE"
  return .LlmPaResult~success(.true)

::method verifySnapshotHygiene private
  expose policy
  use arg snapshot
  files = .array~new
  call SysFileTree snapshot || "/*", files, "FOS"
  do fullPath over files
    relative = fullPath~substr(snapshot~length + 2)~changestr("\\", "/")
    if relative~lower = "manifest.sha256" then iterate
    reason = policy~excludeReason(relative)
    if reason \= "" then return self~failure("RELEASE_HYGIENE_VIOLATION", relative || ":" || reason)
  end
  return .LlmPaResult~success(.true)

::method failureReceipt private
  expose releaseRoot
  use arg attemptRoot, releaseName, sourceRoot, included, excluded, status, detail
  d = .directory~new
  d["schema"] = "llm.pa.package.release/0.1"
  d["release_id"] = self~baseName(attemptRoot)
  d["status"] = status
  d["created_at"] = .LlmPaUtil~timestamp
  d["source_root"] = sourceRoot
  d["release_name"] = releaseName
  d["attempt"] = attemptRoot
  d["released_file_count"] = included~items
  d["excluded_count"] = excluded~items
  d["excluded"] = excluded
  d["detail"] = detail~string
  d["source_tree_modified"] = .false
  path = releaseRoot || "/receipts/" || self~baseName(attemptRoot) || ".json"
  written = self~writeReceipt(path, d)
  if \written~ok then return written
  return .LlmPaResult~failure(status, detail)

::method readReceipt private
  use arg path
  if stream(path, "C", "QUERY EXISTS") = "" then return .nil
  text = self~readText(path)
  if text = "" then return .nil
  signal on syntax name receiptBad
  parsed = .JSON~fromJSON(text)
  signal off syntax
  if parsed~isa(.Directory) then return parsed
  return .nil
receiptBad:
  signal off syntax
  return .nil

::method writeReceipt private
  use arg path, data
  temporary = path || ".tmp-" || random(100000, 999999)
  call stream temporary, "C", "OPEN WRITE REPLACE"
  call lineout temporary, .JSON~toJSON(data)
  call stream temporary, "C", "CLOSE"
  if stream(path, "C", "QUERY EXISTS") \= "" then do
    /* Receipts are immutable.  Reuse only if byte-identical. */
    existing = self~readText(path)
    candidate = self~readText(temporary)
    if existing = candidate then do
      ignore = SysFileDelete(temporary)
      return .LlmPaResult~success(data)
    end
    return self~failure("RELEASE_RECEIPT_COLLISION", path)
  end
  moveRc = SysFileMove(temporary, path)
  if moveRc \= 0 then return self~failure("RELEASE_RECEIPT_WRITE_FAILED", path || " rc=" || moveRc)
  return .LlmPaResult~success(data)

::method ensureLayout private
  expose releaseRoot
  dirs = .array~of(releaseRoot, releaseRoot || "/attempts", releaseRoot || "/generations", releaseRoot || "/artifacts", releaseRoot || "/receipts")
  do dir over dirs
    if \self~ensureDir(dir) then return self~failure("RELEASE_ROOT_CREATE_FAILED", dir)
  end
  return .LlmPaResult~success(.true)

::method ensureParent private
  use arg path
  p = path~lastpos("/")
  if p <= 1 then return .true
  return self~ensureDir(path~left(p - 1))

::method ensureDir private
  use arg pathArg
  path = self~stripTrailingSlash(pathArg~string)
  if path = "" then return .false
  if self~directoryExists(path) then return .true
  parentPos = path~lastpos("/")
  if parentPos > 1 then do
    parent = path~left(parentPos - 1)
    if \self~directoryExists(parent) then do
      if \self~ensureDir(parent) then return .false
    end
  end
  return SysMkDir(path) = 0 | self~directoryExists(path)

::method directoryExists private
  use arg path
  rows = .array~new
  call SysFileTree path, rows, "DO"
  return rows~items = 1

::method hashPath private
  expose runner
  use arg path
  hashed = runner~hash(path)
  if \hashed~ok then return hashed
  if hashed~value["rc"] \= 0 | hashed~value["stdout"]~items = 0 then return self~failure("RELEASE_HASH_FAILED", path || " " || self~commandDetail(hashed))
  digest = word(hashed~value["stdout"][1], 1)
  if digest~length \= 64 then return self~failure("RELEASE_HASH_INVALID", path)
  return .LlmPaResult~success(digest)

::method commandDetail private
  use arg commandResult
  if commandResult == .nil then return ""
  if \commandResult~ok then return commandResult~code || ":" || commandResult~detail
  text = "rc=" || commandResult~value["rc"]
  if commandResult~value["stderr"]~items > 0 then text = text || " stderr=" || self~join(commandResult~value["stderr"])
  return text

::method readText private
  use arg path
  text = ""
  call stream path, "C", "OPEN READ"
  do while lines(path) > 0
    line = linein(path)
    if text \= "" then text = text || "0a"x
    text = text || line
  end
  call stream path, "C", "CLOSE"
  return text

::method absolutePath private
  use arg pathArg
  path = pathArg~string~strip
  if path = "" then return ""
  if path~left(1) = "/" then return path
  return directory() || "/" || path

::method canonicalDirectory private
  use arg path
  previous = directory()
  changed = directory(path)
  if changed = "" then return ""
  canonical = directory()
  ignore = directory(previous)
  return self~stripTrailingSlash(canonical)

::method pathWithin private
  use arg pathArg, rootArg
  path = self~stripTrailingSlash(pathArg~string)
  root = self~stripTrailingSlash(rootArg~string)
  if path = root then return .true
  return (path || "/")~left(root~length + 1) = root || "/"

::method safeAbsolutePath private
  use arg path
  if path = "" | path~left(1) \= "/" then return .false
  if path~pos("'") > 0 | path~pos("0a"x) > 0 | path~pos("0d"x) > 0 then return .false
  if ("/" || path || "/")~pos("/../") > 0 then return .false
  return .true

::method safeName private
  use arg name
  if name = "" | name = "." | name = ".." then return .false
  allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
  do i = 1 to name~length
    if allowed~pos(name~substr(i, 1)) = 0 then return .false
  end
  return .true

::method stripTrailingSlash private
  use arg path
  do while path~length > 1 & path~right(1) = "/"
    path = path~left(path~length - 1)
  end
  return path

::method baseName private
  use arg path
  p = path~lastpos("/")
  if p = 0 then return path
  return path~substr(p + 1)

::method join private
  use arg linesArg
  text = ""
  do line over linesArg
    if text \= "" then text = text || " "
    text = text || line
  end
  return text

::method failure private
  use arg code, detail = ""
  return .LlmPaResult~failure(code, detail)

::requires "LlmPaCore.cls"
::requires "json.cls"
