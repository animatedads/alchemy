/* Durable SMTP delivery/spool integration for Storage Fabric.
 * Message bytes are stored once. Mailbox/quarantine/spool are projections.
 */
::class SmtpDurableBuild public
::constant API "smtp.durable.delivery/0.1"

::class SmtpSpoolState public
::constant PENDING "PENDING"
::constant DISPATCHING "DISPATCHING"
::constant DELIVERED "DELIVERED"
::constant DEFERRED "DEFERRED"
::constant FAILED "FAILED"
::constant HELD "HELD"

::class SmtpSpoolRecord public
::attribute spoolId get
::attribute objectId get
::attribute principalId get
::attribute recipients get
::attribute state
::attribute attempts
::attribute lastCode
::attribute lastDetail
::attribute nextAttemptAt
::attribute evidenceRef get
::method init
  expose spoolId objectId principalId recipients state attempts lastCode lastDetail nextAttemptAt evidenceRef
  use strict arg spoolIdArg,objectIdArg,principalArg,recipientsArg,evidenceArg=""
  spoolId=spoolIdArg~string; objectId=objectIdArg~string; principalId=principalArg~string
  recipients=recipientsArg; state=.SmtpSpoolState~PENDING; attempts=0; lastCode=""; lastDetail=""; nextAttemptAt=""; evidenceRef=evidenceArg~string

::class StorageFabricSmtpStore public
::method init
  expose root catalogue providerId capacityDomainId cataloguePath sequence
  use strict arg rootArg,catalogueArg,providerArg="smtp-local",domainArg="smtp-mail",cataloguePathArg=""
  root=rootArg~string; catalogue=catalogueArg; providerId=providerArg~string; capacityDomainId=domainArg~string
  cataloguePath=cataloguePathArg~string; sequence=0
  if root="" then raise syntax 88.900 array("SMTP durable store root is mandatory")
  if catalogue==.nil then raise syntax 88.900 array("StorageCatalogue is mandatory")
  call SysMkDir root
  call SysMkDir root||"/objects"
  call SysMkDir root||"/meta"

::method persist
  expose root catalogue providerId capacityDomainId cataloguePath sequence
  use strict arg session,message,purpose="MESSAGE"
  existing=message~metadata["storage.objectId"]
  if existing<>.nil then if existing~string<>"" then do
    o=catalogue~get(existing~string)
    if o<>.nil then return .SmtpResult~success(existing~string,"STORED_REPLAY")
  end
  sequence+=1
  id="smtp-"||date("S")||"-"||time("S")||"-"||session~sessionId~translate("_"," :/\\")||"-"||sequence
  path=root||"/objects/"||id||".eml"
  tmp=path||".tmp"
  call charout tmp,message~content
  call charout tmp
  if stream(tmp,"c","query size")<>message~content~length then do
    call SysFileDelete tmp
    return .SmtpResult~failure("STORAGE_WRITE_SIZE_MISMATCH")
  end
  check=charin(tmp,1,message~content~length)
  call stream tmp,"c","close"
  if check<>message~content then do
    call SysFileDelete tmp
    return .SmtpResult~failure("STORAGE_READBACK_MISMATCH")
  end
  call SysFileMove tmp,path
  if result<>0 then return .SmtpResult~failure("STORAGE_COMMIT_FAILED",result)

  ref=.StorageRef~new(id)
  obj=.StorageObject~new(ref,id,message~content~length,"message/rfc822")
  loc=.StorageLocation~new(providerId,path,capacityDomainId,.StorageLocationState~AVAILABLE,"",.true,"smtp-byte-readback",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"")
  obj~addLocation(loc)
  obj~setEA(.StorageEA~new("smtp","purpose",purpose,"STRING","smtp.server/0.1","smtp"))
  obj~setEA(.StorageEA~new("smtp","mailFrom",message~envelope~mailFrom,"STRING","smtp.server/0.1","smtp"))
  obj~setEA(.StorageEA~new("smtp","principalId",session~principalId,"STRING","smtp.server/0.1","smtp"))
  do k over message~metadata~allIndexes
    if k~left(10)="signature." | k~left(7)="policy." | k~left(6)="model." | k="delivery.mailbox" then
      obj~setEA(.StorageEA~new("smtp",k,message~metadata[k],"STRING","smtp.event/0.1","smtp"))
  end
  catalogue~put(obj)
  message~metadata["storage.objectId"]=id
  message~metadata["storage.location"]=path
  self~writeMeta(id,session,message)
  if cataloguePath<>"" then catalogue~save(cataloguePath)
  return .SmtpResult~success(id,"STORED")

