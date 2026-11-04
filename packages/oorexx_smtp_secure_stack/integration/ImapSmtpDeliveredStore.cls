/* IMAP server mailbox provider over the SMTP durable local-mail store.
 *
 * SMTP remains the authority that creates INBOX / INBOX-UNSIGNED membership.
 * IMAP is a read-side projection over the same immutable RFC822 object and
 * membership journal.  No second message body is created here.
 */
::class ImapSmtpDeliveredStoreBuild public
::constant API "imap.smtp.delivered-store/0.1"
::constant VERSION "0.1-dev11-pre1"

::class ImapSmtpDeliveredMailboxProvider subclass ImapMailboxProvider public
::method init
  expose root recipient
  use strict arg rootArg,recipientArg
  root=rootArg~string
  recipient=recipientArg~string~strip
  if root="" then raise syntax 88.900 array("IMAP SMTP store root is required")
  if recipient="" then raise syntax 88.900 array("IMAP SMTP recipient identity is required")

::method capabilities
  return .array~of("NAMESPACE","X-ALCHEMY-SMTP-STORE")

::method namespace
  return .ImapServerResult~success(.ImapServerNamespace~new("","/"),"SMTP_DELIVERED_NAMESPACE")

::method listMailboxes
  use strict arg reference="",pattern="*",subscribedOnly=.false
  out=.array~new
  do name over .array~of("INBOX","INBOX-UNSIGNED")
    if self~matches(name,pattern) then do
      role="SIGNED_INBOX"; if name="INBOX-UNSIGNED" then role="UNSIGNED_INBOX"
      out~append(.ImapServerMailboxDescriptor~new(name,"/","\\NoInferiors",role,.true,.true))
    end
  end
  return out

::method status
  use strict arg mailbox
  return self~snapshotResult(mailbox,.true)

::method select
  use strict arg mailbox,readOnly=.false
  return self~snapshotResult(mailbox,.true)

::method close
  use strict arg mailbox,expungeDeleted=.false
  if \self~supportedMailbox(mailbox) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if expungeDeleted then return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY","SMTP-delivered membership cannot be expunged by dev11-pre1")
  return .ImapServerResult~success(.true,"SMTP_DELIVERED_CLOSE")

::method messageRefs
  expose root recipient
  use strict arg mailbox
  name=mailbox~string~strip~upper
  if \self~supportedMailbox(name) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  path=root||"/memberships.tsv"
  out=.array~new; seen=.directory~new
  if stream(path,"C","QUERY EXISTS")="" then return .ImapServerResult~success(out,"SMTP_DELIVERED_EMPTY")
  do while lines(path)>0
    line=linein(path)
    fields=.StorageCodec~splitTabs(line)
    if fields~items<3 then iterate
    objectId=.StorageCodec~dec(fields[1])
    memberRecipient=.StorageCodec~dec(fields[2])
    memberMailbox=.StorageCodec~dec(fields[3])~upper
    if \memberRecipient~caselessEquals(recipient) then iterate
    if memberMailbox<>name then iterate
    if seen[objectId]==.nil then do
      out~append(objectId)
      seen[objectId]=.true
    end
  end
  call stream path,"C","CLOSE"
  return .ImapServerResult~success(out,"SMTP_DELIVERED_REFS")

::method readMessage
  expose root
  use strict arg objectId
  id=objectId~string
  if id="" then return .ImapServerResult~failure("MESSAGE_ID_REQUIRED")
  if verify(id,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")<>0 then return .ImapServerResult~failure("MESSAGE_ID_INVALID")
  path=root||"/objects/"||id||".eml"
  if stream(path,"C","QUERY EXISTS")="" then return .ImapServerResult~failure("MESSAGE_NOT_FOUND",id)
  size=stream(path,"C","QUERY SIZE")
  data=charin(path,1,size)
  call stream path,"C","CLOSE"
  return .ImapServerResult~success(data,"SMTP_DELIVERED_MESSAGE")

::method snapshotResult private
  use strict arg mailbox,readOnly=.true
  name=mailbox~string~strip~upper
  if \self~supportedMailbox(name) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  refs=self~messageRefs(name)
  if \refs~ok then return refs
  count=refs~value~items
  unseen=count; firstUnseen=0
  if count>0 then firstUnseen=1
  uidNext=count+1
  modseq=count+1
  snap=.ImapServerMailboxSnapshot~new(name,count,0,unseen,firstUnseen,"1",uidNext~string,modseq~string,modseq~string,.true)
  return .ImapServerResult~success(snap,"SMTP_DELIVERED_SNAPSHOT")

::method supportedMailbox private
  use strict arg mailbox
  name=mailbox~string~strip~upper
  return name="INBOX" | name="INBOX-UNSIGNED"

::method matches private
  use strict arg name,pattern
  p=pattern~string
  if p="*" | p="%" then return .true
  return name~caselessEquals(p)

::requires "ImapServer.cls"
::requires "StorageFabric.cls"
