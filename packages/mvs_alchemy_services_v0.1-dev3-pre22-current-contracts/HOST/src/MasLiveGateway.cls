/* MasLiveGateway.cls - first real host endpoint for the MVS guest transport.
 * pre9: TCP carrier + mvs.alchemy/1 framing + existing MAS qualification
 * semantics.  The gateway owns framing/session handles, not provider internals.
 */

::class MasGatewayLogSubject public
::method event public
  use strict arg payload
  return payload

::class MasGatewayLogger public
::method init public
  expose service target logger evidenceFile
  use strict arg evidenceFileArg = ''
  evidenceFile = evidenceFileArg
  service = .LogService~new('mvs-alchemy-live-gateway')
  target = .LogMemoryTarget~new('mas-live-memory', .Log~INTERNAL)
  service~addTarget(target)
  subject = .MasGatewayLogSubject~new
  rule = .LogRule~new('mas-live-event','mvs.alchemy.live','MasGatewayLogSubject','event', -
      .Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.nil,.array~of(target~name),.array~new)
  service~addRule(rule)
  logger = service~loggerFor(subject,'event',.array~new,.Log~INTERNAL)
::attribute target get
::attribute service get
::method emit public
  expose logger evidenceFile
  use strict arg phase, sessionId, requestId, operation, status = 0, reason = 0, details = ''
  payload = .directory~new
  payload['run_id'] = value('MAS_RUN_ID',,'ENVIRONMENT')
  payload['transaction_id'] = sessionId || '-' || requestId
  payload['session_id'] = sessionId
  payload['request_id'] = requestId
  payload['operation'] = operation
  payload['phase'] = phase
  payload['status'] = status
  payload['reason'] = reason
  payload['details'] = details
  ignore = logger~log(.Log~INFO,payload,'MAS.' || phase)
  if evidenceFile <> '' then do
    line = 'phase=' || phase || '|session=' || sessionId || '|request=' || requestId || -
           '|operation=' || operation || '|status=' || status || '|reason=' || reason || '|details=' || details
    call lineout evidenceFile,line
    call lineout evidenceFile
  end
  return payload

::class MasGatewayHandle public
::method init public
  expose kind value
  use strict arg kindArg, valueArg
  kind=kindArg; value=valueArg
::attribute kind get
::attribute value get

::class MasGatewaySession public
::method init public
  expose sessionId handles nextHandle pathDispatcher
  use strict arg sessionIdArg, pathDispatcherArg
  sessionId=sessionIdArg; pathDispatcher=pathDispatcherArg; handles=.directory~new; nextHandle=100
::attribute sessionId get
::method addHandle public
  expose handles nextHandle
  use strict arg kind, value
  nextHandle += 1
  handles[nextHandle] = .MasGatewayHandle~new(kind,value)
  return nextHandle
::method getHandle public
  expose handles
  use strict arg id, expectedKind=''
  if \handles~hasIndex(id) then raise syntax 88.900 array('MAS_INVALID_HANDLE:' id)
  h=handles[id]
  if expectedKind<>'' & h~kind<>expectedKind then raise syntax 88.900 array('MAS_HANDLE_KIND:' h~kind)
  return h
::method dropHandle public
  expose handles
  use strict arg id
  if handles~hasIndex(id) then handles~remove(id)
::attribute pathDispatcher get

::class MasLiveRef public
::method init public
  expose objectId
  use strict arg id
  objectId=id
::attribute objectId get
::method string public
  expose objectId
  return objectId

::class MasLiveObject public
::method init public
  expose ref sizeBytes mediaType
  use strict arg refArg, sizeArg, mediaArg
  ref=refArg; sizeBytes=sizeArg; mediaType=mediaArg
::attribute ref get
::attribute sizeBytes get
::attribute mediaType get

/* Small durable provider used only by the live guest qualification gateway.
 * It preserves immutable refs and current namespace bindings without importing
 * provider-native Storage Fabric implementation details into the wire layer.
 */
::class MasLivePathStore public
::method init public
  expose root sequence bindings objects
  use strict arg rootArg
  root=rootArg; sequence=0; bindings=.directory~new; objects=.directory~new
  call SysMkDir root
  self~reload
