say "FLYLO ACCOUNTING INTEGRATION START"
root=value("FLYLO_TEST_DURABLE_ROOT",,"ENVIRONMENT")
if root="" then root="/tmp/flylo-accounting-v049"
root=root || "-accounting"
call sysFileTree root || "/*", files, "FOS"
if files.0>0 then do i=1 to files.0; call sysFileDelete files.i; end
call sysFileTree root || "/*", dirs, "DOS"
if dirs.0>0 then do i=dirs.0 to 1 by -1; call sysRmDir dirs.i; end
call sysRmDir root

runtime=.FlyLoBackendFactory~fixture(root)
storePath=root || "/flylo-stat.jsonl"
ops=.FlyLoQueueOperationsAdapter~new(runtime)
pay=.FlyLoDemoPaymentAdapter~new(.true)
accounting=.FlyLoAccountingAuthority~new(runtime~topology,.nil,storePath)
sales=.FlyLoSalesProcess~new(ops,pay,accounting)
controller=.FlyLoActionController~new(sales,ops,accounting)

/* Authorisation alone is deliberately not accounting truth. */
intent=.FlyLoPaymentIntent~new("AUTH-ONLY","tok_auth_only",1000,"GBP","AUTH-ONLY-IDEM")
authOnly=pay~authorize(intent)
call eq "AUTHORIZED",authOnly["status"],"authorization fixture"
call eq 0,accounting~engine~book~entryCount,"authorization alone does not post"

offer=sales~search("PIK","EWR","2026-09-01",1)
s=sales~selectOffer(offer,1); saleId=s["saleId"]
p=.directory~new; p["givenName"]="TOM"; p["familyName"]="DYER"
s=sales~passengerDetails(saleId,.array~of(p))
s=sales~extras(saleId,.directory~new)
s=sales~review(saleId,"FLYLO-COC-2026.08.28")
s=sales~pay(saleId,"tok_booking")
call eq "CONFIRMED",s["state"],"booking confirmed"
call eq "CAPTURED",s["paymentCaptureStatus"],"payment explicitly captured after booking"
call eq "POSTED",s["accountingStatus"],"captured booking posted"
call yes s["accountingEntryId"]<>"","booking accounting entry identity"
bookingEntry=accounting~engine~book~sourceEntry("FLYLO:PAYMENT_CAPTURE:" || s["paymentCaptureId"])
call eq .FlyLoAccountingBuild~POLICY_BOOKING_CAPTURE,bookingEntry~policyRef,"effective FlyLo booking accounting policy retained"
call yes bookingEntry~policyIdentity~pos("sha256:" || .FlyLoAccountingBuild~POLICY_IMPL_SHA256)=1,"exact executable accounting policy identity retained"
call eq "BOOKING_PAYMENT_CAPTURED",bookingEntry~eventType,"accounting event type retained"
call yes bookingEntry~sourceEventFingerprint<>"","source event fingerprint retained"
call eq "FLYLO.BOOKING.ENGINE",bookingEntry~metadata["accounting.sourceAuthorityRef"],"source authority retained"
call eq 1,accounting~engine~book~entryCount,"one native journal after booking capture"
amount=s["totalMinor"]+0
call eq amount,accounting~engine~book~balance("1100","GBP")~netDebitMinor,"processor receivable debit"
call eq 0-amount,accounting~engine~book~balance("2100","GBP")~netDebitMinor,"passenger contract liability credit"
call eq 0,accounting~engine~book~balance("4100","GBP")~netDebitMinor,"no carriage revenue at booking"
call eq 0,accounting~engine~book~balance("4110","GBP")~netDebitMinor,"no ancillary revenue at booking"

booking=s["booking"]
bookingRef=booking["bookingRef"]
passengerId=booking["passengers"][1]["passengerId"]
d=.directory~new; d["bookingRef"]=bookingRef; d["passengerIds"]=.array~of(passengerId); d["quantity"]=1; d["paymentMethodToken"]="tok_bag"; d["idempotencyKey"]="ACC-BAG-1"
updated=controller~handle("BOOKING.ADD_CHECKED_BAG",d)
call eq "CAPTURED",updated["lastAncillaryFinancialStatus"],"ancillary capture explicit"
call eq "POSTED",updated["lastAncillaryAccountingStatus"],"ancillary capture posted"
call eq 2,accounting~engine~book~entryCount,"separate ancillary journal"
expected=amount+4900
call eq expected,accounting~engine~book~balance("1100","GBP")~netDebitMinor,"combined processor receivable"
call eq 0-expected,accounting~engine~book~balance("2100","GBP")~netDebitMinor,"combined deferred passenger liability"
call eq 0,accounting~engine~book~balance("4100","GBP")~netDebitMinor,"still no carriage revenue before performance"
call eq 0,accounting~engine~book~balance("4110","GBP")~netDebitMinor,"bag not recognized as revenue before performance"
ancEntry=accounting~engine~book~sourceEntry("FLYLO:PAYMENT_CAPTURE:" || updated["lastAncillaryCaptureId"])
call eq .FlyLoAccountingBuild~POLICY_ANCILLARY_CAPTURE,ancEntry~policyRef,"ancillary policy retained separately"
call yes ancEntry~policyIdentity~pos("#ANCILLARY_PAYMENT_CAPTURED")>0,"ancillary exact policy configuration identity retained"
retainedAccounting=0
do publication over runtime~topology~topics~retainedPublications
  if publication~topicName=.FlyLoServiceTopology~ACCOUNTING_TOPIC then do
    projection=publication~payload
    call eq .AccountingEventCodec~CONTRACT,projection["contract_generation"],"retained Queue event uses accounting.event/0.1"
    retainedAccounting+=1
  end
