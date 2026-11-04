/* MasStorageFabricDsfs.cls
 * mvs.alchemy.storage-path/0.1
 *
 * DSFS-like MVS path personality backed by ooRexx Storage Fabric namespace
 * objects.  StorageRef is authoritative identity; MVS-looking paths are views.
 * This is not IBM z/OS DSFS and does not claim zFS/USS implementation.
 */

::class MasDsfsView public
::constant TEXT "TEXT"
::constant BINARY "BINARY"
::constant RECORD "RECORD"

::class MasDsfsPathOptions public
::constant ORDNLY "ORDONLY"
::constant OWRONLY "OWRONLY"
::constant ORDWR "ORDWR"
::constant OCREAT "OCREAT"
::constant OTRUNC "OTRUNC"
::constant OAPPEND "OAPPEND"

::class MasDsfsOpenSpec public
::method init public
  expose path options fileData readable writable create truncate append
  use strict arg pathArg, optionsArg='ORDONLY', fileDataArg='BINARY'
  path=pathArg~string~strip
  if path='' then raise syntax 88.900 array('PATH_REQUIRED')
  fileData=fileDataArg~string~strip~translate
  if fileData<>.MasDsfsView~TEXT & fileData<>.MasDsfsView~BINARY & fileData<>.MasDsfsView~RECORD then
    raise syntax 88.900 array('UNSUPPORTED_FILEDATA:' fileData)
  options=.set~new
  raw=optionsArg~string
  raw=changestr(',',raw,' ')
  do i=1 to raw~words
    o=raw~word(i)~translate
    if o<>'' then options~put(o)
  end
  readable=(options~hasIndex('ORDONLY') | options~hasIndex('ORDWR'))
  writable=(options~hasIndex('OWRONLY') | options~hasIndex('ORDWR'))
  if \readable & \writable then readable=.true
  create=options~hasIndex('OCREAT')
  truncate=options~hasIndex('OTRUNC')
  append=options~hasIndex('OAPPEND')
  if truncate | append then writable=.true
::attribute path get
::attribute options get
::attribute fileData get
::attribute readable get
::attribute writable get
::attribute create get
::attribute truncate get
::attribute append get

/* Host text representation codec.  PATH FILEDATA=TEXT is a semantic view;
 * tape text records are encoded to EBCDIC CP037 for Hercules AWSTAPE output.
 */
::class MasDsfsTextCodec public
::constant BYTE_TABLE "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"
::constant ASCII_TO_EBCDIC "00010203372d2e2f1605250b0c0d0e0f101112133c3d322618193f271c1d1e1f405a7f7b5b6c507d4d5d5c4e6b604b61f0f1f2f3f4f5f6f7f8f97a5e4c7e6e6f7cc1c2c3c4c5c6c7c8c9d1d2d3d4d5d6d7d8d9e2e3e4e5e6e7e8e9bae0bbb06d79818283848586878889919293949596979899a2a3a4a5a6a7a8a9c04fd0a1076f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f"
::constant EBCDIC_TO_ASCII "000102039c09867f978d8e0b0c0d0e0f101112139d8508871819928f1c1d1e1f80818283840a171b88898a8b8c050607909116939495960498999a9b14159e1a20a0e2e4e0e1e3e5e7f1a22e3c282b7c26e9eaebe8edeeefecdf21242a293bac2d2fc2c4c0c1c3c5c7d1a62c255f3e3ff8c9cacbc8cdcecfcc603a2340273d22d8616263646566676869abbbf0fdfeb1b06a6b6c6d6e6f707172aabae6b8c6a4b57e737475767778797aa1bfd0dddeae5ea3a5b7a9a7b6bcbdbe5b5dafa8b4d77b414243444546474849adf4f6f2f3f57d4a4b4c4d4e4f505152b9fbfcf9faff5cf7535455565758595ab2d4d6d2d3d530313233343536373839b3dbdcd9da9f"
::method normalizeHostText class
  use strict arg bytes
  answer=changestr('0d0a'x,bytes,'0a'x)
  answer=changestr('0d'x,answer,'0a'x)
  return answer
::method asciiToEbcdic class
  use strict arg bytes
  return translate(bytes,x2c(self~ASCII_TO_EBCDIC),x2c(self~BYTE_TABLE),'6f'x)
::method ebcdicToAscii class
  use strict arg bytes
  return translate(bytes,x2c(self~EBCDIC_TO_ASCII),x2c(self~BYTE_TABLE),'3f'x)

