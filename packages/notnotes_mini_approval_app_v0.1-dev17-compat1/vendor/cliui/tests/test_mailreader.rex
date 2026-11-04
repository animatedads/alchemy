call test
exit 0
test: procedure
  imap=.FakeImap~new; smtp=.FakeSmtp~new; ldap=.FakeIdentity~new
  ui=.CliUiMailReader~new(imap,smtp,ldap)
  rows=ui~loadWindow('INBOX',0,100)
  if rows~count<>2 then raise syntax 88.900 array('mail window count')
  if rows~row(2)[1]<>'INBOX|4242|8738' then raise syntax 88.900 array('stable identity lost')
  b=ui~select(2); if b<>'second body' then raise syntax 88.900 array('body fetch')
  r=ui~sendSigned('me@example.test','you@example.test','hello','body')
  if r<>'accepted' then raise syntax 88.900 array('signed send result')
  if smtp~signer<>'ldap:me@example.test' then raise syntax 88.900 array('LDAP signer not delegated')
  say 'PASS mail reader bounded identity read signed-send delegation'
  return
::class FakeMessage public
::method init; expose identity from subject date; use strict arg identity,from,subject,date
::attribute identity get
::attribute from get
::attribute subject get
::attribute date get
::class FakeImap public
::method messageWindow
  use strict arg mailbox,start,count
  return .array~of(.FakeMessage~new('INBOX|4242|8737','a@example.test','one','today'),.FakeMessage~new('INBOX|4242|8738','b@example.test','two','today'))
::method fetchBody; use strict arg ref; if ref='INBOX|4242|8738' then return 'second body'; return 'first body'
::class FakeIdentity public
::method signingIdentity; use strict arg from; return 'ldap:'||from
::class FakeSmtp public
::method init; expose signer; signer=''
::attribute signer get
::method sendSigned
  expose signer
  use strict arg from,to,subject,body,signer
  return 'accepted'
::requires 'CliUiTable.cls'
::requires 'CliUiMailReader.cls'