::method resolve public
  expose bindings
  use strict arg path
  if \bindings~hasIndex(path) then return .nil
  return .MasLiveRef~new(bindings[path])
::method object public
  expose objects
  use strict arg ref
  if ref==.nil | \objects~hasIndex(ref~objectId) then return .nil
  row=objects[ref~objectId]
  return .MasLiveObject~new(ref,row[2],row[3])
::method read public
  expose root objects
  use strict arg ref
  if ref==.nil | \objects~hasIndex(ref~objectId) then raise syntax 88.900 array('PATH_REF_NOT_FOUND')
  row=objects[ref~objectId]
  p=root||'/'||ref~objectId||'.bin'
  n=stream(p,'c','query size')
  if datatype(n,'N')=0 then raise syntax 88.900 array('PATH_BYTES_NOT_FOUND')
  call stream p,'c','open read'
  b=charin(p,,n+0)
  call stream p,'c','close'
  return b
::method publish public
  expose root sequence bindings objects
  use strict arg path, bytes, media='application/octet-stream'
  sequence += 1
  id='live-'||sequence~right(8,'0')
  p=root||'/'||id||'.bin'
  call stream p,'c','open write replace'
  call charout p,bytes
  call stream p,'c','close'
  bindings[path]=id
  objects[id]=.array~of(path,bytes~length,media)
  self~persist
  return .MasLiveRef~new(id)
::method list public
  expose bindings
  use strict arg prefix
  a=.array~new
  do p over bindings~allIndexes~sort
    if left(p,prefix~length)=prefix then a~append(p)
  end
  return a
::method persist private
  expose root sequence bindings objects
  p=root||'/index.tsv'
  call stream p,'c','open write replace'
  call lineout p,'SEQUENCE'||'09'x||sequence
  do path over bindings~allIndexes~sort
    id=bindings[path]; row=objects[id]
    call lineout p,'OBJECT'||'09'x||id||'09'x||c2x(path)||'09'x||row[2]||'09'x||c2x(row[3])
  end
  call lineout p
::method reload private
  expose root sequence bindings objects
  p=root||'/index.tsv'
  if stream(p,'c','query exists')='' then return
  do while lines(p)>0
    l=linein(p)
    if l='' then iterate
    parse var l kind '09'x rest
    if kind='SEQUENCE' then sequence=rest+0
    else if kind='OBJECT' then do
      parse var rest id '09'x pathHex '09'x size '09'x mediaHex
      path=x2c(pathHex); media=x2c(mediaHex)
      bindings[path]=id; objects[id]=.array~of(path,size+0,media)
    end
  end
  call stream p,'c','close'

::class MasLivePathReply public
::method init public
  expose ok code value
  use strict arg okArg, codeArg='OK', valueArg=.nil
  ok=(okArg==.true); code=codeArg; value=valueArg
::attribute ok get
::attribute code get
::attribute value get

::class MasLivePathSpec public
::method init public
  expose path readable writable create truncate append fileData
  use strict arg pathArg, optsArg='ORDONLY', fileDataArg='BINARY'
  path=pathArg; fileData=fileDataArg~translate
  raw=changestr(',',optsArg,' ')
  set=.set~new
  do i=1 to raw~words; set~put(raw~word(i)~translate); end
  readable=(set~hasIndex('ORDONLY') | set~hasIndex('ORDWR'))
  writable=(set~hasIndex('OWRONLY') | set~hasIndex('ORDWR'))
  if \readable & \writable then readable=.true
  create=set~hasIndex('OCREAT'); truncate=set~hasIndex('OTRUNC'); append=set~hasIndex('OAPPEND')
  if truncate | append then writable=.true
::attribute path get
::attribute readable get
::attribute writable get
::attribute create get
::attribute truncate get
::attribute append get
::attribute fileData get

::class MasLivePathHandle public
::method init public
  expose service spec originalRef bytes dirty closed
  use strict arg serviceArg, specArg, originalRefArg=.nil, initial=''
  service=serviceArg; spec=specArg; originalRef=originalRefArg; bytes=initial; dirty=.false; closed=.false
  if spec~truncate then do; bytes=''; dirty=.true; end
