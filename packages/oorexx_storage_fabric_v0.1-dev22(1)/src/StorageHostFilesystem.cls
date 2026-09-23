/* ooRexx Storage Fabric host-filesystem mount and verified commit seam.
 * API: storage.fabric.host-filesystem/0.1
 *
 * This module is deliberately mechanical.  It does not choose backup order,
 * retention, inclusion/exclusion or source deletion.  A READ_ONLY mount can
 * enumerate and read an existing Linux tree.  A WRITE_COMMIT mount can create
 * destination directories and publish verified files through a no-replace,
 * fsync-backed commit helper.
 */

/* Storage byte counts, offsets and capacity values routinely exceed the
 * ooRexx default 9-digit arithmetic context.  Keep these values exact. */
::options digits 30

::class StorageHostFilesystemBuild public
::constant VERSION "0.1-dev21"
::constant API "storage.fabric.host-filesystem/0.1"

::class StorageHostMountMode public
::constant READ_ONLY "READ_ONLY"
::constant WRITE_COMMIT "WRITE_COMMIT"

::class StorageHostEntry public
::attribute relativePath get
::attribute hostPath get
::attribute type get
::attribute modeOctal get
::attribute uid get
::attribute gid get
::attribute sizeBytes get
::attribute mtimeEpoch get
::attribute ctimeEpoch get
::attribute device get
::attribute inode get
::attribute nlink get
::attribute symlinkTarget get
::attribute fingerprint get

::method init
  expose relativePath hostPath type modeOctal uid gid sizeBytes mtimeEpoch ctimeEpoch device inode nlink symlinkTarget fingerprint
  use strict arg relativeArg, hostArg, typeArg, modeArg, uidArg, gidArg, sizeArg, mtimeArg, ctimeArg, deviceArg, inodeArg, nlinkArg, targetArg="", fineArg=""
  relativePath=relativeArg~string
  hostPath=hostArg~string
  type=typeArg~string
  modeOctal=modeArg~string
  uid=uidArg+0
  gid=gidArg+0
  sizeBytes=sizeArg+0
  mtimeEpoch=mtimeArg~string
  ctimeEpoch=ctimeArg~string
  device=deviceArg~string
  inode=inodeArg~string
  nlink=nlinkArg+0
  symlinkTarget=targetArg~string
  fingerprint=type||"|"||modeOctal||"|"||uid||"|"||gid||"|"||sizeBytes||"|"||mtimeEpoch||"|"||ctimeEpoch||"|"||device||"|"||inode||"|"||fineArg~string

::method regularFile
  expose type
  return type="regular file"

::method directory
  expose type
  return type="directory"

::method symbolicLink
  expose type
  return type="symbolic link"

::method sameVersion
  expose fingerprint
  use strict arg other
  if other==.nil then return .false
  return fingerprint==other~fingerprint

::class StorageHostPosix public

/* Return a validated Storage-relative path.  Root is represented by "".
 * Absolute paths, NULs, empty components and dot traversal are rejected so a
 * caller cannot smuggle host-path semantics through the Storage mount. */
::method relative class
  use strict arg valueArg=""
  p=valueArg~string
  if p="" then return ""
  if left(p,1)="/" then raise syntax 88.900 array("HOST_PATH_MUST_BE_RELATIVE",p)
  if pos(d2c(0),p)>0 then raise syntax 88.900 array("HOST_PATH_CONTAINS_NUL")
  if pos("//",p)>0 | right(p,1)="/" then raise syntax 88.900 array("HOST_PATH_NOT_CANONICAL",p)
  rest=p
  do while rest<>""
    slash=pos("/",rest)
    if slash=0 then do; seg=rest; rest=""; end
    else do; seg=left(rest,slash-1); rest=substr(rest,slash+1); end
    if seg="" | seg="." | seg=".." then raise syntax 88.900 array("HOST_PATH_TRAVERSAL_DENIED",p)
  end
  return p