::method addMembership
  expose root
  use strict arg objectId,recipient,mailbox
  line=self~enc(objectId)||"09"x||self~enc(recipient)||"09"x||self~enc(mailbox)
  w=self~appendJournalLine(root||"/memberships.tsv",line,"MEMBERSHIP_WRITE_FAILED")
  if \w~ok then return w
  return .SmtpResult~success(objectId,"MEMBERSHIP_ADDED")

::method enqueue
  expose root
  use strict arg spoolId,objectId,session,recipients,evidenceRef=""
  recips=""
  do i=1 to recipients~items
    if i>1 then recips=recips||","; recips=recips||recipients[i]
  end
  line=self~enc(spoolId)||"09"x||self~enc(objectId)||"09"x||self~enc(session~principalId)||"09"x||self~enc(recips)||"09"x||.SmtpSpoolState~PENDING||"09"x||"0"||"09"x||self~enc(evidenceRef)
  w=self~appendJournalLine(root||"/spool.tsv",line,"SPOOL_ENQUEUE_WRITE_FAILED")
  if \w~ok then return w
  return .SmtpResult~success(spoolId,"SPOOLED")

::method loadSpool
  expose root
  use strict arg spoolId
  p=root||"/spool.tsv"
  if stream(p,"c","query exists")="" then return .SmtpResult~failure("SPOOL_NOT_FOUND",spoolId)
  found=.nil
  do while lines(p)>0
    l=linein(p); fields=self~splitTabs(l)
    if fields~items<7 then iterate
    if self~dec(fields[1])<>spoolId then iterate
    recips=.array~new; rs=self~dec(fields[4])
    if rs<>"" then do i=1 to words(changestr(",",rs," ")); recips~append(word(changestr(",",rs," "),i)); end
    found=.SmtpSpoolRecord~new(self~dec(fields[1]),self~dec(fields[2]),self~dec(fields[3]),recips,self~dec(fields[7]))
    found~state=fields[5]; found~attempts=fields[6]
  end
  call stream p,"c","close"
  if found==.nil then return .SmtpResult~failure("SPOOL_NOT_FOUND",spoolId)
  j=root||"/spool-state.tsv"
  if stream(j,"c","query exists")<>"" then do
    do while lines(j)>0
      l=linein(j); fields=self~splitTabs(l)
      if fields~items<7 then iterate
      if self~dec(fields[1])<>spoolId then iterate
      found~state=fields[2]; found~attempts=fields[3]; found~lastCode=self~dec(fields[4]); found~lastDetail=self~dec(fields[5]); found~nextAttemptAt=self~dec(fields[6])
    end
    call stream j,"c","close"
  end
  return .SmtpResult~success(found,"SPOOL_LOADED")

::method transitionSpool
  expose root
  use strict arg spoolId,state,attempts,lastCode="",lastDetail="",nextAttemptAt=""
  allowed=" PENDING DISPATCHING DELIVERED DEFERRED FAILED HELD "
  if pos(" "||state||" ",allowed)=0 then return .SmtpResult~failure("SPOOL_STATE_INVALID",state)
  l=self~enc(spoolId)||"09"x||state||"09"x||attempts||"09"x||self~enc(lastCode)||"09"x||self~enc(lastDetail)||"09"x||self~enc(nextAttemptAt)||"09"x||self~enc(date("S")||"T"||time("N"))
  w=self~appendJournalLine(root||"/spool-state.tsv",l,"SPOOL_STATE_WRITE_FAILED")
  if \w~ok then return w
  return .SmtpResult~success(spoolId,"SPOOL_STATE_RECORDED")

