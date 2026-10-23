root=.NoSQLServerTestSupport~createBlankDatabase("v049")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR, note VARCHAR)")
raw=.Yaml~new~parseFile(root || "/tables/customer/table.yaml")
raw["storage"]["tombstoneThresholdBytes"]=0
.Yaml~toYamlFile(raw, root || "/tables/customer/table.yaml")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)
call ok sql~execute("INSERT INTO customer VALUES (1,'one','a'),(2,'two','b'),(3,'three','c')")

t=db~table("customer")
dataPath=root || "/tables/customer/data"
call assert t~definition~tombstoneHex="FD", "default tombstone FD"
call assert t~storage~physicalLineCount=4, "header plus three rows"

-- Single-row UPDATE: replacement appended, old line tombstoned in place.
r=sql~execute("UPDATE customer SET name='two updated' WHERE id=2")
call ok r
call assert r~affectedRows=1, "update count"
t=db~table("customer")
call assert t~storage~physicalLineCount=5, "update appended one physical line"
old=t~storage~rawPhysicalLine(3)
call assert old=x2c("FD")~copies(old~length), "old row is FD tombstone"

q=sql~execute("SELECT id,name FROM customer ORDER BY id")
call assert q~rows~items=3, "logical row count after update"
call assert q~rows[2]["id"]=2, "updated id"
call assert q~rows[2]["name"]="two updated", "updated replacement visible"

-- Single-row DELETE: blank/tombstone only, file gains no row.
r=sql~execute("DELETE FROM customer WHERE id=1")
call ok r
call assert r~affectedRows=1, "delete count"
t=db~table("customer")
call assert t~storage~physicalLineCount=5, "delete does not append"
dead=t~storage~rawPhysicalLine(2)
call assert dead=x2c("FD")~copies(dead~length), "deleted row is FD tombstone"
q=sql~execute("SELECT id FROM customer ORDER BY id")
call assert q~rows~items=2, "logical row count after delete"
call assert q~rows[1]["id"]=2, "first survivor"
call assert q~rows[2]["id"]=3, "second survivor"

-- Changed-only constraint validation still detects collision with an unchanged row.
call ok sql~execute("CREATE TABLE constraint_probe (id INTEGER PRIMARY KEY, name VARCHAR)")
call ok sql~execute("INSERT INTO constraint_probe VALUES (1,'one'),(2,'two')")
bad=sql~execute("UPDATE constraint_probe SET id=2 WHERE id=1")
call assert bad~status=.Error~NOTEXECUTED, "changed-row PK collision rejected"
q=sql~execute("SELECT id FROM constraint_probe ORDER BY id")
call assert q~rows~items=2, "constraint failure preserves rows"
call assert q~rows[1]["id"]=1, "constraint row one preserved"
call assert q~rows[2]["id"]=2, "constraint row two preserved"

-- Reader must remain clean across a reopen: tombstones are storage, not rows.
db2=.FileDatabaseEngine~new(root)
sql2=.NoSQLServerSQL~new(db2)
q=sql2~execute("SELECT id,name FROM customer ORDER BY id")
call assert q~rows~items=2, "reopened reader skips tombstones"
call assert q~rows[1]["name"]="two updated", "reopened updated row"

-- Compaction rewrites live rows only and resets physical dead space.
r=db2~compactTable("customer")
call ok r
call assert r~affectedRows=2, "compaction live rows"
t=db2~table("customer")
call assert t~storage~physicalLineCount=3, "compaction removes tombstone slots"
do lineNo=2 to 3
  raw=t~storage~rawPhysicalLine(lineNo)
  call assert raw \= x2c("FD")~copies(raw~length), "compacted line live" lineNo
end

