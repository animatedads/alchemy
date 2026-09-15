b=.OurLadyAirFixture~build
app=b["app"]

obs=.WireUIObservationDefinition~new("CANCEL_FLOW_ENTERED","1","CANCELLATION_JOURNEY_EVIDENCE",.array~of("flowRef","elementInstance","state"),"CLIENT_APPLICATION_ASSERTED")
r=app~registerObservationDefinition(obs); call must r,"register observation"
sub=.WireUISubscription~new("OBS.CANCEL","3","authorised cancellation-flow factual observations","POLICY.CANCEL.OBS@1")
if \sub~addObservation(obs~exactKey) then call fail "add observation"
app~addSubscription(sub)
r=app~activateSubscription("OBS.CANCEL"); call must r,"activate observation subscription"

out=app~drainOutbound
plan=.nil
do m over out
  if m["type"]=.WireUIProtocol~OBSERVATION_PLAN then plan=m
end
if plan==.nil then call fail "observation plan not emitted"
if plan["subscription"]<>"OBS.CANCEL" then call fail "plan subscription"
if plan["revision"]<>"3" then call fail "plan revision"
if plan["points"]~items<>1 then call fail "plan point count"
p=plan["points"][1]
if p["id"]<>"CANCEL_FLOW_ENTERED" then call fail "plan point id"
if p["purpose"]<>"CANCELLATION_JOURNEY_EVIDENCE" then call fail "plan purpose"
if p["allowedFields"]~items<>3 then call fail "plan allowed field count"

m=.table~new
m["type"]=.WireUIProtocol~INTERACTION_OBSERVATION
m["messageId"]="obs-1"
m["subscription"]="OBS.CANCEL"
m["subscriptionRevision"]="3"
m["point"]="CANCEL_FLOW_ENTERED"
m["purpose"]="CANCELLATION_JOURNEY_EVIDENCE"
m["evidenceStrength"]="CLIENT_APPLICATION_ASSERTED"
payload=.table~new; payload["flowRef"]="CANCEL-77"; payload["elementInstance"]="cancelAction"; payload["state"]="ENTERED"
m["observation"]=payload
r=app~receive(m); call must r,"accept observation"
if r~code<>"INTERACTION_OBSERVATION_ACCEPTED" then call fail "accept code"
record=r~value
if record~pointId<>"CANCEL_FLOW_ENTERED" then call fail "record point"
if record~purpose<>"CANCELLATION_JOURNEY_EVIDENCE" then call fail "record purpose"
if record~observation["flowRef"]<>"CANCEL-77" then call fail "record payload"

/* Duplicate direct-queue message must not duplicate factual evidence. */
r2=app~receive(m); call must r2,"duplicate observation"
if r2~code<>"DUPLICATE" then call fail "duplicate code"
accepted=app~drainObservations
if accepted~items<>1 then call fail "duplicate evidence effect"

/* Browser may not widen the positive list. */
m2=.table~new; call baseMessage m2,"obs-2"
payload=.table~new; payload["flowRef"]="CANCEL-88"; payload["secretDOM"]="div:nth-child(4)"
m2["observation"]=payload
r=app~receive(m2)
if r~ok | r~code<>"OBSERVATION_FIELD_NOT_AUTHORISED" then call fail "extra observation field rejected"

/* Subscription revision is part of the authority context. */
m3=.table~new; call baseMessage m3,"obs-3"
m3["subscriptionRevision"]="2"
payload=.table~new; payload["flowRef"]="CANCEL-99"; m3["observation"]=payload
r=app~receive(m3)
if r~ok | r~code<>"OBSERVATION_SUBSCRIPTION_REVISION_MISMATCH" then call fail "stale observation revision rejected"

/* Browser cannot relabel purpose/evidence provenance. */
m4=.table~new; call baseMessage m4,"obs-4"
m4["purpose"]="MARKETING_PROFILE"
payload=.table~new; payload["flowRef"]="CANCEL-100"; m4["observation"]=payload
r=app~receive(m4)
if r~ok | r~code<>"OBSERVATION_PURPOSE_MISMATCH" then call fail "purpose mismatch rejected"

app~deactivateSubscription("OBS.CANCEL")
m5=.table~new; call baseMessage m5,"obs-5"
payload=.table~new; payload["flowRef"]="CANCEL-101"; m5["observation"]=payload
r=app~receive(m5)
if r~ok | r~code<>"OBSERVATION_SUBSCRIPTION_NOT_ACTIVE" then call fail "inactive observation rejected"

say "PASS positive-list observation contract"
exit 0

baseMessage: procedure
  use arg m,id
  m["type"]=.WireUIProtocol~INTERACTION_OBSERVATION
  m["messageId"]=id
  m["subscription"]="OBS.CANCEL"
  m["subscriptionRevision"]="3"
  m["point"]="CANCEL_FLOW_ENTERED"
  m["purpose"]="CANCELLATION_JOURNEY_EVIDENCE"
  m["evidenceStrength"]="CLIENT_APPLICATION_ASSERTED"
  return

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
  return
fail: procedure
  parse arg label
  say "FAIL" label
  exit 1

::requires "OurLadyAirFixture.cls"
::requires "WireUIObservationDefinition.cls"
