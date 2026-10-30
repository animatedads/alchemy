/* UI-only composition fixture. IMAP, SMTP signing and LDAP authority remain
 * external packages and are injected into MailReaderService. */
call main
exit 0

main:
  say 'MailReader service fixture loaded'
  return

::class MailReaderService public
::method init
  expose imap smtp identity
  use strict arg imap, smtp, identity
::method folders; expose imap; return imap~folders
::method messages; expose imap; use strict arg mailbox,start=0,count=100; return imap~messageWindow(mailbox,start,count)
::method read; expose imap; use strict arg messageRef; return imap~fetchBody(messageRef)
::method sendSigned
  expose smtp identity
  use strict arg from,to,subject,body
  signer=identity~signingIdentity(from)
  return smtp~sendSigned(from,to,subject,body,signer)

::requires 'CliUiTable.cls'