::method join class
  use strict arg rootArg, relativeArg=""
  root=rootArg~string
  rel=self~relative(relativeArg)
  if rel="" then return root
  if right(root,1)="/" then return root||rel
  return root||"/"||rel

::method shellQuote class
  use strict arg valueArg
  s=valueArg~string
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::method capture class
  use strict arg commandArg
  tmp=SysTempFileName("/tmp/oorexx-storage-host-??????")
  address system commandArg||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  result=rc
  body=""
  if result=0 then do
    n=stream(tmp,"c","query size")
    if datatype(n,"N") then if n>0 then body=charin(tmp,1,n)
  end
  call stream tmp,"c","close"
  call SysFileDelete tmp
  d=.directory~new
  d["rc"]=result
  d["body"]=body
  return d

::method canonicalExisting class
  use strict arg pathArg
  r=self~capture("/usr/bin/realpath -z -e -- "||self~shellQuote(pathArg))
  if r["rc"]<>0 then return ""
  body=r["body"]
  if body<>"" & right(body,1)=d2c(0) then body=left(body,length(body)-1)
  return body

::method within class
  use strict arg rootArg, pathArg
  root=rootArg~string; path=pathArg~string
  if path==root then return .true
  prefix=root
  if right(prefix,1)<>"/" then prefix=prefix||"/"
  return left(path,length(prefix))==prefix

::method probe class
  use strict arg rootArg, relativeArg=""
  rel=self~relative(relativeArg)
  path=self~join(rootArg,rel)
  us=d2c(31)
  fmt="%F"||us||"%a"||us||"%u"||us||"%g"||us||"%s"||us||"%Y"||us||"%Z"||us||"%d"||us||"%i"||us||"%h"||us||"%y"||us||"%z"
  r=self~capture("/usr/bin/stat --printf="||self~shellQuote(fmt)||" -- "||self~shellQuote(path))
  if r["rc"]<>0 then return .nil
  body=r["body"]
  parse var body type (us) mode (us) uid (us) gid (us) size (us) mtime (us) ctime (us) dev (us) ino (us) nlink (us) mtimeFine (us) ctimeFine
  if type="" then return .nil
  target=""
  if type="symbolic link" then do
    q=self~capture("/usr/bin/readlink -z -- "||self~shellQuote(path))
    if q["rc"]=0 then do
      target=q["body"]
      if target<>"" & right(target,1)=d2c(0) then target=left(target,length(target)-1)
    end
  end
  return .StorageHostEntry~new(rel,path,type,mode,uid,gid,size,mtime,ctime,dev,ino,nlink,target,mtimeFine||"|"||ctimeFine)

::method listNames class
  use strict arg rootArg, relativeArg=""
  rel=self~relative(relativeArg)
  path=self~join(rootArg,rel)
  current=self~probe(rootArg,rel)
  if current==.nil then raise syntax 88.900 array("HOST_DIRECTORY_REQUIRED",rel)
  if \current~directory then raise syntax 88.900 array("HOST_DIRECTORY_REQUIRED",rel)
  /* Canonicalize the directory itself before traversing it.  This rejects a
   * symlink directory whose target escapes the mounted root. */
  canon=self~canonicalExisting(path)
  if canon="" | \self~within(rootArg,canon) then raise syntax 88.900 array("HOST_DIRECTORY_ESCAPES_ROOT",rel)
  r=self~capture("/usr/bin/find -P "||self~shellQuote(path)||" -mindepth 1 -maxdepth 1 -print0")
  if r["rc"]<>0 then raise syntax 88.900 array("HOST_DIRECTORY_LIST_FAILED",rel)
  a=.array~new
  body=r["body"]; start=1; nul=d2c(0)
  do while start<=length(body)
    stop=pos(nul,body,start)
    if stop=0 then leave
    child=substr(body,start,stop-start); start=stop+1
    slash=lastpos("/",child)
    if slash>0 then name=substr(child,slash+1)
    else name=child
    if name<>"" then a~append(name)
  end
  return a

