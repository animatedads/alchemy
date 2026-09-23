/* Storage Fabric <-> ooRexx SFTP compatibility adapter.
 * API: storage.fabric.sftp/0.1
 *
 * Authority boundary:
 *   - SFTP owns protocol framing, request semantics, handles and SSH subsystem use.
 *   - Storage Fabric owns namespace, versions, named streams and mutation policy.
 *   - This adapter translates only the SftpBackend contract onto the Storage FUSE
 *     semantic core.  It does not own SSH authentication, shell/exec or SCP.
 */

::class StorageSftpBuild public
::constant VERSION "0.1-dev18"
::constant API "storage.fabric.sftp/0.1"

::class StorageSftpBackend public subclass SftpBackend
::attribute core get
::attribute rootPath get
::attribute allowMutations get

/* Bind one SFTP namespace to an existing Storage operation core.  rootArg is
 * a Storage namespace prefix, not a host pathname. */
::method init
  expose core rootPath allowMutations
  use strict arg coreArg=.nil, rootArg="/", allowMutationsArg=.false
  if coreArg==.nil then core=.StorageFuseOperationCore~new
  else core=coreArg
  rootPath=.StoragePath~normalize(rootArg)
  allowMutations=(allowMutationsArg==.true)

/* Translate a canonical SFTP path beneath the configured Storage root. */
::method storagePath private
  expose rootPath
  use strict arg pathArg
  p=.SftpPath~canonical(pathArg)
  if rootPath="/" then return .StoragePath~normalize(p)
  if p="/" then return rootPath
  return .StoragePath~normalize(rootPath||p)

/* Convert Storage node metadata into the small SFTP v3 ATTRS subset emitted
 * by the current endpoint: size and POSIX-style type/permission bits. */
::method attrsForNode private
  use strict arg node
  if node==.nil then return .nil
  a=.directory~new
  a["size"]=node~size
  if node~kind=.StorageFuseNodeKind~DIRECTORY then a["permissions"]=16877  /* 040755 */
  else if node~kind=.StorageFuseNodeKind~CONTROL then a["permissions"]=33060 /* 0100444 */
  else a["permissions"]=33188                                      /* 0100644 */
  return a

/* Report Storage path state without materialising or copying the object. */
::method stat
  expose core
  use strict arg path
  r=core~getattr(self~storagePath(path))
  if \r~ok then return .nil
  return self~attrsForNode(r~value)

/* Validate/create an SFTP open against Storage.  SFTP owns its protocol
 * handle; Storage handles are opened only for the individual read/write call. */
::method open
  expose core allowMutations
  use strict arg path, pflags
  sp=self~storagePath(path)
  wantsWrite=.SftpOpenFlags~has(pflags,.SftpOpenFlags~WRITE) | -
             .SftpOpenFlags~has(pflags,.SftpOpenFlags~APPEND) | -
             .SftpOpenFlags~has(pflags,.SftpOpenFlags~CREAT) | -
             .SftpOpenFlags~has(pflags,.SftpOpenFlags~TRUNC)
  if wantsWrite & \allowMutations then return .false
  current=core~getattr(sp)
  exists=current~ok
  if exists then do
    if current~value~kind=.StorageFuseNodeKind~DIRECTORY then return .false
    if .SftpOpenFlags~has(pflags,.SftpOpenFlags~CREAT) & .SftpOpenFlags~has(pflags,.SftpOpenFlags~EXCL) then return .false
  end
  if \exists then do
    if \.SftpOpenFlags~has(pflags,.SftpOpenFlags~CREAT) then return .false
    created=core~create(sp,"RW")
    if \created~ok then return .false
    ignore=core~release(created~value)
  end
  if .SftpOpenFlags~has(pflags,.SftpOpenFlags~TRUNC) then do
    truncated=core~truncatePath(sp,0)
    if \truncated~ok then return .false
  end
  return .true

/* Read one bounded range through a short-lived Storage handle. */
::method read
  expose core
  use strict arg path, offset, count
  sp=self~storagePath(path)
  opened=core~open(sp,"READ")
  if \opened~ok then return .nil
  h=opened~value
  r=core~read(h,offset,count)
  ignore=core~release(h)
  if \r~ok then return .nil
  return r~value

/* Write one range through Storage.  APPEND is resolved from the current
 * Storage-visible length immediately before the write. */
::method write
  expose core allowMutations
  use strict arg path, offset, data, append=.false
  if \allowMutations then return .false
  sp=self~storagePath(path)
  if append then do
    st=core~getattr(sp)
    if \st~ok then return .false
    offset=st~value~size
  end
  opened=core~open(sp,"RW")
  if \opened~ok then return .false
  h=opened~value
  r=core~write(h,offset,data)
  ignore=core~release(h)
  return r~ok

/* Remove one live Storage file.  Named-stream unlink remains governed by the
 * Storage core and therefore fails if that operation is unsupported. */
::method remove
  expose core allowMutations
  use strict arg path
  if \allowMutations then return .false
  r=core~unlink(self~storagePath(path))
  return r~ok

/* Create one live Storage namespace directory. */
::method mkdir
  expose core allowMutations
  use strict arg path
  if \allowMutations then return .false
  r=core~mkdir(self~storagePath(path))
  return r~ok

/* Remove exactly one empty live Storage directory.  Recursive deletion is
 * intentionally not inferred from the SFTP request. */
::method rmdir
  expose core allowMutations
  use strict arg path
  if \allowMutations then return .false
  r=core~rmdir(self~storagePath(path))
  return r~ok

/* Rename one live Storage file.  Directory-tree rename is not claimed by the
 * current Storage semantic core and therefore fails closed. */
::method rename
  expose core allowMutations
  use strict arg oldPath,newPath
  if \allowMutations then return .false
  r=core~rename(self~storagePath(oldPath),self~storagePath(newPath))
  return r~ok

/* Enumerate direct Storage children and provide SFTP v3 NAME entries. */
::method list
  expose core
  use strict arg path
  sp=self~storagePath(path)
  r=core~readdir(sp)
  if \r~ok then return .nil
  entries=.array~new
  do name over r~value
    child=.StoragePath~join(sp,name)
    st=core~getattr(child)
    if \st~ok then iterate
    e=.directory~new
    e["filename"]=name
    e["longname"]=name
    e["attrs"]=self~attrsForNode(st~value)
    entries~append(e)
  end
  return entries

::class StorageSftpBackendFactory public
::attribute core get
::attribute rootPath get
::attribute allowMutations get

/* Factory shape consumed directly by SftpSubsystemHandler. */
::method init
  expose core rootPath allowMutations
  use strict arg coreArg=.nil, rootArg="/", allowMutationsArg=.false
  if coreArg==.nil then core=.StorageFuseOperationCore~new
  else core=coreArg
  rootPath=.StoragePath~normalize(rootArg)
  allowMutations=(allowMutationsArg==.true)

/* Each SSH/SFTP channel receives a backend object while sharing the resident
 * Storage core/authority selected by the embedding application. */
::method newBackend
  expose core rootPath allowMutations
  return .StorageSftpBackend~new(core,rootPath,allowMutations)

/* Convenience constructor for registration as SSH subsystem "sftp". */
::method subsystemHandler
  return .SftpSubsystemHandler~new(self)

::requires "StorageFuse.cls"
::requires "SftpCore.cls"
