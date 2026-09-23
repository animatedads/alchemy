/* ooRexx Storage Evacuation v0.1-dev8
 *
 * Durable generational evacuation/replication authority layered above Storage
 * Fabric.  Transport completion, replica verification and current-source
 * representation are deliberately distinct states.
 */

::class StorageEvacuationBuild public
::constant VERSION "0.1-dev8"
::constant API "storage.evacuation/0.1"

::class EvacReplicaState public
::constant PLANNED "PLANNED"
::constant COPYING "COPYING"
::constant TRANSFERRED "TRANSFERRED"
::constant VERIFIED "VERIFIED"
::constant VERIFIED_OLD_GENERATION "VERIFIED_OLD_GENERATION"
::constant VERIFIED_CURRENT "VERIFIED_CURRENT"
::constant FAILED "FAILED"

::class EvacObjectState public
::constant DISCOVERED "DISCOVERED"
::constant DIRTY "DIRTY"
::constant CURRENT "CURRENT"
::constant EXCLUDED "EXCLUDED"
::constant ERROR "ERROR"
::constant WAITING_FOR_QUIESCENCE "WAITING_FOR_QUIESCENCE"
::constant CONSISTENCY_UNPROVEN "CONSISTENCY_UNPROVEN"

::class EvacConsistencyClass public
::constant UNKNOWN "UNKNOWN"
::constant OBSERVED_QUIESCENT "OBSERVED_QUIESCENT"
::constant APPLICATION_CONSISTENT "APPLICATION_CONSISTENT"
::constant SNAPSHOT_CONSISTENT "SNAPSHOT_CONSISTENT"

/* Immutable-enough POSIX identity snapshot.  ctime is evidence only: POSIX
 * does not provide a normal operation for restoring it. */
::class EvacPosixMetadata public
::attribute path get
::attribute type get
::attribute modeOctal get
::attribute uid get
::attribute gid get
::attribute sizeBytes get
::attribute mtimeEpoch get
::attribute atimeEpoch get
::attribute ctimeEpoch get
::attribute device get
::attribute inode get
::attribute nlink get
::attribute symlinkTarget get
::attribute statFingerprint get
::attribute versionToken get
::method init
  expose path type modeOctal uid gid sizeBytes mtimeEpoch atimeEpoch ctimeEpoch device inode nlink symlinkTarget statFingerprint versionToken
  use arg pathArg,typeArg,modeArg,uidArg,gidArg,sizeArg,mtimeArg,atimeArg,ctimeArg,deviceArg,inodeArg,nlinkArg,targetArg="",versionTokenArg=""
  path=pathArg~string; type=typeArg~string; modeOctal=modeArg~string
  uid=uidArg+0; gid=gidArg+0; sizeBytes=sizeArg+0
  mtimeEpoch=mtimeArg~string; atimeEpoch=atimeArg~string; ctimeEpoch=ctimeArg~string
  device=deviceArg~string; inode=inodeArg~string; nlink=nlinkArg+0; symlinkTarget=targetArg~string
  versionToken=versionTokenArg~string
  statFingerprint=type||"|"||modeOctal||"|"||uid||"|"||gid||"|"||sizeBytes||"|"||mtimeEpoch||"|"||device||"|"||inode||"|"||versionToken
::method contentCandidate
  expose type
  return type="regular file"
::method hardLinkKey
  expose device inode type
  if type<>"regular file" then return ""
  return device||":"||inode
::method sameSourceVersion
  expose statFingerprint
  use arg other
  if other==.nil then return .false
  return statFingerprint==other~statFingerprint

/* Linux qualification probe.  It does not follow symlinks.  Delimiters are
 * unit separators so normal path text never participates in parsing. */
::class EvacPosixMetadataProbe public
/* POSIX Foundation is now authoritative for coherent generation evidence.
 * This adapter deliberately fails closed when coherent lstat is unavailable. */
::method init
  expose posix
  posix=.PosixGapFactory~create