/* Provider protocol expected by the MVS path personality.
 * resolve(path) -> StorageRef/.nil
 * read(ref) -> bytes
 * publish(path, bytes, mediaType) -> new StorageRef
 * list(path) -> StorageNamespaceEntry[]
 */
::class MasStorageObjectStore public
::method resolve abstract
::method read abstract
::method publish abstract
::method list abstract
::method object abstract

/* Executable Storage Fabric binding for qualification and small deployments.
 * It uses real StorageNamespace/StorageRef/StorageObject classes.  Bytes are
 * kept in memory here; production providers may use any StorageByteSource/Sink.
 */
::class MasMemoryStorageFabricStore public subclass MasStorageObjectStore
::method init public
  expose namespace catalogue bodies sequence writePolicy
  use strict arg namespaceArg, catalogueArg, writePolicyArg='DIRECT'
  namespace=namespaceArg; catalogue=catalogueArg; bodies=.directory~new; sequence=0
  writePolicy=writePolicyArg~translate
  if namespace==.nil | catalogue==.nil then raise syntax 88.900 array('STORAGE_NAMESPACE_REQUIRED')
::attribute namespace get
::attribute catalogue get
::method resolve public
  expose namespace
  use strict arg path
  r=namespace~resolve(path)
  if \r~found then return .nil
  return r~entry~ref
::method object public
  expose catalogue
  use strict arg ref
  if ref==.nil then return .nil
  return catalogue~get(ref~objectId)
::method read public
  expose bodies
  use strict arg ref
  if ref==.nil then raise syntax 88.900 array('STORAGE_REF_REQUIRED')
  if \bodies~hasIndex(ref~objectId) then raise syntax 88.900 array('STORAGE_BYTES_UNAVAILABLE:' ref~objectId)
  return bodies[ref~objectId]
::method publish public
  expose namespace catalogue bodies sequence writePolicy
  use strict arg path, bytes, mediaType='application/octet-stream'
  sequence+=1
  id='mvs-sf:'||sequence~right(8,'0')||':'||path
  ref=.StorageRef~new(id)
  object=.StorageObject~new(ref,.StoragePath~name(path),bytes~length,mediaType)
  catalogue~put(object); bodies[id]=bytes
  /* A new immutable object is created every close.  The namespace binding
   * advances; the old StorageRef remains catalogue identity/history. */
  namespace~bind(path,ref,writePolicy)
  return ref
::method list public
  expose namespace
  use strict arg path
  return namespace~list(path)

/* Durable host-backed implementation of the Storage Fabric object-store seam.
 *
 * StorageRef/StorageObject/StorageNamespace remain the authoritative object and
 * namespace model.  The host filesystem below is only a byte provider.  Each
 * publish creates a new immutable object file and appends a restart journal;
 * reopening the store reconstructs the catalogue and current namespace bindings.
 *
 * This deliberately does not claim to replace Storage Fabric dev22 providers.
 * It is a durable MAS binding suitable for live integration while retaining the
 * same provider-neutral MasStorageObjectStore contract.
 */
::class MasHostStorageFabricStore public subclass MasStorageObjectStore
::method init public
  expose root objectRoot journalPath sequence namespace catalogue writePolicy
  use strict arg rootArg, namespaceId='MVS-HOST', writePolicyArg='DIRECT'
  root=rootArg~string~strip
  if root='' then raise syntax 88.900 array('STORAGE_ROOT_REQUIRED')
  objectRoot=root||'/objects'
  journalPath=root||'/objects.journal'
  call SysMkDir root
  call SysMkDir objectRoot
  catalogue=.StorageCatalogue~new
  env=.StorageEnvironment~new(namespaceId||'-LIVE',.StorageEnvironmentKind~LIVE,'',0,1,writePolicyArg)
  namespace=.StorageNamespace~new(namespaceId,catalogue,env)
  writePolicy=writePolicyArg~translate
  sequence=0
  self~reload
::attribute namespace get
::attribute catalogue get
::attribute root get
::method resolve public
  expose namespace
  use strict arg path
  r=namespace~resolve(path)
  if \r~found then return .nil
  return r~entry~ref
::method object public
  expose catalogue
  use strict arg ref
  if ref==.nil then return .nil
  return catalogue~get(ref~objectId)
::method read public
  expose objectRoot
  use strict arg ref
  if ref==.nil then raise syntax 88.900 array('STORAGE_REF_REQUIRED')
  path=self~objectPath(ref~objectId)
  if stream(path,'c','query exists')='' then raise syntax 88.900 array('STORAGE_BYTES_UNAVAILABLE:' ref~objectId)
  size=stream(path,'c','query size')
  if datatype(size,'N')=0 then raise syntax 88.900 array('STORAGE_SIZE_UNAVAILABLE:' ref~objectId)
  call stream path,'c','open read'
  bytes=charin(path,,size+0)
  call stream path,'c','close'
  return bytes
