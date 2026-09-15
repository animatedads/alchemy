say "FLYLO WIRE UI START"
b=.FlyLoDesignFixture~build
r=.WireUICompiler~new~compile(b["workspace"],b["release"])
if \r~ok then do; say "FAIL compile" r~code r~detail; exit 41; end
p=r~value
if p~definitions~items < 12 then do; say "FAIL projection count" p~definitions~items; exit 42; end
needed=.set~of("FLYLO_SEARCH_FORM@2","FLYLO_OFFER_CARDS@2","FLYLO_PASSENGERS@1","FLYLO_EXTRAS@1","FLYLO_REVIEW@1","FLYLO_PAYMENT@1","FLYLO_BOOKED@1","FLYLO_PASSENGER_RIGHTS@1","FLYLO_ASSISTANT@2")
do d over p~definitions
  if needed~hasIndex(d["definitionKey"]) then needed~remove(d["definitionKey"])
end
if needed~items > 0 then do; say "FAIL missing sales definitions" needed~items; exit 43; end
j=b["journey"]
call state j,"HOME"
call state j,"OFFERS"
call state j,"PASSENGERS"
call state j,"EXTRAS"
call state j,"REVIEW"
call state j,"PAYMENT"
call state j,"CONFIRMED"
say "FLYLO WIRE UI: OK definitions="p~definitions~items
exit 0
state: procedure; use arg j,n; if j~state(n)==.nil then do; say "FAIL missing journey state" n; exit 44; end; return
::requires "FlyLoDesignFixture.cls"
