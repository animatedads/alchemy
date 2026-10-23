/* ooRexx Storage Fabric v0.1-dev21
 *
 * Git-backed durable storage provider.
 *
 * StorageRef remains the object identity.  Git commits, trees and paths are
 * provider-location evidence only.  Payloads are chunked into bounded blobs
 * so the provider does not require one Git blob per complete large object.
 * Credentials are deliberately outside this class: use GIT_ASKPASS, a Git
 * credential helper, or a future Secret Broker launcher.  Never put secrets
 * in the repository URL or Storage catalogue.
 */

::class StorageGitBuild public
::constant VERSION "0.1-dev21"
::constant API "storage.fabric.git/0.1"

::class StorageGitCapacityModel public
::constant ELASTIC "ELASTIC"
::constant FIXED "FIXED"

::class StorageGitCommandResult public
::attribute ok get
::attribute rc get
::attribute output get
::attribute error get
::method init
  expose ok rc output error
  use arg rcArg=1, outputArg="", errorArg=""
  rc=rcArg+0; output=outputArg~string; error=errorArg~string; ok=(rc=0)

::class StorageGitPutResult public
::attribute ok get
::attribute code get
::attribute location get
::attribute commitId get
::attribute manifestPath get
::attribute chunksWritten get
::attribute chunksReused get
::method init
  expose ok code location commitId manifestPath chunksWritten chunksReused
  use arg okArg, codeArg="", locationArg=.nil, commitArg="", manifestArg="", writtenArg=0, reusedArg=0
  ok=(okArg==.true); code=codeArg~string; location=locationArg; commitId=commitArg~string; manifestPath=manifestArg~string
  chunksWritten=writtenArg+0; chunksReused=reusedArg+0

::class StorageGitMaterialiseResult public
::attribute ok get
::attribute code get
::attribute bytesWritten get
::attribute verificationRef get
::method init
  expose ok code bytesWritten verificationRef
  use arg okArg, codeArg="", bytesArg=0, verificationArg=""
  ok=(okArg==.true); code=codeArg~string; bytesWritten=bytesArg+0; verificationRef=verificationArg~string

::class StorageGitProvider public
::attribute providerId get
::attribute repositoryUrl get
::attribute branch get
::attribute checkoutRoot get
::attribute vendorId get
::attribute siteId get
::attribute failureDomainId get
::attribute lifecycle get
::attribute chunkBytes get

::method init
  expose providerId repositoryUrl branch checkoutRoot vendorId siteId failureDomainId lifecycle chunkBytes gitBinary
  use arg providerArg, repositoryArg, branchArg="storage-fabric", checkoutArg="", vendorArg="", siteArg="", failureArg="", lifecycleArg=.nil, chunkArg=8388608, gitBinaryArg="/usr/bin/git"
  providerId=providerArg~string~strip
  repositoryUrl=repositoryArg~string~strip
  branch=branchArg~string~strip
  checkoutRoot=checkoutArg~string~strip
  vendorId=vendorArg~string~strip
  siteId=siteArg~string~strip
  failureDomainId=failureArg~string~strip
  if failureDomainId="" & (vendorId<>"" | siteId<>"") then failureDomainId=vendorId||"/"||siteId
  if lifecycleArg==.nil then lifecycle=.StorageServiceLifecycle~new
  else lifecycle=lifecycleArg
  chunkBytes=chunkArg+0
  gitBinary=gitBinaryArg~string~strip
  if providerId="" | repositoryUrl="" | branch="" then raise syntax 88.900 array("Git provider id, repository URL and branch are mandatory")
  if checkoutRoot="" then checkoutRoot=SysTempFileName("/tmp/oorexx-storage-git-checkout-??????")
  if chunkBytes<1 then raise syntax 88.900 array("Git chunk size must be positive")
  if gitBinary="" then raise syntax 88.900 array("Git binary is mandatory")

::method canCatalogue
  return .true
::method canDurable
  return .true
::method countsAsDurable
  expose lifecycle
  return lifecycle~countsAsDurable
::method canWorkspace
  /* A Git repository is a durable/offload provider, not an execution workspace. */
  return .false
::method capacityModel
  return .StorageGitCapacityModel~ELASTIC
::method availability
  return .StorageProviderAvailability~REMOTE
::method supportsChunkDeduplication
  return .true
::method supportsRangeDownload
  /* The object is reconstructed from independently addressable bounded chunks. */
  return .true
::method recommendedTransferChunkBytes
  expose chunkBytes
  return chunkBytes
::method api
  return .StorageGitBuild~API

