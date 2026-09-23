/* ooRexx Storage Fabric FUSE/virtual-filesystem operation core.
 *
 * This is deliberately split from the native libfuse3 mount adapter.  It owns
 * the filesystem semantics that a FUSE callback layer must call: fluid colon
 * views, named streams, handle-pinned generations and multi-file atomic
 * snapshot barriers.  The qualification fixture uses the in-memory generation
 * store below so semantics can be proven even where /dev/fuse/libfuse3 are not
 * available.
 */

::class StorageFuseBuild public
::constant VERSION "0.1-dev14"
::constant API "storage.fabric.fuse/0.1"

::class StorageFuseErrno public
::constant OK 0
::constant ENOENT 2
::constant EIO 5
::constant EAGAIN 11
::constant EACCES 13
::constant EBUSY 16
::constant EEXIST 17
::constant ENOTDIR 20
::constant EISDIR 21
::constant EINVAL 22
::constant EROFS 30
::constant ENOTEMPTY 39
::constant ENOTSUP 95

::class StorageFuseNodeKind public
::constant FILE "FILE"
::constant DIRECTORY "DIRECTORY"
::constant CONTROL "CONTROL"

::class StorageFuseViewKind public
::constant LIVE "LIVE"
::constant FROZEN "FROZEN"
::constant GENERATION "GENERATION"
::constant HISTORY "HISTORY"
::constant RELEASE "RELEASE"

::class StorageFuseSnapshotState public
::constant REQUESTED "REQUESTED"
::constant BARRIER_INSTALLED "BARRIER_INSTALLED"
::constant WAITING_FOR_HANDLES "WAITING_FOR_HANDLES"
::constant PUBLISHED "PUBLISHED"
::constant RELEASED "RELEASED"
::constant FAILED "FAILED"

::class StorageFuseSnapshotMemberState public
::constant DRAINING "DRAINING"
::constant FROZEN "FROZEN"

::class StorageFuseVersionOp public
::attribute kind get
::attribute streamName get
::attribute offset get
::attribute data get
::attribute size get
::method init
  expose kind streamName offset data size
  use arg kindArg, streamArg="", offsetArg=0, dataArg="", sizeArg=0
  kind=kindArg~string~upper
  streamName=streamArg~string
  offset=offsetArg+0
  data=dataArg~string
  size=sizeArg+0

::class StorageFuseVersion public
::attribute versionId get
::attribute path get
::attribute generation get
::attribute frozen get
::attribute baseVersion get
::method init
  expose versionId path generation frozen baseVersion defaultSeed streamSeeds operations
  use arg idArg,pathArg,generationArg,baseArg=.nil,defaultArg=""
  versionId=idArg~string
  path=.StoragePath~normalize(pathArg)
  generation=generationArg+0
  baseVersion=baseArg
  defaultSeed=defaultArg~string
  streamSeeds=.directory~new
  operations=.array~new
  frozen=.false
::method cloneForGeneration
  expose path
  use arg idArg,generationArg
  return .StorageFuseVersion~new(idArg,path,generationArg,self)
::method freeze
  expose frozen
  frozen=.true
  return self
::method putSeedStream
  expose streamSeeds frozen
  use arg nameArg,dataArg
  if frozen then raise syntax 88.900 array("frozen version cannot be mutated")
  n=nameArg~string
  if n="" then raise syntax 88.900 array("named stream name is mandatory")
  streamSeeds[n]=dataArg~string
  return self
::method writeAt
  expose frozen operations
  use arg offsetArg,dataArg,streamArg=""
  if frozen then raise syntax 88.900 array("frozen version cannot be mutated")
  off=offsetArg+0
  if off<0 then raise syntax 88.900 array("negative write offset")
  data=dataArg~string
  operations~append(.StorageFuseVersionOp~new("WRITE",streamArg,off,data,0))
  return length(data)
::method truncate
  expose frozen operations
  use arg sizeArg,streamArg=""
  if frozen then raise syntax 88.900 array("frozen version cannot be mutated")
  n=sizeArg+0
  if n<0 then raise syntax 88.900 array("negative truncate size")
  operations~append(.StorageFuseVersionOp~new("TRUNCATE",streamArg,0,"",n))
  return self
::method streamExists
  expose baseVersion streamSeeds operations
  use arg streamArg=""
  n=streamArg~string
  if n="" then return .true
  if streamSeeds[n]<>.nil then return .true
  do op over operations
    if op~streamName=n then return .true
  end
  if baseVersion<>.nil then return baseVersion~streamExists(n)
  return .false
::method namedStreams
  expose baseVersion streamSeeds operations
  seen=.directory~new
  if baseVersion<>.nil then do n over baseVersion~namedStreams; seen[n]=.true; end
  do n over streamSeeds; seen[n]=.true; end
  do op over operations
    if op~streamName<>"" then seen[op~streamName]=.true
  end
  answer=.array~new
  do n over seen; answer~append(n); end
  return answer
::method materialize
  expose baseVersion defaultSeed streamSeeds operations
  use arg streamArg=""
  n=streamArg~string
  if baseVersion<>.nil then out=baseVersion~materialize(n)
  else if n="" then out=defaultSeed
  else do
    seed=streamSeeds[n]
    if seed==.nil then out=""; else out=seed~string
  end
  do op over operations
    if op~streamName=n then do
      if op~kind="WRITE" then out=self~applyWrite(out,op~offset,op~data)
      else if op~kind="TRUNCATE" then out=self~applyTruncate(out,op~size)
    end
  end
  return out
