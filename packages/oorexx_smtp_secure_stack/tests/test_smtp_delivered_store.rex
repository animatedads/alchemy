parse source . . thisFile
root=value("IMAP_SMTP_STORE_TMP",,"ENVIRONMENT")
if root="" then root="/tmp/oorexx-imap-smtp-store"
address system "rm -rf '"||root||"'"
call SysMkDir root
call SysMkDir root||"/objects"

call charout root||"/objects/msg-1.eml","From: a@example.test"||"0d0a0d0a"x||"signed"
call charout root||"/objects/msg-1.eml"
call charout root||"/objects/msg-2.eml","From: b@example.test"||"0d0a0d0a"x||"unsigned"
call charout root||"/objects/msg-2.eml"
call lineout root||"/memberships.tsv",.StorageCodec~enc("msg-1")||"09"x||.StorageCodec~enc("user@rasenfalcon.com")||"09"x||.StorageCodec~enc("INBOX")
call lineout root||"/memberships.tsv",.StorageCodec~enc("msg-2")||"09"x||.StorageCodec~enc("user@rasenfalcon.com")||"09"x||.StorageCodec~enc("INBOX-UNSIGNED")
call lineout root||"/memberships.tsv",.StorageCodec~enc("other-1")||"09"x||.StorageCodec~enc("other@rasenfalcon.com")||"09"x||.StorageCodec~enc("INBOX")
call lineout root||"/memberships.tsv"

provider=.ImapSmtpDeliveredMailboxProvider~new(root,"user@rasenfalcon.com")
r=provider~status("INBOX")
call assert r~ok,"INBOX status"
call assertEq r~value~messageCount,1,"INBOX count"
call assert r~value~readOnly,"provider is read-only"
u=provider~status("INBOX-UNSIGNED")
call assert u~ok,"unsigned status"
call assertEq u~value~messageCount,1,"unsigned count"
refs=provider~messageRefs("INBOX")
call assert refs~ok,"refs"
call assertEq refs~value[1],"msg-1","same SMTP object id"
body=provider~readMessage("msg-1")
call assert body~ok,"read body"
call assert body~value~pos("signed")>0,"read exact stored RFC822 bytes"
close=provider~close("INBOX",.true)
call assert \close~ok,"expunge denied until mutation semantics exist"
call assertEq close~code,"MAILBOX_PROVIDER_READ_ONLY","expunge denial code"

say "test_smtp_delivered_store: PASS"
exit 0

assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  return
assertEq: procedure
  use arg actual,expected,label
  if actual<>expected then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  return

::requires "ImapSmtpDeliveredStore.cls"