::method publish public
  expose namespace catalogue sequence journalPath writePolicy objectRoot
  use strict arg path, bytes, mediaType='application/octet-stream'
  sequence+=1
  id='mvs-sf:'||sequence~right(12,'0')
  ref=.StorageRef~new(id)
  final=self~objectPath(id)
  stage=final||'.stage'
  call SysFileDelete stage
  state=stream(stage,'c','open write replace')
  if left(state,6)<>'READY:' then raise syntax 88.900 array('STORAGE_STAGE_OPEN_FAILED:' state)
  call charout stage,bytes
  call stream stage,'c','close'
  if SysFileMove(stage,final)<>0 then do
    call SysFileDelete stage
    raise syntax 88.900 array('STORAGE_PUBLISH_RENAME_FAILED:' final)
  end
  object=.StorageObject~new(ref,.StoragePath~name(path),bytes~length,mediaType)
  object~addLocation(.StorageLocation~new('MAS_HOST',final,'HOST',.StorageLocationState~AVAILABLE,'',.true,'MAS_HOST_ATOMIC_PUBLISH'))
  catalogue~put(object)
  namespace~bind(path,ref,writePolicy)
  line=id||'09'x||c2x(path)||'09'x||c2x(mediaType)||'09'x||bytes~length
  call lineout journalPath,line
  call lineout journalPath
  return ref
::method list public
  expose namespace
  use strict arg path
  return namespace~list(path)
::method reload private
  expose journalPath sequence namespace catalogue writePolicy
  if stream(journalPath,'c','query exists')='' then return self
  do while lines(journalPath)>0
    line=linein(journalPath)
    if line='' then iterate
    parse var line id '09'x pathHex '09'x mediaHex '09'x sizeText
    if id='' | pathHex='' then iterate
    ref=.StorageRef~new(id)
    path=x2c(pathHex)
    media=x2c(mediaHex)
    size=sizeText+0
    object=.StorageObject~new(ref,.StoragePath~name(path),size,media)
    final=self~objectPath(id)
    if stream(final,'c','query exists')<>'' then object~addLocation(.StorageLocation~new('MAS_HOST',final,'HOST',.StorageLocationState~AVAILABLE,'',.true,'MAS_HOST_RELOAD'))
    catalogue~put(object)
    namespace~bind(path,ref,writePolicy)
    parse var id 'mvs-sf:' n
    if datatype(n,'W') & n+0>sequence then sequence=n+0
  end
  call stream journalPath,'c','close'
  return self
::method objectPath private
  expose objectRoot
  use strict arg objectId
  safe=changestr(':',objectId,'_')
  safe=changestr('/',safe,'_')
  return objectRoot||'/'||safe||'.bin'

/* Transport-neutral MVS PATH session dispatcher.  A guest transport (DYN75,
 * DIAG8, socket, shared spool, or a future Hercules service channel) only has
 * to carry these operations; it does not own PATH semantics.
 */
::class MasPathOperation public
::constant OPEN 'OPEN'
::constant READ 'READ'
::constant WRITE 'WRITE'
::constant APPEND 'APPEND'
::constant CLOSE 'CLOSE'
::constant STAT 'STAT'
::constant LIST 'LIST'

::class MasPathReply public
::method init public
  expose ok code value
  use strict arg okArg, codeArg='OK', valueArg=.nil
  ok=(okArg==.true); code=codeArg~string; value=valueArg
::attribute ok get
::attribute code get
::attribute value get

::class MasPathSessionDispatcher public
::method init public
  expose service handles nextHandle
  use strict arg serviceArg
  service=serviceArg; handles=.directory~new; nextHandle=0
::method open public
  expose service handles nextHandle
  use strict arg path, pathOpts='ORDONLY', fileData='BINARY'
  h=service~open(path,pathOpts,fileData)
  nextHandle+=1
  id='H'||nextHandle
  handles[id]=h
  return .MasPathReply~new(.true,'OPENED',id)
::method read public
  expose handles
  use strict arg handleId
  h=self~handle(handleId)
  return .MasPathReply~new(.true,'DATA',h~readAll)
::method write public
  expose handles
  use strict arg handleId, bytes
  h=self~handle(handleId)
  return .MasPathReply~new(.true,'WRITTEN',h~write(bytes))
::method append public
  expose handles
  use strict arg handleId, bytes
  h=self~handle(handleId)
  return .MasPathReply~new(.true,'APPENDED',h~append(bytes))