::method readAt
  use arg offsetArg,countArg,streamArg=""
  off=offsetArg+0; count=countArg+0
  if off<0 | count<0 then return ""
  data=self~materialize(streamArg)
  if off>=length(data) then return ""
  remaining=length(data)-off
  if count>remaining then count=remaining
  return substr(data,off+1,count)
::method size
  use arg streamArg=""
  return length(self~materialize(streamArg))
::method applyWrite private
  use arg existing,offsetArg,dataArg
  off=offsetArg+0; data=dataArg~string
  if off>length(existing) then existing=existing||copies("00"x,off-length(existing))
  before=""
  if off>0 then before=left(existing,off)
  afterPos=off+length(data)+1
  after=""
  if afterPos<=length(existing) then after=substr(existing,afterPos)
  return before||data||after
::method applyTruncate private
  use arg existing,sizeArg
  n=sizeArg+0
  if n<=length(existing) then return left(existing,n)
  return existing||copies("00"x,n-length(existing))

::class StorageFuseHandle public
::attribute handleId get
::attribute path get
::attribute version get
::attribute streamName get
::attribute mode get
::attribute openedGeneration get
::attribute closed get
::method init
  expose handleId path version streamName mode openedGeneration closed
  use arg idArg,pathArg,versionArg,modeArg="READ",streamArg=""
  handleId=idArg~string
  path=.StoragePath~normalize(pathArg)
  version=versionArg
  streamName=streamArg~string
  mode=modeArg~string~upper
  openedGeneration=versionArg~generation
  closed=.false
::method writable
  expose mode closed
  if closed then return .false
  return pos("W",mode)>0 | pos("WRITE",mode)>0 | mode="RW" | mode="READWRITE"
::method readable
  expose mode closed
  if closed then return .false
  if self~writable & pos("R",mode)=0 & pos("READ",mode)=0 then return .false
  return .true
::method writeAt
  expose version streamName closed
  use arg offsetArg,dataArg
  if closed | \self~writable then return -1
  return version~writeAt(offsetArg,dataArg,streamName)
::method truncate
  expose version streamName closed
  use arg sizeArg
  if closed | \self~writable then return .false
  version~truncate(sizeArg,streamName)
  return .true
::method readAt
  expose version streamName closed
  use arg offsetArg,countArg
  if closed then return ""
  return version~readAt(offsetArg,countArg,streamName)
::method close
  expose closed
  closed=.true
  return self

::class StorageFuseSnapshotMember public
::attribute path get
::attribute version get
::attribute state get
::method init
  expose path version state
  use arg pathArg,versionArg,stateArg
  path=.StoragePath~normalize(pathArg)
  version=versionArg
  state=stateArg~string
::method freeze
  expose version state
  version~freeze
  state=.StorageFuseSnapshotMemberState~FROZEN
  return self

::class StorageFuseSnapshot public
::attribute snapshotId get
::attribute basePath get
::attribute generation get
::attribute nextGeneration get
::attribute state get
::attribute createdAt get
::attribute publishedAt get
::method init
  expose snapshotId basePath generation nextGeneration state createdAt publishedAt members directories
  use arg idArg,baseArg,generationArg,nextGenerationArg
  snapshotId=idArg~string
  basePath=.StoragePath~normalize(baseArg)
  generation=generationArg+0
  nextGeneration=nextGenerationArg+0
  state=.StorageFuseSnapshotState~REQUESTED
  createdAt=date("S")||"T"||time("L")
  publishedAt=""
  members=.directory~new
  directories=.directory~new
::method installBarrier
  expose state
  state=.StorageFuseSnapshotState~BARRIER_INSTALLED
  return self
::method addMember
  expose members
  use arg member
  members[member~path]=member
  return member
::method member
  expose members
  use arg pathArg
  return members[.StoragePath~normalize(pathArg)]
::method allMembers
  expose members
  a=.array~new
  do p over members; a~append(members[p]); end
  return a
::method addDirectory
  expose directories
  use arg pathArg
  directories[.StoragePath~normalize(pathArg)]=.true
  return self
::method hasDirectory
  expose directories
  use arg pathArg
  return directories[.StoragePath~normalize(pathArg)]<>.nil
::method allDirectories
  expose directories
  a=.array~new
  do p over directories; a~append(p); end
  return a
::method waiting
  expose state
  state=.StorageFuseSnapshotState~WAITING_FOR_HANDLES
  return self
::method allFrozen
  expose members
  do p over members
    if members[p]~state<>.StorageFuseSnapshotMemberState~FROZEN then return .false
  end
  return .true
::method publish
  expose state publishedAt
  if \self~allFrozen then return .false
  state=.StorageFuseSnapshotState~PUBLISHED
  publishedAt=date("S")||"T"||time("L")
  return .true
::method release
  expose state
  state=.StorageFuseSnapshotState~RELEASED
  return .true
::method published
  expose state
  return state=.StorageFuseSnapshotState~PUBLISHED

::class StorageFuseGenerationStore public
::attribute currentGeneration get
::method init
  expose currentGeneration versions live handles dualTargets snapshots latestByBase pendingByBase directories nextVersion nextHandle nextSnapshot
  currentGeneration=1
  versions=.directory~new
  live=.directory~new
  handles=.directory~new
  dualTargets=.directory~new
  snapshots=.directory~new
  latestByBase=.directory~new
  pendingByBase=.directory~new
  directories=.directory~new
  directories["/"]=.true
  nextVersion=1; nextHandle=1; nextSnapshot=1
