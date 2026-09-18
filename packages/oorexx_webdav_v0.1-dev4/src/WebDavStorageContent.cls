/* Durable ordinary-byte content provider for ooRexx WebDAV Gateway v0.1-dev3.
 *
 * WebDAV owns HTTP representation semantics; this class binds ordinary byte
 * representations to Storage Fabric's streaming primitives and StorageLocation
 * evidence. It is intentionally not used for canonical CARD/PAPER/TAPE images.
 */

::class WebDavStoredContent public
::attribute ref get
::attribute sizeBytes get
::attribute location get
::attribute source get
::method init
  expose ref sizeBytes location source
  use arg refArg, sizeArg, locationArg, sourceArg=.nil
  ref=refArg; sizeBytes=sizeArg+0; location=locationArg; source=sourceArg

::class WebDavStorageContentProvider public
::attribute root get
::attribute providerId get
::attribute capacityDomainId get
::attribute nodeId get
::attribute chunkBytes get
::method init
  expose root providerId capacityDomainId nodeId chunkBytes sequence
  use arg rootArg, providerArg='webdav-local', domainArg='posixfs:webdav', nodeArg='', chunkArg=262144
  root=rootArg~string
  providerId=providerArg~string~strip
  capacityDomainId=domainArg~string~strip
  nodeId=nodeArg~string~strip
  chunkBytes=chunkArg+0
  sequence=0
  if root='' | providerId='' | chunkBytes<1 then raise syntax 88.900 array('invalid WebDAV Storage content provider configuration')
  call SysMkDir root

::method nextId
  expose sequence
  sequence+=1
  return 'dav-byte-'||date('S')||'-'||time('S')||'-'||sequence

::method commitBytes
  expose root providerId capacityDomainId nodeId chunkBytes
  use arg bytesArg, objectIdArg=''
  bytes=bytesArg~string
  id=objectIdArg~string~strip
  if id='' then id=self~nextId
  final=root||'/'||self~safeName(id)||'.bin'
  tmp=final||'.part'
  call SysFileDelete tmp
  sink=.StorageLocalFileByteSink~new(tmp)
  sink~openAt(0,bytes~length)
  pos=1
  do while pos<=bytes~length
    n=chunkBytes
    if pos+n-1>bytes~length then n=bytes~length-pos+1
    wrote=sink~writeChunk(bytes~substr(pos,n))
    if wrote<>n then do; sink~close; raise syntax 88.900 array('short WebDAV Storage sink write'); end
    sink~flush
    pos+=wrote
  end
  sink~close
  if bytes~length=0 then do
    sink=.StorageLocalFileByteSink~new(tmp); sink~openAt(0,0); sink~close
  end
  digest=self~sha256(tmp)
  if digest='' then do; call SysFileDelete tmp; raise syntax 88.900 array('unable to verify WebDAV Storage content'); end
  call SysFileDelete final
  moved=SysFileMove(tmp,final)
  if moved<>0 then do; call SysFileDelete tmp; raise syntax 88.900 array('unable to commit WebDAV Storage content',final); end
  ref=.StorageRef~new(id,'sha256:'||digest)
  loc=.StorageLocation~new(providerId,final,capacityDomainId,.StorageLocationState~AVAILABLE,date('S')||'T'||time('L'),.true,'sha256:'||digest,.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,nodeId)
  return .WebDavStoredContent~new(ref,bytes~length,loc,.StorageLocalFileByteSource~new(final))

::method sourceFor
  expose root
  use arg objectArg
  if objectArg==.nil then return .nil
  do loc over objectArg~availableLocations
    if loc~locator<>'' then do
      p=loc~locator
      if stream(p,'c','query exists')<>'' then return .StorageLocalFileByteSource~new(p)
    end
  end
  p=root||'/'||self~safeName(objectArg~ref~objectId)||'.bin'
  if stream(p,'c','query exists')='' then return .nil
  return .StorageLocalFileByteSource~new(p)

::method getObjectBytes
  expose chunkBytes
  use arg objectArg
  src=self~sourceFor(objectArg)
  if src==.nil then return .nil
  src~openAt(0)
  out=''
  do forever
    ch=src~readChunk(chunkBytes)
    out=out||ch~data
    if ch~eof then leave
  end
  src~close
  return out

::method get
  use arg objectIdArg
  /* Compatibility only; object-aware reads are preferred. */
  return .nil

::method remove
  /* Namespace unlink is not physical destruction. */
  return self

::method safeName private
  use arg sArg
  s=sArg~string
  s=changestr('/',s,'_'); s=changestr('\\',s,'_'); s=changestr(':',s,'_'); s=changestr(' ',s,'_')
  return s

::method sha256 private
  use arg pathArg
  tmp=SysTempFileName('/tmp/oorexx-webdav-sha-??????')
  address system '/usr/bin/sha256sum -- '||self~quote(pathArg)||' > '||self~quote(tmp)||' 2>/dev/null'
  if rc<>0 then do; call SysFileDelete tmp; return ''; end
  line=linein(tmp); call stream tmp,'c','close'; call SysFileDelete tmp
  parse var line digest .
  return digest~strip~lower

::method quote private
  use arg sArg
  s=sArg~string
  return "'"||changestr("'",s,"'\\''")||"'"

::requires 'StorageFabric.cls'
::requires 'StorageStreaming.cls'
