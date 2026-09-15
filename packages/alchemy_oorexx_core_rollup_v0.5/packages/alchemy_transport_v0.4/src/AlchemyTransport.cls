/*
 * AlchemyTransport v0.1
 *
 * Transport adapters materialize package bytes and provenance only.
 * They do NOT resolve package dependencies, compose REXX_PATH, execute tests,
 * or decide publication.
 */

::class AlchemyTransportBuild public
::constant VERSION "0.4"
::constant API "alchemy.transport/0.1"


::class AlchemyTransportSource subclass AlchemyCoreComponent public
::attribute kind get
::attribute locator get
::attribute immutableId get
::attribute submissionId get
::attribute packagePath get
::attribute metadata get

::method init
  expose kind locator immutableId submissionId packagePath metadata
  use strict arg kind, locator, immutableId = "", submissionId = "", packagePath = "", metadata = .nil
  self~initCoreComponent("AlchemyTransportSource", "0.3", "Alchemy core AlchemyTransportSource component")
  kind = kind~string~strip
  locator = locator~string
  immutableId = immutableId~string~strip
  submissionId = submissionId~string~strip
  packagePath = packagePath~string
  if kind = "" then raise syntax 88.900 array("transport source kind required")
  if locator = "" then raise syntax 88.900 array("transport source locator required")
  if metadata == .nil then metadata = .table~new
  else metadata = .AlchemyTransportCollections~copyMap(metadata)


::class AlchemyMaterializedPackage subclass AlchemyCoreComponent public
::attribute root get
::attribute source get
::attribute manifestPath get

::method init
  expose root source manifestPath
  use strict arg root, source
  self~initCoreComponent("AlchemyMaterializedPackage", "0.3", "Alchemy core AlchemyMaterializedPackage component")
  root = root~string
  if source == .nil then raise syntax 88.900 array("materialized package source required")
  manifestPath = .AlchemyTransportPath~join(root, "integration.json")
  if \ .AlchemyTransportFs~isDirectory(root) then raise syntax 88.900 array("materialized package root is not a directory: " || root)
  if \ .AlchemyTransportFs~isFile(manifestPath) then raise syntax 88.900 array("materialized package missing integration.json: " || manifestPath)


::class AlchemyTransportContext subclass AlchemyCoreComponent public
::attribute workspaceRoot get
::attribute repoRoot get
::attribute runner get

::method init
  expose workspaceRoot repoRoot runner
  use strict arg workspaceRoot, repoRoot = "", runner = .nil
  self~initCoreComponent("AlchemyTransportContext", "0.3", "Alchemy core AlchemyTransportContext component")
  workspaceRoot = workspaceRoot~string
  repoRoot = repoRoot~string
  if runner == .nil then runner = .AlchemyCommandRunner~new
  if \ .AlchemyTransportFs~isDirectory(workspaceRoot) then raise syntax 88.900 array("transport workspace is not a directory: " || workspaceRoot)

::method allocate
  expose workspaceRoot
  use strict arg prefix = "pkg"
  prefix = .AlchemyTransportPath~safeLeaf(prefix)
  pattern = .AlchemyTransportPath~join(workspaceRoot, prefix || "-??????")
  path = SysTempFileName(pattern)
  if path = "" then raise syntax 88.900 array("unable to allocate transport workspace path")
  if SysMkDir(path) \= 0 then raise syntax 88.900 array("unable to create transport workspace path: " || path)
  return path


::class AlchemyCommandResult subclass AlchemyCoreComponent public
::attribute argv get
::attribute cwd get
::attribute rc get
::attribute stdout get
::attribute stderr get

::method init
  expose argv cwd rc stdout stderr
  use strict arg argv, cwd, rc, stdout, stderr
  self~initCoreComponent("AlchemyCommandResult", "0.3", "Alchemy core AlchemyCommandResult component")
  argv = .AlchemyTransportCollections~copyArray(argv)

::method ok
  expose rc
  return rc = 0


::class AlchemyCommandRunner subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyCommandRunner", "0.3", "Alchemy core AlchemyCommandRunner component")
  return self