::method probe
  expose posix
  use arg pathArg
  path=pathArg~string
  if path="" then return .nil
  result=posix~lstat(path)
  if \result~ok then return .nil
  st=result~value
  if \st~coherent then return .nil
  type=self~legacyType(st~fileType)
  mode=self~toOctal(st~mode // 4096)
  target=""
  if st~fileType="SYMLINK" then do
    rr=posix~readLink(path)
    if \rr~ok then return .nil
    target=rr~value~string
  end
  mtime=st~mtimeSec; atime=st~atimeSec; ctime=st~ctimeSec
  token=st~mtimeSec||"."||self~padNsec(st~mtimeNsec)||"|"||st~ctimeSec||"."||self~padNsec(st~ctimeNsec)
  return .EvacPosixMetadata~new(path,type,mode,st~uid,st~gid,st~size,mtime,atime,ctime,st~device,st~inode,st~linkCount,target,token)
::method legacyType private
  use arg t
  select
    when t="REGULAR" then return "regular file"
    when t="DIRECTORY" then return "directory"
    when t="SYMLINK" then return "symbolic link"
    when t="FIFO" then return "fifo"
    when t="SOCKET" then return "socket"
    when t="CHARACTER_DEVICE" then return "character special file"
    when t="BLOCK_DEVICE" then return "block special file"
    otherwise return t~string~lower
  end
::method toOctal private
  use arg nArg
  n=nArg+0
  if n=0 then return "0"
  out=""
  do while n>0
    out=(n // 8)||out
    n=n % 8
  end
  return out
::method padNsec private
  use arg nArg
  s=(nArg+0)~string
  return copies("0",9-length(s))||s

/* Captures opaque ACL/xattr evidence separately from the portable core
 * metadata.  Absence of getfacl/getfattr is explicit rather than silently
 * treated as "no metadata". */
::class EvacPosixExtendedMetadata public
::attribute aclText get
::attribute xattrText get
::attribute aclAvailable get
::attribute xattrAvailable get
::method init
  expose aclText xattrText aclAvailable xattrAvailable
  use arg aclArg="",xattrArg="",aclOk=.false,xattrOk=.false
  aclText=aclArg~string; xattrText=xattrArg~string
  aclAvailable=(aclOk==.true); xattrAvailable=(xattrOk==.true)

::class EvacPosixExtendedMetadataProbe public
::method probe
  use arg pathArg
  path=pathArg~string; q=self~shellQuote(path)
  acl=self~capture("/usr/bin/getfacl -cp --absolute-names -- "||q, "getfacl")
  xa=self~capture("/usr/bin/getfattr -d -m - -e hex --absolute-names -- "||q||" | /usr/bin/sed '/^# file:/d'", "getfattr")
  return .EvacPosixExtendedMetadata~new(acl["text"],xa["text"],acl["available"],xa["available"])
::method capture private
  use arg commandArg, executable
  d=.directory~new; d["text"]=""; d["available"]=.false
  address system "test -x /usr/bin/"||executable
  if rc<>0 then return d
  tmp=SysTempFileName("/tmp/oorexx-evac-meta-??????")
  address system commandArg||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  result=rc
  if result=0 then do
    n=stream(tmp,"c","query size")
    if datatype(n,"N") then d["text"]=charin(tmp,1,n)
    d["available"]=.true
  end
  call stream tmp,"c","close"; call SysFileDelete tmp
  return d
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::class EvacManifestEntry public
::attribute objectId get
::attribute relativePath get
::attribute generation get
::attribute metadata get
::attribute extendedMetadata get
::attribute contentSha256
::attribute objectState
::attribute lastError
::attribute replicas get
::attribute consistencyClass
::attribute consistencyEvidence
::method init
  expose objectId relativePath generation metadata extendedMetadata contentSha256 objectState lastError replicas consistencyClass consistencyEvidence
  use arg idArg,pathArg,generationArg,metadataArg,extendedArg=.nil
  objectId=idArg~string; relativePath=pathArg~string; generation=generationArg+0
  metadata=metadataArg; extendedMetadata=extendedArg
  contentSha256=""; objectState=.EvacObjectState~DISCOVERED; lastError=""; replicas=.directory~new
  consistencyClass=.EvacConsistencyClass~UNKNOWN; consistencyEvidence=""
::method addReplica
  expose replicas
  use arg replica
  replicas[replica~replicaId]=replica
  return replica
::method verifiedCurrentCount
  expose replicas
  n=0
  do k over replicas
    if replicas[k]~state=.EvacReplicaState~VERIFIED_CURRENT then n+=1
  end
  return n

::class EvacReplicaRecord public
::attribute replicaId get
::attribute destinationRef get
::attribute state
::attribute bytesCommitted
::attribute verificationRef
::attribute lastError
::attribute verifiedAt
::method init
  expose replicaId destinationRef state bytesCommitted verificationRef lastError verifiedAt
  use arg idArg,destinationArg
  replicaId=idArg~string; destinationRef=destinationArg~string
  state=.EvacReplicaState~PLANNED; bytesCommitted=0; verificationRef=""; lastError=""; verifiedAt=""

::class EvacGeneration public
::attribute number get
::attribute root get
::attribute createdAt get
::attribute entries get
::attribute sealed
::method init
  expose number root createdAt entries sealed
  use arg numberArg,rootArg
  number=numberArg+0; root=rootArg~string; createdAt=date("S")||"T"||time("L")
  entries=.directory~new; sealed=.false
::method put
  expose entries
  use arg entry
  entries[entry~relativePath]=entry
  return entry
::method count
  expose entries
  return entries~items
::method outstandingCount
  expose entries
  n=0
  do p over entries
    e=entries[p]
    if e~objectState=.EvacObjectState~EXCLUDED then iterate
    if e~verifiedCurrentCount=0 then do; n+=1; iterate; end
    if e~metadata~type="regular file" & e~consistencyClass=.EvacConsistencyClass~UNKNOWN then n+=1
  end
  return n
::method errorCount
  expose entries
  n=0
  do p over entries
    if entries[p]~objectState=.EvacObjectState~ERROR then n+=1
  end
  return n
::method dirtyCount
  expose entries
  n=0
  do p over entries
    if entries[p]~objectState=.EvacObjectState~DIRTY then n+=1
  end
  return n
::method equivalentInventory
  expose entries root
  use arg other
  if other==.nil then return .false
  if root<>other~root | entries~items<>other~entries~items then return .false
  do p over entries
    if \other~entries~hasIndex(p) then return .false
    a=entries[p]; b=other~entries[p]
    if \a~metadata~sameSourceVersion(b~metadata) then return .false
    if a~metadata~symlinkTarget<>b~metadata~symlinkTarget then return .false
  end
  return .true
::method seal
  expose sealed
  if self~outstandingCount<>0 | self~errorCount<>0 | self~dirtyCount<>0 then return .false
  sealed=.true
  return .true

::class EvacInventory public
::attribute metadataProbe get
::attribute extendedProbe get
::method init
  expose metadataProbe extendedProbe posix
  metadataProbe=.EvacPosixMetadataProbe~new; extendedProbe=.EvacPosixExtendedMetadataProbe~new
  posix=.PosixGapFactory~create
::method scan
  expose metadataProbe extendedProbe
  use arg rootArg,generationArg,captureExtendedArg=.true
  root=self~canonicalRoot(rootArg)
  if root="" then raise syntax 88.900 array("inventory root is unavailable",rootArg)
  generation=.EvacGeneration~new(generationArg,root)
  self~walk(root,"",generation,generationArg,captureExtendedArg)
  return generation
::method walk private
  expose metadataProbe extendedProbe posix
  use arg root,relBase,generation,generationArg,captureExtendedArg
  here=root
  if relBase<>"" then here=self~join(root,relBase)
  lr=posix~listDirectory(here,.false)
  if \lr~ok then raise syntax 88.900 array("POSIX directory iteration failed",here,lr~error~string)
  do name over lr~value~entries
    rel=name~string
    if relBase<>"" then rel=relBase||"/"||rel
    path=self~join(root,rel)
    m=metadataProbe~probe(path)
    if m==.nil then raise syntax 88.900 array("coherent POSIX lstat unavailable",path)
    id="posix:"||m~device||":"||m~inode||":"||generationArg
    x=.nil
    if captureExtendedArg==.true then x=extendedProbe~probe(path)
    generation~put(.EvacManifestEntry~new(id,rel,generationArg,m,x))
    if m~type="directory" then self~walk(root,rel,generation,generationArg,captureExtendedArg)
  end
::method join private
  use arg rootArg,relArg
  r=rootArg~string; if right(r,1)="/" then r=left(r,length(r)-1)
  return r||"/"||relArg~string
::method canonicalRoot private
  use arg rootArg
  /* POSIX v0.1-dev1 does not yet expose realpath(3).  Keep this one isolated
   * compatibility seam; it is not used for metadata/generation authority. */
  tmp=SysTempFileName("/tmp/oorexx-evac-root-??????")
  address system "/usr/bin/realpath -e -- "||self~shellQuote(rootArg~string)||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  if rc<>0 then do; call SysFileDelete tmp; return ""; end
  root=linein(tmp); call stream tmp,"c","close"; call SysFileDelete tmp
  return root~strip
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

/* Durable, line-oriented manifest codec.  Text is hex encoded so legal POSIX
 * pathname bytes (except NUL, which POSIX forbids) and multiline ACL/xattr
 * evidence survive round trips without depending on a JSON package. */
::class EvacManifestStore public
::method save
  use arg generation,pathArg
  tmp=pathArg||".tmp"
  call SysFileDelete tmp
  call lineout tmp,"EVAC4"||d2c(9)||generation~number||d2c(9)||self~enc(generation~root)||d2c(9)||self~enc(generation~createdAt)||d2c(9)||generation~sealed
  do p over generation~entries
    e=generation~entries[p]; m=e~metadata; x=e~extendedMetadata
    acl=""; xa=""; aclOk=0; xaOk=0
    if x<>.nil then do
      acl=x~aclText; xa=x~xattrText
      if x~aclAvailable then aclOk=1
      if x~xattrAvailable then xaOk=1
    end
    line="E"||d2c(9)||self~enc(e~objectId)||d2c(9)||self~enc(e~relativePath)||d2c(9)||self~enc(m~type)||d2c(9)||self~enc(m~modeOctal)||d2c(9)||m~uid||d2c(9)||m~gid||d2c(9)||m~sizeBytes||d2c(9)||self~enc(m~mtimeEpoch)||d2c(9)||self~enc(m~atimeEpoch)||d2c(9)||self~enc(m~ctimeEpoch)||d2c(9)||self~enc(m~device)||d2c(9)||self~enc(m~inode)||d2c(9)||m~nlink||d2c(9)||self~enc(m~symlinkTarget)||d2c(9)||self~enc(m~versionToken)||d2c(9)||self~enc(e~contentSha256)||d2c(9)||self~enc(e~objectState)||d2c(9)||self~enc(e~lastError)||d2c(9)||self~enc(e~consistencyClass)||d2c(9)||self~enc(e~consistencyEvidence)||d2c(9)||aclOk||d2c(9)||xaOk||d2c(9)||self~enc(acl)||d2c(9)||self~enc(xa)
    call lineout tmp,line
    do rid over e~replicas
      r=e~replicas[rid]
      call lineout tmp,"R"||d2c(9)||self~enc(e~relativePath)||d2c(9)||self~enc(r~replicaId)||d2c(9)||self~enc(r~destinationRef)||d2c(9)||self~enc(r~state)||d2c(9)||r~bytesCommitted||d2c(9)||self~enc(r~verificationRef)||d2c(9)||self~enc(r~lastError)||d2c(9)||self~enc(r~verifiedAt)
    end
  end
  call stream tmp,"c","close"
  address system "/bin/mv -f -- "||self~shellQuote(tmp)||" "||self~shellQuote(pathArg)
  if rc<>0 then raise syntax 88.900 array("manifest atomic replace failed",pathArg)
  return pathArg
::method load
  use arg pathArg
  if stream(pathArg,"c","query exists")="" then return .nil
  header=linein(pathArg)
  parse var header magic (d2c(9)) number (d2c(9)) rootHex (d2c(9)) createdHex (d2c(9)) sealed
  if magic<>"EVAC4" then do; call stream pathArg,"c","close"; raise syntax 88.900 array("unsupported evacuation manifest",magic); end
  g=.EvacGeneration~new(number,self~dec(rootHex))
  do while lines(pathArg)>0
    line=linein(pathArg); if line="" then iterate
    kind=left(line,1)
    if kind="E" then do
      parse var line . (d2c(9)) idh (d2c(9)) ph (d2c(9)) th (d2c(9)) mh (d2c(9)) uid (d2c(9)) gid (d2c(9)) size (d2c(9)) mtimeh (d2c(9)) atimeh (d2c(9)) ctimeh (d2c(9)) devh (d2c(9)) inoh (d2c(9)) nlink (d2c(9)) targeth (d2c(9)) tokenh (d2c(9)) digesth (d2c(9)) stateh (d2c(9)) errorh (d2c(9)) consistencyh (d2c(9)) evidenceh (d2c(9)) aclOk (d2c(9)) xaOk (d2c(9)) aclh (d2c(9)) xah
      m=.EvacPosixMetadata~new(self~dec(ph),self~dec(th),self~dec(mh),uid,gid,size,self~dec(mtimeh),self~dec(atimeh),self~dec(ctimeh),self~dec(devh),self~dec(inoh),nlink,self~dec(targeth),self~dec(tokenh))
      x=.EvacPosixExtendedMetadata~new(self~dec(aclh),self~dec(xah),aclOk=1,xaOk=1)
      e=.EvacManifestEntry~new(self~dec(idh),self~dec(ph),number,m,x)
      e~contentSha256=self~dec(digesth); e~objectState=self~dec(stateh); e~lastError=self~dec(errorh)
      e~consistencyClass=self~dec(consistencyh); e~consistencyEvidence=self~dec(evidenceh)
      g~put(e)
    end
    else if kind="R" then do
      parse var line . (d2c(9)) ph (d2c(9)) ridh (d2c(9)) desth (d2c(9)) stateh (d2c(9)) bytes (d2c(9)) verifyh (d2c(9)) errorh (d2c(9)) timeh
      path=self~dec(ph)
      if g~entries~hasIndex(path) then do
        r=.EvacReplicaRecord~new(self~dec(ridh),self~dec(desth)); r~state=self~dec(stateh); r~bytesCommitted=bytes+0; r~verificationRef=self~dec(verifyh); r~lastError=self~dec(errorh); r~verifiedAt=self~dec(timeh)
        g~entries[path]~addReplica(r)
      end
    end
  end
  call stream pathArg,"c","close"
  if sealed=1 then if g~outstandingCount=0 & g~errorCount=0 & g~dirtyCount=0 then g~seal
  return g
::method enc private
  use arg v
  if v==.nil then return ""
  return c2x(v~string)
::method dec private
  use arg v
  if v="" then return ""
  return x2c(v)
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

/* Reconstructs filesystem metadata objects at a local replica.  It is
 * intentionally separate from byte transport.  Applying metadata is followed
 * by an independent stat/link verification rather than trusting command rc. */
::class EvacLocalMetadataMaterializer public
::attribute probe get
::method init
  expose probe
  probe=.EvacPosixMetadataProbe~new
::method materializeNonRegular
  expose probe
  use arg generation,destinationRoot
  /* Directories first so children have somewhere to land. */
  do p over generation~entries
    e=generation~entries[p]
    if e~metadata~type="directory" then self~ensureDirectory(e,destinationRoot)
  end
  /* Symlinks next. Other special objects fail closed until explicitly added. */
  do p over generation~entries
    e=generation~entries[p]
    t=e~metadata~type
    if t="symbolic link" then self~ensureSymlink(e,destinationRoot)
    else if t<>"directory" & t<>"regular file" then do
      e~objectState=.EvacObjectState~ERROR; e~lastError="UNSUPPORTED_OBJECT_TYPE:"||t
    end
  end
  return 0
::method reconcileHardLinks
  use arg generation,destinationRoot
  primaries=.directory~new
  do p over generation~entries
    e=generation~entries[p]; m=e~metadata
    if m~type<>"regular file" | m~nlink<2 then iterate
    key=m~hardLinkKey
    if \primaries~hasIndex(key) then primaries[key]=e~relativePath
    else do
      primary=primaries[key]
      if primary<>e~relativePath then self~hardLinkReplica(generation~entries[primary],e,destinationRoot)
    end
  end
  return 0
::method applyAndVerifyMetadata
  expose probe
  use arg generation,destinationRoot
  /* Files first, directories last because child creation mutates directory mtime. */
  do p over generation~entries
    e=generation~entries[p]
    if e~metadata~type<>"directory" then self~applyOne(e,destinationRoot)
  end
  paths=.array~new
  do p over generation~entries
    if generation~entries[p]~metadata~type="directory" then paths~append(p)
  end
  /* Reverse lexical order is sufficient for the qualifier; every directory is
   * touched only after all file creation has ceased. */
  arr=paths~makeArray
  do i=arr~items to 1 by -1
    self~applyOne(generation~entries[arr[i]],destinationRoot)
  end
  return 0
::method ensureDirectory private
  use arg e,root
  dst=self~join(root,e~relativePath)
  address system "/bin/mkdir -p -- "||self~shellQuote(dst)
  if rc<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="MKDIR_FAILED"; return; end
  self~markMetadataReplica(e,dst)
::method ensureSymlink private
  use arg e,root
  dst=self~join(root,e~relativePath); parent=self~parent(dst)
  address system "/bin/mkdir -p -- "||self~shellQuote(parent)
  address system "/bin/rm -f -- "||self~shellQuote(dst)
  address system "/bin/ln -s -- "||self~shellQuote(e~metadata~symlinkTarget)||" "||self~shellQuote(dst)
  if rc<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="SYMLINK_CREATE_FAILED"; return; end
  self~markMetadataReplica(e,dst)
::method hardLinkReplica private
  use arg primary,entry,root
  src=self~join(root,primary~relativePath); dst=self~join(root,entry~relativePath)
  if stream(src,"c","query exists")="" then do; entry~objectState=.EvacObjectState~ERROR; entry~lastError="HARDLINK_PRIMARY_MISSING"; return; end
  address system "/bin/rm -f -- "||self~shellQuote(dst)
  address system "/bin/ln -- "||self~shellQuote(src)||" "||self~shellQuote(dst)
  if rc<>0 then do; entry~objectState=.EvacObjectState~ERROR; entry~lastError="HARDLINK_CREATE_FAILED"; return; end
  pm=.EvacPosixMetadataProbe~new~probe(src); dm=.EvacPosixMetadataProbe~new~probe(dst)
  if pm==.nil | dm==.nil | pm~device<>dm~device | pm~inode<>dm~inode then do; entry~objectState=.EvacObjectState~ERROR; entry~lastError="HARDLINK_VERIFY_FAILED"; return; end
  r=.EvacReplicaRecord~new("local:"||dst,dst); r~state=.EvacReplicaState~VERIFIED_CURRENT; r~bytesCommitted=entry~metadata~sizeBytes; r~verificationRef=primary~contentSha256; r~verifiedAt=date("S")||"T"||time("L")
  entry~addReplica(r); entry~contentSha256=primary~contentSha256; entry~objectState=.EvacObjectState~CURRENT
::method applyOne private
  expose probe
  use arg e,root
  if e~objectState=.EvacObjectState~ERROR then return
  dst=self~join(root,e~relativePath); m=e~metadata
  if m~type="symbolic link" then do
    address system "/bin/chown -h -- "||m~uid||":"||m~gid||" "||self~shellQuote(dst)||" 2>/dev/null"
    address system "/usr/bin/touch -h -a -d @"||m~atimeEpoch||" -- "||self~shellQuote(dst)||" 2>/dev/null"
    address system "/usr/bin/touch -h -m -d @"||m~mtimeEpoch||" -- "||self~shellQuote(dst)||" 2>/dev/null"
  end
  else do
    address system "/bin/chmod -- "||m~modeOctal||" "||self~shellQuote(dst)||" 2>/dev/null"
    address system "/bin/chown -- "||m~uid||":"||m~gid||" "||self~shellQuote(dst)||" 2>/dev/null"
    address system "/usr/bin/touch -a -d @"||m~atimeEpoch||" -- "||self~shellQuote(dst)||" 2>/dev/null"
    address system "/usr/bin/touch -m -d @"||m~mtimeEpoch||" -- "||self~shellQuote(dst)||" 2>/dev/null"
  end
  if \self~applyExtended(e,dst) then return
  got=probe~probe(dst)
  if got==.nil then do; e~objectState=.EvacObjectState~ERROR; e~lastError="METADATA_TARGET_MISSING"; return; end
  if got~type<>m~type | got~uid<>m~uid | got~gid<>m~gid then do; e~objectState=.EvacObjectState~ERROR; e~lastError="METADATA_IDENTITY_MISMATCH"; return; end
  if m~type<>"symbolic link" & got~modeOctal<>m~modeOctal then do; e~objectState=.EvacObjectState~ERROR; e~lastError="MODE_MISMATCH"; return; end
  if m~type="symbolic link" & got~symlinkTarget<>m~symlinkTarget then do; e~objectState=.EvacObjectState~ERROR; e~lastError="SYMLINK_TARGET_MISMATCH"; return; end
  if got~mtimeEpoch<>m~mtimeEpoch then do; e~objectState=.EvacObjectState~ERROR; e~lastError="MTIME_MISMATCH"; return; end
  if m~type<>"regular file" then self~markMetadataReplica(e,dst)
::method applyExtended private
  use arg e,dst
  x=e~extendedMetadata
  if x==.nil then return .true
  if x~aclAvailable then do
    address system "test -x /usr/bin/setfacl"
    if rc<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="SETFACL_UNAVAILABLE"; return .false; end
    tmp=SysTempFileName("/tmp/oorexx-evac-acl-??????")
    call charout tmp,x~aclText; call stream tmp,"c","close"
    address system "/usr/bin/setfacl -M "||self~shellQuote(tmp)||" -- "||self~shellQuote(dst)||" 2>/dev/null"
    result=rc; call SysFileDelete tmp
    if result<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="ACL_RESTORE_FAILED"; return .false; end
  end
  if x~xattrAvailable then do
    address system "test -x /usr/bin/setfattr"
    if rc<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="SETFATTR_UNAVAILABLE"; return .false; end
    body=x~xattrText; nl=d2c(10); start=1
    do while start<=length(body)
      stop=pos(nl,body,start); if stop=0 then stop=length(body)+1
      line=substr(body,start,stop-start); start=stop+1
      line=line~strip
      if line="" | left(line,1)="#" then iterate
      eq=pos("=",line); if eq=0 then iterate
      name=left(line,eq-1); value=substr(line,eq+1)
      address system "/usr/bin/setfattr -n "||self~shellQuote(name)||" -v "||self~shellQuote(value)||" -- "||self~shellQuote(dst)||" 2>/dev/null"
      if rc<>0 then do; e~objectState=.EvacObjectState~ERROR; e~lastError="XATTR_RESTORE_FAILED:"||name; return .false; end
    end
  end
  if x~aclAvailable | x~xattrAvailable then do
    got=.EvacPosixExtendedMetadataProbe~new~probe(dst)
    if x~aclAvailable then if \got~aclAvailable | got~aclText<>x~aclText then do; e~objectState=.EvacObjectState~ERROR; e~lastError="ACL_VERIFY_FAILED"; return .false; end
    if x~xattrAvailable then if \got~xattrAvailable | got~xattrText<>x~xattrText then do; e~objectState=.EvacObjectState~ERROR; e~lastError="XATTR_VERIFY_FAILED"; return .false; end
  end
  return .true
::method markMetadataReplica private
  use arg e,dst
  rid="local:"||dst
  if e~replicas~hasIndex(rid) then r=e~replicas[rid]; else do; r=.EvacReplicaRecord~new(rid,dst); e~addReplica(r); end
  r~state=.EvacReplicaState~VERIFIED_CURRENT; r~verificationRef="metadata:"||e~metadata~statFingerprint; r~verifiedAt=date("S")||"T"||time("L")
  e~objectState=.EvacObjectState~CURRENT
::method join private
  use arg root,path
  r=root~string; if right(r,1)="/" then r=left(r,length(r)-1)
  return r||"/"||path
::method parent private
  use arg path
  p=lastpos("/",path); if p<=1 then return "/"
  return left(path,p-1)
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

/* Linux source-use observer. This is deliberately evidence, not an application
 * consistency oracle. It scans /proc/<pid>/fd and /proc/<pid>/maps without
 * requiring lsof/fuser. Any foreign open descriptor or mapping blocks ordinary
 * file dispatch. Writer evidence is retained separately for diagnosis. */
::class EvacSourceUseEvidence public
::attribute inUse get
::attribute writerSeen get
::attribute holders get
::attribute observedAt get
::method init
  expose inUse writerSeen holders observedAt
  use arg inUseArg=.false,writerArg=.false,holdersArg=""
  inUse=(inUseArg==.true); writerSeen=(writerArg==.true); holders=holdersArg~string
  observedAt=date("S")||"T"||time("L")
::method summary
  expose inUse writerSeen holders observedAt
  return "inUse="||inUse||";writer="||writerSeen||";holders="||holders||";at="||observedAt

::class EvacLinuxSourceUseProbe public
::method inspect
  use arg pathArg
  target=self~canonical(pathArg)
  if target="" then return .EvacSourceUseEvidence~new(.true,.true,"SOURCE_UNAVAILABLE")
  tmp=SysTempFileName("/tmp/oorexx-evac-use-??????")
  script="import os,sys\n"||,
    "target=os.path.realpath(sys.argv[1]); me=os.getpid(); out=[]; writer=False\n"||,
    "for name in os.listdir('/proc'):\n"||,
    "  if not name.isdigit(): continue\n"||,
    "  pid=int(name)\n"||,
    "  try:\n"||,
    "    comm=open('/proc/%s/comm'%name).read().strip()\n"||,
    "    fdroot='/proc/%s/fd'%name\n"||,
    "    for fd in os.listdir(fdroot):\n"||,
    "      try:\n"||,
    "        link=os.readlink(fdroot+'/'+fd)\n"||,
    "        clean=link[:-10] if link.endswith(' (deleted)') else link\n"||,
    "        if os.path.realpath(clean)!=target: continue\n"||,
    "        flags=int(open('/proc/%s/fdinfo/%s'%(name,fd)).read().split('flags:')[1].split()[0],8)\n"||,
    "        wr=(flags & 3)!=0; writer=writer or wr; out.append('%s:%s:fd%s:%s'%(name,comm,fd,'W' if wr else 'R'))\n"||,
    "      except Exception: pass\n"||,
    "    try:\n"||,
    "      for line in open('/proc/%s/maps'%name,errors='replace'):\n"||,
    "        parts=line.rstrip().split(None,5)\n"||,
    "        if len(parts)<6: continue\n"||,
    "        clean=parts[5][:-10] if parts[5].endswith(' (deleted)') else parts[5]\n"||,
    "        if os.path.realpath(clean)==target:\n"||,
    "          wr='w' in parts[1]; writer=writer or wr; out.append('%s:%s:mmap:%s'%(name,comm,'W' if wr else 'R'))\n"||,
    "    except Exception: pass\n"||,
    "  except Exception: pass\n"||,
    "print('1' if out else '0'); print('1' if writer else '0'); print('|'.join(sorted(set(out))))\n"
  script=changestr("\n",script,d2c(10))
  py=SysTempFileName("/tmp/oorexx-evac-usepy-??????")
  call charout py,script; call stream py,"c","close"
  address system "/usr/bin/python3 "||self~shellQuote(py)||" "||self~shellQuote(target)||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  r=rc; call SysFileDelete py
  if r<>0 then do; call SysFileDelete tmp; return .EvacSourceUseEvidence~new(.true,.true,"PROBE_FAILED"); end
  used=linein(tmp); writer=linein(tmp); holders=linein(tmp); call stream tmp,"c","close"; call SysFileDelete tmp
  return .EvacSourceUseEvidence~new(used=1,writer=1,holders)
::method canonical private
  use arg pathArg
  tmp=SysTempFileName("/tmp/oorexx-evac-usepath-??????")
  address system "/usr/bin/realpath -e -- "||self~shellQuote(pathArg~string)||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  if rc<>0 then do; call SysFileDelete tmp; return ""; end
  v=linein(tmp); call stream tmp,"c","close"; call SysFileDelete tmp; return v~strip
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::class EvacOrdinaryFileConsistencyProvider public
::attribute probe get
::attribute quietSeconds get
::method init
  expose probe quietSeconds
  use arg quietArg=1
  probe=.EvacLinuxSourceUseProbe~new; quietSeconds=quietArg+0
::method acquire
  expose probe quietSeconds
  use arg entry,sourcePath
  first=probe~inspect(sourcePath)
  if first~inUse then return first
  before=.EvacPosixMetadataProbe~new~probe(sourcePath)
  if quietSeconds>0 then call SysSleep quietSeconds
  second=probe~inspect(sourcePath)
  after=.EvacPosixMetadataProbe~new~probe(sourcePath)
  if second~inUse then return second
  if before==.nil | after==.nil | \before~sameSourceVersion(after) then return .EvacSourceUseEvidence~new(.true,.true,"CHANGED_DURING_QUIET_WINDOW")
  return second

/* Shared aggregate byte-rate authority.  The governor is transport-neutral:
 * any byte source can be wrapped, so USB may use unlimited while network
 * replicas share a bounded rate.  Rate is bytes/second; <=0 means unlimited. */
::class EvacBandwidthGovernor public
::attribute bytesPerSecond get
::method init
  expose bytesPerSecond started transferred
  use arg rateArg=0
  bytesPerSecond=rateArg+0; started=time("E"); transferred=0
::method account
  expose bytesPerSecond started transferred
  use arg bytesArg
  if bytesPerSecond<=0 then return 0
  transferred += bytesArg+0
  elapsed=time("E")-started
  target=transferred/bytesPerSecond
  delay=target-elapsed
  if delay>0 then call SysSleep delay
  return delay

::class EvacGovernedByteSource subclass StorageByteSource public
::attribute sizeBytes get
::method init
  expose delegate governor sizeBytes
  use strict arg delegateArg, governorArg
  delegate=delegateArg; governor=governorArg; sizeBytes=delegate~sizeBytes
::method resumeIdentity
  expose delegate
  return delegate~resumeIdentity
::method verificationPath
  expose delegate
  return delegate~verificationPath
::method openAt
  expose delegate
  use strict arg offset
  return delegate~openAt(offset)
::method readChunk
  expose delegate governor
  use strict arg maxBytes
  c=delegate~readChunk(maxBytes)
  if c~data~length>0 then governor~account(c~data~length)
  return c
::method close
  expose delegate
  return delegate~close

/* Executes a regular-file replica using Storage Fabric's bounded-memory
 * transfer engine and independent SHA-256 verifier. */
::class EvacLocalReplicaExecutor public
::attribute chunkBytes get
::method init
  expose chunkBytes governor consistencyProvider
  use arg chunkArg=8388608, governorArg=.nil, consistencyArg=.nil
  chunkBytes=chunkArg+0; governor=governorArg
  if consistencyArg==.nil then consistencyProvider=.EvacOrdinaryFileConsistencyProvider~new; else consistencyProvider=consistencyArg
::method transfer
  expose chunkBytes governor consistencyProvider
  use arg entry, sourceRootArg, destinationRootArg, checkpointRootArg
  sourcePath=self~join(sourceRootArg,entry~relativePath)
  destinationPath=self~join(destinationRootArg,entry~relativePath)
  if entry~metadata~type<>"regular file" then return .nil
  useEvidence=consistencyProvider~acquire(entry,sourcePath)
  entry~consistencyEvidence=useEvidence~summary
  if useEvidence~inUse then do
    entry~consistencyClass=.EvacConsistencyClass~UNKNOWN
    entry~objectState=.EvacObjectState~WAITING_FOR_QUIESCENCE
    entry~lastError="SOURCE_IN_USE:"||useEvidence~holders
    return .nil
  end
  entry~consistencyClass=.EvacConsistencyClass~OBSERVED_QUIESCENT
  /* Fence dispatch against the inventory generation.  Never copy newer bytes
   * under an older manifest identity. */
  before=.EvacPosixMetadataProbe~new~probe(sourcePath)
  if before==.nil | \entry~metadata~sameSourceVersion(before) then do
    entry~objectState=.EvacObjectState~DIRTY
    entry~lastError="SOURCE_CHANGED_BEFORE_TRANSFER"
    return .nil
  end
  self~ensureParent(destinationPath)
  replicaId="local:"||destinationPath
  replica=.EvacReplicaRecord~new(replicaId,destinationPath); entry~addReplica(replica)
  source=.StorageLocalFileByteSource~new(sourcePath)
  if governor\=.nil then source=.EvacGovernedByteSource~new(source,governor)
  ref=.StorageRef~new(entry~objectId)
  loc=.StorageLocation~new("evac-source",sourcePath,"",.StorageLocationState~AVAILABLE)
  transfer=.StorageTransfer~new("evac:"||entry~generation||":"||entry~objectId||":"||destinationPath,ref,loc,"evac-local",destinationPath,source~sizeBytes)
  replica~state=.EvacReplicaState~COPYING
  engine=.StorageResumableTransferEngine~new(chunkBytes)
  cp=checkpointRootArg||"/"||self~safeName(entry~objectId||"|"||destinationPath)
  runResult=engine~copy(transfer,source,.StorageLocalFileByteSink~new(destinationPath),cp,0,.StoragePosixSha256Verifier~new)
  replica~bytesCommitted=runResult~bytesTransferred
  if runResult~status<>.StorageTransferRunStatus~COMPLETED | runResult~verificationRef="" then do
    replica~state=.EvacReplicaState~FAILED; replica~lastError=runResult~failure
    entry~objectState=.EvacObjectState~ERROR; entry~lastError=runResult~failure
    return replica
  end
  replica~state=.EvacReplicaState~VERIFIED; replica~verificationRef=runResult~verificationRef
  entry~contentSha256=self~digestFromVerification(runResult~verificationRef)
  /* Re-probe source after destination verification. */
  current=.EvacPosixMetadataProbe~new~probe(sourcePath)
  afterUse=consistencyProvider~probe~inspect(sourcePath)
  entry~consistencyEvidence=entry~consistencyEvidence||";post="||afterUse~summary
  if entry~metadata~sameSourceVersion(current) & \afterUse~inUse then do
    replica~state=.EvacReplicaState~VERIFIED_CURRENT
    entry~objectState=.EvacObjectState~CURRENT
  end
  else do
    replica~state=.EvacReplicaState~VERIFIED_OLD_GENERATION
    entry~objectState=.EvacObjectState~DIRTY
  end
  replica~verifiedAt=date("S")||"T"||time("L")
  return replica
::method digestFromVerification private
  use arg value
  p=pos("sha256:",value~lower)
  if p=0 then return value
  return substr(value,p+7,64)
::method ensureParent private
  use arg path
  p=lastpos("/",path)
  if p<=1 then return
  parent=left(path,p-1)
  address system "/bin/mkdir -p -- "||self~shellQuote(parent)
  if rc<>0 then raise syntax 88.900 array("cannot create destination parent",parent)
::method join private
  use arg root,path
  r=root~string
  if right(r,1)="/" then r=left(r,length(r)-1)
  return r||"/"||path
::method safeName private
  use arg value
  /* checkpoint names need not be reversible; SHA-256 gives stable identity. */
  tmp=SysTempFileName("/tmp/oorexx-evac-name-??????")
  call charout tmp,value; call stream tmp,"c","close"
  out=SysTempFileName("/tmp/oorexx-evac-nameout-??????")
  address system "/usr/bin/sha256sum -- "||self~shellQuote(tmp)||" > "||self~shellQuote(out)
  line=linein(out); call stream out,"c","close"; call SysFileDelete tmp; call SysFileDelete out
  return word(line,1)
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

/* Convergence authority.  Transports remain below this layer. */
::class EvacConvergenceController public
::attribute inventory get
::attribute executor get
::attribute materializer get
::attribute manifestStore get
::method init
  expose inventory executor materializer manifestStore
  inventory=.EvacInventory~new; executor=.EvacLocalReplicaExecutor~new
  materializer=.EvacLocalMetadataMaterializer~new; manifestStore=.EvacManifestStore~new
::method evacuateGeneration
  expose executor materializer
  use arg generation,destinationRoot,checkpointRoot
  copied=0; failed=0
  materializer~materializeNonRegular(generation,destinationRoot)
  do path over generation~entries
    e=generation~entries[path]
    if e~metadata~type="regular file" then do
      r=executor~transfer(e,generation~root,destinationRoot,checkpointRoot)
      if r<>.nil & r~state=.EvacReplicaState~VERIFIED_CURRENT then copied+=1
      else failed+=1
    end
  end
  materializer~reconcileHardLinks(generation,destinationRoot)
  materializer~applyAndVerifyMetadata(generation,destinationRoot)
  d=.directory~new
  d["verifiedCurrent"]=copied; d["failed"]=failed; d["outstanding"]=generation~outstandingCount; d["errors"]=generation~errorCount
  return d
::method evacuateRegularFiles
  /* Compatibility alias retained from dev1. */
  use arg generation,destinationRoot,checkpointRoot
  return self~evacuateGeneration(generation,destinationRoot,checkpointRoot)
::method carryForwardVerified
  use arg previous,current
  do p over current~entries
    if \previous~entries~hasIndex(p) then iterate
    old=previous~entries[p]; now=current~entries[p]
    if \old~metadata~sameSourceVersion(now~metadata) then iterate
    if old~metadata~symlinkTarget<>now~metadata~symlinkTarget then iterate
    if old~verifiedCurrentCount=0 then iterate
    now~contentSha256=old~contentSha256; now~objectState=.EvacObjectState~CURRENT
    now~consistencyClass=old~consistencyClass; now~consistencyEvidence=old~consistencyEvidence
    do rid over old~replicas
      r=old~replicas[rid]
      if r~state=.EvacReplicaState~VERIFIED_CURRENT then now~addReplica(r)
    end
  end
  return current
::method sealStablePair
  use arg previous,current
  if previous==.nil | current==.nil then return .false
  if \previous~equivalentInventory(current) then return .false
  self~carryForwardVerified(previous,current)
  if current~outstandingCount<>0 | current~errorCount<>0 | current~dirtyCount<>0 then return .false
  return current~seal

::requires "vendor/storage_fabric/StorageStreaming.cls"

/* dev5: multi-object consistency authority.  A lease is deliberately separate
 * from content verification: it states why a set of source objects may be
 * captured as one recoverable epoch. */
::class EvacConsistencyLease public
::attribute leaseId get
::attribute groupId get
::attribute consistencyClass get
::attribute evidence get
::attribute sourceRoot get
::attribute acquiredAt get
::attribute active
::method init
  expose leaseId groupId consistencyClass evidence sourceRoot acquiredAt active
  use arg leaseArg,groupArg,classArg,evidenceArg,rootArg=""
  leaseId=leaseArg~string; groupId=groupArg~string; consistencyClass=classArg~string
  evidence=evidenceArg~string; sourceRoot=rootArg~string
  acquiredAt=date("S")||"T"||time("L"); active=.true
::method release
  expose active
  active=.false; return .true

::class EvacConsistencyGroup public
::attribute groupId get
::attribute memberPaths get
::attribute requiredClass get
::method init
  expose groupId memberPaths requiredClass
  use arg idArg,pathsArg,classArg
  if arg() < 3 then classArg=.EvacConsistencyClass~APPLICATION_CONSISTENT
  groupId=idArg~string; memberPaths=pathsArg; requiredClass=classArg~string
::method contains
  expose memberPaths
  use arg pathArg
  do p over memberPaths
    if p~string==pathArg~string then return .true
  end
  return .false
::method validateGeneration
  expose memberPaths
  use arg generation
  do p over memberPaths
    rel=p~string
    if \generation~entries~hasIndex(rel) then return .false
    if generation~entries[rel]~metadata~type<>"regular file" then return .false
  end
  return .true

/* Explicit application quiesce provider.  Commands are policy supplied, never
 * inferred.  Acquire command must return zero before a lease is issued; release
 * is always attempted by the group executor. */
::class EvacApplicationQuiesceProvider public
::attribute acquireCommand get
::attribute releaseCommand get
::method init
  expose acquireCommand releaseCommand
  use arg acquireArg,releaseArg
  acquireCommand=acquireArg~string; releaseCommand=releaseArg~string
::method acquire
  expose acquireCommand
  use arg group,sourceRoot
  if acquireCommand="" then return .nil
  address system acquireCommand
  if rc<>0 then return .nil
  return .EvacConsistencyLease~new("app:"||group~groupId||":"||time("L"),group~groupId,.EvacConsistencyClass~APPLICATION_CONSISTENT,"APPLICATION_QUIESCE_RC0",sourceRoot)
::method release
  expose releaseCommand
  use arg lease
  result=.true
  if releaseCommand<>"" then do
    address system releaseCommand
    if rc<>0 then result=.false
  end
  lease~release
  return result

/* Snapshot provider consumes an already-created immutable/read-only snapshot
 * root. Snapshot creation itself belongs to the filesystem/platform adapter.
 * The provider proves that every group member exists there before issuing the
 * lease and redirects reads to that stable root. */
::class EvacPreparedSnapshotProvider public
::attribute snapshotRoot get
::method init
  expose snapshotRoot
  use arg rootArg
  snapshotRoot=rootArg~string
::method acquire
  expose snapshotRoot
  use arg group,sourceRoot
  probe=.EvacPosixMetadataProbe~new
  do p over group~memberPaths
    rel=p~string
    if probe~probe(self~join(snapshotRoot,rel))==.nil then return .nil
  end
  return .EvacConsistencyLease~new("snapshot:"||group~groupId||":"||time("L"),group~groupId,.EvacConsistencyClass~SNAPSHOT_CONSISTENT,"PREPARED_SNAPSHOT:"||snapshotRoot,snapshotRoot)
::method release
  use arg lease
  return lease~release
::method join private
  use arg rootArg,relArg
  r=rootArg~string; if right(r,1)="/" then r=left(r,length(r)-1)
  return r||"/"||relArg~string

/* Executes all regular-file members while one group lease is active.  If any
 * member fails, the group is not promoted as consistent.  The ordinary-file
 * observer is intentionally bypassed only because the stronger provider owns
 * quiescence/snapshot authority for the whole group. */
::class EvacConsistencyGroupExecutor public
::method init
  expose chunkBytes governor
  use arg chunkArg=8388608,governorArg=.nil
  chunkBytes=chunkArg+0; governor=governorArg
::method transferGroup
  expose chunkBytes governor
  use arg group,generation,sourceRoot,destinationRoot,checkpointRoot,provider
  if \group~validateGeneration(generation) then return .false
  lease=provider~acquire(group,sourceRoot)
  if lease==.nil then do
    do p over group~memberPaths
      rel=p~string
      e=generation~entries[rel]; e~objectState=.EvacObjectState~WAITING_FOR_QUIESCENCE
      e~consistencyClass=.EvacConsistencyClass~UNKNOWN; e~consistencyEvidence="GROUP_LEASE_NOT_ACQUIRED:"||group~groupId
    end
    return .false
  end
  ok=.true
  readRoot=lease~sourceRoot; if readRoot="" then readRoot=sourceRoot
  /* For application quiesce, source identities must still be the inventoried
   * live identities. For snapshots, the snapshot itself is the fenced epoch. */
  do p over group~memberPaths
    rel=p~string; e=generation~entries[rel]
    if lease~consistencyClass=.EvacConsistencyClass~APPLICATION_CONSISTENT then do
      now=.EvacPosixMetadataProbe~new~probe(self~join(sourceRoot,rel))
      if now==.nil | \e~metadata~sameSourceVersion(now) then do
        e~objectState=.EvacObjectState~DIRTY; e~lastError="GROUP_SOURCE_CHANGED_BEFORE_CAPTURE"; ok=.false; leave
      end
    end
    /* A lease-aware pass-through provider prevents the ordinary open-file
     * observer from rejecting the application process that we deliberately
     * quiesced while retaining the stronger group evidence. */
    pass=.EvacLeaseConsistencyProvider~new(lease)
    ex=.EvacLocalReplicaExecutor~new(chunkBytes,governor,pass)
    rr=ex~transfer(e,readRoot,destinationRoot,checkpointRoot)
    if rr==.nil then do; ok=.false; leave; end
    if rr~state<>.EvacReplicaState~VERIFIED_CURRENT then do; ok=.false; leave; end
    e~consistencyClass=lease~consistencyClass
    e~consistencyEvidence=lease~evidence||";group="||group~groupId||";lease="||lease~leaseId
  end
  released=provider~release(lease)
  if \released then ok=.false
  if \ok then do
    do p over group~memberPaths
      rel=p~string; e=generation~entries[rel]
      if e~consistencyClass=lease~consistencyClass then e~consistencyClass=.EvacConsistencyClass~UNKNOWN
    end
  end
  return ok
::method join private
  use arg rootArg,relArg
  r=rootArg~string; if right(r,1)="/" then r=left(r,length(r)-1)
  return r||"/"||relArg~string

::class EvacLeaseConsistencyProvider public
::attribute probe get
::method init
  expose lease probe
  use arg leaseArg
  lease=leaseArg; probe=.EvacNeverInUseProbe~new
::method acquire
  expose lease
  use arg entry,sourcePath
  return .EvacSourceUseEvidence~new(.false,.false,"LEASE:"||lease~leaseId)

::class EvacNeverInUseProbe public
::method inspect
  use arg pathArg
  return .EvacSourceUseEvidence~new(.false,.false,"LEASE_AUTHORITY")

::requires "PosixGap.cls"

/* dev8: operational policy/session/reporting.  Domain-only; filesystem facts remain POSIX authority. */
::class EvacSelectionPolicy public
::attribute includePrefixes get
::attribute excludePrefixes get
::method init
  expose includePrefixes excludePrefixes
  includePrefixes=.Array~new; excludePrefixes=.Array~new
::method include
  expose includePrefixes
  use arg prefix
  includePrefixes~append(prefix~string); return self
::method exclude
  expose excludePrefixes
  use arg prefix
  excludePrefixes~append(prefix~string); return self
::method selected
  expose includePrefixes excludePrefixes
  use arg relArg
  rel=relArg~string
  do x over excludePrefixes
    if self~under(rel,x~string) then return .false
  end
  if includePrefixes~items=0 then return .true
  do x over includePrefixes
    if self~under(rel,x~string) then return .true
  end
  return .false
::method apply
  use arg generation
  do p over generation~entries
    e=generation~entries[p]
    if \self~selected(e~relativePath) then e~objectState=.EvacObjectState~EXCLUDED
  end
  return generation
::method under private
  use arg pathArg,prefixArg
  p=prefixArg~string
  if p="" | p="." then return .true
  if pathArg=p then return .true
  if right(p,1)<>"/" then p=p||"/"
  return left(pathArg,length(p))=p

::class EvacOperationalPolicy public
::attribute bandwidthBytesPerSec
::attribute concurrency
::attribute minVerifiedReplicas
::attribute selection get
::method init
  expose bandwidthBytesPerSec concurrency minVerifiedReplicas selection
  bandwidthBytesPerSec=0; concurrency=2; minVerifiedReplicas=1; selection=.EvacSelectionPolicy~new

::class EvacSession public
::attribute sessionId get
::attribute root get
::attribute destination get
::attribute manifestPath get
::attribute createdAt get
::attribute policy get
::method init
  expose sessionId root destination manifestPath createdAt policy
  use strict arg idArg,rootArg,destinationArg,manifestArg,policyArg
  sessionId=idArg~string; root=rootArg~string; destination=destinationArg~string; manifestPath=manifestArg~string; policy=policyArg
  createdAt=date("S")||"T"||time("L")
::method status
  expose sessionId
  use strict arg generation
  d=.directory~new; d["sessionId"]=sessionId; d["generation"]=generation~number; d["objects"]=generation~count
  d["outstanding"]=generation~outstandingCount; d["errors"]=generation~errorCount; d["dirty"]=generation~dirtyCount; d["sealed"]=generation~sealed
  verified=0; excluded=0; bytes=0; verifiedBytes=0
  do p over generation~entries
    e=generation~entries[p]
    if e~objectState=.EvacObjectState~EXCLUDED then excluded+=1
    if e~metadata~type="regular file" then bytes+=e~metadata~sizeBytes
    if e~verifiedCurrentCount>0 then do
      verified+=1
      if e~metadata~type="regular file" then verifiedBytes+=e~metadata~sizeBytes
    end
  end
  d["verifiedObjects"]=verified; d["excludedObjects"]=excluded; d["selectedBytes"]=bytes; d["verifiedBytes"]=verifiedBytes
  return d
::method renderStatus
  use strict arg generation
  s=self~status(generation)
  return "session="||s["sessionId"]||" generation="||s["generation"]||" objects="||s["objects"]||" verified="||s["verifiedObjects"]||" outstanding="||s["outstanding"]||" dirty="||s["dirty"]||" errors="||s["errors"]||" bytes="||s["verifiedBytes"]||"/"||s["selectedBytes"]||" sealed="||s["sealed"]

::class EvacDryRunReport public
::method render
  use strict arg generation,policy
  selected=0; excluded=0; bytes=0
  do p over generation~entries
    e=generation~entries[p]
    if policy~selection~selected(e~relativePath) then do; selected+=1; if e~metadata~type="regular file" then bytes+=e~metadata~sizeBytes; end
    else excluded+=1
  end
  return "generation="||generation~number||" selected="||selected||" excluded="||excluded||" selectedBytes="||bytes||" bandwidthBytesPerSec="||policy~bandwidthBytesPerSec||" concurrency="||policy~concurrency||" minVerifiedReplicas="||policy~minVerifiedReplicas