::method mkdir
  expose directories
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  directories[p]=.true
  self~ensureParents(p)
  return .true
::method createFile
  expose currentGeneration versions live nextVersion
  use arg pathArg,dataArg=""
  p=.StoragePath~normalize(pathArg)
  if live[p]<>.nil then return .nil
  id="v"||nextVersion; nextVersion+=1
  v=.StorageFuseVersion~new(id,p,currentGeneration,.nil,dataArg)
  versions[id]=v; live[p]=v
  self~ensureParents(.StoragePath~parent(p))
  return v
::method fileExists
  expose live
  use arg pathArg
  return live[.StoragePath~normalize(pathArg)]<>.nil
::method directoryExists
  expose directories live
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if directories[p]<>.nil then return .true
  prefix=p
  if prefix<>"/" then prefix=prefix||"/"
  do fp over live
    if left(fp,length(prefix))=prefix then return .true
  end
  return .false
::method liveVersion
  expose live
  use arg pathArg
  return live[.StoragePath~normalize(pathArg)]
::method open
  expose live handles nextHandle
  use arg pathArg,modeArg="READ",streamArg=""
  p=.StoragePath~normalize(pathArg)
  v=live[p]
  if v==.nil then return .nil
  mode=modeArg~string~upper
  stream=streamArg~string
  wantsWrite=(pos("W",mode)>0 | pos("WRITE",mode)>0 | mode="RW" | mode="READWRITE")
  if \wantsWrite & stream<>"" & \v~streamExists(stream) then return .nil
  id="h"||nextHandle; nextHandle+=1
  h=.StorageFuseHandle~new(id,p,v,mode,stream)
  handles[id]=h
  return h
::method openVersion
  expose handles nextHandle
  use arg pathArg,versionArg,modeArg="READ",streamArg=""
  if versionArg==.nil then return .nil
  mode=modeArg~string~upper
  if pos("W",mode)>0 | pos("WRITE",mode)>0 then return .nil
  stream=streamArg~string
  if stream<>"" & \versionArg~streamExists(stream) then return .nil
  id="h"||nextHandle; nextHandle+=1
  h=.StorageFuseHandle~new(id,pathArg,versionArg,mode,stream)
  handles[id]=h
  return h
::method handle
  expose handles
  use arg idArg
  return handles[idArg~string]
::method write
  expose handles dualTargets
  use arg handleArg,offsetArg,dataArg
  h=self~resolveHandle(handleArg)
  if h==.nil then return -1
  n=h~writeAt(offsetArg,dataArg)
  if n<0 then return n
  dual=dualTargets[h~handleId]
  if dual<>.nil then dual~writeAt(offsetArg,dataArg,h~streamName)
  return n
::method truncateHandle
  expose dualTargets
  use arg handleArg,sizeArg
  h=self~resolveHandle(handleArg)
  if h==.nil then return .false
  if \h~truncate(sizeArg) then return .false
  dual=dualTargets[h~handleId]
  if dual<>.nil then dual~truncate(sizeArg,h~streamName)
  return .true
::method read
  use arg handleArg,offsetArg,countArg
  h=self~resolveHandle(handleArg)
  if h==.nil then return ""
  return h~readAt(offsetArg,countArg)
::method close
  expose handles dualTargets
  use arg handleArg
  h=self~resolveHandle(handleArg)
  if h==.nil then return .false
  oldVersion=h~version
  h~close
  dualTargets~remove(h~handleId)
  handles~remove(h~handleId)
  self~advancePendingForVersion(oldVersion)
  return .true
::method liveRead
  expose live
  use arg pathArg,offsetArg=0,countArg=2147483647,streamArg=""
  v=live[.StoragePath~normalize(pathArg)]
  if v==.nil then return ""
  if streamArg~string<>"" & \v~streamExists(streamArg) then return ""
  return v~readAt(offsetArg,countArg,streamArg)
::method renameLive
  expose live directories
  use arg oldArg,newArg
  old=.StoragePath~normalize(oldArg); new=.StoragePath~normalize(newArg)
  v=live[old]
  if v==.nil then return .false
  if live[new]<>.nil then return .false
  live~remove(old); live[new]=v
  self~ensureParents(.StoragePath~parent(new))
  return .true
::method unlinkLive
  expose live
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if live[p]==.nil then return .false
  live~remove(p)
  return .true
/* Remove one explicit empty live directory.  Storage identity remains the
 * namespace path; this only changes live directory membership and never
 * removes descendants implicitly. */
::method rmdirLive
  expose directories live
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  if p="/" | directories[p]==.nil then return .false
  prefix=p||"/"
  do d over directories
    if d<>p & left(d,length(prefix))=prefix then return .false
  end
  do fp over live
    if left(fp,length(prefix))=prefix then return .false
  end
  directories~remove(p)
  return .true
::method listLive
  expose live directories
  use arg folderArg
  folder=.StoragePath~normalize(folderArg)
  return self~collectDirectChildren(folder,live,directories)
::method allLivePaths
  expose live
  a=.array~new
  do p over live; a~append(p); end
  return a