::method run
  use strict arg argv, cwd = ""
  if argv == .nil | argv~items = 0 then raise syntax 88.900 array("command argv required")
  if cwd = "" then cwd = directory()
  if \ .AlchemyTransportFs~isDirectory(cwd) then raise syntax 88.900 array("command cwd is not a directory: " || cwd)

  outPath = SysTempFileName("/tmp/alchemy-transport-out-??????")
  errPath = SysTempFileName("/tmp/alchemy-transport-err-??????")
  if outPath = "" | errPath = "" then raise syntax 88.900 array("unable to allocate command capture files")

  command = "cd " || .AlchemyShell~quote(cwd) || " && " || .AlchemyShell~joinArgv(argv) ||,
            " >" || .AlchemyShell~quote(outPath) || " 2>" || .AlchemyShell~quote(errPath)
  address system command
  code = rc
  stdout = .AlchemyTransportFs~readFile(outPath)
  stderr = .AlchemyTransportFs~readFile(errPath)
  call SysFileDelete outPath
  call SysFileDelete errPath
  return .AlchemyCommandResult~new(argv, cwd, code, stdout, stderr)

::method require
  use strict arg argv, cwd = "", label = "command"
  result = self~run(argv, cwd)
  if \result~ok then raise syntax 88.900 array(label || " failed rc=" || result~rc || " stderr=" || result~stderr~strip)
  return result


::class AlchemyLocalDirectoryTransport subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyLocalDirectoryTransport", "0.3", "Alchemy core AlchemyLocalDirectoryTransport component")
  return self

::method materialize
  use strict arg source, context
  if source~kind \= "local-directory" then raise syntax 88.900 array("local directory transport requires local-directory source")
  src = source~locator
  if \ .AlchemyTransportFs~isDirectory(src) then raise syntax 88.900 array("local package directory not found: " || src)
  target = context~allocate("local")
  args = .array~of("cp", "-a", "--", src || "/.", target || "/")
  context~runner~require(args, "", "local package copy")
  .AlchemyTransportTreePolicy~assertSafe(target, context~runner)
  return .AlchemyMaterializedPackage~new(target, source)


::class AlchemyZipArchive subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner = .nil
  self~initCoreComponent("AlchemyZipArchive", "0.3", "Alchemy core AlchemyZipArchive component")
  if runner == .nil then runner = .AlchemyCommandRunner~new

::method list
  expose runner
  use strict arg archive
  if \ .AlchemyTransportFs~isFile(archive) then raise syntax 88.900 array("ZIP not found: " || archive)
  result = runner~require(.array~of("unzip", "-Z1", "--", archive), "", "ZIP inventory")
  entries = .AlchemyTransportText~lines(result~stdout)
  if entries~items = 0 then raise syntax 88.900 array("ZIP is empty")
  .AlchemyArchivePathPolicy~assertEntries(entries)
  return entries

::method extract
  expose runner
  use strict arg archive, target
  self~list(archive)
  if \ .AlchemyTransportFs~isDirectory(target) then raise syntax 88.900 array("ZIP extraction target is not a directory: " || target)
  runner~require(.array~of("unzip", "-qq", "--", archive, "-d", target), "", "ZIP extraction")
  .AlchemyTransportTreePolicy~assertSafe(target, runner)
  return target


::class AlchemyManagedZipTransport subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyManagedZipTransport", "0.3", "Alchemy core AlchemyManagedZipTransport component")
  return self

::method materialize
  use strict arg source, context
  if source~kind \= "managed-zip" then raise syntax 88.900 array("managed ZIP transport requires managed-zip source")
  archive = source~locator
  target = context~allocate("zip")
  .AlchemyZipArchive~new(context~runner)~extract(archive, target)
  return .AlchemyMaterializedPackage~new(target, source)


::class AlchemyGitBranchTransport subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyGitBranchTransport", "0.3", "Alchemy core AlchemyGitBranchTransport component")
  return self

