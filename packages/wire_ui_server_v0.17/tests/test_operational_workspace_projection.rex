/* FederationBank-style dense operational workspace capabilities:
   stable ordered collections, atomic row updates and typed semantic state. */
view=.WireUIView~new("MB.PORTFOLIO","portfolio")
root=.table~new; root["visible"]=.true
call must view~createInstance("portfolio","PORTFOLIO@1",root)
positions=.table~new; positions["visible"]=.true
call must view~createInstance("positions","POSITION_TABLE@1",positions,"portfolio")

p1=.table~new
p1["clientState"]="CLOSED"
p1["economicState"]="NET_ZERO"
p1["marketValue"]="GBP 0"
p1["severity"]="NEUTRAL"
r=view~listAppend("positions","C-55201","POSITION_ROW@1",p1)
call must r
call assert r~value["operations"][1]["op"]="LIST_APPEND","first row append operation"
call assert r~value["newRevision"]=1,"first row revision"

p2=.table~new
p2["clientState"]="CLOSED"
p2["economicState"]="HEDGE_EQUIVALENT"
p2["severity"]="INFO"
r=view~listAppend("positions","C-77881","POSITION_ROW@1",p2)
call must r
call assert r~value["newRevision"]=2,"second row revision"
call assert view~instance("positions")["children"][1]="C-55201" & view~instance("positions")["children"][2]="C-77881","stable insertion order"

/* One risk reassessment changes several semantic facets atomically. */
updates=.table~new
updates["economicState"]="HEDGE_IMPAIRED"
updates["severity"]="CRITICAL"
updates["riskSummary"]="SANCTIONS / CUSTODY"
updates["replacementExposure"]="GBP 120000"
r=view~setSlots("C-77881",updates)
call must r
call assert r~value["previousRevision"]=2 & r~value["newRevision"]=3,"slot group consumes one revision"
call assert r~value["operations"]~items=4,"four row changes in one patch"
call assert view~instance("C-77881")["slots"]["economicState"]="HEDGE_IMPAIRED","authoritative row state updated"
call assert view~instance("C-77881")["slots"]["severity"]="CRITICAL","severity updated atomically"

/* Ordering is explicit state, not DOM coincidence. */
r=view~listMove("positions","C-77881",0)
call must r
call assert r~value["operations"][1]["op"]="LIST_MOVE","move operation"
call assert view~instance("positions")["children"][1]="C-77881","server owns new order"
snapshot=view~snapshot
call assert snapshot["instances"][3]["instanceId"]="C-77881","snapshot preserves collection order parent-before-child"

/* Rows may own semantic subtrees; removal clears descendants as well. */
risk=.table~new; risk["value"]="SANCTIONS"; risk["severity"]="CRITICAL"
call must view~createInstance("C-77881-RISK","RISK_CHIP@1",risk,"C-77881")
r=view~listRemove("positions","C-77881")
call must r
call assert r~value["operations"]~items=2,"descendant destroy plus list remove"
call assert r~value["operations"][1]["op"]="DESTROY_INSTANCE","descendant registry cleanup"
call assert r~value["operations"][2]["op"]="LIST_REMOVE","collection row removal"
call assert view~instance("C-77881")==.nil & view~instance("C-77881-RISK")==.nil,"removed subtree absent from authoritative view"

/* Typed semantic state records meaning without prescribing browser styling. */
state=.WireUISemanticState~new("STATUS","HEDGE_IMPAIRED","Hedge equivalence impaired","CRITICAL","","risk.hedge","LEGAL-TRANSFER-20260827")
wire=state~asWire
call assert wire["kind"]="STATUS" & wire["code"]="HEDGE_IMPAIRED","typed state identity"
call assert wire["severity"]="CRITICAL","typed state severity"
call assert wire["provenanceRef"]="LEGAL-TRANSFER-20260827","typed state provenance"
slots=state~asSlots
call assert slots["value"]="Hedge equivalence impaired","typed state display projection"
call assert slots["stateCode"]="HEDGE_IMPAIRED" & slots["semanticRole"]="risk.hedge","typed state semantic slots"

/* Dependency projection can publish an atomic slot group. */
projection=.WireUIProjection~new
projection~bindSlots("position.C-55201.risk","C-55201")
rowUpdate=.table~new; rowUpdate["severity"]="WARNING"; rowUpdate["riskSummary"]="FX / BASIS"
patches=projection~projectChange(view,"position.C-55201.risk",rowUpdate)
call assert patches~items=1,"slot-group dependency emits one patch"
call assert patches[1]["operations"]~items=2,"dependency patch retains atomic row update"

say "PASS operational workspace projection"
exit 0

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
