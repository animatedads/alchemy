root = .NoSQLServerTestSupport~createBlankDatabase("ourladyair-pnrgov")
fed = .FederatedDatabaseEngine~new(root)

doc = .EdiFactDocumentContext~new("fixtures/ourladyair_pnrgov_demo.edi")
call assert doc~groups~items = 7, "seven functional groups"
call assert doc~annotations~items >= 10, "source annotations retained"
report = doc~validateEnvelope
call assert report~status = "INVALID", "demo envelope defects surfaced, not hidden"

provider = .EdiFactRelationProvider~new(.DatabaseResult)
messages = provider~defineRelation("pnr_messages", doc, "MESSAGE:PNRGOV")
messages~columnMap("message_ref", "@reference")
messages~columnMap("group_ref", "@groupReference")
messages~columnMap("pnr", "RCI/1/2")
messages~columnMap("passenger_qty", "EQN/1/1", "INTEGER")

ssr = provider~defineRelation("pnr_ssr", doc, "SEGMENT:SSR")
ssr~columnMap("group_ref", "@groupReference")
ssr~columnMap("message_ref", "@messageReference")
ssr~columnMap("service_code", "1/1")
ssr~columnMap("service_status", "1/2")
ssr~columnMap("flight", "1/5")
ssr~columnMap("flight_date", "1/6")
ssr~columnMap("service_value", "2")

pax = provider~defineRelation("pnr_passengers", doc, "SEGMENT:TIF")
pax~columnMap("group_ref", "@groupReference")
pax~columnMap("message_ref", "@messageReference")
pax~columnMap("surname", "1")
pax~columnMap("given_name", "2")
pax~columnMap("title", "3")
pax~columnMap("passenger_type", "4")
pax~columnMap("dob", "5")

ignore = fed~addEngine(provider)

r = fed~execute("SELECT group_ref, message_ref, service_code, service_value FROM pnr_ssr WHERE service_code='NSST' ORDER BY message_ref")
call ok r
call assert r~rows~items = 3, "three no-seat-purchase SSR rows"
do row over r~rows
  call assert row["group_ref"] = "G07", "only G07 has NSST"
  call assert row["service_value"] = "SEAT NOT PURCHASED", "explicit no-seat evidence"
end

j = fed~execute("SELECT p.group_ref AS group_ref, p.message_ref AS message_ref, p.surname AS surname, p.given_name AS given_name, s.service_code AS service_code FROM pnr_passengers p JOIN pnr_ssr s ON p.group_ref=s.group_ref AND p.message_ref=s.message_ref WHERE p.group_ref='G07' AND s.service_code='NSST' ORDER BY p.message_ref")
call ok j
call assert j~rows~items = 3, "compound join identifies three G07 passengers without reserved seats"
call assert j~rows[1]["surname"] = "MACLEOD", "G07A passenger"
call assert j~rows[2]["surname"] = "ROBERTSON", "G07B passenger"
call assert j~rows[3]["surname"] = "OKAFOR", "G07C passenger"

togetherCharge = j~rows~items * 20
call assert togetherCharge = 60, "three unreserved seats at EUR20 = EUR60"
say "G07 seat-together offer: seats=" j~rows~items "unit_eur=20 total_eur=" togetherCharge

/* Prove scattered but already-reserved groups are not selected by this rule. */
g02 = fed~execute("SELECT COUNT(*) AS c FROM pnr_ssr WHERE group_ref='G02' AND service_code='NSST'")
call ok g02
call assert g02~rows[1]["c"] = 0, "G02 scattered passengers already have reserved seats"
g06 = fed~execute("SELECT COUNT(*) AS c FROM pnr_ssr WHERE group_ref='G06' AND service_code='NSST'")
call ok g06
call assert g06~rows[1]["c"] = 0, "G06 split school seats are already reserved"

ignore = provider~close
ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "OURLADYAIR PNRGOV NOSQL SEAT OFFER SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "FAILED:" rs~status rs~error rs~message
    exit 1
  end
  return .true

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "../src/EdiFactRelationAdapter.cls"