::method beginSnapshot
  expose currentGeneration versions live handles dualTargets snapshots latestByBase pendingByBase directories nextVersion nextSnapshot
  use arg baseArg,membersArg=.nil
  base=.StoragePath~normalize(baseArg)
  pending=pendingByBase[base]
  if pending<>.nil then return snapshots[pending]
  /* One unresolved generation barrier at a time.  This avoids overlapping
   * barriers targeting a version that is still being dual-written by an older
   * snapshot.  Published snapshots may coexist indefinitely. */
  do b over pendingByBase
    pid=pendingByBase[b]
    if pid<>.nil then do
      ps=snapshots[pid]
      if ps<>.nil & ps~state=.StorageFuseSnapshotState~WAITING_FOR_HANDLES then return .nil
    end
  end
  oldGeneration=currentGeneration
  newGeneration=currentGeneration+1
  sid="s"||nextSnapshot; nextSnapshot+=1
  s=.StorageFuseSnapshot~new(sid,base,oldGeneration,newGeneration)
  snapshots[sid]=s
  s~installBarrier
  /* Freeze directory membership as part of the same namespace generation. */
  do d over directories
    if self~pathWithin(d,base) then s~addDirectory(d)
  end
  if membersArg==.nil then paths=self~pathsUnder(base)
  else paths=membersArg
  if paths==.nil then paths=.array~new
  do pathItem over paths
    p=.StoragePath~normalize(pathItem)
    old=live[p]
    if old<>.nil then do
      id="v"||nextVersion; nextVersion+=1
      child=old~cloneForGeneration(id,newGeneration)
      versions[id]=child
      live[p]=child
      writers=self~writersForVersion(old)
      if writers~items>0 then do
        m=.StorageFuseSnapshotMember~new(p,old,.StorageFuseSnapshotMemberState~DRAINING)
        do h over writers; dualTargets[h~handleId]=child; end
      end
      else do
        old~freeze
        m=.StorageFuseSnapshotMember~new(p,old,.StorageFuseSnapshotMemberState~FROZEN)
      end
      s~addMember(m)
    end
  end
  currentGeneration=newGeneration
  if s~allFrozen then do
    s~publish
    latestByBase[base]=sid
  end
  else do
    s~waiting
    pendingByBase[base]=sid
  end
  return s
::method snapshot
  expose snapshots
  use arg idArg
  return snapshots[idArg~string]
::method latestSnapshot
  expose latestByBase snapshots
  use arg baseArg
  id=latestByBase[.StoragePath~normalize(baseArg)]
  if id==.nil then return .nil
  s=snapshots[id]
  if s==.nil | s~state=.StorageFuseSnapshotState~RELEASED then return .nil
  return s
::method pendingSnapshot
  expose pendingByBase snapshots
  use arg baseArg
  id=pendingByBase[.StoragePath~normalize(baseArg)]
  if id==.nil then return .nil
  return snapshots[id]
::method snapshotByGeneration
  expose snapshots
  use arg baseArg,generationArg
  base=.StoragePath~normalize(baseArg); g=generationArg+0
  do id over snapshots
    s=snapshots[id]
    if s~basePath=base & s~generation=g & s~state<>.StorageFuseSnapshotState~RELEASED then return s
  end
  return .nil
::method snapshotsForBase
  expose snapshots
  use arg baseArg
  base=.StoragePath~normalize(baseArg)
  a=.array~new
  do id over snapshots
    s=snapshots[id]
    if s~basePath=base then a~append(s)
  end
  return a
::method snapshotRead
  use arg snapshotArg,pathArg,offsetArg=0,countArg=2147483647,streamArg=""
  if snapshotArg==.nil | \snapshotArg~published then return ""
  m=snapshotArg~member(pathArg)
  if m==.nil then return ""
  if streamArg~string<>"" & \m~version~streamExists(streamArg) then return ""
  return m~version~readAt(offsetArg,countArg,streamArg)
::method snapshotVersion
  use arg snapshotArg,pathArg
  if snapshotArg==.nil then return .nil
  m=snapshotArg~member(pathArg)
  if m==.nil then return .nil
  return m~version
::method listSnapshot
  use arg snapshotArg,folderArg
  if snapshotArg==.nil | \snapshotArg~published then return .nil
  folder=.StoragePath~normalize(folderArg)
  members=.directory~new
  do m over snapshotArg~allMembers; members[m~path]=m~version; end
  dirs=.directory~new
  do d over snapshotArg~allDirectories; dirs[d]=.true; end
  return self~collectDirectChildren(folder,members,dirs)
::method releaseSnapshot
  expose snapshots latestByBase pendingByBase
  use arg snapshotArg
  if snapshotArg==.nil then return .false
  if snapshotArg~state=.StorageFuseSnapshotState~WAITING_FOR_HANDLES then return .false
  base=snapshotArg~basePath; sid=snapshotArg~snapshotId
  snapshotArg~release
  if latestByBase[base]=sid then latestByBase~remove(base)
  if pendingByBase[base]=sid then pendingByBase~remove(base)
  return .true
::method writersForVersion private
  expose handles
  use arg versionArg
  a=.array~new
  do id over handles
    h=handles[id]
    if h<>.nil & h~writable & h~version==versionArg then a~append(h)
  end
  return a
::method advancePendingForVersion private
  expose snapshots pendingByBase latestByBase
  use arg versionArg
  do base over pendingByBase
    sid=pendingByBase[base]
    if sid<>.nil then do
      s=snapshots[sid]
      if s<>.nil & s~state=.StorageFuseSnapshotState~WAITING_FOR_HANDLES then do
        do m over s~allMembers
          if m~version==versionArg & m~state=.StorageFuseSnapshotMemberState~DRAINING then do
            if self~writersForVersion(versionArg)~items=0 then m~freeze
          end
        end
        if s~allFrozen then do
          s~publish
          latestByBase[base]=sid
          pendingByBase~remove(base)
        end
      end
    end
  end
  return self