::method materialize
  use strict arg source, context
  if source~kind \= "git-branch" then raise syntax 88.900 array("Git branch transport requires git-branch source")
  if context~repoRoot = "" | \ .AlchemyTransportFs~isDirectory(.AlchemyTransportPath~join(context~repoRoot, ".git")) then -
    raise syntax 88.900 array("Git branch transport requires a working Git repository")
  if source~submissionId = "" then raise syntax 88.900 array("Git branch source submission id required")

  revision = source~immutableId
  if revision = "" then revision = source~locator
  revResult = context~runner~require(.array~of("git", "rev-parse", "--verify", revision || "^{commit}"), context~repoRoot, "Git revision resolve")
  rev = .AlchemyTransportText~firstLine(revResult~stdout)
  if rev = "" then raise syntax 88.900 array("Git revision did not resolve")
  if source~immutableId \= "" & source~immutableId \= rev then raise syntax 88.900 array("Git immutable id mismatch")

  packagePath = source~packagePath
  if packagePath = "" then packagePath = "package"
  .AlchemyArchivePathPolicy~assertOne(packagePath)
  subtree = "autobuild/inbox/" || source~submissionId || "/" || packagePath
  .AlchemyArchivePathPolicy~assertOne(subtree)

  target = context~allocate("git")
  tarPath = SysTempFileName(.AlchemyTransportPath~join(context~workspaceRoot, "git-archive-??????.tar"))
  if tarPath = "" then raise syntax 88.900 array("unable to allocate Git archive path")

  context~runner~require(.array~of("git", "archive", "--format=tar", "--output=" || tarPath, rev || ":" || subtree), context~repoRoot, "Git subtree archive")
  context~runner~require(.array~of("tar", "-xf", tarPath, "-C", target), "", "Git subtree extraction")
  call SysFileDelete tarPath
  .AlchemyTransportTreePolicy~assertSafe(target, context~runner)

  meta = .AlchemyTransportCollections~copyMap(source~metadata)
  meta["resolved_commit"] = rev
  resolvedSource = .AlchemyTransportSource~new("git-branch", source~locator, rev, source~submissionId, packagePath, meta)
  return .AlchemyMaterializedPackage~new(target, resolvedSource)


::class AlchemyGitRevisionSnapshot subclass AlchemyCoreComponent public
::attribute root get
::attribute commit get

::method init
  expose repoRoot runner root commit active
  use strict arg repoRoot, runner = .nil
  self~initCoreComponent("AlchemyGitRevisionSnapshot", "0.3", "Read-only detached snapshot of accepted Git main")
  repoRoot = repoRoot~string
  if runner == .nil then runner = .AlchemyCommandRunner~new
  root = ""
  commit = ""
  active = .false
  if \.AlchemyTransportFs~isDirectory(.AlchemyTransportPath~join(repoRoot, ".git")) then -
    raise syntax 88.900 array("Git revision snapshot requires a working repository")

::method begin
  expose repoRoot runner root commit active
  if active then raise syntax 88.900 array("Git revision snapshot already active")
  lease = .AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  leaseActive = .true
  worktreeAdded = .false
  signal on syntax name snapshotBeginSyntax
  refspec = "+refs/heads/main:refs/remotes/origin/main"
  runner~require(.array~of("git", "fetch", "origin", refspec), repoRoot, "Git accepted-main fetch")
  commit = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "--verify", "refs/remotes/origin/main^{commit}"), repoRoot, "Git accepted-main resolve")~stdout)
  if commit = "" then raise syntax 88.900 array("accepted-main revision did not resolve")
  root = SysTempFileName("/tmp/alchemy-main-snapshot-??????")
  if root = "" then raise syntax 88.900 array("unable to allocate Git accepted-main snapshot path")
  runner~require(.array~of("git", "worktree", "add", "--detach", root, commit), repoRoot, "Git accepted-main snapshot add")
  worktreeAdded = .true
  active = .true
  lease~close
  leaseActive = .false
  signal off syntax
  return self

snapshotBeginSyntax:
  signal off syntax
  if worktreeAdded then runner~run(.array~of("git", "worktree", "remove", "--force", root), repoRoot)
  if leaseActive then lease~close
  root = ""
  active = .false
  raise propagate

::method close
  expose repoRoot runner root active
  if \active then return .false
  lease = .AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  cleanup = runner~run(.array~of("git", "worktree", "remove", "--force", root), repoRoot)
  active = .false
  root = ""
  lease~close
  if \cleanup~ok then raise syntax 88.900 array("Git accepted-main snapshot cleanup failed: " || cleanup~stderr)
  return .true


::class AlchemyGitMainTransaction subclass AlchemyCoreComponent public
::attribute root get
::attribute baseCommit get

::method init
  expose repoRoot runner root baseCommit active lease
  use strict arg repoRoot, runner = .nil
  self~initCoreComponent("AlchemyGitMainTransaction", "0.3", "Leased accepted-main Git write transaction")
  repoRoot = repoRoot~string
  if runner == .nil then runner = .AlchemyCommandRunner~new
  root = ""
  baseCommit = ""
  active = .false
  lease = .nil
  if \.AlchemyTransportFs~isDirectory(.AlchemyTransportPath~join(repoRoot, ".git")) then -
    raise syntax 88.900 array("Git main transaction requires a working repository")

