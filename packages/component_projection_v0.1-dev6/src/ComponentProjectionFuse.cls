/* Optional Storage Fabric FUSE renderer for component.projection/0.1.
 * Requires StorageFuse.cls but does not change Storage Fabric or participating
 * components. Mounting this renderer is a deployment choice.
 */

::class ComponentProjectionFuseErrno public
::constant EFBIG 27

::class ComponentProjectionFuseHandle public
::attribute handleId get
::attribute path get
::attribute writable get
::attribute readable get
::attribute data get
::attribute dirty get
::attribute maxWriteBytes get
::method init
  expose handleId path writable readable data dirty maxWriteBytes
  use strict arg handleArg,pathArg,readableArg,writableArg,dataArg="",maxWriteBytesArg=65536
  handleId=handleArg~string; path=pathArg~string
  readable=(readableArg=.true); writable=(writableArg=.true)
  data=dataArg~string; dirty=.false; maxWriteBytes=maxWriteBytesArg+0
::method readAt
  expose data readable
  use strict arg offsetArg,countArg
  if eadable then return .nil
  o=offsetArg+0; n=countArg+0
  if o<0 | n<0 then return .nil
  if o>=length(data) then return ""
  return substr(data,o+1,n)
::method writeAt
  expose data writable dirty maxWriteBytes
  use strict arg offsetArg,chunkArg
  if writable then return -1
  o=offsetArg+0; if o<0 then return -1
  chunk=chunkArg~string
  final=max(length(data),o+length(chunk))
  if final>maxWriteBytes then return -2
  if o>length(data) then data=data||copies("00"x,o-length(data))
  prefix=left(data,o); suffix=""; tail=o+length(chunk)+1
  if tail<=length(data) then suffix=substr(data,tail)
  data=prefix||chunk||suffix; dirty=.true
  return length(chunk)
::method truncate
  expose data writable dirty maxWriteBytes
  use strict arg sizeArg
  if writable then return -1
  n=sizeArg+0; if n<0 then return -1
  if n>maxWriteBytes then return -2
  if n<length(data) then data=left(data,n)
  else if n>length(data) then data=data||copies("00"x,n-length(data))
  dirty=.true
  return 0

/* Composite operation core. Requests under projectionRoot use the component
 * registry; every other request is delegated unchanged to StorageFuseOperationCore. */
::class StorageComponentProjectionFuseCore public
::attribute delegate get
::attribute registry get
::attribute projectionRoot get
::method init
  expose delegate registry projectionRoot handles nextHandle
  use strict arg registryArg,delegateArg=.nil,rootArg="/components"
  registry=registryArg
  if delegateArg==.nil then delegate=.StorageFuseOperationCore~new; else delegate=delegateArg
  projectionRoot=.ComponentProjectionPath~normalize(rootArg)
  handles=.directory~new; nextHandle=1
::method isProjection private
  expose projectionRoot
  use strict arg pathArg
  return .ComponentProjectionPath~under(pathArg,projectionRoot)
::method localPath private
  expose projectionRoot
  use strict arg pathArg
  return .ComponentProjectionPath~relative(pathArg,projectionRoot)
::method modeRead private
  use strict arg modeArg
  m=modeArg~string~upper~strip
  if m="READ" | m="R" | m="RW" | m="WR" | m="READWRITE" | m="READ_WRITE" then return .true
  return .false
::method modeWrite private
  use strict arg modeArg
  m=modeArg~string~upper~strip
  if m="WRITE" | m="W" | m="RW" | m="WR" | m="READWRITE" | m="READ_WRITE" then return .true
  return .false
::method getattr
  expose delegate registry
  use strict arg pathArg
  if self~isProjection(pathArg) then return delegate~getattr(pathArg)
  lp=self~localPath(pathArg)
  if registry~isDirectory(lp) then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"COMPONENT",registry~generation),"")
  ep=registry~endpoint(lp)
  if ep==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"component projection path absent")
  size=0
  if ep~readable then size=length(.ComponentProjectionText~render(ep~readObject))
  state=ep~kind
  if ep~readable & ep~writable then state="WRITE_ONLY_CONTROL"
  return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~FILE,pathArg,size,state,registry~generation),"")
::method readdir
  expose delegate registry
  use strict arg pathArg
  if self~isProjection(pathArg) then return delegate~readdir(pathArg)
  lp=self~localPath(pathArg); a=registry~list(lp)
  if a==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"component projection directory absent")
  return .StorageFuseResult~new(0,a,"")
