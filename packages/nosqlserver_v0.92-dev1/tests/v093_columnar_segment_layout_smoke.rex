/* dev1 sparse segment/layout qualification: run against the real NoSQLServer
 * stack. This also runs with the isolated stand-in fixture when qualifying
 * the physical planner without application dependencies.
 */
raw = .table~new
raw["name"] = "sensors"
raw["columns"] = .array~new
names = .array~of("id","station","temperature","notes","blob")
types = .array~of("INTEGER","INTEGER","DECIMAL","TEXT","BLOB")
do i = 1 to names~items
  c = .table~new
  c["name"] = names[i]
  c["type"] = types[i]
  c["primaryKey"] = (i = 1)
  raw["columns"]~append(c)
end
definition = .TableDefinition~new(raw)
rows = .array~new
do i = 1 to 128
  v = .table~new
  v["id"] = i
  if i = 3 then v["station"] = 99
  else v["station"] = 17
  v["temperature"] = 20+i/10
  v["notes"] = "content " || i
  v["blob"] = x2c("000AFF")
  if i = 3 then v["notes"] = .nil
  rows~append(.DatabaseRow~new(v))
end

port = .NoSQLColumnarMemoryPort~new
engine = .NoSQLColumnarEngine~new(port)
call check engine~register("sensors",definition,rows,16)=1,"first-generation"
t = engine~table("sensors")
call check t~rowCount=128,"count"
call check t~readRows[3]["notes"]==.nil,"NULL round-trip"
call check t~readRows[2]["blob"]==x2c("000AFF"),"binary round-trip"
port~readCount=0
filter = .SQLComparisonPredicate~new("station","=",99)
r = engine~selectColumnar("sensors",filter,"temperature","")
call check r~rows~items=1,"sparse-predicate"
call check r~rows[1]["temperature"]=rows[3]["temperature"],"projected-value"
call check t~lastSegmentsRead=1,"only matching measure segment read"
call check port~readCount=9,"eight station segments and one measure segment"
call check engine~lastPlan["reason"]="COLUMN_PROJECTED_SEGMENTS","plan-evidence"

positions = .array~of(3,3,17,128)
port~readCount=0
subset=t~readPositions(.array~of("temperature"),positions)
call check subset["temperature"]~items=4,"position count"
call check subset["temperature"][1]=subset["temperature"][2],"duplicate position"
call check t~lastSegmentsRead=3,"three physical chunks"
call check port~readCount=3,"no repeated chunk reads"

casFailed=.false
signal on syntax name expectedCAS
ignore=port~publish("sensors",1,128,16,definition)
signal off syntax
signal afterCAS
expectedCAS:
  casFailed=.true
  signal off syntax
afterCAS:
call check casFailed,"stale publication rejected"
call check t~generation=1,"generation unchanged after conflict"

port~failWriteAt=port~writeCount+1
failed=.false
signal on syntax name expectedFailure
ignore=t~publishRows(rows)
signal off syntax
signal afterFailure
expectedFailure:
  failed=.true
  signal off syntax
afterFailure:
call check failed,"write failure propagated"
call check port~manifest("sensors")["generation"]=1,"manifest preserved"
port~failWriteAt=0
call check t~publishRows(rows)=2,"new generation after failure"

source=.TestRowTable~new(definition,rows)
re=.TestRowEngine~new(source)
port2=.NoSQLColumnarMemoryPort~new
hybrid=.NoSQLColumnarEngine~new(port2,re)
call check hybrid~promote("sensors",16)=1,"row-to-column promotion"
reference=re~selectWhere("sensors",filter)
answer=hybrid~selectColumnar("sensors",filter,"temperature","")
call check answer~rows~items=reference~rows~items,"row-column count parity"
call check answer~rows[1]["temperature"]=reference~rows[1]["temperature"],"row-column value parity"
call check hybrid~selectColumnar("sensors",filter,"id,temperature,notes,blob","")==.nil,"wide AUTO -> row"
call check hybrid~selectColumnar("sensors",.SQLComparisonPredicate~new("id","=",3),"temperature","")==.nil,"indexed PK -> row"
call check hybrid~setLayout("sensors","ROW")="ROW","row mode"
call check hybrid~table("sensors")~isA(.TestRowTable),"row table presentation"
call check hybrid~selectColumnar("sensors",filter,"temperature","")==.nil,"row suppresses projection"
call check hybrid~setLayout("sensors","COLUMN")="COLUMN","column mode"
call check hybrid~selectColumnar("sensors",filter,"id,temperature,notes,blob","")~rows~items=1,"forced column mode"
source~generation=2
call check hybrid~selectColumnar("sensors",filter,"temperature","")==.nil,"stale projection invalidated"
call check hybrid~table("sensors")~isA(.TestRowTable),"stale projection falls back"
say "PASS v0.93-dev1 segmented late materialisation and layout"
exit 0

check: procedure
  use arg truth, message
  if \truth then do
    say "FAIL" message
    exit 1
  end
  return

::requires "../src/NoSQLServerColumnar.cls"

::class TestRowTable public
::attribute definition
::attribute generation
::attribute storedRows
::method init
  use strict arg definition, rows
  self~definition=definition
  self~storedRows=rows
  self~generation=1
::method readRows
  return self~storedRows
::method rowCount
  return self~storedRows~items

::class TestRowEngine public
::attribute physical
::method init
  use strict arg physical
  self~physical=physical
::method table
  use strict arg name
  if name~caselessEquals(self~physical~definition~name) then return self~physical
  return .nil
::method selectWhere
  use strict arg name, predicate
  t=self~table(name)
  r=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  selected=.array~new
  do row over t~readRows
    if predicate == .nil then selected~append(row)
    else if predicate~evaluate(row,t~definition) then selected~append(row)
  end
  r~rows=selected
  r~rowsScanned=t~rowCount
  r~affectedRows=selected~items
  r~accessPath="ROW_ENGINE_SCAN"
  return r
::method queryPatternLog
  return .NullQueryPatternLog~new
::method version
  return .NoSQLServerVersionInfo~new(1)
