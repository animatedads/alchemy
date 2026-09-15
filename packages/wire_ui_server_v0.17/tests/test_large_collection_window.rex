/* Large Merchant-workspace collections: authoritative windowing plus factual evidence stream. */
view=.WireUIView~new("MB.BOOK","workspace")
root=.table~new; root["visible"]=.true
call must view~createInstance("workspace","WORKSPACE@1",root)
listSlots=.table~new; listSlots["visible"]=.true
call must view~createInstance("positions","POSITION_TABLE@1",listSlots,"workspace")

/* Initial window: two rows out of a 50,000-position authoritative collection. */
r1=.table~new; r1["instanceId"]="P-100"; r1["definitionKey"]="POSITION_ROW@1"
s1=.table~new; s1["symbol"]="AAA"; s1["severity"]="INFO"; r1["slots"]=s1
r2=.table~new; r2["instanceId"]="P-200"; r2["definitionKey"]="POSITION_ROW@1"
s2=.table~new; s2["symbol"]="BBB"; s2["severity"]="WARNING"; r2["slots"]=s2
rows=.array~of(r1,r2)
window=.WireUICollectionWindow~new("positions",0,2,50000,"risk-desc","open-only",1,"P-100")
r=view~reconcileCollectionWindow("positions",rows,window)
call must r
call assert r~value["previousRevision"]=0 & r~value["newRevision"]=1,"initial window uses one revision"
call assert view~instance("positions")["children"]~items=2,"only visible window materialised"
call assert view~instance("positions")["slots"]["windowTotalCount"]=50000,"total count projected separately from visible rows"

/* Move to next window: one retained row changes, one disappears, one arrives. */
n1=.table~new; n1["instanceId"]="P-200"; n1["definitionKey"]="POSITION_ROW@1"
ns1=.table~new; ns1["symbol"]="BBB"; ns1["severity"]="CRITICAL"; ns1["riskSummary"]="SANCTIONS / CUSTODY"; n1["slots"]=ns1
n2=.table~new; n2["instanceId"]="P-300"; n2["definitionKey"]="POSITION_ROW@1"
ns2=.table~new; ns2["symbol"]="CCC"; ns2["severity"]="INFO"; n2["slots"]=ns2
rows2=.array~of(n1,n2)
window2=.WireUICollectionWindow~new("positions",2,2,50000,"risk-desc","open-only",2,"P-200")
r=view~reconcileCollectionWindow("positions",rows2,window2)
call must r
call assert r~value["previousRevision"]=1 & r~value["newRevision"]=2,"window movement remains one revision"
call assert view~instance("P-100")==.nil,"row outside window removed from renderer state"
call assert view~instance("P-200")["slots"]["severity"]="CRITICAL","retained row updated in place"
call assert view~instance("positions")["children"][1]="P-200" & view~instance("positions")["children"][2]="P-300","window order is authoritative"
call assert view~instance("positions")["slots"]["windowOffset"]=2 & view~instance("positions")["slots"]["windowRevision"]=2,"window metadata advances atomically"

/* Repeating an identical window is a genuine no-op. */
r=view~reconcileCollectionWindow("positions",rows2,window2)
call must r
call assert r~code="NO_CHANGE" & r~value==.nil,"identical window has zero revision churn"
call assert view~revision=2,"no-op window preserves revision"

/* A window cannot silently swap the compiled definition for a retained identity. */
bad=.table~new; bad["instanceId"]="P-200"; bad["definitionKey"]="POSITION_ROW@2"; bad["slots"]=ns1
r=view~reconcileCollectionWindow("positions",.array~of(bad),.WireUICollectionWindow~new("positions",2,2,50000,"risk-desc","open-only",3,"P-200"))
call assert \r~ok & r~code="WINDOW_DEFINITION_MISMATCH","exact definition identity retained across windows"
call assert view~revision=2,"rejected window does not mutate revision"

/* Factual evidence is an ordered semantic collection, not an analytics conclusion. */
evSlots=.table~new; evSlots["visible"]=.true
call must view~createInstance("evidence","EVIDENCE_STREAM@1",evSlots,"workspace")
attrs=.table~new; attrs["restriction"]="TRANSFER_BLOCKED"
e=.WireUIEvidenceEntry~new("EV-001","CUSTODY_RESTRICTION","2026-08-28T10:15:00Z","CRITICAL","Transfer restriction recorded","CUSTODY","LEGAL-42","CORR-9",attrs)
r=view~appendEvidence("evidence",e)
call must r
call assert r~value["operations"][1]["op"]="LIST_APPEND","evidence uses ordinary semantic collection append"
call assert view~instance("EV-001")["slots"]["eventType"]="CUSTODY_RESTRICTION","factual event type projected"
call assert view~instance("EV-001")["slots"]["provenanceRef"]="LEGAL-42","evidence provenance preserved"
call assert \view~instance("EV-001")["slots"]~hasIndex("darkPattern"),"Wire UI does not invent assessment conclusions"

say "PASS large authoritative collection window and evidence stream"
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