::method open
  expose delegate registry handles nextHandle
  use strict arg pathArg,modeArg="READ"
  if self~isProjection(pathArg) then return delegate~open(pathArg,modeArg)
  lp=self~localPath(pathArg); ep=registry~endpoint(lp)
  if ep==.nil then do
    if registry~isDirectory(lp) then return .StorageFuseResult~new(.StorageFuseErrno~EISDIR,.nil,"component projection directory is not openable")
    return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"component projection endpoint absent")
  end
  wantsRead=self~modeRead(modeArg); wantsWrite=self~modeWrite(modeArg)
  if wantsRead & ep~readable then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"control endpoint is write only")
  if wantsWrite & ep~writable then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"report endpoint is read only")
  seed=""
  if wantsRead then seed=.ComponentProjectionText~render(ep~readObject)
  id="cp"||nextHandle; nextHandle=nextHandle+1
  h=.ComponentProjectionFuseHandle~new(id,lp,wantsRead,wantsWrite,seed,ep~maxWriteBytes); handles[id]=h
  return .StorageFuseResult~new(0,h,"")
::method read
  expose delegate handles
  use strict arg handleArg,offsetArg,countArg
  h=handles[handleArg~string]
  if h==.nil then return delegate~read(handleArg,offsetArg,countArg)
  data=h~readAt(offsetArg,countArg)
  if data==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"handle not readable")
  return .StorageFuseResult~new(0,data,"")
::method write
  expose delegate handles
  use strict arg handleArg,offsetArg,dataArg
  h=handles[handleArg~string]
  if h==.nil then return delegate~write(handleArg,offsetArg,dataArg)
  rc=h~writeAt(offsetArg,dataArg)
  if rc=-1 then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"handle not writable")
  if rc=-2 then return .StorageFuseResult~new(.ComponentProjectionFuseErrno~EFBIG,.nil,"component control write exceeds configured limit")
  return .StorageFuseResult~new(0,rc,"")
::method truncate
  expose delegate handles
  use strict arg handleArg,sizeArg
  h=handles[handleArg~string]
  if h==.nil then return delegate~truncate(handleArg,sizeArg)
  rc=h~truncate(sizeArg)
  if rc=-1 then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"handle not writable")
  if rc=-2 then return .StorageFuseResult~new(.ComponentProjectionFuseErrno~EFBIG,.nil,"component control write exceeds configured limit")
  return .StorageFuseResult~new(0,.true,"")
::method release
  expose delegate registry handles
  use strict arg handleArg
  id=handleArg~string; h=handles[id]
  if h==.nil then return delegate~release(handleArg)
  if h~writable & h~dirty then do
    ep=registry~endpoint(h~path)
    if ep==.nil then do; handles~remove(id); return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"endpoint disappeared before control commit"); end
    command=h~data
    /* Remove shell command terminators, not embedded newlines. */
    do while length(command)>0 & (right(command,1)="0a"x | right(command,1)="0d"x); command=left(command,length(command)-1); end
    signal on syntax name writeFailed
    accepted=ep~writeObject(command)
    signal off syntax
    if accepted==.false then do; handles~remove(id); return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"component control rejected command"); end
  end
  handles~remove(id)
  return .StorageFuseResult~new(0,.true,"")
writeFailed:
  signal off syntax
  handles~remove(id)
  return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"component control raised while committing command")
::method truncatePath
  expose delegate registry
  use strict arg pathArg,sizeArg
  if self~isProjection(pathArg) then return delegate~truncatePath(pathArg,sizeArg)
  lp=self~localPath(pathArg); ep=registry~endpoint(lp)
  if ep==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"endpoint absent")
  if ep~writable then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"report endpoint is read only")
  if sizeArg+0<>0 then return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"control path truncate only accepts zero")
  return .StorageFuseResult~new(0,.true,"control write buffer is per-open; truncate does not mutate component")
::method create
  expose delegate
  use strict arg pathArg,modeArg="RW"
  if self~isProjection(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"component namespace is registered, not created through FUSE")
  return delegate~create(pathArg,modeArg)
::method mkdir
  expose delegate
  use strict arg pathArg
  if self~isProjection(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"component namespace is registered, not created through FUSE")
  return delegate~mkdir(pathArg)
::method unlink
  expose delegate
  use strict arg pathArg
  if self~isProjection(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"component namespace entries are registrations")
  return delegate~unlink(pathArg)
::method rename
  expose delegate
  use strict arg oldArg,newArg
  if self~isProjection(oldArg) | self~isProjection(newArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"component namespace entries are registrations")
  return delegate~rename(oldArg,newArg)
::method rmdir
  expose delegate
  use strict arg pathArg
  if self~isProjection(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"component namespace entries are registrations")
  return delegate~rmdir(pathArg)
::method readVirtual
  expose delegate
  use strict arg pathArg
  if self~isProjection(pathArg) then return .StorageFuseResult~new(.StorageFuseErrno~ENOTSUP,.nil,"component endpoints are ordinary projected files")
  return delegate~readVirtual(pathArg)

::requires "ComponentProjection.cls"
::requires "src/StorageFuse.cls"
