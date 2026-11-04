parse source . . thisFile
root=value("TEST_ROOT",,"ENVIRONMENT")
if root="" then root="."
tmp=value("SMTP_TEST_TMP",,"ENVIRONMENT")
if tmp="" then tmp="/tmp/oorexx-smtp-mailstore-restart-test"
address system "rm -rf '"||tmp||"'"
call SysMkDir tmp

cataloguePath=tmp||"/catalogue.tsv"
cat=.StorageCatalogue~new
store=.StorageFabricSmtpStore~new(tmp,cat,"smtp-test","smtp-mail",cataloguePath)
delivery=.StorageFabricSmtpDeliveryProvider~new(store,.array~of("example.test"))

env=.SmtpEnvelope~new("alice@remote.test")
env~addRecipient("bob@example.test")
content="From: alice@remote.test"||"0d0a"x|| -
        "To: bob@example.test"||"0d0a"x|| -
        "Subject: restart proof"||"0d0a"x||"0d0a"x|| -
        "persist me"
msg=.SmtpMessage~new(env,content)
sess=.SmtpSession~new("restart-in","192.0.2.10","",.false,.true)
msg~metadata["signature.present"]=.false
msg~metadata["signature.verified"]=.false

r=delivery~deliverLocal(sess,msg,env~recipients,"INBOX-UNSIGNED")
call assert r~ok,"initial durable local delivery"
objectId=r~value
call assert stream(tmp||"/objects/"||objectId||".eml","c","query exists")<>"","RFC822 object exists"
call assert stream(tmp||"/meta/"||objectId||".tsv","c","query exists")<>"","metadata exists"
call assert stream(cataloguePath,"c","query exists")<>"","catalogue checkpoint exists"

/* Retrying membership projection must be idempotent. */
m=store~addMembership(objectId,"bob@example.test","INBOX-UNSIGNED")
call assert m~ok,"membership replay accepted"
call assert store~mailboxCount("bob@example.test","INBOX-UNSIGNED")=1,"membership replay does not duplicate mailbox entry"

/* Simulate process restart: reload a fresh catalogue and a fresh store object. */
cat2=.StorageCatalogue~new
cat2~load(cataloguePath)
call assert cat2~get(objectId)<>.nil,"catalogue restored after restart"
store2=.StorageFabricSmtpStore~new(tmp,cat2,"smtp-test","smtp-mail",cataloguePath)
ids=store2~mailboxObjectIds("bob@example.test","INBOX-UNSIGNED")
call assert ids~items=1,"mailbox enumeration survives restart"
call assert ids[1]=objectId,"mailbox enumeration returns stored object id"

loaded=store2~loadMailboxMessage("bob@example.test",1,"INBOX-UNSIGNED")
call assert loaded~ok,"mailbox message reload succeeds"
call assert loaded~value~content=content,"mail body byte-identical after restart"
call assert loaded~value~envelope~mailFrom="alice@remote.test","mailFrom metadata restored"
call assert loaded~value~envelope~recipients~items=1,"recipient metadata restored"
call assert loaded~value~envelope~recipients[1]="bob@example.test","recipient value restored"

/* Recovery must fail closed if catalogue or metadata evidence is missing. */
catMissing=.StorageCatalogue~new
storeMissing=.StorageFabricSmtpStore~new(tmp,catMissing,"smtp-test","smtp-mail","")
missingCatalogue=storeMissing~loadMessage(objectId)
call assert \missingCatalogue~ok & missingCatalogue~code="STORAGE_CATALOGUE_OBJECT_NOT_FOUND","orphan body rejected without catalogue evidence"

metaPath=tmp||"/meta/"||objectId||".tsv"
metaBackup=metaPath||".bak"
call SysFileMove metaPath,metaBackup
missingMeta=store2~loadMessage(objectId)
call assert \missingMeta~ok & missingMeta~code="STORAGE_META_NOT_FOUND","missing recovery metadata rejected"
call SysFileMove metaBackup,metaPath

say "test_mail_store_restart: PASS"
exit 0

assert:
  use arg condition,label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
return

::requires "SmtpCore.cls"
::requires "SmtpDurableDelivery.cls"
::requires "StorageFabric.cls"