::method pathsUnder private
  expose live
  use arg baseArg
  base=.StoragePath~normalize(baseArg)
  a=.array~new
  if live[base]<>.nil then do; a~append(base); return a; end
  prefix=base
  if prefix<>"/" then prefix=prefix||"/"
  do p over live
    if left(p,length(prefix))=prefix then a~append(p)
  end
  return a
::method pathWithin private
  use arg pathArg,baseArg
  p=.StoragePath~normalize(pathArg); b=.StoragePath~normalize(baseArg)
  if p=b then return .true
  if b="/" then return left(p,1)="/"
  return left(p,length(b)+1)=b||"/"
::method collectDirectChildren private
  use arg folderArg,fileMap,dirMap
  folder=.StoragePath~normalize(folderArg)
  seen=.directory~new
  answer=.array~new
  do d over dirMap
    if .StoragePath~isDirectChild(d,folder) then do
      n=.StoragePath~name(d)
      if seen[n]==.nil then do; seen[n]=.true; answer~append(n); end
    end
  end
  do p over fileMap
    if .StoragePath~isDirectChild(p,folder) then do
      n=.StoragePath~name(p)
      if seen[n]==.nil then do; seen[n]=.true; answer~append(n); end
    end
    else if self~pathWithin(p,folder) & p<>folder then do
      prefix=folder
      if prefix="/" then rest=substr(p,2)
      else rest=substr(p,length(folder)+2)
      slash=pos("/",rest)
      if slash>0 then do
        n=left(rest,slash-1)
        if seen[n]==.nil then do; seen[n]=.true; answer~append(n); end
      end
    end
  end
  return answer
::method ensureParents private
  expose directories
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  do forever
    directories[p]=.true
    if p="/" then leave
    p=.StoragePath~parent(p)
  end
  return self
::method resolveHandle
  expose handles
  use arg handleArg
  if handleArg==.nil then return .nil
  if handleArg~isA(.StorageFuseHandle) then return handleArg
  return handles[handleArg~string]

/* Colon-aware virtual path parser.
 * Reserved view selectors are interpreted only when the suffix is a Storage
 * system word.  Unknown final suffixes remain ordinary named streams, so
 * file:thumbnail and file:1 can hold bytes independent of the default stream.
 */
::class StorageFuseVirtualPath public
::attribute original get
::attribute viewKind get
::attribute generation get
::attribute basePath get
::attribute relativePath get
::attribute effectivePath get
::attribute namedStream get
::attribute systemStream get
::method init
  expose original viewKind generation basePath relativePath effectivePath namedStream systemStream
  use arg pathArg
  original=.StoragePath~normalize(pathArg)
  viewKind=.StorageFuseViewKind~LIVE; generation=0; namedStream=""; systemStream=""
  parts=self~split(original)
  viewIndex=0; viewBase=""
  /* Find the first reserved directory-view selector. */
  do i=1 to parts~items
    c=parts[i]
    cp=pos(":",c)
    if cp>0 then do
      stem=left(c,cp-1); suffix=substr(c,cp+1)
      su=suffix~lower
      if su="frozen" | su="live" | su="history" | su="release" | (left(su,1)="g" & self~digits(substr(su,2))) then do
        viewIndex=i; viewBase=stem
        select
          when su="frozen" then viewKind=.StorageFuseViewKind~FROZEN
          when su="live" then viewKind=.StorageFuseViewKind~LIVE
          when su="history" then viewKind=.StorageFuseViewKind~HISTORY
          when su="release" then viewKind=.StorageFuseViewKind~RELEASE
          otherwise do
            viewKind=.StorageFuseViewKind~GENERATION
            generation=substr(su,2)+0
          end
        end
        leave
      end
    end
  end
  if viewIndex>0 then do
    baseParts=.array~new
    do i=1 to viewIndex-1; baseParts~append(parts[i]); end
    if viewBase<>"" then baseParts~append(viewBase)
    basePath=self~joinParts(baseParts)
    relParts=.array~new
    do i=viewIndex+1 to parts~items; relParts~append(parts[i]); end
    relativePath=self~joinParts(relParts)
    if relativePath="/" then effectivePath=basePath
    else if basePath="/" then effectivePath=relativePath
    else effectivePath=.StoragePath~normalize(basePath||relativePath)
  end
  else do
    basePath="/"; relativePath=original; effectivePath=original
  end
  /* Final component can independently name a system or application stream. */
  ep=.StoragePath~name(effectivePath)
  cp=pos(":",ep)
  if cp>0 then do
    stem=left(ep,cp-1); suffix=substr(ep,cp+1)
    if left(suffix,1)="$" then systemStream=suffix
    else namedStream=suffix
    parent=.StoragePath~parent(effectivePath)
    effectivePath=.StoragePath~join(parent,stem)
    if viewIndex=0 then relativePath=effectivePath
  end
::method split private
  use arg pathArg
  p=.StoragePath~normalize(pathArg)
  a=.array~new
  if p="/" then return a
  rest=substr(p,2)
  do while rest<>""
    slash=pos("/",rest)
    if slash=0 then do; a~append(rest); leave; end
    a~append(left(rest,slash-1))
    rest=substr(rest,slash+1)
  end
  return a