::method close public
  expose handles
  use strict arg handleId
  h=self~handle(handleId)
  ref=h~close
  handles~remove(handleId)
  return .MasPathReply~new(.true,'CLOSED',ref)
::method stat public
  expose service
  use strict arg path, view='BINARY'
  st=service~stat(path,view)
  if st==.nil then return .MasPathReply~new(.false,'NOT_FOUND')
  return .MasPathReply~new(.true,'STAT',st)
::method list public
  expose service
  use strict arg path
  return .MasPathReply~new(.true,'LIST',service~list(path))
::method handle private
  expose handles
  use strict arg handleId
  if \handles~hasIndex(handleId) then raise syntax 88.900 array('INVALID_PATH_HANDLE:' handleId)
  return handles[handleId]

::class MasDsfsStat public
::method init public
  expose path ref size mediaType view
  use strict arg path, ref, size, mediaType, view
::attribute path get
::attribute ref get
::attribute size get
::attribute mediaType get
::attribute view get

::class MasDsfsHandle public
::method init public
  expose service spec originalRef bytes dirty closed position
  use strict arg serviceArg, specArg, originalRefArg=.nil, initialBytes=''
  service=serviceArg; spec=specArg; originalRef=originalRefArg
  bytes=initialBytes; dirty=.false; closed=.false; position=1
  if spec~truncate then do; bytes=''; dirty=.true; end
  if spec~append then position=bytes~length+1
::attribute originalRef get
::attribute spec get
::method readAll public
  expose spec bytes closed
  if closed then raise syntax 88.900 array('HANDLE_CLOSED')
  if \spec~readable then raise syntax 88.900 array('NOT_OPEN_FOR_READ')
  return bytes
::method write public
  expose spec bytes dirty closed position
  use strict arg data
  if closed then raise syntax 88.900 array('HANDLE_CLOSED')
  if \spec~writable then raise syntax 88.900 array('NOT_OPEN_FOR_WRITE')
  if spec~append then bytes=bytes||data
  else bytes=data
  position=bytes~length+1; dirty=.true
  return data~length
::method append public
  expose spec bytes dirty closed position
  use strict arg data
  if closed then raise syntax 88.900 array('HANDLE_CLOSED')
  if \spec~writable then raise syntax 88.900 array('NOT_OPEN_FOR_WRITE')
  bytes=bytes||data; position=bytes~length+1; dirty=.true
  return data~length
::method close public
  expose service spec originalRef bytes dirty closed
  if closed then return originalRef
  closed=.true
  if dirty | (originalRef==.nil & spec~create) then return service~commit(spec,bytes,originalRef)
  return originalRef

::class MasStorageFabricDsfsService public
::method init public
  expose store
  use strict arg storeArg
  store=storeArg
  if store==.nil then raise syntax 88.900 array('STORAGE_STORE_REQUIRED')
::attribute store get
::method open public
  expose store
  use strict arg path, pathOpts='ORDONLY', fileData='BINARY'
  spec=.MasDsfsOpenSpec~new(path,pathOpts,fileData)
  ref=store~resolve(spec~path)
  if ref==.nil then do
    if \spec~create then raise syntax 88.900 array('PATH_NOT_FOUND:' spec~path)
    initial=''
  end
  else initial=store~read(ref)
  if spec~fileData=.MasDsfsView~TEXT then initial=.MasDsfsTextCodec~normalizeHostText(initial)
  return .MasDsfsHandle~new(self,spec,ref,initial)
::method commit public
  expose store
  use strict arg spec, bytes, oldRef=.nil
  media='application/octet-stream'
  if spec~fileData=.MasDsfsView~TEXT then do
    bytes=.MasDsfsTextCodec~normalizeHostText(bytes)
    media='text/plain'
  end
  else if spec~fileData=.MasDsfsView~RECORD then media='application/x-mvs-record-stream'
  return store~publish(spec~path,bytes,media)
::method stat public
  expose store
  use strict arg path, view='BINARY'
  ref=store~resolve(path)
  if ref==.nil then return .nil
  o=store~object(ref)
  if o==.nil then return .nil
  return .MasDsfsStat~new(path,ref,o~sizeBytes,o~mediaType,view)
::method list public
  expose store
  use strict arg path
  return store~list(path)

/* Internal record stream representation for FILEDATA=RECORD: each record is
 * four-byte big-endian length followed by exact record bytes.  This is an
 * Alchemy transport representation, not a claim about IBM DSFS wire format.
 */
