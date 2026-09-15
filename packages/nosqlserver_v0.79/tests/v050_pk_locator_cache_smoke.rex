root=.NoSQLServerTestSupport~createBlankDatabase("v050")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR)")
raw=.Yaml~new~parseFile(root || "/tables/customer/table.yaml")
raw["storage"]["tombstoneThresholdBytes"]=0
.Yaml~toYamlFile(raw, root || "/tables/customer/table.yaml")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

-- First INSERT builds the empty PK cache; subsequent inserts maintain it.
call ok sql~execute("INSERT INTO customer VALUES (1,'one')")
cache=db~primaryKeyCache("customer")
call assert cache~generation=1, "cache generation after insert 1"
call assert cache~entries~items=1, "cache size 1"

call ok sql~execute("INSERT INTO customer VALUES (2,'two')")
cache2=db~primaryKeyCache("customer")
call assert cache~generation=2, "cache generation after insert 2"
call assert cache~entries~items=2, "cache size 2"

bad=sql~execute("INSERT INTO customer VALUES (2,'duplicate')")
call assert bad~status=.Error~NOTEXECUTED, "duplicate PK rejected from cache"
call assert cache~generation=2, "failed insert does not advance cache"

-- PK equality UPDATE uses cached physical locator and maintains new PK mapping.
call ok sql~execute("UPDATE customer SET id=20,name='twenty' WHERE id=2")
cache=db~primaryKeyCache("customer")
probe=.DatabaseRow~new
probe["id"]=20
sig=db~table("customer")~primaryKeySignature(probe)
entry=cache~lookup(sig)
call assert entry \== .nil, "new PK cached"
call assert entry["row"]["name"]="twenty", "cached updated row"
probe2=.DatabaseRow~new
probe2["id"]=2
oldsig=db~table("customer")~primaryKeySignature(probe2)
call assert cache~lookup(oldsig)==.nil, "old PK removed"

-- PK equality DELETE uses locator and removes cache entry.
call ok sql~execute("DELETE FROM customer WHERE id=20")
cache=db~primaryKeyCache("customer")
call assert cache~lookup(sig)==.nil, "deleted PK removed"
call assert cache~entries~items=1, "one cache entry remains"

-- A rewrite operation invalidates the cache. Reopen/access rebuilds from authority.
call ok sql~execute("INSERT INTO customer VALUES (3,'three'),(4,'four')")
newCache=db~primaryKeyCache("customer")
call assert newCache~entries~items=3, "rebuilt cache sees live rows"

-- Compaction invalidates physical locations and forces another rebuild.
before=newCache
call ok db~compactTable("customer")
after=db~primaryKeyCache("customer")
call assert after~entries~items=3, "post-compact cache rebuilt"

q=sql~execute("SELECT id,name FROM customer ORDER BY id")
call assert q~rows~items=3, "logical rows intact"
call assert q~rows[1]["id"]=1, "id1"
call assert q~rows[2]["id"]=3, "id3"
call assert q~rows[3]["id"]=4, "id4"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("PK_PHYSICAL_LOCATOR"), "locator survives newer release"
call assert db~version~supports("RUNTIME_PK_CACHE"), "cache capability"
call assert db~version~supports("PK_PHYSICAL_LOCATOR"), "locator capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.50 PK LOCATOR CACHE SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "operation"
  return

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