::method joinParts private
  use arg parts
  if parts~items=0 then return "/"
  out=""
  do p over parts; out=out||"/"||p; end
  return .StoragePath~normalize(out)
::method digits private
  use arg s
  if s="" then return .false
  do i=1 to length(s)
    if pos(substr(s,i,1),"0123456789")=0 then return .false
  end
  return .true

::class StorageFuseNode public
::attribute kind get
::attribute size get
::attribute state get
::attribute generation get
::attribute path get
::method init
  expose kind size state generation path
  use arg kindArg,pathArg,sizeArg=0,stateArg="",generationArg=0
  kind=kindArg~string; path=pathArg~string; size=sizeArg+0; state=stateArg~string; generation=generationArg+0

::class StorageFuseResult public
::attribute errno get
::attribute value get
::attribute detail get
::method init
  expose errno value detail
  use arg errnoArg=0,valueArg=.nil,detailArg=""
  errno=errnoArg+0; value=valueArg; detail=detailArg~string
::method ok
  expose errno
  return errno=0

/* FUSE callback semantics independent of libfuse.  A native adapter can map
 * these methods directly onto getattr/readdir/open/read/write/release/truncate,
 * while tests exercise the same operation core without requiring /dev/fuse. */
::class StorageFuseOperationCore public
::attribute store get
::attribute autoAcquireFrozen get
::method init
  expose store autoAcquireFrozen
  use arg storeArg=.nil,autoAcquireArg=.true
  if storeArg==.nil then store=.StorageFuseGenerationStore~new; else store=storeArg
  autoAcquireFrozen=autoAcquireArg
/* Resolve one virtual path into stable FUSE metadata without exposing store internals. */
::method getattr
  expose store autoAcquireFrozen
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~systemStream<>"" then do
    data=self~systemStreamData(vp)
    if data==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"unknown system stream")
    return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~CONTROL,pathArg,length(data),"READY",0),"")
  end
  select
    when vp~viewKind=.StorageFuseViewKind~LIVE then return self~getattrLive(vp)
    when vp~viewKind=.StorageFuseViewKind~FROZEN then do
      s=store~latestSnapshot(vp~basePath)
      if s==.nil & autoAcquireFrozen then s=store~beginSnapshot(vp~basePath)
      if s==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EBUSY,.nil,"another snapshot barrier is draining")
      if vp~relativePath="/" then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,s~state,s~generation),"")
      if \s~published then return .StorageFuseResult~new(.StorageFuseErrno~EAGAIN,.nil,"frozen generation is waiting for existing writers")
      v=store~snapshotVersion(s,vp~effectivePath)
      if v<>.nil then do
        if vp~namedStream<>"" & \v~streamExists(vp~namedStream) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"named stream absent")
        return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~FILE,pathArg,v~size(vp~namedStream),"FROZEN",s~generation),"")
      end
      if s~hasDirectory(vp~effectivePath) then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"FROZEN",s~generation),"")
      return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"path not in frozen membership")
    end
    when vp~viewKind=.StorageFuseViewKind~GENERATION then do
      s=store~snapshotByGeneration(vp~basePath,vp~generation)
      if s==.nil | \s~published then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"generation not published")
      if vp~relativePath="/" then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"FROZEN",s~generation),"")
      v=store~snapshotVersion(s,vp~effectivePath)
      if v<>.nil then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~FILE,pathArg,v~size(vp~namedStream),"FROZEN",s~generation),"")
      if s~hasDirectory(vp~effectivePath) then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"FROZEN",s~generation),"")
      return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"generation path absent")
    end
    when vp~viewKind=.StorageFuseViewKind~HISTORY then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,pathArg,0,"HISTORY",0),"")
    when vp~viewKind=.StorageFuseViewKind~RELEASE then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~CONTROL,pathArg,0,"CONTROL",0),"lookup is observational; release requires an explicit mutation operation")
    otherwise return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"unsupported view")
  end
::method getattrLive private
  expose store
  use arg vp
  p=vp~effectivePath
  v=store~liveVersion(p)
  if v<>.nil then do
    if vp~namedStream<>"" & \v~streamExists(vp~namedStream) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"named stream absent")
    return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~FILE,vp~original,v~size(vp~namedStream),"LIVE",v~generation),"")
  end
  if store~directoryExists(p) then return .StorageFuseResult~new(0,.StorageFuseNode~new(.StorageFuseNodeKind~DIRECTORY,vp~original,0,"LIVE",store~currentGeneration),"")
  return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"path absent")
/* Enumerate live/frozen/generation/history views under their existing snapshot rules. */
::method readdir
  expose store autoAcquireFrozen
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~namedStream<>"" | vp~systemStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTDIR,.nil,"stream is not a directory")
  select
    when vp~viewKind=.StorageFuseViewKind~LIVE then do
      if \store~directoryExists(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"directory absent")
      return .StorageFuseResult~new(0,store~listLive(vp~effectivePath),"")
    end
    when vp~viewKind=.StorageFuseViewKind~FROZEN then do
      s=store~latestSnapshot(vp~basePath)
      if s==.nil & autoAcquireFrozen then s=store~beginSnapshot(vp~basePath)
      if s==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EBUSY,.nil,"another barrier is draining")
      if \s~published then return .StorageFuseResult~new(.StorageFuseErrno~EAGAIN,.nil,"snapshot pending existing writer close")
      a=store~listSnapshot(s,vp~effectivePath)
      if a==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"frozen directory absent")
      return .StorageFuseResult~new(0,a,"")
    end
    when vp~viewKind=.StorageFuseViewKind~GENERATION then do
      s=store~snapshotByGeneration(vp~basePath,vp~generation)
      if s==.nil | \s~published then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"generation absent")
      a=store~listSnapshot(s,vp~effectivePath)
      if a==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"generation directory absent")
      return .StorageFuseResult~new(0,a,"")
    end
    when vp~viewKind=.StorageFuseViewKind~HISTORY then do
      a=.array~new
      do s over store~snapshotsForBase(vp~basePath)
        if s~state<>.StorageFuseSnapshotState~RELEASED then a~append("g"||s~generation)
      end
      return .StorageFuseResult~new(0,a,"")
    end
    otherwise return .StorageFuseResult~new(.StorageFuseErrno~ENOTDIR,.nil,"control selector is not a normal directory")
  end
