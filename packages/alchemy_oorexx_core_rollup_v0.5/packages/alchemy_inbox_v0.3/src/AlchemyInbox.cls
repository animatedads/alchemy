/*
 * AlchemyInbox v0.1
 *
 * Read-only discovery of pending Git submissions.  A remote branch contributes
 * only ready markers added after its merge-base with accepted main, so inherited
 * historical markers are never reinterpreted as new branch deliveries.
 */

::class AlchemyInboxBuild public
::constant VERSION "0.3"
::constant API "alchemy.inbox/0.1"

::class AlchemyInboxCandidate subclass AlchemyCoreComponent public
::attribute submissionId get
::attribute sourceRef get
::attribute revision get
::attribute packagePath get
::attribute packageTree get
::attribute submittedBy get
::attribute aliases get
::attribute conflicted get
::attribute conflictMessage get

::method init
  expose submissionId sourceRef revision packagePath packageTree submittedBy aliases conflicted conflictMessage
  use strict arg submissionId, sourceRef, revision, packagePath="package", packageTree="", submittedBy="", aliases=.nil, conflicted=.false, conflictMessage=""
  self~initCoreComponent("AlchemyInboxCandidate", "0.1", "Pending autobuild submission candidate")
  submissionId=submissionId~string~strip
  sourceRef=sourceRef~string
  revision=revision~string~strip
  packagePath=packagePath~string
  packageTree=packageTree~string~strip
  submittedBy=submittedBy~string~strip
  if aliases==.nil then aliases=.array~new
  else aliases=.AlchemyTransportCollections~copyArray(aliases)
  if conflicted then conflicted=.true; else conflicted=.false
  conflictMessage=conflictMessage~string
  if submissionId="" then raise syntax 88.900 array("inbox candidate submission id required")
  if sourceRef="" then raise syntax 88.900 array("inbox candidate source ref required")
  if revision="" & \conflicted then raise syntax 88.900 array("inbox candidate revision required")

::method source
  expose submissionId sourceRef revision packagePath submittedBy
  meta=.table~new
  meta["submitted_by"]=submittedBy
  meta["discovered_ref"]=sourceRef
  return .AlchemyTransportSource~new("git-branch",sourceRef,revision,submissionId,packagePath,meta)

::class AlchemyInboxScanResult subclass AlchemyCoreComponent public
::attribute mainCommit get
::attribute candidates get
::attribute suppressedReceipts get
::attribute remoteRefs get

::method init
  expose mainCommit candidates suppressedReceipts remoteRefs
  use strict arg mainCommit, candidates, suppressedReceipts, remoteRefs
  self~initCoreComponent("AlchemyInboxScanResult", "0.1", "Git inbox scan result")
  candidates=.AlchemyTransportCollections~copyArray(candidates)
  suppressedReceipts=.AlchemyTransportCollections~copyArray(suppressedReceipts)
  remoteRefs=.AlchemyTransportCollections~copyArray(remoteRefs)

::class AlchemyGitInbox subclass AlchemyCoreComponent public
::method init
  expose runner discovery
  use strict arg runner=.nil, discovery=.nil
  self~initCoreComponent("AlchemyGitInbox", "0.2", "Leased Git submission inbox")
  if runner==.nil then runner=.AlchemyCommandRunner~new
  if discovery==.nil then discovery=.AlchemyGitSubmissionDiscovery~new

::method scan
  expose runner discovery
  use strict arg repoRoot
  if \.AlchemyTransportFs~isDirectory(repoRoot || "/.git") then raise syntax 88.900 array("Git inbox requires repository checkout")
  lease=.AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  leaseActive=.true
  signal on syntax name scanSyntax
  runner~require(.array~of("git","fetch","--prune","origin","+refs/heads/*:refs/remotes/origin/*"),repoRoot,"inbox fetch")
  mainRef="refs/remotes/origin/main"
  mainCommit=self~resolveCommit(repoRoot,mainRef)
  refs=self~remoteRefs(repoRoot)
  byId=.table~new
  suppressed=.array~new

  /* Legacy/direct-main inbox remains supported. */
  do readyPath over self~readyPathsAt(repoRoot,mainCommit)
    id=self~submissionIdFromReadyPath(readyPath)
    if id="" then iterate
    if self~hasReceipt(repoRoot,mainCommit,id) then do
      suppressed~append(id)
      iterate
    end
    candidate=self~candidateAt(repoRoot,mainRef,mainCommit,id)
    self~mergeCandidate(byId,candidate)
  end

  /* Remote branches contribute only markers added since their merge-base. */
  do ref over refs
    if ref=mainRef then iterate
    if ref~right(5)="/HEAD" then iterate
    branchCommit=self~resolveCommit(repoRoot,ref)
    mb=runner~run(.array~of("git","merge-base",mainCommit,branchCommit),repoRoot)
    if \mb~ok then iterate
    base=.AlchemyTransportText~firstLine(mb~stdout)
    if base="" then iterate
    diff=runner~require(.array~of("git","diff","--name-only","--diff-filter=A",base,branchCommit,"--","autobuild/inbox"),repoRoot,"branch ready diff")
    do path over .AlchemyTransportText~lines(diff~stdout)
      id=self~submissionIdFromReadyPath(path)
      if id="" then iterate
      if self~hasReceipt(repoRoot,mainCommit,id) then do
        suppressed~append(id)
        iterate
      end
      candidate=self~candidateAt(repoRoot,ref,branchCommit,id)
      self~mergeCandidate(byId,candidate)
    end
  end

  ids=.array~new
  sup=byId~supplier
  do while sup~available
    ids~append(sup~index)
    sup~next
  end
  ids~sort
  candidates=.array~new
  do id over ids; candidates~append(byId[id]); end
  suppressed=self~uniqueSorted(suppressed)
  scanResult=.AlchemyInboxScanResult~new(mainCommit,candidates,suppressed,refs)
  lease~close; leaseActive=.false; signal off syntax
  return scanResult