::method begin
  expose repoRoot runner root baseCommit active lease
  if active then raise syntax 88.900 array("Git main transaction already active")
  lease = .AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  worktreeAdded = .false
  signal on syntax name transactionBeginSyntax
  refspec = "+refs/heads/main:refs/remotes/origin/main"
  runner~require(.array~of("git", "fetch", "origin", refspec), repoRoot, "Git main fetch")
  baseCommit = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "--verify", "refs/remotes/origin/main^{commit}"), repoRoot, "Git main resolve")~stdout)
  root = SysTempFileName("/tmp/alchemy-main-worktree-??????")
  if root = "" then raise syntax 88.900 array("unable to allocate Git main worktree path")
  runner~require(.array~of("git", "worktree", "add", "--detach", root, baseCommit), repoRoot, "Git worktree add")
  worktreeAdded = .true
  active = .true
  signal off syntax
  return self

transactionBeginSyntax:
  signal off syntax
  if worktreeAdded then runner~run(.array~of("git", "worktree", "remove", "--force", root), repoRoot)
  if lease \== .nil then lease~close
  lease = .nil
  root = ""
  active = .false
  raise propagate

::method commitAndPush
  expose repoRoot runner root active
  use strict arg paths, message
  if \active then raise syntax 88.900 array("Git main transaction is not active")
  args = .array~of("git", "add", "--")
  do p over paths
    args~append(p~string)
  end
  runner~require(args, root, "Git transaction add")
  changed = runner~require(.array~of("git", "status", "--porcelain"), root, "Git transaction status")~stdout
  if changed = "" then return ""
  runner~require(.array~of("git", "config", "user.name", "Alchemy ooRexx"), root, "Git transaction identity")
  runner~require(.array~of("git", "config", "user.email", "alchemy-oorexx@localhost"), root, "Git transaction identity")
  runner~require(.array~of("git", "commit", "-m", message), root, "Git transaction commit")

  do attempt = 1 to 3
    pushed = runner~run(.array~of("git", "push", "origin", "HEAD:refs/heads/main"), root)
    if pushed~ok then return .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), root)~stdout)
    refspec = "+refs/heads/main:refs/remotes/origin/main"
    runner~require(.array~of("git", "fetch", "origin", refspec), root, "Git transaction refetch")
    runner~require(.array~of("git", "rebase", "refs/remotes/origin/main"), root, "Git transaction rebase")
  end
  raise syntax 88.900 array("Git transaction push failed after 3 attempts")

::method close
  expose repoRoot runner root active lease
  if \active then do
    if lease \== .nil then do; lease~close; lease = .nil; end
    return .false
  end
  cleanup = runner~run(.array~of("git", "worktree", "remove", "--force", root), repoRoot)
  active = .false
  root = ""
  if lease \== .nil then do; lease~close; lease = .nil; end
  if \cleanup~ok then raise syntax 88.900 array("Git worktree cleanup failed: " || cleanup~stderr)
  return .true


::class AlchemyGitSubmissionDiscovery subclass AlchemyCoreComponent public
::method init
  self~initCoreComponent("AlchemyGitSubmissionDiscovery", "0.3", "Alchemy core AlchemyGitSubmissionDiscovery component")
  return self

::method discover
  use strict arg repoRoot, revision, submissionId, runner = .nil
  if runner == .nil then runner = .AlchemyCommandRunner~new
  if submissionId~string~strip = "" then raise syntax 88.900 array("submission id required")
  .AlchemyArchivePathPolicy~assertOne(submissionId)
  revResult = runner~require(.array~of("git", "rev-parse", "--verify", revision || "^{commit}"), repoRoot, "Git revision resolve")
  rev = .AlchemyTransportText~firstLine(revResult~stdout)
  readyPath = "autobuild/inbox/" || submissionId || "/ready.json"
  readyText = runner~require(.array~of("git", "show", rev || ":" || readyPath), repoRoot, "ready marker read")~stdout
  ready = .JSON~fromJSON(readyText)
  if ready["schema"]~string \= "alchemy.autobuild.git-submission/0.1" then raise syntax 88.900 array("unsupported ready marker schema")
  if ready["submission_id"]~string \= submissionId then raise syntax 88.900 array("ready marker submission id mismatch")
  packagePath = "package"
  if ready~hasIndex("package_path") then packagePath = ready["package_path"]~string
  .AlchemyArchivePathPolicy~assertOne(packagePath)
  submittedBy = ""
  if ready~hasIndex("submitted_by") then submittedBy = ready["submitted_by"]~string
  meta = .table~new
  meta["submitted_by"] = submittedBy
  meta["ready_path"] = readyPath
  return .AlchemyTransportSource~new("git-branch", revision, rev, submissionId, packagePath, meta)