::method mountOptions class
  use strict arg rootArg
  r=self~capture("/usr/bin/findmnt -T "||self~shellQuote(rootArg)||" -n -o OPTIONS")
  if r["rc"]<>0 then return ""
  return r["body"]~strip

::method digestFile class
  use strict arg pathArg
  r=self~capture("/usr/bin/sha256sum -- "||self~shellQuote(pathArg))
  if r["rc"]<>0 then return ""
  digest=word(r["body"],1)~lower
  if length(digest)<>64 then return ""
  return digest

::method digestText class
  use strict arg valueArg
  tmp=SysTempFileName("/tmp/oorexx-storage-host-id-??????")
  call charout tmp,valueArg~string
  call stream tmp,"c","close"
  digest=self~digestFile(tmp)
  call SysFileDelete tmp
  return digest

::class StorageHostFilesystemMount public
::attribute mountId get
::attribute root get
::attribute mode get
::attribute helper get
::attribute kernelOptions get
::attribute rootDevice get

/* Bind one existing host directory into Storage.  READ_ONLY is a policy
 * guarantee made by this object; kernelReadOnly separately reports whether the
 * underlying Linux mount itself is also ro. */
::method init
  expose mountId root mode helper kernelOptions rootDevice
  use strict arg idArg, rootArg, modeArg="READ_ONLY", helperArg="build/storage-host-commit"
  mountId=idArg~string~strip
  if mountId="" then raise syntax 88.900 array("HOST_MOUNT_ID_REQUIRED")
  root=.StorageHostPosix~canonicalExisting(rootArg~string)
  if root="" then raise syntax 88.900 array("HOST_MOUNT_ROOT_UNAVAILABLE",rootArg)
  rootEntry=.StorageHostPosix~probe(root,"")
  if rootEntry==.nil then raise syntax 88.900 array("HOST_MOUNT_ROOT_NOT_DIRECTORY",root)
  if \rootEntry~directory then raise syntax 88.900 array("HOST_MOUNT_ROOT_NOT_DIRECTORY",root)
  rootDevice=rootEntry~device
  mode=modeArg~string~upper
  if mode<>.StorageHostMountMode~READ_ONLY & mode<>.StorageHostMountMode~WRITE_COMMIT then raise syntax 88.900 array("HOST_MOUNT_MODE_INVALID",mode)
  helper=helperArg~string
  kernelOptions=.StorageHostPosix~mountOptions(root)
  if mode=.StorageHostMountMode~WRITE_COMMIT then do
    if helper="" | stream(helper,"c","query exists")="" then raise syntax 88.900 array("HOST_COMMIT_HELPER_REQUIRED",helper)
    address system "test -x "||.StorageHostPosix~shellQuote(helper)
    if rc<>0 then raise syntax 88.900 array("HOST_COMMIT_HELPER_NOT_EXECUTABLE",helper)
    address system "test -w "||.StorageHostPosix~shellQuote(root)
    if rc<>0 then raise syntax 88.900 array("HOST_DESTINATION_NOT_WRITABLE",root)
  end

::method readOnly
  expose mode
  return mode=.StorageHostMountMode~READ_ONLY

::method writeCommit
  expose mode
  return mode=.StorageHostMountMode~WRITE_COMMIT

::method kernelReadOnly
  expose kernelOptions
  opts=","||kernelOptions||"," 
  return pos(",ro,",opts)>0

::method kernelReadWrite
  expose kernelOptions
  opts=","||kernelOptions||"," 
  return pos(",rw,",opts)>0

/* True only when ENTRY belongs to the filesystem that backs this mount root.
 * Backup orchestration can use this to stop at Linux mount boundaries instead
 * of accidentally walking /proc, /sys, another disk, or the USB destination. */
::method sameFilesystem
  expose rootDevice
  use strict arg entryArg
  if entryArg==.nil then return .false
  return entryArg~device==rootDevice

::method entry
  expose root
  use strict arg relativeArg=""
  return .StorageHostPosix~probe(root,relativeArg)