::method store
  expose checkoutRoot chunkBytes branch providerId vendorId siteId failureDomainId lifecycle
  use arg ref, sourcePathArg, observedAtArg=""
  if ref==.nil then return .StorageGitPutResult~new(.false,"MISSING_REF")
  sourcePath=sourcePathArg~string
  if stream(sourcePath,"c","query exists")="" then return .StorageGitPutResult~new(.false,"SOURCE_NOT_FOUND")
  expected=self~expectedSha256(ref)
  if expected="" then return .StorageGitPutResult~new(.false,"REF_SHA256_REQUIRED")
  actual=self~digestFile(sourcePath)
  if actual="" then return .StorageGitPutResult~new(.false,"SOURCE_DIGEST_FAILED")
  if actual<>expected then return .StorageGitPutResult~new(.false,"SOURCE_DIGEST_MISMATCH")
  size=stream(sourcePath,"c","query size")
  if datatype(size,"N")=0 then return .StorageGitPutResult~new(.false,"SOURCE_SIZE_FAILED")

  ready=self~prepareCheckout
  if \ready~ok then return .StorageGitPutResult~new(.false,"GIT_PREPARE_FAILED:"||ready~error)

  objectRoot=".storage-fabric/objects/sha256/"||left(expected,2)||"/"||expected
  manifestPath=objectRoot||"/manifest.tsv"
  manifestFile=checkoutRoot||"/"||manifestPath
  junk=self~mkdirP(checkoutRoot||"/"||objectRoot)

  verifier=.StoragePosixSha256Verifier~new
  chunks=.array~new; offset=0; index=0; written=0; reused=0
  do while offset<size
    index+=1
    remain=size-offset
    n=chunkBytes
    if remain<n then n=remain
    data=charin(sourcePath,offset+1,n)
    if length(data)<>n then return .StorageGitPutResult~new(.false,"SOURCE_READ_SHORT")
    stage=SysTempFileName(checkoutRoot||"/.storage-git-chunk-??????")
    call charout stage,data,1
    call stream stage,"c","close"
    digest=verifier~digestFile(stage)
    if digest="" then do; call SysFileDelete stage; return .StorageGitPutResult~new(.false,"CHUNK_DIGEST_FAILED"); end
    chunkRel=".storage-fabric/chunks/sha256/"||left(digest,2)||"/"||digest
    chunkFile=checkoutRoot||"/"||chunkRel
    if stream(chunkFile,"c","query exists")<>"" then do
      existing=verifier~digestFile(chunkFile)
      if existing<>digest then do; call SysFileDelete stage; return .StorageGitPutResult~new(.false,"EXISTING_CHUNK_DIGEST_MISMATCH"); end
      call SysFileDelete stage; reused+=1
    end
    else do
      junk=self~mkdirP(self~parentPath(chunkFile))
      moveRc=SysFileMove(stage,chunkFile)
      if moveRc<>0 then do; call SysFileDelete stage; return .StorageGitPutResult~new(.false,"CHUNK_STAGE_MOVE_FAILED"); end
      written+=1
    end
    chunks~append(index||"09"x||offset||"09"x||n||"09"x||digest||"09"x||chunkRel)
    offset+=n
  end
  call stream sourcePath,"c","close"

  call SysFileDelete manifestFile
  call lineout manifestFile,"storage.fabric.git-object/0.1"
  call lineout manifestFile,"objectId"||"09"x||.StorageCodec~enc(ref~objectId)
  call lineout manifestFile,"digest"||"09"x||"sha256:"||expected
  call lineout manifestFile,"size"||"09"x||size
  call lineout manifestFile,"chunkBytes"||"09"x||chunkBytes
  call lineout manifestFile,"chunks"||"09"x||chunks~items
  do line over chunks
    call lineout manifestFile,"chunk"||"09"x||line
  end
  call lineout manifestFile

  qroot=self~quote(checkoutRoot)
  add=self~runGit("-C "||qroot||" add -- .storage-fabric")
  if \add~ok then return .StorageGitPutResult~new(.false,"GIT_ADD_FAILED:"||add~error)
  status=self~runGit("-C "||qroot||" status --porcelain -- .storage-fabric")
  if \status~ok then return .StorageGitPutResult~new(.false,"GIT_STATUS_FAILED:"||status~error)
  if status~output~strip<>"" then do
    commitRun=self~runGit("-C "||qroot||" -c user.name="||self~quote("Storage Fabric")||" -c user.email="||self~quote("storage-fabric@localhost")||" commit -m "||self~quote("Storage Fabric store "||ref~objectId))
    if \commitRun~ok then return .StorageGitPutResult~new(.false,"GIT_COMMIT_FAILED:"||commitRun~error)
  end
  commitResult=self~runGit("-C "||qroot||" rev-parse HEAD")
  if \commitResult~ok then return .StorageGitPutResult~new(.false,"GIT_COMMIT_ID_FAILED:"||commitResult~error)
  commitId=word(commitResult~output,1)
  push=self~runGit("-C "||qroot||" push origin HEAD:refs/heads/"||self~quoteRef(branch))
  if \push~ok then return .StorageGitPutResult~new(.false,"GIT_PUSH_FAILED:"||push~error)
  remote=self~runGit("-C "||qroot||" ls-remote --heads origin "||self~quote("refs/heads/"||branch))
  if \remote~ok then return .StorageGitPutResult~new(.false,"GIT_REMOTE_CONFIRM_FAILED:"||remote~error)
  remoteCommit=word(remote~output,1)
  if remoteCommit<>commitId then return .StorageGitPutResult~new(.false,"GIT_REMOTE_COMMIT_MISMATCH")
  fetched=self~runGit("-C "||qroot||" fetch origin "||self~quote("refs/heads/"||branch))
  if \fetched~ok then return .StorageGitPutResult~new(.false,"GIT_REMOTE_FETCH_FAILED:"||fetched~error)
  fetchedHead=self~runGit("-C "||qroot||" rev-parse FETCH_HEAD")
  if \fetchedHead~ok | word(fetchedHead~output,1)<>commitId then return .StorageGitPutResult~new(.false,"GIT_REMOTE_FETCH_MISMATCH")

  verify=self~verifyCommitObject(commitId,ref)
  if \verify~ok then return .StorageGitPutResult~new(.false,"POST_PUSH_VERIFY_FAILED:"||verify~code)
  locator="git:"||branch||"@"||commitId||":"||manifestPath
  verification="sha256:"||expected||";git-commit:"||commitId
  loc=.StorageLocation~new(providerId,locator,"git:"||providerId,.StorageLocationState~AVAILABLE,observedAtArg,.true,verification,.StorageSafetyClass~SAFE,lifecycle~state,"",vendorId,siteId,failureDomainId)
  return .StorageGitPutResult~new(.true,"OK",loc,commitId,manifestPath,written,reused)

