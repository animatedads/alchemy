/* ooRexx IMAP -> Storage Fabric projection bridge.
 *
 * This module consumes Storage Fabric's published storage.fabric/0.1 and
 * storage.fabric.streaming/0.1 contracts.  It does not modify or fork Storage
 * Fabric.  Durable IMAP identity is account-key + mailbox + UIDVALIDITY + UID;
 * friendly namespace paths are projections only.
 */

::class ImapStorageMessageRecord public
::attribute accountKey get
::attribute mailbox get
::attribute uidValidity get
::attribute uid get
::attribute sizeBytes get
::attribute subject get
::attribute fromAddress get
::attribute internalDate get
::attribute flags get
::attribute messageId get
::method init
  expose accountKey mailbox uidValidity uid sizeBytes subject fromAddress internalDate flags messageId
  use strict arg accountArg, mailboxArg, uidValidityArg, uidArg, sizeArg=0, subjectArg="", fromArg="", internalDateArg="", flagsArg="", messageIdArg=""
  accountKey=accountArg~string~strip
  mailbox=mailboxArg~string
  uidValidity=uidValidityArg~string~strip
  uid=uidArg~string~strip
  sizeBytes=sizeArg+0
  subject=subjectArg~string
  fromAddress=fromArg~string
  internalDate=internalDateArg~string
  flags=flagsArg~string
  messageId=messageIdArg~string
  if accountKey="" then raise syntax 88.900 array("IMAP_STORAGE_ACCOUNT_KEY_REQUIRED")
  if mailbox="" then raise syntax 88.900 array("IMAP_STORAGE_MAILBOX_REQUIRED")
  if datatype(uidValidity,"W")=0 | uidValidity+0<1 then raise syntax 88.900 array("IMAP_STORAGE_UIDVALIDITY_REQUIRED",uidValidity)
  if datatype(uid,"W")=0 | uid+0<1 then raise syntax 88.900 array("IMAP_STORAGE_UID_REQUIRED",uid)
  if sizeBytes<0 then raise syntax 88.900 array("IMAP_STORAGE_SIZE_INVALID",sizeBytes)
::method objectId
  expose accountKey mailbox uidValidity uid
  return "imap:"||self~escapeIdentity(accountKey)||":"||self~escapeIdentity(mailbox)||":"||uidValidity||":"||uid
::method storageRef
  return .StorageRef~new(self~objectId)
::method displayName
  expose uid subject fromAddress
  s=subject~strip
  if s="" then s="(no subject)"
  f=fromAddress~strip
  if f="" then f="unknown sender"
  name="IDX"||uid||" "||s||" <"||f||">"
  name=self~safeName(name)
  if name~length>220 then name=name~left(220)
  return name
::method storageObject
  expose accountKey mailbox uidValidity uid sizeBytes subject fromAddress internalDate flags messageId
  use strict arg providerId
  p=providerId~string~strip
  if p="" then raise syntax 88.900 array("IMAP_STORAGE_PROVIDER_ID_REQUIRED")
  obj=.StorageObject~new(self~storageRef,self~displayName,sizeBytes,"message/rfc822")
  locator="mailbox="||self~escapeIdentity(mailbox)||";uidvalidity="||uidValidity||";uid="||uid
  obj~addLocation(.StorageLocation~new(p,locator,"",.StorageLocationState~AVAILABLE,"",.false,"",.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE,""))
  provenance="provider="||p||";mailbox="||self~escapeIdentity(mailbox)||";uidvalidity="||uidValidity||";uid="||uid
  obj~setEA(.StorageEA~new("imap","account-key",accountKey,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","mailbox",mailbox,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","uidvalidity",uidValidity,"INTEGER",provenance,p))
  obj~setEA(.StorageEA~new("imap","uid",uid,"INTEGER",provenance,p))
  obj~setEA(.StorageEA~new("imap","subject",subject,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","from",fromAddress,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","internal-date",internalDate,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","flags",flags,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","message-id",messageId,"STRING",provenance,p))
  obj~setEA(.StorageEA~new("imap","size",sizeBytes,"INTEGER",provenance,p))
  return obj