::method list
  expose root
  use strict arg relativeArg=""
  names=.StorageHostPosix~listNames(root,relativeArg)
  a=.array~new
  base=.StorageHostPosix~relative(relativeArg)
  do name over names
    if base="" then rel=name
    else rel=base||"/"||name
    e=.StorageHostPosix~probe(root,rel)
    if e<>.nil then a~append(e)
  end
  return a

/* Return a bounded-memory source only for a real regular file whose canonical
 * target still lies under this mount.  Symlinks are metadata, never silently
 * followed as backup file content. */
::method byteSource
  expose root
  use strict arg relativeArg
  rel=.StorageHostPosix~relative(relativeArg)
  e=.StorageHostPosix~probe(root,rel)
  if e==.nil then raise syntax 88.900 array("HOST_SOURCE_NOT_REGULAR",rel)
  if \e~regularFile then raise syntax 88.900 array("HOST_SOURCE_NOT_REGULAR",rel)
  if \self~sameFilesystem(e) then raise syntax 88.900 array("HOST_SOURCE_FILESYSTEM_BOUNDARY",rel,e~device,rootDevice)
  canon=.StorageHostPosix~canonicalExisting(e~hostPath)
  if canon="" | \.StorageHostPosix~within(root,canon) then raise syntax 88.900 array("HOST_SOURCE_ESCAPES_ROOT",rel)
  return .StorageLocalFileByteSource~new(canon)

/* Create destination directories segment-by-segment.  Existing components
 * must be real directories, not symlinks; new components are checked after
 * creation before traversal continues. */
::method ensureDirectory
  expose root mode helper
  use strict arg relativeArg=""
  if mode<>.StorageHostMountMode~WRITE_COMMIT then raise syntax 88.900 array("HOST_MOUNT_READ_ONLY")
  rel=.StorageHostPosix~relative(relativeArg)
  if rel="" then return root
  currentRel=""; rest=rel
  do while rest<>""
    slash=pos("/",rest)
    if slash=0 then do; seg=rest; rest=""; end
    else do; seg=left(rest,slash-1); rest=substr(rest,slash+1); end
    if currentRel="" then currentRel=seg
    else currentRel=currentRel||"/"||seg
    e=.StorageHostPosix~probe(root,currentRel)
    if e==.nil then do
      candidate=.StorageHostPosix~join(root,currentRel)
      address system "/bin/mkdir --mode=0700 -- "||.StorageHostPosix~shellQuote(candidate)
      if rc<>0 then raise syntax 88.900 array("HOST_MKDIR_FAILED",currentRel)
      e=.StorageHostPosix~probe(root,currentRel)
    end
    if e==.nil then raise syntax 88.900 array("HOST_DIRECTORY_COMPONENT_INVALID",currentRel)
    if \e~directory then raise syntax 88.900 array("HOST_DIRECTORY_COMPONENT_INVALID",currentRel)
    canon=.StorageHostPosix~canonicalExisting(e~hostPath)
    if canon="" | \.StorageHostPosix~within(root,canon) then raise syntax 88.900 array("HOST_DIRECTORY_COMPONENT_ESCAPES_ROOT",currentRel)
  end
  self~syncDirectory(.StorageHostPosix~join(root,rel))
  return .StorageHostPosix~join(root,rel)

/* Construct a resumable sink whose bytes remain hidden under a deterministic
 * partial name until independent verification has succeeded. */