::method readAll public
  expose spec bytes closed
  if closed then raise syntax 88.900 array('PATH_HANDLE_CLOSED')
  if \spec~readable then raise syntax 88.900 array('PATH_NOT_READABLE')
  return bytes
::method write public
  expose spec bytes dirty closed
  use strict arg data
  if closed then raise syntax 88.900 array('PATH_HANDLE_CLOSED')
  if \spec~writable then raise syntax 88.900 array('PATH_NOT_WRITABLE')
  if spec~append then bytes ||= data
  else bytes=data
  dirty=.true
  return data~length
::method append public
  expose spec bytes dirty closed
  use strict arg data
  if closed then raise syntax 88.900 array('PATH_HANDLE_CLOSED')
  if \spec~writable then raise syntax 88.900 array('PATH_NOT_WRITABLE')
  bytes ||= data; dirty=.true
  return data~length
::method close public
  expose service spec originalRef bytes dirty closed
  if closed then return originalRef
  closed=.true
  if dirty | (originalRef==.nil & spec~create) then return service~commit(spec,bytes)
  return originalRef

::class MasLivePathService public
::method init public
  expose store
  use strict arg storeArg
  store=storeArg
::method open public
  expose store
  use strict arg path, opts='ORDONLY', fileData='BINARY'
  spec=.MasLivePathSpec~new(path,opts,fileData)
  ref=store~resolve(path)
  if ref==.nil then do
    if \spec~create then raise syntax 88.900 array('PATH_NOT_FOUND:' path)
    initial=''
  end
  else initial=store~read(ref)
  return .MasLivePathHandle~new(self,spec,ref,initial)
::method commit public
  expose store
  use strict arg spec, bytes
  media='application/octet-stream'; if spec~fileData='TEXT' then media='text/plain'
  return store~publish(spec~path,bytes,media)
::method list public
  expose store
  use strict arg path
  return store~list(path)

::class MasLivePathDispatcher public
::method init public
  expose service handles nextHandle
  use strict arg serviceArg
  service=serviceArg; handles=.directory~new; nextHandle=0
::method open public
  expose service handles nextHandle
  use strict arg path, opts, fileData
  h=service~open(path,opts,fileData); nextHandle+=1; handles[nextHandle]=h
  return .MasLivePathReply~new(.true,'OK',nextHandle)
::method read public
  expose handles
  use strict arg handle
  if \handles~hasIndex(handle) then return .MasLivePathReply~new(.false,'BAD_HANDLE')
  return .MasLivePathReply~new(.true,'OK',handles[handle]~readAll)
::method write public
  expose handles
  use strict arg handle,data
  if \handles~hasIndex(handle) then return .MasLivePathReply~new(.false,'BAD_HANDLE')
  return .MasLivePathReply~new(.true,'OK',handles[handle]~write(data))
::method append public
  expose handles
  use strict arg handle,data
  if \handles~hasIndex(handle) then return .MasLivePathReply~new(.false,'BAD_HANDLE')
  return .MasLivePathReply~new(.true,'OK',handles[handle]~append(data))
::method close public
  expose handles
  use strict arg handle
  if \handles~hasIndex(handle) then return .MasLivePathReply~new(.false,'BAD_HANDLE')
  ref=handles[handle]~close; handles~remove(handle)
  return .MasLivePathReply~new(.true,'OK',ref)
::method list public
  expose service
  use strict arg path
  return .MasLivePathReply~new(.true,'OK',service~list(path))

::class MasLiveGateway public
::method init public
  expose services logger pathStore pathService observer identityResolver
  use strict arg evidenceFile='', root='', observerArg=.nil, identityResolverArg=.nil, servicesArg=.nil
  if servicesArg==.nil then services=.MasVirtualServices~new
  else services=servicesArg
  logger=.MasGatewayLogger~new(evidenceFile)
  if root='' then root='/tmp/mas-live-path-'||random(100000,999999)
  pathStore=.MasLivePathStore~new(root)
  pathService=.MasLivePathService~new(pathStore)
  observer=observerArg
  identityResolver=identityResolverArg