-- FE-delimited tables can independently retain FD as tombstone.
cols=.array~new
cols~append(.DatabaseColumn~new("id","INTEGER",.false,.false,.true))
cols~append(.DatabaseColumn~new("value","VARCHAR",.true,.false,.false))
r=db2~createTable("fe_table",cols,.array~of("id"),.nil,x2c("FE"),"\\N",.nil,"FD",0)
call ok r
ft=db2~table("fe_table")
call assert ft~definition~delimiterDefinition~resolved=x2c("FE"), "FE separator"
call assert ft~definition~tombstoneByte=x2c("FD"), "FD tombstone beside FE separator"
call ok .NoSQLServerSQL~new(db2)~execute("INSERT INTO fe_table VALUES (1,'hello'),(2,'world')")
call ok .NoSQLServerSQL~new(db2)~execute("DELETE FROM fe_table WHERE id=1")
ft=db2~table("fe_table")
fdline=ft~storage~rawPhysicalLine(2)
call assert fdline=x2c("FD")~copies(fdline~length), "FE table FD tombstone"
q=.NoSQLServerSQL~new(db2)~execute("SELECT id,value FROM fe_table")
call assert q~rows~items=1, "FE reader skips FD tombstone"
call assert q~rows[1]["id"]=2, "FE survivor"

-- Per-table tombstone byte can be changed when FD is unsuitable.
cols=.array~new
cols~append(.DatabaseColumn~new("id","INTEGER",.false,.false,.true))
cols~append(.DatabaseColumn~new("value","VARCHAR",.true,.false,.false))
r=db2~createTable("fc_table",cols,.array~of("id"),.nil,",","\\N",.nil,"FC",0)
call ok r
call ok .NoSQLServerSQL~new(db2)~execute("INSERT INTO fc_table VALUES (1,'custom'),(2,'keep')")
call ok .NoSQLServerSQL~new(db2)~execute("DELETE FROM fc_table WHERE id=1")
ct=db2~table("fc_table")
call assert ct~definition~tombstoneHex="FC", "custom tombstone metadata"
raw=ct~storage~rawPhysicalLine(2)
call assert raw~verify(x2c("FC"),"N")=0, "custom FC tombstone physical bytes"
q=.NoSQLServerSQL~new(db2)~execute("SELECT id FROM fc_table")
call assert q~rows~items=1, "custom tombstone reader"
call assert q~rows[1]["id"]=2, "custom tombstone survivor"

-- A logical CSV row containing a newline spans >1 physical line. It must use
-- the safe whole-file rewrite instead of a line-number tombstone.
call ok sql2~execute("CREATE TABLE multiline (id INTEGER PRIMARY KEY, note VARCHAR)")
raw=.Yaml~new~parseFile(root || "/tables/multiline/table.yaml")
raw["storage"]["tombstoneThresholdBytes"]=0
.Yaml~toYamlFile(raw, root || "/tables/multiline/table.yaml")
db2=.FileDatabaseEngine~new(root)
sql2=.NoSQLServerSQL~new(db2)
mt=db2~table("multiline")
vals=.table~new
vals["id"]=1
vals["note"]="line one" || x2c("0A") || "line two"
ignore=mt~insert(vals)
mt=db2~table("multiline")
located=mt~storage~readLocatedRows
call assert located[1]["lineCount"]>1, "multiline row spans physical lines"
beforeLines=mt~storage~physicalLineCount
r=.NoSQLServerSQL~new(db2)~execute("UPDATE multiline SET note='flattened' WHERE id=1")
call ok r
mt=db2~table("multiline")
afterLines=mt~storage~physicalLineCount
call assert afterLines<beforeLines, "multiline update used compact rewrite"
q=.NoSQLServerSQL~new(db2)~execute("SELECT note FROM multiline WHERE id=1")
call assert q~rows[1]["note"]="flattened", "multiline fallback update correct"

call assert db2~version~product="NoSQLServer", "version product"
call assert db2~version~supports("PHYSICAL_TOMBSTONES"), "tombstones survive newer release"
call assert db2~version~supports("PHYSICAL_TOMBSTONES"), "tombstone capability"
call assert db2~version~supports("APPEND_TOMBSTONE_UPDATE"), "update capability"
call assert db2~version~supports("TOMBSTONE_DELETE"), "delete capability"
call assert db2~version~supports("TABLE_COMPACTION"), "compact capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.49 TOMBSTONE STORAGE SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "operation"
  return

assert: procedure
  use arg condition,message,detail=""
  if \condition then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