::method atomicSink
  expose root mode helper mountId
  use strict arg relativeArg, transferIdArg, expectedBytesArg
  if mode<>.StorageHostMountMode~WRITE_COMMIT then raise syntax 88.900 array("HOST_MOUNT_READ_ONLY")
  rel=.StorageHostPosix~relative(relativeArg)
  if rel="" then raise syntax 88.900 array("HOST_DESTINATION_FILE_REQUIRED")
  parent=self~parentRelative(rel)
  ignore=self~ensureDirectory(parent)
  finalPath=.StorageHostPosix~join(root,rel)
  finalEntry=.StorageHostPosix~probe(root,rel)
  if finalEntry<>.nil then do
    if \finalEntry~regularFile then raise syntax 88.900 array("HOST_DESTINATION_COLLISION",rel)
    finalCanon=.StorageHostPosix~canonicalExisting(finalPath)
    if finalCanon="" | \.StorageHostPosix~within(root,finalCanon) then raise syntax 88.900 array("HOST_DESTINATION_ESCAPES_ROOT",rel)
  end
  hash=.StorageHostPosix~digestText(mountId||"|"||transferIdArg~string||"|"||rel)
  if hash="" then raise syntax 88.900 array("HOST_PARTIAL_ID_FAILED")
  tempName=".sf-partial-"||left(hash,48)
  if parent="" then tempRel=tempName
  else tempRel=parent||"/"||tempName
  tempEntry=.StorageHostPosix~probe(root,tempRel)
  if tempEntry<>.nil then do
    if \tempEntry~regularFile then raise syntax 88.900 array("HOST_PARTIAL_COLLISION",tempRel)
    tempCanon=.StorageHostPosix~canonicalExisting(.StorageHostPosix~join(root,tempRel))
    if tempCanon="" | \.StorageHostPosix~within(root,tempCanon) then raise syntax 88.900 array("HOST_PARTIAL_ESCAPES_ROOT",tempRel)
  end
  return .StorageHostAtomicFileSink~new(self,tempRel,rel,expectedBytesArg)

::method syncDirectory
  expose helper
  use strict arg pathArg
  address system .StorageHostPosix~shellQuote(helper)||" syncdir "||.StorageHostPosix~shellQuote(pathArg)
  if rc<>0 then raise syntax 88.900 array("HOST_DIRECTORY_SYNC_FAILED",pathArg,rc)
  return .true

::method syncFile
  expose helper
  use strict arg pathArg
  address system .StorageHostPosix~shellQuote(helper)||" flush "||.StorageHostPosix~shellQuote(pathArg)
  if rc<>0 then raise syntax 88.900 array("HOST_FILE_SYNC_FAILED",pathArg,rc)
  return .true

/* Exercise the exact destination publication primitives in a hidden scratch
 * directory.  This is deliberately tiny and self-cleaning; a backup task can
 * require it before committing any user object to a newly attached disk. */
::method qualifyCommitFilesystem
  expose root mode helper
  if mode<>.StorageHostMountMode~WRITE_COMMIT then raise syntax 88.900 array("HOST_MOUNT_READ_ONLY")
  address system .StorageHostPosix~shellQuote(helper)||" probe "||.StorageHostPosix~shellQuote(root)
  if rc<>0 then raise syntax 88.900 array("HOST_COMMIT_FILESYSTEM_UNQUALIFIED",root,rc)
  return .true

::method helperPath
  expose helper
  return helper

::method hostPath
  expose root
  use strict arg relativeArg=""
  return .StorageHostPosix~join(root,relativeArg)

::method parentRelative private
  use strict arg relArg
  rel=.StorageHostPosix~relative(relArg)
  p=lastpos("/",rel)
  if p=0 then return ""
  return left(rel,p-1)

::class StorageHostAtomicFileSink subclass StorageByteSink public
::attribute mount get
::attribute tempRelative get
::attribute finalRelative get
::attribute tempPath get
::attribute finalPath get
::attribute expectedBytes get
::attribute published get

::method init
  expose mount tempRelative finalRelative tempPath finalPath expectedBytes published delegate
  use strict arg mountArg, tempArg, finalArg, expectedArg
  mount=mountArg
  tempRelative=tempArg~string
  finalRelative=finalArg~string
  tempPath=mount~hostPath(tempRelative)
  finalPath=mount~hostPath(finalRelative)
  expectedBytes=expectedArg+0
  if expectedBytes<0 then raise syntax 88.900 array("HOST_EXPECTED_SIZE_INVALID")
  published=.false
  delegate=.StorageLocalFileByteSink~new(tempPath)

::method resumeIdentity
  expose mount tempRelative finalRelative expectedBytes
  return "HOST_ATOMIC_SINK|"||mount~mountId||"|"||tempRelative||"|"||finalRelative||"|"||expectedBytes

