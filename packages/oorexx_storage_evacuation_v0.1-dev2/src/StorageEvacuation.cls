/* ooRexx Storage Evacuation v0.1-dev2
 *
 * Durable generational evacuation/replication authority layered above Storage
 * Fabric.  Transport completion, replica verification and current-source
 * representation are deliberately distinct states.
 */

::class StorageEvacuationBuild public
::constant VERSION "0.1-dev2"
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
::method probe
  use arg pathArg
  path=pathArg~string
  if path="" then return .nil
  tmp=SysTempFileName("/tmp/oorexx-evac-stat-??????")
  qpath=self~shellQuote(path); qtmp=self~shellQuote(tmp)
  us=d2c(31)
  fmt="%F"||us||"%a"||us||"%u"||us||"%g"||us||"%s"||us||"%Y"||us||"%X"||us||"%Z"||us||"%d"||us||"%i"||us||"%h"||us||"%y"||us||"%z"
  address system "/usr/bin/stat --printf="||self~shellQuote(fmt)||" -- "||qpath||" > "||qtmp||" 2>/dev/null"
  result=rc
  if result<>0 then do; call SysFileDelete tmp; return .nil; end
  rec=charin(tmp,1,stream(tmp,"c","query size")); call stream tmp,"c","close"; call SysFileDelete tmp
  parse var rec type (us) mode (us) uid (us) gid (us) size (us) mtime (us) atime (us) ctime (us) dev (us) ino (us) nlink (us) mtimeFine (us) ctimeFine
  if type="" then return .nil
  target=""
  if type="symbolic link" then do
    tmp=SysTempFileName("/tmp/oorexx-evac-link-??????")
    address system "/usr/bin/readlink -- "||qpath||" > "||self~shellQuote(tmp)||" 2>/dev/null"
    if rc=0 then do
      target=charin(tmp,1,stream(tmp,"c","query size"))
      if right(target,1)=d2c(10) then target=left(target,length(target)-1)
    end
    call stream tmp,"c","close"; call SysFileDelete tmp
  end
  return .EvacPosixMetadata~new(path,type,mode,uid,gid,size,mtime,atime,ctime,dev,ino,nlink,target,mtimeFine||"|"||ctimeFine)
::method shellQuote private
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

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
::method init
  expose objectId relativePath generation metadata extendedMetadata contentSha256 objectState lastError replicas
  use arg idArg,pathArg,generationArg,metadataArg,extendedArg=.nil
  objectId=idArg~string; relativePath=pathArg~string; generation=generationArg+0
  metadata=metadataArg; extendedMetadata=extendedArg
  contentSha256=""; objectState=.EvacObjectState~DISCOVERED; lastError=""; replicas=.directory~new
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
    if e~objectState<>.EvacObjectState~EXCLUDED & e~verifiedCurrentCount=0 then n+=1
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
  expose metadataProbe extendedProbe
  metadataProbe=.EvacPosixMetadataProbe~new; extendedProbe=.EvacPosixExtendedMetadataProbe~new
::method scan
  expose metadataProbe extendedProbe
  use arg rootArg,generationArg,captureExtendedArg=.true
  root=self~canonicalRoot(rootArg)
  if root="" then raise syntax 88.900 array("inventory root is unavailable",rootArg)
  generation=.EvacGeneration~new(generationArg,root)
  /* -P means do not follow symlinks.  NUL-separated output preserves spaces,
   * newlines and other legal pathname bytes except NUL itself. */
  tmp=SysTempFileName("/tmp/oorexx-evac-find-??????")
  address system "/usr/bin/find -P "||self~shellQuote(root)||" -mindepth 1 -print0 > "||self~shellQuote(tmp)
  if rc<>0 then do; call SysFileDelete tmp; raise syntax 88.900 array("inventory find failed",root); end
  n=stream(tmp,"c","query size"); body=""
  if datatype(n,"N") then if n>0 then body=charin(tmp,1,n)
  call stream tmp,"c","close"; call SysFileDelete tmp
  start=1; nul=d2c(0)
  do while start<=length(body)
    stop=pos(nul,body,start)
    if stop=0 then leave
    path=substr(body,start,stop-start); start=stop+1
    if path="" then iterate
    m=metadataProbe~probe(path)
    if m==.nil then iterate
    rel=substr(path,length(root)+1)
    if left(rel,1)="/" then rel=substr(rel,2)
    id="posix:"||m~device||":"||m~inode||":"||generationArg
    x=.nil
    if captureExtendedArg==.true then x=extendedProbe~probe(path)
    generation~put(.EvacManifestEntry~new(id,rel,generationArg,m,x))
  end
  return generation
