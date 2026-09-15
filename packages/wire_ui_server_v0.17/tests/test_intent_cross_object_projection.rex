/* FederationBank-style pre-action intent projection and cross-object coherent
   derived state: position + risk + collateral + intent consequences. */
view=.WireUIView~new("MB.INTENT","root")
base=.table~new; base["visible"]=.true
call must view~createInstance("root","WORKSPACE@1",base)
call must view~createInstance("position","POSITION_ROW@1",.table~new,"root")
call must view~createInstance("risk","RISK_BANNER@1",.table~new,"root")
call must view~createInstance("margin","MARGIN_SUMMARY@1",.table~new,"root")
call must view~createInstance("intent","INTENT_PANEL@1",.table~new,"root")

projection=.WireUIProjection~new
keys=.array~of("position.closeValue","collateral.available","legal.transferRestricted")
r=projection~bindDerived(keys,.MerchantCloseProjector~new)
call must r
app=.WireUIApplication~new("MB-APP","SESSION-1","AP-1",view,projection)

/* One authoritative state-group transition drives several semantic objects,
   but the access point sees one coherent view revision. */
state=.table~new
state["position.closeValue"]=1200000
state["collateral.available"]=700000
state["legal.transferRestricted"]=.true
r=app~mutateStateGroup(state)
call must r
patch=r~value
call assert patch["previousRevision"]=0 & patch["newRevision"]=1,"cross-object projection is one revision"
call assert patch["operations"]~items=10,"all related outputs share one patch"
call assert view~instance("position")["slots"]["economicState"]="HEDGE_IMPAIRED","position consequence projected"
call assert view~instance("risk")["slots"]["severity"]="CRITICAL","legal/risk severity projected"
call assert view~instance("margin")["slots"]["shortfall"]=500000,"collateral shortfall projected"
call assert view~instance("intent")["slots"]["confirmEnabled"]=.false,"intent confirmation disabled by guard state"
call assert app~drainOutbound~items=1,"one outbound coherent patch"

/* Clearing the legal restriction recomputes all dependent meaning from the
   full authoritative snapshot, not merely the changed boolean value. */
state2=.table~new; state2["legal.transferRestricted"]=.false
r=app~mutateStateGroup(state2)
call must r
call assert r~value["previousRevision"]=1 & r~value["newRevision"]=2,"second derived transition is one revision"
call assert view~instance("position")["slots"]["economicState"]="OFFSET_AVAILABLE","position re-evaluated from complete state"
call assert view~instance("risk")["slots"]["severity"]="WARNING","remaining collateral risk retained"
call assert view~instance("intent")["slots"]["confirmEnabled"]=.true,"server makes confirm admissible"

/* Intent projection is an authoritative semantic explanation of a proposed
   action. It is not itself execution authority. */
inputs=.table~new; inputs["positionId"]="C-77881"; inputs["requestedCloseQuantity"]=10000
consequences=.table~new; consequences["reversalSide"]="LONG"; consequences["reversalQuantity"]=10000; consequences["expectedNetQuantity"]=0
warnings=.array~of("CROSS_LISTED_HEDGE_REQUIRES_REVIEW")
actions=.array~of("POSITION.CLOSE.REVIEW","POSITION.CLOSE.CONFIRM")
confirmations=.array~of("ECONOMIC_EFFECT_ACKNOWLEDGED")
intent=.WireUIIntentProjection~new("INTENT-77881-CLOSE","POSITION.CLOSE","PROPOSED",3,inputs,consequences,warnings,actions,confirmations,"RISK-SNAPSHOT-20260828-1")
wire=intent~asWire
call assert wire["intentRef"]="INTENT-77881-CLOSE" & wire["intentType"]="POSITION.CLOSE","intent identity"
call assert wire["consequences"]["reversalSide"]="LONG" & wire["consequences"]["expectedNetQuantity"]=0,"authoritative economic consequence"
call assert wire["warnings"][1]="CROSS_LISTED_HEDGE_REQUIRES_REVIEW","warning carried semantically"
call assert wire["requiredConfirmations"][1]="ECONOMIC_EFFECT_ACKNOWLEDGED","required confirmation explicit"
slots=intent~asSlots
call assert slots["intentRevision"]=3 & slots["provenanceRef"]="RISK-SNAPSHOT-20260828-1","intent revision/provenance"

say "PASS intent and cross-object projection"
exit 0

::class MerchantCloseProjector
::method call
  use arg state, changedKeys
  closeValue=state["position.closeValue"]
  available=state["collateral.available"]
  restricted=state["legal.transferRestricted"]
  shortfall=closeValue-available
  if restricted then do
    economic="HEDGE_IMPAIRED"
    severity="CRITICAL"
    riskCode="TRANSFER_RESTRICTED"
    confirm=.false
  end
  else do
    economic="OFFSET_AVAILABLE"
    if shortfall>0 then severity="WARNING"; else severity="GOOD"
    if shortfall>0 then riskCode="COLLATERAL_SHORTFALL"; else riskCode="READY"
    confirm=.true
  end
  output=.table~new
  p=.table~new; p["economicState"]=economic; p["severity"]=severity; output["position"]=p
  risk=.table~new; risk["stateCode"]=riskCode; risk["severity"]=severity; output["risk"]=risk
  margin=.table~new; margin["required"]=closeValue; margin["available"]=available; margin["shortfall"]=shortfall; output["margin"]=margin
  intent=.table~new; intent["confirmEnabled"]=confirm; intent["expectedNetQuantity"]=0; intent["reversalSide"]="LONG"; output["intent"]=intent
  return output

::routine must
  use arg r,label="operation"
  if \r~ok then do
    say "FAIL" label r~code r~detail
    exit 10
  end
  return r

::routine assert
  use arg condition,label
  if \condition then do
    say "FAIL" label
    exit 11
  end
  return

::requires "WireUIAll.cls"