::method openAt
  expose delegate expectedBytes published mount tempRelative tempPath
  use strict arg offsetArg=0, totalArg=0
  if published then raise syntax 88.900 array("HOST_SINK_ALREADY_PUBLISHED")
  if totalArg+0<>expectedBytes then raise syntax 88.900 array("HOST_SINK_SIZE_MISMATCH",totalArg,expectedBytes)
  existing=mount~entry(tempRelative)
  if existing<>.nil then do
    if \existing~regularFile then raise syntax 88.900 array("HOST_PARTIAL_NOT_REGULAR",tempRelative)
    canon=.StorageHostPosix~canonicalExisting(tempPath)
    if canon="" | \.StorageHostPosix~within(mount~root,canon) then raise syntax 88.900 array("HOST_PARTIAL_ESCAPES_ROOT",tempRelative)
  end
  delegate~openAt(offsetArg,expectedBytes)
  return self

::method writeChunk
  expose delegate published
  use strict arg dataArg
  if published then raise syntax 88.900 array("HOST_SINK_ALREADY_PUBLISHED")
  return delegate~writeChunk(dataArg)

/* Checkpoint durability: the transfer engine calls FLUSH before advancing its
 * durable checkpoint, so this method performs fdatasync on the partial file. */
::method flush
  expose delegate mount tempPath published
  if published then return self
  delegate~flush
  helper=mount~helperPath
  address system .StorageHostPosix~shellQuote(helper)||" flush "||.StorageHostPosix~shellQuote(tempPath)
  if rc<>0 then raise syntax 88.900 array("HOST_PARTIAL_FLUSH_FAILED",tempPath,rc)
  return self

::method close
  expose delegate published
  if \published then delegate~close
  return self

::method verificationPath
  expose tempPath finalPath published
  if published then return finalPath
  return tempPath

::method sizeOnDisk
  expose tempPath finalPath published
  if published then path=finalPath
  else path=tempPath
  q=stream(path,"c","query size")
  if datatype(q,"N")=0 then return -1
  return q+0

/* Publish a verified partial file without replacing an existing final file.
 * A repeated call after a crash is idempotent only when the already-published
 * final file has the exact expected SHA-256. */
::method publish
  expose mount tempPath finalPath expectedBytes published
  use strict arg verificationRef
  expected=self~digestFromVerification(verificationRef)
  if expected="" then raise syntax 88.900 array("HOST_VERIFICATION_REQUIRED")
  finalExists=stream(finalPath,"c","query exists")<>""
  tempExists=stream(tempPath,"c","query exists")<>""
  if finalExists then do
    digest=.StorageHostPosix~digestFile(finalPath)
    if digest<>expected then raise syntax 88.900 array("HOST_FINAL_ALREADY_EXISTS_DIFFERENT",finalPath)
    q=stream(finalPath,"c","query size")
    if datatype(q,"N")=0 | q+0<>expectedBytes then raise syntax 88.900 array("HOST_FINAL_SIZE_MISMATCH",finalPath)
    if tempExists then do
      address system "/bin/rm -f -- "||.StorageHostPosix~shellQuote(tempPath)
      if rc<>0 then raise syntax 88.900 array("HOST_PARTIAL_CLEANUP_FAILED",tempPath)
    end
    /* Reconciliation is a durability operation too.  Re-sync the existing
     * verified file and its parent before reporting committed state. */
    ignore=mount~syncFile(finalPath)
    parent=lastpos("/",finalPath)
    if parent<=1 then parentPath="/"
    else parentPath=left(finalPath,parent-1)
    ignore=mount~syncDirectory(parentPath)
    published=.true
    return "ALREADY_COMMITTED"
  end
  if \tempExists then raise syntax 88.900 array("HOST_PARTIAL_MISSING",tempPath)
  q=stream(tempPath,"c","query size")
  if datatype(q,"N")=0 | q+0<>expectedBytes then raise syntax 88.900 array("HOST_PARTIAL_SIZE_MISMATCH",tempPath)
  digest=.StorageHostPosix~digestFile(tempPath)
  if digest<>expected then raise syntax 88.900 array("HOST_PARTIAL_DIGEST_MISMATCH",tempPath)
  helper=mount~helperPath
  address system .StorageHostPosix~shellQuote(helper)||" publish "||.StorageHostPosix~shellQuote(tempPath)||" "||.StorageHostPosix~shellQuote(finalPath)
  if rc<>0 then raise syntax 88.900 array("HOST_PUBLISH_FAILED",finalPath,rc)
  digest=.StorageHostPosix~digestFile(finalPath)
  if digest<>expected then raise syntax 88.900 array("HOST_POST_PUBLISH_DIGEST_MISMATCH",finalPath)
  published=.true
  return "COMMITTED"