scanSyntax:
  signal off syntax
  if leaseActive then lease~close
  raise propagate

::method candidateAt private
  expose runner discovery
  use strict arg repoRoot, sourceRef, revision, submissionId
  source=discovery~discover(repoRoot,revision,submissionId,runner)
  subtree="autobuild/inbox/" || submissionId || "/" || source~packagePath
  tree=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","--verify",source~immutableId || ":" || subtree),repoRoot,"submission package tree")~stdout)
  submittedBy=""
  if source~metadata~hasIndex("submitted_by") then submittedBy=source~metadata["submitted_by"]
  return .AlchemyInboxCandidate~new(submissionId,sourceRef,source~immutableId,source~packagePath,tree,submittedBy)

::method mergeCandidate private
  use strict arg byId, candidate
  id=candidate~submissionId
  existing=byId[id]
  if existing==.nil then do
    byId[id]=candidate
    return
  end
  if existing~conflicted then do
    aliases=.AlchemyTransportCollections~copyArray(existing~aliases)
    aliases~append(candidate~sourceRef)
    byId[id]=.AlchemyInboxCandidate~new(id,existing~sourceRef,"",existing~packagePath,"",existing~submittedBy,aliases,.true,existing~conflictMessage)
    return
  end
  if existing~packageTree=candidate~packageTree then do
    aliases=.AlchemyTransportCollections~copyArray(existing~aliases)
    aliases~append(existing~sourceRef)
    aliases~append(candidate~sourceRef)
    chosen=existing
    mainRef="refs/remotes/origin/main"
    if existing~sourceRef=mainRef & candidate~sourceRef<>mainRef then chosen=candidate
    else if existing~sourceRef<>mainRef & candidate~sourceRef<>mainRef then do
      if candidate~sourceRef<existing~sourceRef then chosen=candidate
    end
    byId[id]=.AlchemyInboxCandidate~new(id,chosen~sourceRef,chosen~revision,chosen~packagePath,chosen~packageTree,chosen~submittedBy,self~uniqueSorted(aliases),.false,"")
    return
  end
  aliases=.array~of(existing~sourceRef,candidate~sourceRef)
  message="submission id has different package trees: " || existing~packageTree || " vs " || candidate~packageTree
  byId[id]=.AlchemyInboxCandidate~new(id,existing~sourceRef,"",existing~packagePath,"",existing~submittedBy,self~uniqueSorted(aliases),.true,message)

::method readyPathsAt private
  expose runner
  use strict arg repoRoot, revision
  r=runner~require(.array~of("git","ls-tree","-r","--name-only",revision,"--","autobuild/inbox"),repoRoot,"main inbox scan")
  out=.array~new
  do path over .AlchemyTransportText~lines(r~stdout)
    if self~submissionIdFromReadyPath(path)<>"" then out~append(path)
  end
  out~sort
  return out

::method submissionIdFromReadyPath private
  use strict arg path
  prefix="autobuild/inbox/"
  suffix="/ready.json"
  p=path~string
  if p~left(prefix~length)<>prefix then return ""
  if p~right(suffix~length)<>suffix then return ""
  id=p~substr(prefix~length+1,p~length-prefix~length-suffix~length)
  if id="" | id~pos("/")>0 then return ""
  return id

::method hasReceipt private
  expose runner
  use strict arg repoRoot, mainCommit, submissionId
  rel="autobuild/receipts/" || submissionId || ".json"
  r=runner~run(.array~of("git","cat-file","-e",mainCommit || ":" || rel),repoRoot)
  return r~rc=0

::method resolveCommit private
  expose runner
  use strict arg repoRoot, ref
  return .AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","--verify",ref || "^{commit}"),repoRoot,"inbox ref resolve")~stdout)

::method remoteRefs private
  expose runner
  use strict arg repoRoot
  r=runner~require(.array~of("git","for-each-ref","--format=%(refname)","refs/remotes/origin"),repoRoot,"remote ref inventory")
  out=.AlchemyTransportText~lines(r~stdout)
  out~sort
  return out

::method uniqueSorted private
  use strict arg values
  seen=.table~new; out=.array~new
  do v over values
    if \seen~hasIndex(v) then do; seen[v]=.true; out~append(v); end
  end
  out~sort
  return out

::requires "AlchemyTransport.cls"
::requires "AlchemyRepositoryLease.cls"
::requires "AlchemyCoreComponent.cls"
