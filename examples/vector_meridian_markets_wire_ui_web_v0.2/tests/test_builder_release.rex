b=.VMMWireUIDesignFixture~build
c=.WireUICompiler~new
r=c~compile(b["workspace"],b["release"])
call must r,"compile VMM operator release"
pkg=r~value
call expect pkg~packageId="VECTOR_MERIDIAN_MARKETS_OPERATIONS","package identity"
call expect pkg~packageVersion="2","package version"
call expect pkg~definitions~items=23,"23 exact VMM human projections"
call expect pkg~journeyPlans~items=1,"one HUMAN_VISUAL journey plan"
call expect pkg~releaseRef~contentAddress=b["release"]~contentAddress,"sealed release identity"

needed=.set~new
needed~put("VMM_ORDER_CANCEL@2")
needed~put("VMM_ORDER_RECONCILE@2")
needed~put("VMM_ALGO_KILL@2")
needed~put("VMM_ALGO_RESUME@2")
needed~put("VMM_EXCEPTION_ACK@2")
actions=.table~new
business=.false

do d over pkg~definitions
  key=d["definitionKey"]
  if needed~hasIndex(key) then needed~remove(key)
  if d["action"]<>"" then actions[d["action"]]=.true
  text=d~string
  if text~caselessPos("VMMMarketMaker")>0 | text~caselessPos("VMMExecutionService")>0 | text~caselessPos("VMMAccountingService")>0 then business=.true
end
call expect needed~items=0,"operator action definitions compiled"
call expect actions~hasIndex("VMM.ORDER.CANCEL.REQUEST"),"cancel intent compiled"
call expect actions~hasIndex("VMM.ORDER.RECONCILE.REQUEST"),"reconcile intent compiled"
call expect actions~hasIndex("VMM.ALGO.KILL.REQUEST"),"algo kill intent compiled"
call expect actions~hasIndex("VMM.ALGO.RESUME.REQUEST"),"algo resume intent compiled"
call expect actions~hasIndex("VMM.EXCEPTION.ACKNOWLEDGE.REQUEST"),"exception ack intent compiled"
call expect \business,"compiled release has no VMM business object reference"

plan=pkg~journeyPlans[1]
call expect plan["initialState"]="DEALING","dealing initial state"
call expect plan["states"]~items=4,"four operator workspace states"
say "PASS VMM Builder semantic release"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
  return
expect: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  say "ok" label
  return
::requires "VMMWireUIDesignFixture.cls"