/* Open live or immutable-generation data while enforcing read-only snapshot semantics. */
::method open
  expose store
  use arg pathArg,modeArg="READ"
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~systemStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTSUP,.nil,"system streams are read through readVirtual in this core")
  if vp~viewKind=.StorageFuseViewKind~LIVE then do
    h=store~open(vp~effectivePath,modeArg,vp~namedStream)
    if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"file/stream absent")
    return .StorageFuseResult~new(0,h,"")
  end
  if vp~viewKind=.StorageFuseViewKind~FROZEN | vp~viewKind=.StorageFuseViewKind~GENERATION then do
    mode=modeArg~string~upper
    if pos("W",mode)>0 | pos("WRITE",mode)>0 then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"frozen generations are read-only")
    if vp~viewKind=.StorageFuseViewKind~FROZEN then s=store~latestSnapshot(vp~basePath)
    else s=store~snapshotByGeneration(vp~basePath,vp~generation)
    if s==.nil | \s~published then return .StorageFuseResult~new(.StorageFuseErrno~EAGAIN,.nil,"snapshot not published")
    v=store~snapshotVersion(s,vp~effectivePath)
    if v==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"snapshot file absent")
    h=store~openVersion(vp~effectivePath,v,modeArg,vp~namedStream)
    if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"snapshot stream absent")
    return .StorageFuseResult~new(0,h,"")
  end
  return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"selector is not openable as a data file")
/* Read bytes through a previously resolved handle; handle generation stays pinned. */
::method read
  expose store
  use arg handleArg,offsetArg,countArg
  return .StorageFuseResult~new(0,store~read(handleArg,offsetArg,countArg),"")
/* Write only through a writable live handle and translate store failure to errno. */
::method write
  expose store
  use arg handleArg,offsetArg,dataArg
  h=store~resolveHandle(handleArg)
  if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"handle absent")
  if \h~writable then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"handle not writable")
  n=store~write(h,offsetArg,dataArg)
  if n<0 then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"write failed")
  return .StorageFuseResult~new(0,n,"")
/* Resize an already-open writable handle without bypassing handle policy. */
::method truncate
  expose store
  use arg handleArg,sizeArg
  h=store~resolveHandle(handleArg)
  if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"handle absent")
  if \h~writable then return .StorageFuseResult~new(.StorageFuseErrno~EACCES,.nil,"handle not writable")
  if \store~truncateHandle(h,sizeArg) then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"truncate failed")
  return .StorageFuseResult~new(0,.true,"")
/* Release exactly one handle and report an absent/already-released handle cleanly. */
::method release
  expose store
  use arg handleArg
  if \store~close(handleArg) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"handle absent")
  return .StorageFuseResult~new(0,.true,"")
/* Create a live file or named stream; frozen/history/control views remain immutable. */
::method create
  expose store
  use arg pathArg,modeArg="RW"
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"cannot create in frozen/history/control view")
  if vp~systemStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTSUP,.nil,"system streams are filesystem-owned")
  /* An application named stream is created on an existing logical file.  It
   * is not a second directory entry and remains absent from readdir. */
  if vp~namedStream<>"" then do
    v=store~liveVersion(vp~effectivePath)
    if v==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"base file for named stream is absent")
    if v~streamExists(vp~namedStream) then return .StorageFuseResult~new(.StorageFuseErrno~EEXIST,.nil,"named stream already exists")
    h=store~open(vp~effectivePath,modeArg,vp~namedStream)
    if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"named stream could not be opened")
    if \h~truncate(0) then do; ignore=store~close(h); return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"named stream initialization failed"); end
    return .StorageFuseResult~new(0,h,"")
  end
  if store~fileExists(vp~effectivePath) | store~directoryExists(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~EEXIST,.nil,"path already exists")
  v=store~createFile(vp~effectivePath,"")
  if v==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"create failed")
  h=store~open(vp~effectivePath,modeArg,"")
  if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"created file could not be opened")
  return .StorageFuseResult~new(0,h,"")
/* Create a directory only in the live namespace and reject stream selectors. */
::method mkdir
  expose store
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"cannot create directory in frozen/history/control view")
  if vp~namedStream<>"" | vp~systemStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"stream selector cannot be a directory")
  if store~fileExists(vp~effectivePath) | store~directoryExists(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~EEXIST,.nil,"path already exists")
  if \store~mkdir(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"mkdir failed")
  return .StorageFuseResult~new(0,.true,"")