::method escapeIdentity private
  use strict arg value
  safe="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-@"
  out=""
  do i=1 to value~length
    c=value~substr(i,1)
    if safe~pos(c)>0 then out=out||c
    else out=out||"%"||c2x(c)
  end
  return out
::method safeName private
  use strict arg value
  out=""
  do i=1 to value~length
    c=value~substr(i,1)
    if c="/" | c="\\" | c=":" | c="00"x | c="0d"x | c="0a"x | c="09"x then c="_"
    out=out||c
  end
  return out~strip

::class ImapStorageNamespaceProjector public
::attribute providerId get
::attribute rootPath get
::method init
  expose providerId rootPath
  use strict arg providerArg, rootArg="/mail/inbox"
  providerId=providerArg~string~strip
  rootPath=.StoragePath~normalize(rootArg)
  if providerId="" then raise syntax 88.900 array("IMAP_STORAGE_PROVIDER_ID_REQUIRED")
::method bindMessage
  expose providerId rootPath
  use strict arg namespace, messageRecord
  if namespace==.nil then raise syntax 88.900 array("IMAP_STORAGE_NAMESPACE_REQUIRED")
  obj=messageRecord~storageObject(providerId)
  namespace~catalogue~put(obj)
  path=.StoragePath~join(rootPath,obj~displayName)
  namespace~bind(path,obj~ref,.StorageWritePolicy~READ_ONLY)
  return path
::method bindMessages
  use strict arg namespace, records
  answer=.array~new
  do r over records
    answer~append(self~bindMessage(namespace,r))
  end
  return answer
::method bindIndexResult
  use strict arg namespace, searchResult
  if searchResult==.nil then raise syntax 88.900 array("IMAP_STORAGE_INDEX_RESULT_REQUIRED")
  answer=.array~new
  do r over searchResult~hits
    sr=.ImapStorageMessageRecord~new(r~accountKey,r~mailbox,r~uidValidity,r~uid,r~sizeBytes,r~subject,r~fromAddress,r~internalDate,r~flags,r~messageId)
    answer~append(self~bindMessage(namespace,sr))
  end
  return answer

/* A bounded literal capture factory used by ranged StorageByteSource reads.
 * The announced IMAP literal may never exceed the requested Storage chunk. */
::class ImapStorageBoundedLiteralFactory public
::attribute maximum get
::method init
  expose maximum
  use strict arg maximumArg
  maximum=maximumArg+0
  if maximum<1 then raise syntax 88.900 array("IMAP_STORAGE_CAPTURE_BOUND_INVALID",maximum)
::method createLiteralSink
  expose maximum
  use strict arg length, record
  if length>maximum then raise syntax 88.900 array("IMAP_STORAGE_LITERAL_EXCEEDS_BOUND",length,maximum)
  return .ImapInlineLiteralSink~new

/* Provider-neutral ranged view of one immutable IMAP UID identity.
 * BODY.PEEK partial fetches preserve \\Seen and keep each read bounded. */
::class ImapStorageRawByteSource subclass StorageByteSource public
::attribute sizeBytes get
::attribute position get
::attribute opened get
::method init
  expose session accountKey mailbox uidValidity uid sizeBytes position opened
  use strict arg sessionArg, accountArg, mailboxArg, uidValidityArg, uidArg, sizeArg
  session=sessionArg
  accountKey=accountArg~string~strip
  mailbox=mailboxArg~string
  uidValidity=uidValidityArg~string~strip
  uid=uidArg~string~strip
  sizeBytes=sizeArg+0
  position=0; opened=.false
  if session==.nil then raise syntax 88.900 array("IMAP_STORAGE_SESSION_REQUIRED")
  if accountKey="" | mailbox="" then raise syntax 88.900 array("IMAP_STORAGE_IDENTITY_REQUIRED")
  if datatype(uidValidity,"W")=0 | uidValidity+0<1 then raise syntax 88.900 array("IMAP_STORAGE_UIDVALIDITY_REQUIRED")
  if datatype(uid,"W")=0 | uid+0<1 then raise syntax 88.900 array("IMAP_STORAGE_UID_REQUIRED")
  if sizeBytes<0 then raise syntax 88.900 array("IMAP_STORAGE_SIZE_INVALID")
