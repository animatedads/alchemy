/* Server-authored dense-workspace patch stream for JS cross-language acceptance. */
view=.WireUIView~new("MB.PORTFOLIO","portfolio")
root=.table~new; root["visible"]=.true
call must view~createInstance("portfolio","PORTFOLIO@1",root)
list=.table~new; list["visible"]=.true
call must view~createInstance("positions","POSITION_TABLE@1",list,"portfolio")

say "DEF" json(.WireUIElementDefinition~new("PORTFOLIO","1","PANEL")~asWire)
say "DEF" json(.WireUIElementDefinition~new("POSITION_TABLE","1","SEMANTIC_COLLECTION")~asWire)
say "DEF" json(.WireUIElementDefinition~new("POSITION_ROW","1","SEMANTIC_RECORD")~asWire)
say "SNAP" json(view~snapshot)

p1=.table~new; p1["clientState"]="CLOSED"; p1["economicState"]="NET_ZERO"; p1["severity"]="NEUTRAL"
r=view~listAppend("positions","C-55201","POSITION_ROW@1",p1); call must r; say "PATCH" json(r~value)
changes=.table~new; changes["economicState"]="HEDGE_IMPAIRED"; changes["severity"]="CRITICAL"; changes["riskSummary"]="SANCTIONS / CUSTODY"
r=view~setSlots("C-55201",changes); call must r; say "PATCH" json(r~value)
p2=.table~new; p2["clientState"]="CLOSED"; p2["economicState"]="HEDGED"; p2["severity"]="INFO"
r=view~listAppend("positions","C-77881","POSITION_ROW@1",p2); call must r; say "PATCH" json(r~value)
r=view~listMove("positions","C-77881",0); call must r; say "PATCH" json(r~value)
multi=.table~new
row2=.table~new; row2["severity"]="WARNING"; row2["riskSummary"]="COLLATERAL SHORTFALL"; multi["C-77881"]=row2
summary=.table~new; summary["portfolioSeverity"]="WARNING"; summary["attentionCount"]=1; multi["positions"]=summary
r=view~setSlotsAcross(multi); call must r; say "PATCH" json(r~value)
r=view~listRemove("positions","C-55201"); call must r; say "PATCH" json(r~value)
exit 0

::routine must
 use arg r
 if \r~ok then do; say "FAIL" r~code r~detail; exit 4; end
 return

::routine json
  use arg value
  if value==.nil then return "null"
  if value~isA(.string) then do
    s=value~string
    if datatype(s,"N") then return s
  end
  if value==.true then return "true"
  if value==.false then return "false"
  if value~isA(.table) | value~isA(.directory) then do
    keys=value~allIndexes; keys~sort
    out="{"; first=.true
    do k over keys
      if \first then out ||= ","
      out ||= quote(k)":"json(value[k])
      first=.false
    end
    return out"}"
  end
  if value~isA(.array) then do
    out="["
    do i=1 to value~items
      if i>1 then out ||= ","
      out ||= json(value[i])
    end
    return out"]"
  end
  s=value~string
  if datatype(s,"N") then return s
  return quote(s)

::routine quote
  use arg s
  s=changestr('\\',s,'\\\\')
  s=changestr('"',s,'\\"')
  s=changestr('0a'x,s,'\\n')
  s=changestr('0d'x,s,'\\r')
  return '"'s'"'

::requires "WireUIAll.cls"