/* Open, truncate and close a live path as one path-level convenience operation. */
::method truncatePath
  expose store
  use arg pathArg,sizeArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"cannot truncate frozen/history/control view")
  h=store~open(vp~effectivePath,"RW",vp~namedStream)
  if h==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"file/stream absent")
  ok=store~truncateHandle(h,sizeArg)
  ignore=store~close(h)
  if \ok then return .StorageFuseResult~new(.StorageFuseErrno~EIO,.nil,"truncate failed")
  return .StorageFuseResult~new(0,.true,"")
/* Remove a live namespace entry; immutable and control views stay read-only. */
::method unlink
  expose store
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"cannot unlink frozen/history/control view")
  if vp~namedStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTSUP,.nil,"named-stream unlink is a later operation")
  if \store~unlinkLive(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"path absent")
  return .StorageFuseResult~new(0,.true,"")
/* Rename only within the live namespace; cross-view and named-stream moves are rejected. */
::method rename
  expose store
  use arg oldArg,newArg
  old=.StorageFuseVirtualPath~new(oldArg); new=.StorageFuseVirtualPath~new(newArg)
  if old~viewKind<>.StorageFuseViewKind~LIVE | new~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"rename across frozen/control view denied")
  if old~namedStream<>"" | new~namedStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~ENOTSUP,.nil,"named-stream rename is a later operation")
  if \store~renameLive(old~effectivePath,new~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"rename failed")
  return .StorageFuseResult~new(0,.true,"")
/* Handle the explicit frozen-view release control while leaving ordinary rmdir unsupported. */
/* Remove an empty live directory, or release the synthetic :frozen view.
 * No recursive delete is implied: live directories with descendants fail
 * closed so protocol adapters cannot turn rmdir into subtree deletion. */
::method rmdir
  expose store
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  if vp~viewKind=.StorageFuseViewKind~FROZEN & vp~relativePath="/" then do
    s=store~latestSnapshot(vp~basePath)
    if s==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"no published frozen generation")
    if \store~releaseSnapshot(s) then return .StorageFuseResult~new(.StorageFuseErrno~EBUSY,.nil,"snapshot is still draining")
    return .StorageFuseResult~new(0,.true,"explicit rmdir releases the synthetic frozen-view pin; underlying files are untouched")
  end
  if vp~viewKind<>.StorageFuseViewKind~LIVE then return .StorageFuseResult~new(.StorageFuseErrno~EROFS,.nil,"cannot remove directory in frozen/history/control view")
  if vp~namedStream<>"" | vp~systemStream<>"" then return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"stream selector cannot be removed as a directory")
  if \store~directoryExists(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"directory absent")
  entries=store~listLive(vp~effectivePath)
  if entries<>.nil & entries~items>0 then return .StorageFuseResult~new(.StorageFuseErrno~ENOTEMPTY,.nil,"directory not empty")
  if \store~rmdirLive(vp~effectivePath) then return .StorageFuseResult~new(.StorageFuseErrno~EINVAL,.nil,"directory removal failed")
  return .StorageFuseResult~new(0,.true,"")
/* Read Storage-owned system streams such as status/history without opening data handles. */
::method readVirtual
  use arg pathArg
  vp=.StorageFuseVirtualPath~new(pathArg)
  data=self~systemStreamData(vp)
  if data==.nil then return .StorageFuseResult~new(.StorageFuseErrno~ENOENT,.nil,"unknown virtual stream")
  return .StorageFuseResult~new(0,data,"")
::method systemStreamData private
  expose store
  use arg vp
  ss=vp~systemStream~lower
  if ss="" then return .nil
  base=vp~effectivePath
  if ss="$status" then do
    latest=store~latestSnapshot(base); pending=store~pendingSnapshot(base)
    out="liveGeneration="||store~currentGeneration||d2c(10)
    if pending<>.nil then out=out||"snapshot="||pending~snapshotId||" state="||pending~state||" generation="||pending~generation||d2c(10)
    else if latest<>.nil then out=out||"snapshot="||latest~snapshotId||" state="||latest~state||" generation="||latest~generation||d2c(10)
    else out=out||"snapshot=none"||d2c(10)
    return out
  end
  if ss="$history" then do
    out=""
    do s over store~snapshotsForBase(base)
      out=out||s~snapshotId||" generation="||s~generation||" state="||s~state||d2c(10)
    end
    return out
  end
  return .nil


/* Stable handoff to consumers such as Storage Evacuation.  :frozen is a
 * convenient moving alias; a prepared consistency lease must name the exact
 * immutable generation so a later snapshot cannot retarget the source root. */
::class StorageFusePreparedSnapshotRef public
::attribute snapshotId get
::attribute basePath get
::attribute generation get
::method init
  expose snapshotId basePath generation
  use arg snapshotArg
  if snapshotArg==.nil | \snapshotArg~published then raise syntax 88.900 array("published snapshot is required")
  snapshotId=snapshotArg~snapshotId
  basePath=snapshotArg~basePath
  generation=snapshotArg~generation
::method virtualRoot
  expose basePath generation
  if basePath="/" then return "/:g"||generation
  return basePath||":g"||generation
::method mountedRoot
  use arg mountRootArg
  root=mountRootArg~string~strip
  v=self~virtualRoot
  if root="" | root="/" then return v
  do while length(root)>1 & right(root,1)="/"; root=left(root,length(root)-1); end
  return root||v
::method evidence
  expose snapshotId generation
  return "FUSE_GENERATION:"||snapshotId||":g"||generation

::requires "src/StorageFabric.cls"