::method digestFromVerification private
  use strict arg valueArg
  v=valueArg~string~lower
  if left(v,7)="sha256:" then v=substr(v,8)
  if length(v)<>64 then return ""
  return v

/* Mechanical admission check shared by operator tooling and backup tasks.  It
 * validates policy/disk separation and exercises the actual destination commit
 * primitive, but deliberately does not decide what should be backed up. */
::class StorageHostBackupPreflight public
::method run class
  use strict arg sourceMount, destinationMount, checkpointRelativeArg=".storage-fabric/checkpoints", requireKernelRoArg=.false, requireDistinctFilesystemArg=.true
  d=.directory~new
  d["ok"]=.false
  d["status"]="FAILED"
  d["failure"]=""
  if sourceMount==.nil | destinationMount==.nil then do
    d["failure"]="MISSING_MOUNT"
    return d
  end
  d["sourceRoot"]=sourceMount~root
  d["destinationRoot"]=destinationMount~root
  d["sourceDevice"]=sourceMount~rootDevice
  d["destinationDevice"]=destinationMount~rootDevice
  d["sourceKernelReadOnly"]=sourceMount~kernelReadOnly
  d["destinationKernelReadWrite"]=destinationMount~kernelReadWrite
  if \sourceMount~readOnly then do; d["failure"]="SOURCE_NOT_READ_ONLY"; return d; end
  if \destinationMount~writeCommit then do; d["failure"]="DESTINATION_NOT_WRITE_COMMIT"; return d; end
  if \destinationMount~kernelReadWrite then do; d["failure"]="DESTINATION_KERNEL_NOT_RW"; return d; end
  if requireKernelRoArg==.true then do
    if \sourceMount~kernelReadOnly then do; d["failure"]="SOURCE_KERNEL_NOT_RO"; return d; end
  end
  if requireDistinctFilesystemArg==.true then do
    if sourceMount~rootDevice==destinationMount~rootDevice then do; d["failure"]="SOURCE_DESTINATION_SAME_FILESYSTEM"; return d; end
  end
  signal on syntax name qualificationFailed
  if \destinationMount~qualifyCommitFilesystem then do; signal off syntax; d["failure"]="DESTINATION_COMMIT_PROBE_FAILED"; return d; end
  checkpointRel=.StorageHostPosix~relative(checkpointRelativeArg)
  checkpointRoot=destinationMount~ensureDirectory(checkpointRel)
  signal off syntax
  d["checkpointRoot"]=checkpointRoot
  d["ok"]=.true
  d["status"]="READY"
  return d
qualificationFailed:
  info=condition("O")
  detail="DESTINATION_QUALIFICATION_FAILED"
  if info<>.nil then if info~hasIndex("DESCRIPTION") then detail=info["DESCRIPTION"]
  d["failure"]=detail
  return d

::class StorageHostCopyResult public
::attribute ok get
::attribute status get
::attribute bytes get
::attribute verificationRef get
::attribute sourceRelative get
::attribute destinationRelative get
::attribute failure get