end
call eq 2,retainedAccounting,"two normalized accounting events retained"

/* Exact replay is idempotent in Booking, Payment and Accounting. */
replayed=controller~handle("BOOKING.ADD_CHECKED_BAG",d)
call eq 2,accounting~engine~book~entryCount,"ancillary replay does not duplicate journal"
call eq "DUPLICATE",replayed["lastAncillaryAccountingStatus"],"accounting source-event replay detected"

/* A changed replay is rejected by Accounting Core before it can overwrite durable evidence. */
conflictPayload=.directory~new
conflictPayload["status"]="CAPTURED"; conflictPayload["amountMinor"]=amount+1; conflictPayload["currency"]="GBP"
conflictPayload["captureId"]=s["paymentCaptureId"]; conflictPayload["paymentAuthorizationId"]=s["paymentAuthorizationId"]; conflictPayload["paymentSource"]="DEMO_PAYMENT_CAPTURE"
conflictEvent=.AccountingEvent~new("FLYLO:PAYMENT_CAPTURE:" || s["paymentCaptureId"],.FlyLoAccountingBuild~LEGAL_ENTITY_ID,"BOOKING_PAYMENT_CAPTURED","2026-08-28",bookingRef,"","FLYLO.BOOKING.ENGINE",conflictPayload)
conflict=accounting~recordEvent(conflictEvent)
call no conflict~ok,"changed accounting source replay rejected"
call eq "SOURCE_EVENT_CONFLICT",conflict~errorCode,"changed replay conflict code"
call eq 2,accounting~engine~book~entryCount,"changed replay creates no journal"

/* An authorization-shaped accounting.event/0.1 event is rejected by policy. */
badPayload=.directory~new
badPayload["status"]="AUTHORIZED"; badPayload["amountMinor"]=1000; badPayload["currency"]="GBP"
badPayload["captureId"]="NONE"; badPayload["paymentAuthorizationId"]="AUTH"; badPayload["paymentSource"]="TEST"
bad=.AccountingEvent~new("FLYLO:AUTH-NOT-CAPTURE",.FlyLoAccountingBuild~LEGAL_ENTITY_ID,"BOOKING_PAYMENT_CAPTURED","2026-08-28","TEST","","FLYLO.BOOKING.ENGINE",badPayload)
br=accounting~recordEvent(bad)
call no br~ok,"authorization event refused"
call eq "PAYMENT_CAPTURE_REQUIRED",br~errorCode,"authorization rejection code"
call eq 2,accounting~engine~book~entryCount,"rejected authorization does not post"

/* Accounting Core v0.7 durable store recovers the independent book first; retained Queue source events then reconcile as exact duplicates. */
runtime2=.FlyLoBackendFactory~fixture(root)
accounting2=.FlyLoAccountingAuthority~new(runtime2~topology,.nil,storePath)
call eq 2,accounting2~engine~book~entryCount,"accounting journals recovered durably and reconciled against retained capture evidence"
call yes accounting2~engine~book~store<>.nil,"recovered accounting book remains attached to AccountingFileStore"
call yes stream(storePath,"c","query exists")<>"","durable Accounting Core JSONL exists"
call eq expected,accounting2~engine~book~balance("1100","GBP")~netDebitMinor,"restart receivable balance"
call eq 0-expected,accounting2~engine~book~balance("2100","GBP")~netDebitMinor,"restart liability balance"

say "FLYLO ACCOUNTING INTEGRATION: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 42; end; return
no: procedure; use arg v,l; if v then do; say "FAIL" l; exit 43; end; return

::requires "FlyLoAccounting.cls"
::requires "FlyLoActionController.cls"
::requires "FlyLoQueueOperationsAdapter.cls"