::method materialise
  use arg ref, targetPathArg, commitArg=""
  if ref==.nil then return .StorageGitMaterialiseResult~new(.false,"MISSING_REF")
  target=targetPathArg~string
  if target="" then return .StorageGitMaterialiseResult~new(.false,"MISSING_TARGET")
  expected=self~expectedSha256(ref)
  if expected="" then return .StorageGitMaterialiseResult~new(.false,"REF_SHA256_REQUIRED")
  ready=self~prepareCheckout
  if \ready~ok then return .StorageGitMaterialiseResult~new(.false,"GIT_PREPARE_FAILED")
  commit=commitArg~string~strip
  if commit="" then do
    head=self~runGit("-C "||self~quote(self~checkoutRoot)||" rev-parse HEAD")
    if \head~ok then return .StorageGitMaterialiseResult~new(.false,"GIT_HEAD_FAILED")
    commit=word(head~output,1)
  end
  manifest=self~readManifest(commit,expected)
  if manifest==.nil then return .StorageGitMaterialiseResult~new(.false,"MANIFEST_NOT_FOUND_OR_INVALID")
  if manifest["objectId"]<>ref~objectId then return .StorageGitMaterialiseResult~new(.false,"OBJECT_ID_MISMATCH")
  if manifest["digest"]<>"sha256:"||expected then return .StorageGitMaterialiseResult~new(.false,"OBJECT_DIGEST_MISMATCH")
  junk=self~mkdirP(self~parentPath(target))
  call SysFileDelete target
  chunks=manifest["chunkList"]
  total=0
  do entry over chunks
    fields=.StorageCodec~splitTabs(entry)
    if fields~items<>5 then do; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"MANIFEST_CHUNK_INVALID"); end
    n=fields[3]+0; digest=fields[4]; rel=fields[5]
    tmp=SysTempFileName(self~checkoutRoot||"/.storage-git-read-??????")
    show=self~runGitToFile("-C "||self~quote(self~checkoutRoot)||" show "||self~quote(commit||":"||rel),tmp)
    if \show~ok then do; call SysFileDelete tmp; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"GIT_CHUNK_READ_FAILED"); end
    if stream(tmp,"c","query size")<>n then do; call SysFileDelete tmp; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"CHUNK_SIZE_MISMATCH"); end
    if self~digestFile(tmp)<>digest then do; call SysFileDelete tmp; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"CHUNK_DIGEST_MISMATCH"); end
    junk=self~appendFile(tmp,target)
    call SysFileDelete tmp
    total+=n
  end
  actual=self~digestFile(target)
  if actual<>expected then do; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"MATERIALISED_DIGEST_MISMATCH",total); end
  if total<>manifest["size"] then do; call SysFileDelete target; return .StorageGitMaterialiseResult~new(.false,"MATERIALISED_SIZE_MISMATCH",total); end
  return .StorageGitMaterialiseResult~new(.true,"OK",total,"sha256:"||actual||";git-commit:"||commit)

