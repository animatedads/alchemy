/* Server-authored large collection window stream for JS acceptance. */
view=.WireUIView~new("MB.BOOK","workspace")
root=.table~new; root["visible"]=.true
call must view~createInstance("workspace","WORKSPACE@1",root)
ls=.table~new; ls["visible"]=.true
call must view~createInstance("positions","POSITION_TABLE@1",ls,"workspace")

say "DEF" json(.WireUIElementDefinition~new("WORKSPACE","1","PANEL")~asWire)
say "DEF" json(.WireUIElementDefinition~new("POSITION_TABLE","1","SEMANTIC_COLLECTION")~asWire)
say "DEF" json(.WireUIElementDefinition~new("POSITION_ROW","1","SEMANTIC_RECORD")~asWire)
say "SNAP" json(view~snapshot)

a=.table~new; a["instanceId"]="P-100"; a["definitionKey"]="POSITION_ROW@1"; as=.table~new; as["symbol"]="AAA"; as["severity"]="INFO"; a["slots"]=as
b=.table~new; b["instanceId"]="P-200"; b["definitionKey"]="POSITION_ROW@1"; bs=.table~new; bs["symbol"]="BBB"; bs["severity"]="WARNING"; b["slots"]=bs
r=view~reconcileCollectionWindow("positions",.array~of(a,b),.WireUICollectionWindow~new("positions",0,2,50000,"risk-desc","open-only",1,"P-100")); call must r; say "PATCH" json(r~value)

c=.table~new; c["instanceId"]="P-200"; c["definitionKey"]="POSITION_ROW@1"; cs=.table~new; cs["symbol"]="BBB"; cs["severity"]="CRITICAL"; cs["riskSummary"]="SANCTIONS / CUSTODY"; c["slots"]=cs
d=.table~new; d["instanceId"]="P-300"; d["definitionKey"]="POSITION_ROW@1"; ds=.table~new; ds["symbol"]="CCC"; ds["severity"]="INFO"; d["slots"]=ds
r=view~reconcileCollectionWindow("positions",.array~of(c,d),.WireUICollectionWindow~new("positions",2,2,50000,"risk-desc","open-only",2,"P-200")); call must r; say "PATCH" json(r~value)
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