::attribute logger get
::attribute services get
::attribute observer get
::attribute identityResolver get
::method serve public
  expose services logger pathService observer
  use strict arg socket
  session=.nil
  if observer<>.nil then do; observer~sessionOpened; observer~serviceHealthy; end
  do forever
    header=.MasSocketIO~readExact(socket,.MasWire~HEADER_LENGTH)
    if header==.nil then leave
    h=.MasWire~decodeHeader(header)
    payload=''
    if h['payload_length']>0 then do
      payload=.MasSocketIO~readExact(socket,h['payload_length'])
      if payload==.nil then leave
    end
    logger~emit('REQUEST',h['session_id'],h['request_id'],h['operation'],0,0,'payload='||payload~length)
    if observer<>.nil then do
      observer~frameReceived(h['operation'],.MasWire~HEADER_LENGTH+payload~length)
      observer~requestAccepted(h['operation'])
    end
    if session==.nil then session=.MasGatewaySession~new(h['session_id'],.MasLivePathDispatcher~new(pathService))
    response=self~dispatch(session,h,payload)
    .MasSocketIO~writeAll(socket,response)
    if observer<>.nil then observer~frameSent(h['operation'],response~length)
    if h['operation']=.MasWire~OP_DISCONNECT then leave
  end

::method dispatch private
  expose services logger observer identityResolver
  use strict arg session,h,payload
  status=0; reason=0; responsePayload=''; responseOp=h['operation']; vals=.array~new
  signal on syntax name dispatchError
  if payload<>'' then vals=.MasWire~decodeValues(payload)
  op=h['operation']
  select
    when op=.MasWire~OP_HELLO then do
      responseOp=.MasWire~OP_ACCEPT
      responsePayload=.MasWire~uint32('MAX_FRAME',.MasWire~MAX_FRAME)||.MasWire~uint32('GUEST_CCSID',37)
    end
    when op=.MasWire~OP_PING then do
      v=.MasWire~findValue(vals,'ECHO'); if v==.nil then responsePayload=.MasWire~bytes('ECHO','')
      else responsePayload=.MasWire~bytes('ECHO',v~value)
    end
    when op=.MasWire~OP_QOPEN then do
      name=self~char(vals,'NAME'); id=session~addHandle('QUEUE',name)
      responsePayload=.MasWire~handle('HANDLE',id)
    end
    when op=.MasWire~OP_QPUT then do
      id=self~u32(vals,'HANDLE'); q=session~getHandle(id,'QUEUE')~value
      depth=services~queueProvider~put(q,self~bytes(vals,'DATA'))
      responsePayload=.MasWire~uint32('DEPTH',depth)
    end
    when op=.MasWire~OP_QGET then do
      id=self~u32(vals,'HANDLE'); q=session~getHandle(id,'QUEUE')~value; b=services~queueProvider~get(q)
      if b==.nil then b=''
      responsePayload=.MasWire~bytes('DATA',b)
    end
    when op=.MasWire~OP_QDEPTH then do
      id=self~u32(vals,'HANDLE'); q=session~getHandle(id,'QUEUE')~value
      responsePayload=.MasWire~uint32('DEPTH',services~queueProvider~depth(q))
    end
    when op=.MasWire~OP_QCLOSE then session~dropHandle(self~u32(vals,'HANDLE'))

    when op=.MasWire~OP_DBOPEN then do
      name=self~char(vals,'NAME'); id=session~addHandle('DATABASE',name)
      responsePayload=.MasWire~handle('HANDLE',id)
    end
    when op=.MasWire~OP_DBPUT then do
      id=self~u32(vals,'HANDLE'); db=session~getHandle(id,'DATABASE')~value
      ignore=services~databaseProvider~put(db,self~bytes(vals,'KEY'),self~bytes(vals,'VALUE'))
      responsePayload=.MasWire~uint32('STORED',1)
    end
    when op=.MasWire~OP_DBGET then do
      id=self~u32(vals,'HANDLE'); db=session~getHandle(id,'DATABASE')~value
      b=services~databaseProvider~get(db,self~bytes(vals,'KEY')); if b==.nil then b=''
      responsePayload=.MasWire~bytes('VALUE',b)
    end
    when op=.MasWire~OP_DBDELETE then do
      id=self~u32(vals,'HANDLE'); db=session~getHandle(id,'DATABASE')~value
      ok=services~databaseProvider~delete(db,self~bytes(vals,'KEY'))
      responsePayload=.MasWire~uint32('DELETED',ok)
    end
    when op=.MasWire~OP_DBCLOSE then session~dropHandle(self~u32(vals,'HANDLE'))

    when op=.MasWire~OP_MAILINIT then do
      id=session~addHandle('IMAP','IMAP')
      responsePayload=.MasWire~handle('HANDLE',id)
    end
    when op=.MasWire~OP_MAILLIST then do
      ignore=session~getHandle(self~u32(vals,'HANDLE'),'IMAP')
      names=services~imapProvider~listMailboxes; text=''
      do n over names; if text<>'' then text||='0a'x; text||=n; end
      responsePayload=.MasWire~bytes('MAILBOXES',text)
    end
    when op=.MasWire~OP_MAILOPEN then do
      ignore=session~getHandle(self~u32(vals,'HANDLE'),'IMAP')
      m=services~imapProvider~get(self~char(vals,'MAILBOX'),self~u32(vals,'UIDVALIDITY'),self~u32(vals,'UID'))
      if m==.nil then raise syntax 88.900 array('MAIL_NOT_FOUND')
      mid=session~addHandle('MESSAGE',m); responsePayload=.MasWire~handle('MESSAGE',mid)
    end
    when op=.MasWire~OP_MAILHEAD then do
      m=session~getHandle(self~u32(vals,'MESSAGE'),'MESSAGE')~value
      responsePayload=.MasWire~bytes('HEADERS',m~headers)
    end
    when op=.MasWire~OP_MAILBODY then do
      m=session~getHandle(self~u32(vals,'MESSAGE'),'MESSAGE')~value
      responsePayload=.MasWire~bytes('BODY',m~body)
    end
    when op=.MasWire~OP_MAILCLOS then session~dropHandle(self~u32(vals,'MESSAGE'))
    when op=.MasWire~OP_MAILTERM then session~dropHandle(self~u32(vals,'HANDLE'))

    when op=.MasWire~OP_MAILNEW then do
      d=.MasOutboundDraft~new; id=session~addHandle('SMTP',d); responsePayload=.MasWire~handle('HANDLE',id)
    end
    when op=.MasWire~OP_MAILFROM then session~getHandle(self~u32(vals,'HANDLE'),'SMTP')~value~sender=self~char(vals,'ADDRESS')
    when op=.MasWire~OP_MAILTO then session~getHandle(self~u32(vals,'HANDLE'),'SMTP')~value~addRecipient(self~char(vals,'ADDRESS'))
    when op=.MasWire~OP_MAILTEXT then session~getHandle(self~u32(vals,'HANDLE'),'SMTP')~value~body=self~bytes(vals,'DATA')
    when op=.MasWire~OP_MAILSIGN then do
      d=session~getHandle(self~u32(vals,'HANDLE'),'SMTP')~value
      if services~smtpProvider~hasMethod('signFor') then do
        identity=self~trustedIdentity(session,h)
        result=services~smtpProvider~signFor(identity~principalId,d)
        if \result~ok then raise syntax 88.900 array('MAILSIGN:'||result~code)
      end
      else do
        ok=(self~u32(vals,'VERIFIED')<>0); d~signaturePresent=.true; d~signatureVerified=ok; d~identityMatches=ok
      end
    end
    when op=.MasWire~OP_MAILSEND then do
      d=session~getHandle(self~u32(vals,'HANDLE'),'SMTP')~value
      if services~smtpProvider~hasMethod('submitFor') then do
        identity=self~trustedIdentity(session,h)
        result=services~smtpProvider~submitFor(identity~principalId,session~sessionId,d)
        if \result~ok then raise syntax 88.900 array('MAILSEND:'||result~code)
        responsePayload=.MasWire~char('STATUS',result~code)
      end
      else do
        d~emailSendAuthorized=(self~u32(vals,'AUTHORIZED')<>0)
        d~egressPermitted=(self~u32(vals,'EGRESS')<>0)
        result=services~smtpProvider~submit(d)
        responsePayload=.MasWire~char('STATUS',result)
      end
    end

    when op=.MasWire~OP_PATHOPEN then do
      r=session~pathDispatcher~open(self~char(vals,'PATH'),self~char(vals,'OPTS'),self~char(vals,'FILEDATA'))
      id=session~addHandle('PATH',r~value); responsePayload=.MasWire~handle('HANDLE',id)
    end
    when op=.MasWire~OP_PATHWRITE then do
      id=self~u32(vals,'HANDLE'); hid=session~getHandle(id,'PATH')~value
      r=session~pathDispatcher~write(hid,self~bytes(vals,'DATA')); responsePayload=.MasWire~uint32('COUNT',r~value)
    end
    when op=.MasWire~OP_PATHAPPEND then do
      id=self~u32(vals,'HANDLE'); hid=session~getHandle(id,'PATH')~value
      r=session~pathDispatcher~append(hid,self~bytes(vals,'DATA')); responsePayload=.MasWire~uint32('COUNT',r~value)
    end
    when op=.MasWire~OP_PATHREAD then do
      id=self~u32(vals,'HANDLE'); hid=session~getHandle(id,'PATH')~value
      r=session~pathDispatcher~read(hid); responsePayload=.MasWire~bytes('DATA',r~value)
    end
    when op=.MasWire~OP_PATHCLOSE then do
      id=self~u32(vals,'HANDLE'); hid=session~getHandle(id,'PATH')~value
      r=session~pathDispatcher~close(hid); session~dropHandle(id); responsePayload=.MasWire~char('REF',r~value~string)
    end
    when op=.MasWire~OP_DISCONNECT then nop
    otherwise do
      status=8; reason=1537
    end
  end
  logger~emit('COMMIT',h['session_id'],h['request_id'],op,status,reason,'response='||responsePayload~length)
  if observer<>.nil then observer~requestCompleted(op,status)
  return .MasWire~encodeFrame(h['session_id'],h['request_id'],h['object_handle'],responseOp,h['flags'],status,reason,responsePayload)