::method materialiseLocation
  use arg ref, location, targetPathArg
  if location==.nil then return .StorageGitMaterialiseResult~new(.false,"MISSING_LOCATION")
  commit=self~commitFromLocator(location~locator)
  if commit="" then return .StorageGitMaterialiseResult~new(.false,"INVALID_GIT_LOCATOR")
  return self~materialise(ref,targetPathArg,commit)

::method has
  use arg ref, commitArg=""
  if ref==.nil then return .false
  expected=self~expectedSha256(ref)
  if expected="" then return .false
  ready=self~prepareCheckout
  if \ready~ok then return .false
  commit=commitArg~string~strip
  if commit="" then do
    head=self~runGit("-C "||self~quote(self~checkoutRoot)||" rev-parse HEAD")
    if \head~ok then return .false
    commit=word(head~output,1)
  end
  return self~readManifest(commit,expected)<>.nil

::method refresh
  expose checkoutRoot branch
  if stream(checkoutRoot,"c","query exists")="" then return self~prepareCheckout
  fetch=self~runGit("-C "||self~quote(checkoutRoot)||" fetch origin "||self~quoteRef(branch))
  if \fetch~ok then return fetch
  return self~runGit("-C "||self~quote(checkoutRoot)||" reset --hard FETCH_HEAD")

::method prepareCheckout private
  expose checkoutRoot repositoryUrl branch
  if stream(checkoutRoot||"/.git","c","query exists")<>"" then return self~refreshExisting
  parent=self~parentPath(checkoutRoot); junk=self~mkdirP(parent)
  clone=self~runGit("clone --no-checkout "||self~quote(repositoryUrl)||" "||self~quote(checkoutRoot))
  if \clone~ok then return clone
  remote=self~runGit("-C "||self~quote(checkoutRoot)||" ls-remote --exit-code --heads origin "||self~quote("refs/heads/"||branch))
  if remote~ok then do
    fetch=self~runGit("-C "||self~quote(checkoutRoot)||" fetch origin "||self~quote("refs/heads/"||branch))
    if \fetch~ok then return fetch
    return self~runGit("-C "||self~quote(checkoutRoot)||" checkout -B "||self~quoteRef(branch)||" FETCH_HEAD")
  end
  orphan=self~runGit("-C "||self~quote(checkoutRoot)||" checkout --orphan "||self~quoteRef(branch))
  if \orphan~ok then return orphan
  return .StorageGitCommandResult~new(0,"READY","")

::method refreshExisting private
  expose checkoutRoot branch
  fetch=self~runGit("-C "||self~quote(checkoutRoot)||" fetch origin")
  if \fetch~ok then return fetch
  remote=self~runGit("-C "||self~quote(checkoutRoot)||" rev-parse --verify "||self~quote("refs/remotes/origin/"||branch))
  if remote~ok then return self~runGit("-C "||self~quote(checkoutRoot)||" reset --hard "||self~quote("refs/remotes/origin/"||branch))
  local=self~runGit("-C "||self~quote(checkoutRoot)||" rev-parse --verify HEAD")
  if local~ok then return .StorageGitCommandResult~new(0,"READY","")
  return self~runGit("-C "||self~quote(checkoutRoot)||" checkout --orphan "||self~quoteRef(branch))

::method verifyCommitObject private
  use arg commit, ref
  expected=self~expectedSha256(ref)
  manifest=self~readManifest(commit,expected)
  if manifest==.nil then return .StorageGitMaterialiseResult~new(.false,"MANIFEST_INVALID")
  if manifest["objectId"]<>ref~objectId then return .StorageGitMaterialiseResult~new(.false,"OBJECT_ID_MISMATCH")
  if manifest["digest"]<>"sha256:"||expected then return .StorageGitMaterialiseResult~new(.false,"OBJECT_DIGEST_MISMATCH")
  return .StorageGitMaterialiseResult~new(.true,"OK",manifest["size"],"sha256:"||expected||";git-commit:"||commit)