::class MasRecordStream public
::method encode class
  use strict arg records
  out=''
  do r over records
    if r~length>2147483647 then raise syntax 88.900 array('RECORD_TOO_LARGE')
    out=out||d2c(r~length,4)||r
  end
  return out
::method decode class
  use strict arg bytes
  records=.array~new; p=1
  do while p<=bytes~length
    if p+3>bytes~length then raise syntax 88.900 array('TRUNCATED_RECORD_LENGTH')
    n=c2d(substr(bytes,p,4)); p+=4
    if p+n-1>bytes~length then raise syntax 88.900 array('TRUNCATED_RECORD')
    records~append(substr(bytes,p,n)); p+=n
  end
  return records

::class MasTapeProjectionFile public
::method init public
  expose sequence path ref view records
  use strict arg sequence, path, ref, view, records
::attribute sequence get
::attribute path get
::attribute ref get
::attribute view get
::attribute records get

::class MasTapeProjection public
::method init public
  expose files sourceDirectory
  use strict arg sourceDirectoryArg
  sourceDirectory=sourceDirectoryArg; files=.array~new
::attribute sourceDirectory get
::attribute files get
::method add public
  expose files
  use strict arg f
  files~append(f); return self

::class MasDirectoryTapeProjector public
::method init public
  expose service
  use strict arg serviceArg
  service=serviceArg
::method project public
  expose service
  use strict arg directory, view='TEXT'
  view=view~translate
  entries=service~list(directory)
  names=.array~new
  do e over entries; names~append(e~path); end
  names=names~sort
  tape=.MasTapeProjection~new(directory); seq=1
  do path over names
    ref=service~store~resolve(path)
    bytes=service~store~read(ref)
    records=self~recordsFor(bytes,view)
    tape~add(.MasTapeProjectionFile~new(seq,path,ref,view,records)); seq+=1
  end
  return tape
::method recordsFor private
  use strict arg bytes, view
  select
    when view=.MasDsfsView~BINARY then do
      a=.array~new; p=1; max=32760
      do while p<=bytes~length
        a~append(substr(bytes,p,max)); p+=max
      end
      if a~items=0 then a~append('')
      return a
    end
    when view=.MasDsfsView~RECORD then return .MasRecordStream~decode(bytes)
    when view=.MasDsfsView~TEXT then do
      text=.MasDsfsTextCodec~normalizeHostText(bytes)
      a=.array~new
      do while text<>''
        p=pos('0a'x,text)
        if p=0 then do; line=text; text=''; end
        else do; line=substr(text,1,p-1); text=substr(text,p+1); end
        a~append(.MasDsfsTextCodec~asciiToEbcdic(line))
      end
      if a~items=0 then a~append('')
      return a
    end
    otherwise raise syntax 88.900 array('UNSUPPORTED_TAPE_VIEW:' view)
  end

/* Hercules-compatible uncompressed AWSTAPE writer.  Each record receives the
 * documented 6-byte little-endian AWS header; each logical projected file is
 * terminated by a tape mark.  File 1 is an EBCDIC MAS directory manifest.
 */
::class MasAwsTapeWriter public
::method write public
  use strict arg projection, targetPath
  call SysFileDelete targetPath
  s=stream(targetPath,'c','open write replace')
  if left(s,6)<>'READY:' then raise syntax 88.900 array('TAPE_OPEN_FAILED:' s)
  prev=0
  manifest=.array~new
  manifest~append('MASDIR 1 '||projection~sourceDirectory)
  do f over projection~files
    manifest~append(f~sequence~right(5,0)||' '||f~view~left(6)||' '||f~ref~objectId||' '||f~path)
  end
  do line over manifest
    data=.MasDsfsTextCodec~asciiToEbcdic(line)
    prev=self~writeRecord(targetPath,data,prev)
  end
  prev=self~writeTapeMark(targetPath,prev)
  do f over projection~files
    do record over f~records
      prev=self~writeRecord(targetPath,record,prev)
    end
    prev=self~writeTapeMark(targetPath,prev)
  end
  call stream targetPath,'c','close'
  return targetPath
::method writeRecord private
  use strict arg path, data, prev
  n=data~length
  if n>65535 then raise syntax 88.900 array('AWS_RECORD_TOO_LARGE:' n)
  hdr=reverse(d2c(n,2))||reverse(d2c(prev,2))||'a000'x
  call charout path,hdr||data
  return n
::method writeTapeMark private
  use strict arg path, prev
  hdr='0000'x||reverse(d2c(prev,2))||'4000'x
  call charout path,hdr
  return 0

::requires "../../deps/qualification/storage_fabric/StorageFabric.cls"
