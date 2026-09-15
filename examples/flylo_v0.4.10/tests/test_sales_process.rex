say "FLYLO SALES PROCESS START"
ops=.FlyLoDemoOperationsAdapter~new(.true)
pay=.FlyLoDemoPaymentAdapter~new(.true)
sales=.FlyLoSalesProcess~new(ops,pay)

offer=sales~search("PIK","EWR","2026-08-25",1)
call eq "DEMO",offer["source"],"search source"
call eq 19900,offer["fareMinor"],"all-in mandatory fare"

s=sales~selectOffer(offer,1)
call eq "PASSENGERS",s["state"],"offer selected"
saleId=s["saleId"]

p=.directory~new; p["givenName"]="DARIA"; p["familyName"]="TEST"; p["email"]="daria@example.invalid"
passengers=.array~of(p)
s=sales~passengerDetails(saleId,passengers)
call eq "EXTRAS",s["state"],"passenger captured"

choices=.directory~new; choices["CABIN_BAG"]=.true; choices["CHECKED_BAG"]=.false; choices["SEAT_SELECTION"]=.true; choices["PRIORITY_BOARDING"]=.false
s=sales~extras(saleId,choices)
call eq "REVIEW",s["state"],"extras captured"
call eq 24200,s["totalMinor"],"extras total"

s=sales~review(saleId,"FLYLO-COC-2026.08.24")
call eq "PAYMENT",s["state"],"review accepted"

s=sales~pay(saleId,"tok_demo_123")
call eq "CONFIRMED",s["state"],"payment and booking confirmed"
call eq "AUTHORIZED",s["paymentStatus"],"payment authorised"
call yes s~hasIndex("booking"),"booking present"
call eq "CONFIRMED",s["booking"]["status"],"booking host confirmation"

/* Re-reading status does not create another payment or booking. */
s2=sales~status(saleId)
call eq s["paymentAuthorizationId"],s2["paymentAuthorizationId"],"stable authorization identity"

t=.CapturingAS400Transport~new
realOps=.FlyLoAS400OperationsAdapter~new(t)
req=.directory~new; req["saleId"]="SALE-X"; req["idempotencyKey"]="idem-booking"
r=realOps~createBooking(req)
call eq "BOOKING_CREATE",r["op"],"production booking delegated to AS400 transport"
call eq "idem-booking",r["payload"]["idempotencyKey"],"booking idempotency preserved"

say "FLYLO SALES PROCESS: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 42; end; return

::class CapturingAS400Transport
::method request
  use arg op,payload
  d=.directory~new; d["op"]=op; d["payload"]=payload; return d

::requires "FlyLoSalesProcess.cls"
