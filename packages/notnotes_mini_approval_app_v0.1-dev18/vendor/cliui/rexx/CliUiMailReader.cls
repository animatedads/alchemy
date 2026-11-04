::class CliUiMailReader public
::method init
  expose imap smtp identity messages body status
  use strict arg imap,smtp,identity
  messages=.CliUiTableModel~new(.array~of('From','Subject','Date')); body=''; status='Ready'
::attribute messages get
::attribute body get
::attribute status get
::method loadWindow
  expose imap messages status
  use strict arg mailbox,start=0,count=100
  messages=.CliUiTableModel~new(.array~of('From','Subject','Date'))
  window=imap~messageWindow(mailbox,start,count)
  do m over window
    /* identity is mailbox|UIDVALIDITY|UID authority supplied by IMAP adapter. */
    messages~append(m~identity,.array~of(m~from,m~subject,m~date))
  end
  status=messages~count||' messages'; return messages
::method select
  expose imap messages body status
  use strict arg row
  messages~select(row); if row=0 then do; body=''; return body; end
  ref=messages~row(row)[1]; body=imap~fetchBody(ref); status='Read '||ref; return body
::method sendSigned
  expose smtp identity status
  use strict arg from,to,subject,body
  signer=identity~signingIdentity(from)
  sendReceipt=smtp~sendSigned(from,to,subject,body,signer)
  status='Signed message submitted'; return sendReceipt
::requires 'CliUiTable.cls'