dispatchError:
  status=20; reason=1537
  details=condition('D')
  logger~emit('ERROR',h['session_id'],h['request_id'],h['operation'],status,reason,details)
  if observer<>.nil then observer~requestFailed(h['operation'],status)
  return .MasWire~encodeFrame(h['session_id'],h['request_id'],h['object_handle'],h['operation'],h['flags'],status,reason,.MasWire~char('ERROR',details))

::method trustedIdentity private
  expose identityResolver
  use strict arg session,h
  if identityResolver==.nil then raise syntax 88.900 array('MAS_PRINCIPAL_REQUIRED')
  context=.directory~new
  context['session_id']=session~sessionId
  context['request_id']=h['request_id']
  context['operation']=h['operation']
  identity=identityResolver~resolve(session~sessionId,context)
  if identity==.nil then raise syntax 88.900 array('MAS_PRINCIPAL_REQUIRED')
  if \identity~hasMethod('principalId') then raise syntax 88.900 array('MAS_PRINCIPAL_CONTRACT')
  if identity~principalId~string~strip='' then raise syntax 88.900 array('MAS_PRINCIPAL_REQUIRED')
  return identity

::method value private
  use strict arg vals, tag
  v=.MasWire~findValue(vals,tag)
  if v==.nil then raise syntax 88.900 array('MAS_MISSING_FIELD:' tag)
  return v
::method u32 private
  use strict arg vals, tag
  return self~value(vals,tag)~asUint32
::method bytes private
  use strict arg vals, tag
  return self~value(vals,tag)~value
::method char private
  use strict arg vals, tag
  return self~value(vals,tag)~asChar

::requires 'MasWire.cls'
::requires 'MasVirtualServices.cls'
::requires 'LoggingCore.cls'
::requires 'MasHostIdentity.cls'
