say "FLYLO ACTION CONTROLLER START"
ops=.FlyLoDemoOperationsAdapter~new(.true)
pay=.FlyLoDemoPaymentAdapter~new(.true)
sales=.FlyLoSalesProcess~new(ops,pay)
c=.FlyLoActionController~new(sales,ops)

d=.directory~new; d["origin"]="PIK"; d["destination"]="EWR"; d["date"]="2026-08-25"; d["passengers"]=1
offer=c~handle("FLIGHT.SEARCH",d)
call eq "FL101",offer["flightNo"],"search action"

d=.directory~new; d["offer"]=offer; d["passengers"]=1
s=c~handle("FLIGHT.SELECT",d)
call eq "PASSENGERS",s["state"],"select action"
saleId=s["saleId"]

p=.directory~new; p["givenName"]="TEST"; p["familyName"]="PASSENGER"
d=.directory~new; d["saleId"]=saleId; d["passengers"]=.array~of(p)
s=c~handle("PASSENGER.SAVE",d)
call eq "EXTRAS",s["state"],"passenger action"

d=.directory~new; d["saleId"]=saleId; d["selections"]=.directory~new
s=c~handle("ANCILLARY.SAVE",d)
call eq "REVIEW",s["state"],"extras action"

d=.directory~new; d["saleId"]=saleId; d["termsVersion"]="FLYLO-COC-2026.08.24"
s=c~handle("SALE.REVIEW",d)
call eq "PAYMENT",s["state"],"review action"

d=.directory~new; d["saleId"]=saleId; d["paymentMethodToken"]="tok_test"
s=c~handle("PAYMENT.AUTHORIZE",d)
call eq "CONFIRMED",s["state"],"payment action"

say "FLYLO ACTION CONTROLLER: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
::requires "FlyLoActionController.cls"