::method resumeIdentity
  expose accountKey mailbox uidValidity uid sizeBytes
  record=.ImapStorageMessageRecord~new(accountKey,mailbox,uidValidity,uid,sizeBytes)
  return "IMAP_RAW_SOURCE|"||record~objectId||"|"||sizeBytes
::method openAt
  expose position opened sizeBytes
  use strict arg offsetArg=0
  offset=offsetArg+0
  if offset<0 | offset>sizeBytes then raise syntax 88.900 array("IMAP_STORAGE_OFFSET_OUTSIDE_MESSAGE",offset,sizeBytes)
  self~validateSelection
  position=offset; opened=.true
  return self
::method readChunk
  expose session uid sizeBytes position opened
  use strict arg maximumArg
  if \opened then raise syntax 88.900 array("IMAP_STORAGE_SOURCE_NOT_OPEN")
  self~validateSelection
  maximum=maximumArg+0
  if maximum<1 then raise syntax 88.900 array("IMAP_STORAGE_CHUNK_INVALID",maximum)
  if position>=sizeBytes then return .StorageByteChunk~new(position,"",.true)
  want=maximum
  remaining=sizeBytes-position
  if want>remaining then want=remaining
  start=position
  partial=position||"."||want
  factory=.ImapStorageBoundedLiteralFactory~new(want)
  result=session~uidFetchBodyPeek(uid,"",partial,factory)
  if \result~ok then raise syntax 88.900 array("IMAP_STORAGE_FETCH_FAILED",result~status,result~text)
  bytes=self~firstLiteral(result)
  if bytes==.nil then raise syntax 88.900 array("IMAP_STORAGE_FETCH_NO_LITERAL",uid,position,want)
  got=bytes~length
  if got<1 | got>want then raise syntax 88.900 array("IMAP_STORAGE_FETCH_BAD_LENGTH",got,want)
  position+=got
  return .StorageByteChunk~new(start,bytes,position>=sizeBytes)
::method close
  expose opened
  opened=.false
  return self
::method validateSelection private
  expose session mailbox uidValidity
  s=session~selectedState
  if s==.nil then raise syntax 88.900 array("IMAP_STORAGE_MAILBOX_NOT_SELECTED")
  if s~mailbox<>mailbox then raise syntax 88.900 array("IMAP_STORAGE_MAILBOX_CHANGED",mailbox,s~mailbox)
  if s~uidValidity~string<>uidValidity then raise syntax 88.900 array("IMAP_STORAGE_UIDVALIDITY_CHANGED",uidValidity,s~uidValidity)
  return .true
::method firstLiteral private
  use strict arg result
  do rec over result~untagged
    if rec~literalCount>0 then return rec~literalSegments[1]~bytes
  end
  return .nil

/* Semantic selector syntax is intentionally parsed here without claiming that
 * Storage Fabric dev13 natively understands semantic attributes.  dev13's FUSE
 * parser preserves an unknown final colon suffix as a named stream, so strings
 * such as ?subject and ?attachment:1:?filename can traverse that boundary
 * unchanged.  Resolution remains an IMAP/MIME/transform-provider concern. */
::class ImapStorageSemanticSelector public
::attribute original get
::attribute stages get
::method init
  expose original stages
  use strict arg valueArg
  original=valueArg~string
  if original~left(1)<>"?" then raise syntax 88.900 array("IMAP_STORAGE_SELECTOR_INVALID",original)
  stages=.array~new
  rest=original~substr(2)
  do while rest<>""
    p=rest~pos(":?")
    if p=0 then do; stages~append(rest); leave; end
    stages~append(rest~left(p-1))
    rest=rest~substr(p+2)
  end
  if stages~items=0 then raise syntax 88.900 array("IMAP_STORAGE_SELECTOR_EMPTY")
::method head
  expose stages
  return stages[1]
::method tailCount
  expose stages
  return stages~items-1
::method isAttachment
  return self~head~lower~left(11)="attachment:"
::method attachmentIndex
  if \self~isAttachment then return 0
  token=self~head~substr(12)
  if datatype(token,"W")=0 | token+0<1 then return 0
  return token+0

::requires "ImapSession.cls"
::requires "StorageFabric.cls"
::requires "StorageStreaming.cls"