::method canonicalRoot private
  use arg rootArg
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
  call lineout tmp,"EVAC2"||d2c(9)||generation~number||d2c(9)||self~enc(generation~root)||d2c(9)||self~enc(generation~createdAt)||d2c(9)||generation~sealed
  do p over generation~entries
    e=generation~entries[p]; m=e~metadata; x=e~extendedMetadata
    acl=""; xa=""; aclOk=0; xaOk=0
    if x<>.nil then do
      acl=x~aclText; xa=x~xattrText
      if x~aclAvailable then aclOk=1
      if x~xattrAvailable then xaOk=1
    end
    line="E"||d2c(9)||self~enc(e~objectId)||d2c(9)||self~enc(e~relativePath)||d2c(9)||self~enc(m~type)||d2c(9)||self~enc(m~modeOctal)||d2c(9)||m~uid||d2c(9)||m~gid||d2c(9)||m~sizeBytes||d2c(9)||self~enc(m~mtimeEpoch)||d2c(9)||self~enc(m~atimeEpoch)||d2c(9)||self~enc(m~ctimeEpoch)||d2c(9)||self~enc(m~device)||d2c(9)||self~enc(m~inode)||d2c(9)||m~nlink||d2c(9)||self~enc(m~symlinkTarget)||d2c(9)||self~enc(m~versionToken)||d2c(9)||self~enc(e~contentSha256)||d2c(9)||self~enc(e~objectState)||d2c(9)||self~enc(e~lastError)||d2c(9)||aclOk||d2c(9)||xaOk||d2c(9)||self~enc(acl)||d2c(9)||self~enc(xa)
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
  if magic<>"EVAC2" then do; call stream pathArg,"c","close"; raise syntax 88.900 array("unsupported evacuation manifest",magic); end
  g=.EvacGeneration~new(number,self~dec(rootHex))
  do while lines(pathArg)>0
    line=linein(pathArg); if line="" then iterate
    kind=left(line,1)
    if kind="E" then do
      parse var line . (d2c(9)) idh (d2c(9)) ph (d2c(9)) th (d2c(9)) mh (d2c(9)) uid (d2c(9)) gid (d2c(9)) size (d2c(9)) mtimeh (d2c(9)) atimeh (d2c(9)) ctimeh (d2c(9)) devh (d2c(9)) inoh (d2c(9)) nlink (d2c(9)) targeth (d2c(9)) tokenh (d2c(9)) digesth (d2c(9)) stateh (d2c(9)) errorh (d2c(9)) aclOk (d2c(9)) xaOk (d2c(9)) aclh (d2c(9)) xah
      m=.EvacPosixMetadata~new(self~dec(ph),self~dec(th),self~dec(mh),uid,gid,size,self~dec(mtimeh),self~dec(atimeh),self~dec(ctimeh),self~dec(devh),self~dec(inoh),nlink,self~dec(targeth),self~dec(tokenh))
      x=.EvacPosixExtendedMetadata~new(self~dec(aclh),self~dec(xah),aclOk=1,xaOk=1)
      e=.EvacManifestEntry~new(self~dec(idh),self~dec(ph),number,m,x)
      e~contentSha256=self~dec(digesth); e~objectState=self~dec(stateh); e~lastError=self~dec(errorh)
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

/* Executes a regular-file replica using Storage Fabric's bounded-memory
 * transfer engine and independent SHA-256 verifier. */
::class EvacLocalReplicaExecutor public
::attribute chunkBytes get
::method init
  expose chunkBytes
  use arg chunkArg=8388608
  chunkBytes=chunkArg+0
::method transfer
  expose chunkBytes
  use arg entry, sourceRootArg, destinationRootArg, checkpointRootArg
  sourcePath=self~join(sourceRootArg,entry~relativePath)
  destinationPath=self~join(destinationRootArg,entry~relativePath)
  if entry~metadata~type<>"regular file" then return .nil
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
  if entry~metadata~sameSourceVersion(current) then do
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

::requires "StorageStreaming.cls"
