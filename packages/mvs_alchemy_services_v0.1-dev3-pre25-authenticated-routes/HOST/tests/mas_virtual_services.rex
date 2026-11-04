#!/usr/bin/env rexx

s = .MasVirtualServices~new
inv = s~inventory
call assert inv['QUEUE'] = 'AVAILABLE', 'queue inventory'
call assert inv['DATABASE'] = 'AVAILABLE', 'db inventory'
call assert inv['IMAP'] = 'AVAILABLE', 'imap inventory'
call assert inv['SMTP'] = 'AVAILABLE', 'smtp inventory'

q = s~queueProvider
call assert q~depth('MAS.TEST.QUEUE') = 0, 'queue empty'
call assert q~put('MAS.TEST.QUEUE', '410042ff'x) = 1, 'queue put'
call assert q~get('MAS.TEST.QUEUE') == '410042ff'x, 'queue bytes'

db = s~databaseProvider
call assert db~put('MAS.TEST.DB', '41'x, '610062ff'x), 'db put'
call assert db~get('MAS.TEST.DB', '41'x) == '610062ff'x, 'db bytes'
scan = db~scan('MAS.TEST.DB')
call assert scan~items = 1, 'db scan count'
call assert scan[1][1] == '41'x, 'db scan key'
call assert scan[1][2] == '610062ff'x, 'db scan value'
call assert db~delete('MAS.TEST.DB', '41'x), 'db delete'
call assert db~get('MAS.TEST.DB', '41'x) == .nil, 'db gone'

imap = s~imapProvider
boxes = imap~listMailboxes
call assert boxes~items = 2, 'imap mailbox count'
m = imap~get('INBOX', 71, 1001)
call assert m \== .nil, 'imap get'
call assert m~body == ('hello' || '0d0a'x), 'imap body bytes'
call assert imap~setSeen('INBOX',71,1001,.true), 'imap seen'

d = .MasOutboundDraft~new
d~sender = 'mvs@example.test'; d~addRecipient('dest@example.test'); d~body = '620079ff'x
smtp = s~smtpProvider
call assert smtp~submit(d) = 'MESSAGE_SIGNATURE_REQUIRED', 'smtp unsigned denied'
d~signaturePresent=.true; d~signatureVerified=.true; d~identityMatches=.true
d~emailSendAuthorized=.true; d~egressPermitted=.true
call assert smtp~submit(d) = 'RELAY_ELIGIBLE', 'smtp eligible'
call assert smtp~relayed~items = 1, 'smtp recorded'

say 'MAS dev3-pre6 ooRexx virtual QUEUE/DB/IMAP/SMTP services: PASS'
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return
::requires '../src/MasVirtualServices.cls'