::method recipientStates
  expose root
  use strict arg spoolId,recipients
  d=.directory~new
  do r over recipients; d[r~string]=.SmtpSpoolState~PENDING; end
  p=root||"/spool-recipient-state.tsv"
  if stream(p,"c","query exists")="" then return d
  do while lines(p)>0
    l=linein(p); f=self~splitTabs(l)
    if f~items<7 then iterate
    if self~dec(f[1])<>spoolId then iterate
    recipient=self~dec(f[2]); info=.directory~new
    info["state"]=f[3]; info["attempts"]=f[4]; info["code"]=self~dec(f[5]); info["detail"]=self~dec(f[6]); info["nextAttemptAt"]=self~dec(f[7])
    d[recipient]=info
  end
  call stream p,"c","close"
  return d

::method transitionRecipient
  expose root
  use strict arg spoolId,recipient,state,attempts,lastCode="",lastDetail="",nextAttemptAt=""
  allowed=" PENDING DISPATCHING DELIVERED DEFERRED FAILED HELD "
  if pos(" "||state||" ",allowed)=0 then return .SmtpResult~failure("RECIPIENT_STATE_INVALID",state)
  l=self~enc(spoolId)||"09"x||self~enc(recipient)||"09"x||state||"09"x||attempts||"09"x||self~enc(lastCode)||"09"x||self~enc(lastDetail)||"09"x||self~enc(nextAttemptAt)||"09"x||self~enc(date("S")||"T"||time("N"))
  w=self~appendJournalLine(root||"/spool-recipient-state.tsv",l,"RECIPIENT_STATE_WRITE_FAILED")
  if \w~ok then return w
  return .SmtpResult~success(recipient,"RECIPIENT_STATE_RECORDED")

::method recordBounce
  expose root
  use strict arg spoolId,objectId,recipient,code,detail
  l=self~enc(spoolId)||"09"x||self~enc(objectId)||"09"x||self~enc(recipient)||"09"x||self~enc(code)||"09"x||self~enc(detail)||"09"x||self~enc(date("S")||"T"||time("N"))
  w=self~appendJournalLine(root||"/bounce.tsv",l,"BOUNCE_WRITE_FAILED")
  if \w~ok then return w
  return .SmtpResult~success(recipient,"BOUNCE_EVIDENCE_RECORDED")

::method appendJournalLine private
  use strict arg path,line,code
  rc=lineout(path,line)
  if rc<>0 then do
    ignore=lineout(path)
    return .SmtpResult~failure(code,"lineout rc="||rc)
  end
  rc=lineout(path)
  if rc<>0 then return .SmtpResult~failure(code,"close rc="||rc)
  return .SmtpResult~success(path,"JOURNAL_WRITE_OK")

::method splitTabs private
  use strict arg line
  a=.array~new; rest=line
  do forever
    p=pos("09"x,rest)
    if p=0 then do; a~append(rest); leave; end
    a~append(substr(rest,1,p-1)); rest=substr(rest,p+1)
  end
  return a

::method loadMessage
  expose root
  use strict arg objectId
  path=root||"/objects/"||objectId||".eml"
  if stream(path,"c","query exists")="" then return .SmtpResult~failure("STORAGE_OBJECT_NOT_FOUND",objectId)
  size=stream(path,"c","query size")
  content=charin(path,1,size); call stream path,"c","close"
  meta=self~readMeta(objectId)
  env=.SmtpEnvelope~new(meta["mailFrom"])
  recips=meta["recipients"]
  if recips<>.nil then if recips<>"" then do i=1 to words(changestr(",",recips," ")); env~addRecipient(word(changestr(",",recips," "),i)); end
  msg=.SmtpMessage~new(env,content)
  do k over meta~allIndexes; msg~metadata[k]=meta[k]; end
  return .SmtpResult~success(msg,"LOADED")