::class AlchemyTransportTreePolicy subclass AlchemyCoreComponent public
::method assertSafe class
  use strict arg root, runner
  links = runner~require(.array~of("find", root, "-type", "l", "-print", "-quit"), "", "symlink scan")~stdout~strip
  if links \= "" then raise syntax 88.900 array("materialized package contains symlink: " || links)
  return .true


::class AlchemyArchivePathPolicy subclass AlchemyCoreComponent public
::method assertEntries class
  use strict arg entries
  do entry over entries
    self~assertOne(entry)
  end
  return .true

::method assertOne class
  use strict arg entry
  p = entry~string
  if p = "" then raise syntax 88.900 array("empty archive path")
  if p~left(1) = "/" then raise syntax 88.900 array("absolute archive path rejected: " || p)
  if p~pos("\\") > 0 then raise syntax 88.900 array("backslash archive path rejected: " || p)
  rest = p
  do while rest \= ""
    parse var rest part "/" rest
    if part = ".." then raise syntax 88.900 array("archive traversal path rejected: " || p)
    if part = "." then iterate
  end
  return .true


::class AlchemyTransportFs subclass AlchemyCoreComponent public
::method isDirectory class
  use strict arg path
  stem = "ALCHEMY_T_DIR."
  call SysFileTree path, stem, "DO"
  return value(stem || "0") > 0

::method isFile class
  use strict arg path
  stem = "ALCHEMY_T_FILE."
  call SysFileTree path, stem, "FO"
  return value(stem || "0") > 0

::method readFile class
  use strict arg path
  if \self~isFile(path) then return ""
  s = .stream~new(path)
  s~open("read")
  data = s~charin(1, s~chars)
  s~close
  return data


::class AlchemyTransportPath subclass AlchemyCoreComponent public
::method join class
  use strict arg left, right
  if left~right(1) = "/" then return left || right
  return left || "/" || right

::method safeLeaf class
  use strict arg value
  out = value~string~strip
  if out = "" then out = "pkg"
  out = out~changeStr("/", "_")~changeStr("\\", "_")~changeStr(" ", "_")
  return out


::class AlchemyTransportText subclass AlchemyCoreComponent public
::method firstLine class
  use strict arg text
  lines = self~lines(text)
  if lines~items = 0 then return ""
  return lines[1]~strip

::method lines class
  use strict arg text
  out = .array~new
  rest = text~changeStr("0d0a"x, "0a"x)~changeStr("0d"x, "0a"x)
  do while rest \= ""
    p = rest~pos("0a"x)
    if p = 0 then do
      line = rest
      rest = ""
    end
    else do
      line = rest~left(p - 1)
      rest = rest~substr(p + 1)
    end
    if line \= "" then out~append(line)
  end
  return out


::class AlchemyTransportCollections subclass AlchemyCoreComponent public
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


::class AlchemyChecksumTool subclass AlchemyCoreComponent public
::method sha256 class
  use strict arg path, runner = .nil
  if runner == .nil then runner = .AlchemyCommandRunner~new
  if \ .AlchemyTransportFs~isFile(path) then raise syntax 88.900 array("checksum file not found: " || path)
  line = .AlchemyTransportText~firstLine(runner~require(.array~of("sha256sum", "--", path), "", "SHA-256")~stdout)
  parse var line digest .
  digest = digest~strip~lower
  if digest~length \= 64 then raise syntax 88.900 array("invalid SHA-256 result")
  return digest



::class AlchemyShell subclass AlchemyCoreComponent public
::method quote class
  use strict arg value
  s = value~string
  q = "27"x
  escapedQuote = "2722272227"x
  return q || s~changeStr(q, escapedQuote) || q

::method joinArgv class
  use strict arg argv
  out = ""
  do arg over argv
    if out \= "" then out ||= " "
    out ||= self~quote(arg)
  end
  return out

::requires "json.cls"

::requires "AlchemyRepositoryLease.cls"
::requires "AlchemyCoreComponent.cls"