::method readManifest private
  expose checkoutRoot
  use arg commitArg, expectedArg
  commit=commitArg~string~strip; expected=expectedArg~string~strip~lower
  path=".storage-fabric/objects/sha256/"||left(expected,2)||"/"||expected||"/manifest.tsv"
  tmp=SysTempFileName(checkoutRoot||"/.storage-git-manifest-??????")
  r=self~runGitToFile("-C "||self~quote(checkoutRoot)||" show "||self~quote(commit||":"||path),tmp)
  if \r~ok then do; call SysFileDelete tmp; return .nil; end
  if lines(tmp)=0 then do; call SysFileDelete tmp; return .nil; end
  schema=linein(tmp)
  if schema<>"storage.fabric.git-object/0.1" then do; call stream tmp,"c","close"; call SysFileDelete tmp; return .nil; end
  d=.directory~new; chunkList=.array~new
  do while lines(tmp)>0
    line=linein(tmp)
    if line="" then iterate
    fields=.StorageCodec~splitTabs(line)
    if fields~items<2 then iterate
    key=fields[1]
    if key="chunk" then do
      if fields~items<>6 then do; call stream tmp,"c","close"; call SysFileDelete tmp; return .nil; end
      chunkList~append(fields[2]||"09"x||fields[3]||"09"x||fields[4]||"09"x||fields[5]||"09"x||fields[6])
    end
    else d[key]=fields[2]
  end
  call stream tmp,"c","close"; call SysFileDelete tmp
  if d["objectId"]==.nil | d["digest"]==.nil | d["size"]==.nil | d["chunks"]==.nil then return .nil
  d["objectId"]=.StorageCodec~dec(d["objectId"])
  d["size"]=d["size"]+0
  if d["chunks"]+0<>chunkList~items then return .nil
  d["chunkList"]=chunkList
  return d

::method expectedSha256 private
  use arg ref
  d=ref~digest~string~strip~lower
  if left(d,7)="sha256:" then d=substr(d,8)
  if length(d)<>64 then return ""
  valid="0123456789abcdef"
  do i=1 to length(d)
    if valid~pos(substr(d,i,1))=0 then return ""
  end
  return d

::method digestFile private
  use arg path
  return .StoragePosixSha256Verifier~new~digestFile(path)

::method appendFile private
  use arg source,target
  address system "/bin/cat -- "||self~quote(source)||" >> "||self~quote(target)
  return rc=0

::method commitFromLocator private
  use arg locatorArg
  locator=locatorArg~string
  at=pos("@",locator); colon=pos(":",locator,at+1)
  if left(locator,4)<>"git:" | at=0 | colon=0 then return ""
  return substr(locator,at+1,colon-at-1)

::method runGit private
  expose gitBinary
  use arg argsArg
  out=SysTempFileName("/tmp/oorexx-storage-git-out-??????")
  err=SysTempFileName("/tmp/oorexx-storage-git-err-??????")
  command=self~quote(gitBinary)||" "||argsArg||" >"||self~quote(out)||" 2>"||self~quote(err)
  address system command
  result=rc
  output=self~readText(out); error=self~readText(err)
  call SysFileDelete out; call SysFileDelete err
  return .StorageGitCommandResult~new(result,output,error)

::method runGitToFile private
  expose gitBinary
  use arg argsArg, outputPathArg
  err=SysTempFileName("/tmp/oorexx-storage-git-err-??????")
  command=self~quote(gitBinary)||" "||argsArg||" >"||self~quote(outputPathArg)||" 2>"||self~quote(err)
  address system command
  result=rc; error=self~readText(err); call SysFileDelete err
  return .StorageGitCommandResult~new(result,"",error)

::method readText private
  use arg path
  if stream(path,"c","query exists")="" then return ""
  text=""
  do while lines(path)>0
    line=linein(path)
    if text<>"" then text=text||"0A"x
    text=text||line
  end
  call stream path,"c","close"
  return text

::method mkdirP private
  use arg pathArg
  path=pathArg~string
  if path="" | path="/" then return .true
  address system "/bin/mkdir -p -- "||self~quote(path)||" >/dev/null 2>&1"
  return rc=0

::method parentPath private
  use arg pathArg
  path=pathArg~string
  p=lastpos("/",path)
  if p=0 then return "."
  if p=1 then return "/"
  return left(path,p-1)

::method quote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s~string,replacement)||sq

::method quoteRef private
  use arg s
  /* Ref names are configuration, not free-form request data.  Shell quoting is
   * still applied; Git itself performs the final ref-name validation. */
  return self~quote(s)

::requires 'StorageFabric.cls'
::requires 'StorageStreaming.cls'