::method writeMeta private
  expose root
  use strict arg id,session,message
  p=root||"/meta/"||id||".tsv"
  recips=""
  do i=1 to message~envelope~recipients~items
    if i>1 then recips=recips||","; recips=recips||message~envelope~recipients[i]
  end
  call lineout p,"mailFrom"||"09"x||self~enc(message~envelope~mailFrom)
  call lineout p,"recipients"||"09"x||self~enc(recips)
  call lineout p,"sessionId"||"09"x||self~enc(session~sessionId)
  call lineout p,"principalId"||"09"x||self~enc(session~principalId)
  call lineout p,"authenticated"||"09"x||session~authenticated
  call lineout p,"tlsActive"||"09"x||session~tlsActive
  do k over message~metadata~allIndexes; call lineout p,self~enc(k)||"09"x||self~enc(message~metadata[k]); end
  call lineout p
  return .true

::method readMeta private
  expose root
  use strict arg id
  d=.directory~new; p=root||"/meta/"||id||".tsv"
  if stream(p,"c","query exists")="" then return d
  do while lines(p)>0
    l=linein(p); q=pos("09"x,l); if q=0 then iterate
    d[self~dec(substr(l,1,q-1))]=self~dec(substr(l,q+1))
  end
  call stream p,"c","close"; return d

::method enc private
  use strict arg s
  return .StorageCodec~enc(s)
::method dec private
  use strict arg s
  return .StorageCodec~dec(s)

::class StorageFabricSmtpDeliveryProvider subclass SmtpDeliveryProvider public
::method init
  expose store localDomains publisher sequence
  use strict arg storeArg,localDomainsArg,publisherArg=.nil
  store=storeArg; localDomains=localDomainsArg; publisher=publisherArg; sequence=0
::method classifyRecipients
  expose localDomains
  use strict arg message
  d=.directory~new; local=.array~new; relay=.array~new
  do r over message~envelope~recipients
    domain=self~domainOf(r); isLocal=.false
    do x over localDomains; if domain~caselessEquals(x~string) then isLocal=.true; end
    if isLocal then local~append(r); else relay~append(r)
  end
  d["local"]=local; d["relay"]=relay; return d
::method deliverLocal
  expose store
  use strict arg session,message,recipients,mailbox="INBOX"
  p=store~persist(session,message,"INBOUND")
  if \p~ok then return p
  do r over recipients
    m=store~addMembership(p~value,r,mailbox)
    if \m~ok then return m
  end
  return .SmtpResult~success(p~value,"DELIVERED_DURABLE")
::method quarantine
  expose store
  use strict arg session,message,reason
  message~metadata["quarantine.reason"]=reason
  p=store~persist(session,message,"QUARANTINE")
  if \p~ok then return p
  do r over message~envelope~recipients; ignore=store~addMembership(p~value,r,"QUARANTINE"); end
  return .SmtpResult~success(p~value,"QUARANTINED_DURABLE")
::method relaySigned
  expose store publisher sequence
  use strict arg session,message,recipients,signatureEvidence
  p=store~persist(session,message,"OUTBOUND")
  if \p~ok then return p
  sequence+=1; spoolId="smtp-out-"||session~sessionId||"-"||sequence
  q=store~enqueue(spoolId,p~value,session,recipients,signatureEvidence~certificateId)
  if \q~ok then return q
  message~metadata["spool.id"]=spoolId
  if publisher<>.nil then do
    pub=publisher~publish(spoolId,p~value,session~principalId)
    if pub==.nil | \pub~ok then return .SmtpResult~failure("OUTBOUND_QUEUE_PUBLISH_FAILED")
  end
  return .SmtpResult~success(spoolId,"SPOOLED_DURABLE")
::method domainOf private
  use strict arg address
  s=address~string~strip; p=lastpos("@",s); if p=0 then return ""; return substr(s,p+1)~strip("B","<>")

::requires "SmtpCore.cls"
::requires "StorageFabric.cls"
