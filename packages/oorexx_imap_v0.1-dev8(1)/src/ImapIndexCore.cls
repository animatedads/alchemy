/* ooRexx IMAP local index contracts.
 *
 * Index data is a derived projection of IMAP authority.  It may be rebuilt.
 * The core classes deliberately have no database dependency; concrete stores
 * (for example NoSQLServer) plug in below this seam.
 */

::class ImapIndexRecord public
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
  if accountKey="" | mailbox="" then raise syntax 88.900 array("IMAP_INDEX_IDENTITY_REQUIRED")
  if datatype(uidValidity,"W")=0 | uidValidity+0<1 then raise syntax 88.900 array("IMAP_INDEX_UIDVALIDITY_INVALID",uidValidity)
  if datatype(uid,"W")=0 | uid+0<1 then raise syntax 88.900 array("IMAP_INDEX_UID_INVALID",uid)
  if sizeBytes<0 then raise syntax 88.900 array("IMAP_INDEX_SIZE_INVALID",sizeBytes)
::method key
  expose accountKey mailbox uidValidity uid
  return .ImapIndexIdentity~messageKey(accountKey,mailbox,uidValidity,uid)
::method fromKey
  expose fromAddress
  return .ImapIndexText~addressKey(fromAddress)

::class ImapIndexIdentity public
::method messageKey class
  use strict arg accountArg, mailboxArg, uidValidityArg, uidArg
  return self~escape(accountArg~string~strip)||"|"||self~escape(mailboxArg~string)||"|"||uidValidityArg~string~strip||"|"||uidArg~string~strip
::method mailboxKey class
  use strict arg accountArg, mailboxArg
  return self~escape(accountArg~string~strip)||"|"||self~escape(mailboxArg~string)
::method escape class private
  use strict arg value
  safe="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-@"
  out=""
  do i=1 to value~length
    c=value~substr(i,1)
    if safe~pos(c)>0 then out=out||c
    else out=out||"%"||c2x(c)
  end
  return out

::class ImapIndexText public
::method addressKey class
  use strict arg valueArg
  value=valueArg~string~strip~lower
  lt=value~lastPos("<")
  if lt>0 then do
    gt=value~pos(">",lt+1)
    if gt>lt+1 then value=value~substr(lt+1,gt-lt-1)~strip
  end
  return value
::method tokens class
  use strict arg textArg, minimumLengthArg=2, maximumLengthArg=128, maximumUniqueArg=20000
  text=textArg~string~lower
  minimumLength=minimumLengthArg+0
  maximumLength=maximumLengthArg+0
  maximumUnique=maximumUniqueArg+0
  if minimumLength<1 | maximumLength<minimumLength | maximumUnique<1 then raise syntax 88.900 array("IMAP_INDEX_TOKEN_POLICY_INVALID")
  answer=.array~new
  seen=.directory~new
  token=""
  allowedExtra="@._+-"
  do i=1 to text~length
    c=text~substr(i,1)
    if datatype(c,"A") | allowedExtra~pos(c)>0 then do
      if token~length<maximumLength then token=token||c
    end
    else do
      ignore=self~appendToken(answer,seen,token,minimumLength,maximumUnique)
      if answer~items>=maximumUnique then return answer
      token=""
    end
  end
  ignore=self~appendToken(answer,seen,token,minimumLength,maximumUnique)
  return answer
::method appendToken class private
  use strict arg answer, seen, token, minimumLength, maximumUnique
  t=token~strip
  if t~length<minimumLength | t~length=0 then return .false
  if answer~items>=maximumUnique then return .false
  if seen[t]<>.nil then return .false
  seen[t]=.true
  answer~append(t)
  return .true

::class ImapIndexSearchResult public
::attribute query get
::attribute terms get
::attribute hits get
::attribute truncated get
::attribute bodyCoverageComplete get
::method init
  expose query terms hits truncated bodyCoverageComplete
  use strict arg queryArg, termsArg, hitsArg, truncatedArg=.false, bodyCoverageArg=.false
  query=queryArg~string
  terms=termsArg
  hits=hitsArg
  truncated=(truncatedArg==.true)
  bodyCoverageComplete=(bodyCoverageArg==.true)
::method count
  expose hits
  return hits~items