::method init
  expose ok status bytes verificationRef sourceRelative destinationRelative failure
  use strict arg okArg, statusArg, bytesArg, verificationArg, sourceArg, destinationArg, failureArg=""
  ok=(okArg==.true)
  status=statusArg~string
  bytes=bytesArg+0
  verificationRef=verificationArg~string
  sourceRelative=sourceArg~string
  destinationRelative=destinationArg~string
  failure=failureArg~string

::class StorageHostVerifiedCopy public
::attribute chunkBytes get

::method init
  expose chunkBytes
  use strict arg chunkArg=8388608
  chunkBytes=chunkArg+0
  if chunkBytes<1 then raise syntax 88.900 array("HOST_COPY_CHUNK_INVALID")

/* Copy exactly one regular file from a policy-read-only host mount into a
 * WRITE_COMMIT host mount.  The caller owns ordering and retry scheduling;
 * this method owns only byte transfer, resume, verification and publication. */
::method copyFile
  expose chunkBytes
  use strict arg sourceMount, sourceRelativeArg, destinationMount, destinationRelativeArg, transferIdArg, checkpointRootArg="", maxChunksArg=0
  srcRel=.StorageHostPosix~relative(sourceRelativeArg)
  dstRel=.StorageHostPosix~relative(destinationRelativeArg)
  if sourceMount==.nil then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"MISSING_MOUNT")
  if destinationMount==.nil then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"MISSING_MOUNT")
  if \sourceMount~readOnly then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"SOURCE_NOT_READ_ONLY")
  if \destinationMount~writeCommit then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"DESTINATION_NOT_WRITE_COMMIT")
  if sourceMount~root==destinationMount~root then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"SOURCE_EQUALS_DESTINATION")
  before=sourceMount~entry(srcRel)
  if before==.nil then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"SOURCE_NOT_REGULAR")
  if \before~regularFile then return .StorageHostCopyResult~new(.false,"FAILED",0,"",srcRel,dstRel,"SOURCE_NOT_REGULAR")
  source=sourceMount~byteSource(srcRel)
  sink=destinationMount~atomicSink(dstRel,transferIdArg,before~sizeBytes)
  ref=.StorageRef~new("host:"||sourceMount~mountId||":"||srcRel)
  loc=.StorageLocation~new(sourceMount~mountId,source~verificationPath,"",.StorageLocationState~AVAILABLE)
  transfer=.StorageTransfer~new(transferIdArg,ref,loc,destinationMount~mountId,dstRel,before~sizeBytes)
  engine=.StorageResumableTransferEngine~new(chunkBytes)
  run=engine~copy(transfer,source,sink,checkpointRootArg,maxChunksArg,.StoragePosixSha256Verifier~new)
  if run~status=.StorageTransferRunStatus~PAUSED then return .StorageHostCopyResult~new(.false,"PAUSED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,"")
  if run~status<>.StorageTransferRunStatus~COMPLETED | run~verificationRef="" then return .StorageHostCopyResult~new(.false,"FAILED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,run~failure)
  after=sourceMount~entry(srcRel)
  if after==.nil then return .StorageHostCopyResult~new(.false,"SOURCE_CHANGED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,"SOURCE_CHANGED_BEFORE_COMMIT")
  if \before~sameVersion(after) then return .StorageHostCopyResult~new(.false,"SOURCE_CHANGED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,"SOURCE_CHANGED_BEFORE_COMMIT")
  signal on syntax name publishFailed
  publishStatus=sink~publish(run~verificationRef)
  signal off syntax
  if \transfer~commit then return .StorageHostCopyResult~new(.false,"FAILED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,"TRANSFER_COMMIT_STATE_INVALID")
  return .StorageHostCopyResult~new(.true,publishStatus,run~bytesTransferred,run~verificationRef,srcRel,dstRel,"")
publishFailed:
  info=condition("O")
  detail="HOST_PUBLISH_FAILED"
  if info<>.nil then if info~hasIndex("DESCRIPTION") then detail=info["DESCRIPTION"]
  return .StorageHostCopyResult~new(.false,"FAILED",run~bytesTransferred,run~verificationRef,srcRel,dstRel,detail)

::requires "src/StorageStreaming.cls"
