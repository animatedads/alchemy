/* t_mapped.rex -- MappedObjects on NoSQLServer's FILE engine, with Tom
   Dyer's example: a Person from ent.per, its addresses from ent.addr through
   the link table ent.per_addr; with an extension table (ent.per_ext), owned
   notes (ent.note) and a reference to a company (ent.com).
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx t_mapped.rex SCRATCH_DIR
     SCRATCH_DIR: a new, empty folder; the test makes its databases in it.
     REXX_PATH: this package's src, NoSQLServer's src, alchemy_objects' src
     and crypto's src. */
parse arg base .
base = base~strip
if base == "" then do
  say "usage: rexx t_mapped.rex SCRATCH_DIR"
  return 2
end
call SysFileTree base"/*", "x.", "B"
if x.0 > 0 then do
  say "t_mapped: SCRATCH_DIR must be empty:" base
  return 2
end
fails = 0
checks = 0
say "t_mapped: MappedObjects" .ObjectStore~module_version

-- the database, as a DBA would have made it
ent = makeDb(base, "ent")
sql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(ent))
call run "CREATE TABLE com (com_id INTEGER PRIMARY KEY, com_name VARCHAR NOT NULL)"
call run "CREATE TABLE per (per_id INTEGER PRIMARY KEY, per_name VARCHAR NOT NULL, per_company INTEGER REFERENCES com(com_id))"
call run "CREATE TABLE per_ext (per_id INTEGER PRIMARY KEY REFERENCES per(per_id), phone VARCHAR)"
call run "CREATE TABLE addr (addr_id INTEGER PRIMARY KEY, addr_street VARCHAR, addr_town VARCHAR)"
call run "CREATE TABLE per_addr (per_id INTEGER NOT NULL REFERENCES per(per_id), addr_id INTEGER NOT NULL REFERENCES addr(addr_id))"
call run "CREATE TABLE note (note_id INTEGER PRIMARY KEY, per_id INTEGER REFERENCES per(per_id), note_text VARCHAR)"
call run "INSERT INTO com (com_id, com_name) VALUES (10, 'Anduin')"
call run "INSERT INTO per (per_id, per_name, per_company) VALUES (1, 'Tom', 10)"
call run "INSERT INTO per (per_id, per_name) VALUES (2, 'Rony')"
call run "INSERT INTO per_ext (per_id, phone) VALUES (1, '0141 555 0100')"
call run "INSERT INTO addr (addr_id, addr_street, addr_town) VALUES (100, 'Byres Road', 'Glasgow')"
call run "INSERT INTO addr (addr_id, addr_street, addr_town) VALUES (101, 'Augasse', 'Wien')"
call run "INSERT INTO per_addr (per_id, addr_id) VALUES (1, 100)"
call run "INSERT INTO per_addr (per_id, addr_id) VALUES (1, 101)"
call run "INSERT INTO per_addr (per_id, addr_id) VALUES (2, 101)"
call run "INSERT INTO note (note_id, per_id, note_text) VALUES (500, 1, 'first')"
call run "INSERT INTO note (note_id, per_id, note_text) VALUES (501, 1, 'second')"

store = .ObjectStore~new
store~attach("ent", ent)

-- the map, read from the annotations
m = store~map(.Person)
call check "the map: ent.per, key per_id, the id attribute", m~qualified == "ENT.per" & m~key == "per_id" & m~keyAttribute == "id"
call check "  its columns, with phone in the extension table", m~columns~items = 3 & m~extensions~items = 1 & m~extensions[1] == "ENT.per_ext"
kinds = ""
do p over m~parts
  kinds = kinds p~attribute":"p~kind":"p~owned
end
call check "  its parts:" kinds~strip, kinds~strip == "addresses:LINK:0 employer:ONE:0 notes:MANY:1"
g = store~graphLines
call check "graph lines: the object over its tables", g~pos("OBJECT" || "09"x || "PERSON" || "09"x || "ENT.per") > 0 & -
  g~pos("addresses" || "09"x || "LINK" || "09"x || "ENT.addr" || "09"x || "ENT.per_addr" || "09"x || "SHARED") > 0 & -
  g~pos("EXT" || "09"x || "ENT.per_ext") > 0
call refusesWith "a map that does not fit the database: every problem at once", "store~map(.Drifted)", "has no column per_nickname; there is no table ENT.nowhere"

-- loading: one object over five tables
s = store~session
tom = s~find(.Person, 1)
call check "find: the name, from per", tom~name == "Tom" & tom~id == 1
call check "  the phone, from per_ext", tom~phone == "0141 555 0100"
call check "  the employer, a Company", tom~employer~isA(.Company) & tom~employer~name == "Anduin"
call check "  the addresses, through per_addr", tom~addresses~items = 2 & tom~addresses[1]~street == "Byres Road"
call check "  the notes, owned", tom~notes~items = 2 & tom~notes[2]~text == "second"
rony = s~find(.Person, 2)
call check "one object per key: the address Tom and Rony share is one object", rony~addresses[1] == tom~addresses[2]
call check "  Rony has no phone row: nil", rony~phone == .nil & rony~employer == .nil
call check "find of a key that is not there: nil", s~find(.Person, 99) == .nil
call check "nothing changed, nothing to do", s~plan~items = 0

-- changing: only what changed
tom~name = "Tom Dyer"
plan = s~plan
call check "a name changed: one UPDATE of per:" plan[1], plan~items = 1 & plan[1]~string == "UPDATE per SET per_name = 'Tom Dyer' WHERE per_id = 1"
tom~phone = "0141 555 0199"
call check "a phone changed: an UPDATE of per_ext as well", s~plan~items = 2 & s~plan[2]~string~pos("UPDATE per_ext SET phone") = 1
call check "commit: 2 statements", s~commit = 2
call check "  in the database", value1("SELECT per_name FROM per WHERE per_id = 1") == "Tom Dyer" & value1("SELECT phone FROM per_ext WHERE per_id = 1") == "0141 555 0199"
call check "  and nothing left to do", s~plan~items = 0

-- the link table: a new address, a shared one taken out
home = s~new(.Address)
home~street = "Great Western Road"; home~town = "Glasgow"
tom~addresses~append(home)
plan = s~plan
call check "a new address: INSERT addr, then INSERT per_addr", plan~items = 2 & plan[1]~string~pos("INSERT INTO addr") = 1 & plan[2]~string == "INSERT INTO per_addr (per_id, addr_id) VALUES (1, 102)"
call check "  its key, generated: max + 1", s~keyOf(home) == 102
wien = tom~addresses[2]
tom~addresses~delete(2)
plan = s~plan
call check "a shared address taken out: only its link deleted", plan~items = 3 & plan[3]~string == "DELETE FROM per_addr WHERE per_id = 1 AND addr_id = 101"
call check "commit", s~commit = 3
call check "  Wien is still Rony's", value1("SELECT COUNT(*) AS n FROM per_addr WHERE addr_id = 101") = 1 & value1("SELECT COUNT(*) AS n FROM addr") = 3

-- an owned note taken out is deleted
tom~notes~delete(1)
call check "an owned note taken out: deleted", s~plan[1]~string == "DELETE FROM note WHERE note_id = 500"
call check "commit", s~commit = 1

-- a new Person, with everything, in the right order
ada = s~new(.Person)
ada~name = "Ada"; ada~phone = "0131 555 0123"; ada~employer = tom~employer
ada~addresses~append(home)
n = s~new(.Note); n~text = "met at the ooRexx developers' call"
ada~notes~append(n)
plan = s~plan
order = ""
do st over plan
  order = order st~string~word(3)
end
call check "a new Person: per, per_ext, note, per_addr:" order~strip, order~strip == "per per_ext note per_addr"
call check "  its key generated (3), the note holds it", plan[1]~string~pos("VALUES (10, 3, 'Ada')") > 0 & plan[3]~string~pos(", 3)") > 0
call check "commit", s~commit = 4
call check "  ada~id is its key", ada~id == 3

-- a fresh session sees what was committed
s2 = store~session
ada2 = s2~find(.Person, 3)
call check "a fresh session: Ada, her phone, note, address, employer", ada2~name == "Ada" & ada2~phone == "0131 555 0123" & ada2~notes~items = 1 & ada2~addresses[1]~street == "Great Western Road" & ada2~employer~name == "Anduin"
call check "  Tom has two addresses now", s2~find(.Person, 1)~addresses~items = 2

-- all or nothing
bad = s2~find(.Person, 2)
bad~name = .nil                                  -- per_name is NOT NULL
bad~phone = "missing"
call refusesWith "a commit the database refuses: refused", "s2~commit", "nothing was changed"
call check "  nothing changed in the database", value1("SELECT per_name FROM per WHERE per_id = 2") == "Rony" & value1("SELECT COUNT(*) AS n FROM per_ext") = 2
s2~rollback
call check "rollback: the objects as the database has them", bad~name == "Rony" & bad~phone == .nil & s2~plan~items = 0

-- deleting: links, owned parts, extension row, row; shared things stay
s2~delete(ada2)
plan = s2~plan
words = ""
do st over plan
  words = words st~string~word(3)
end
call check "delete Ada: her note, her link, her phone row, her row:" words~strip, words~strip == "note per_addr per_ext per"
call check "commit", s2~commit = 4
call check "  Ada gone, the address and company stay", value1("SELECT COUNT(*) AS n FROM per WHERE per_id = 3") = 0 & value1("SELECT COUNT(*) AS n FROM addr WHERE addr_id = 102") = 1 & value1("SELECT COUNT(*) AS n FROM com") = 1
call check "  find answers nil now", s2~find(.Person, 3) == .nil

-- two databases in one commit: refused
hr = makeDb(base, "hr")
hrSql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(hr))
r = hrSql~execute("CREATE TABLE badge (badge_id INTEGER PRIMARY KEY, badge_code VARCHAR)")
r = hrSql~execute("INSERT INTO badge (badge_id, badge_code) VALUES (1, 'A1')")
store~attach("hr", hr)
s3 = store~session
b = s3~find(.Badge, 1)
b~code = "A2"
t = s3~find(.Person, 1)
t~name = "Tom"
call refusesWith "one commit over two databases: refused", "s3~commit", "one database's"

-- the store's language
store~language = "de"
call refusesWith "refusals in German", "store~session~new(.NotMapped)", "nennt keine Tabelle"
call check "module_version", .ObjectStore~module_version == "0.1.0" & .ObjectSession~module_version == "0.1.0"

say "t_mapped:" checks - fails "of" checks "checks passed"
return fails

run:
  r = sql~execute(arg(1))
  if r~status \== .Error~SUCCESS then do
    say "t_mapped: setup failed:" r~error r~message "--" arg(1)
    exit 3
  end
  return

value1: procedure expose sql
  r = sql~execute(arg(1))
  d = r~asDirectories[1]
  do k over d~allIndexes
    return d[k]
  end
  return .nil

makeDb: procedure
  use arg root, name
  path = root"/"name
  call SysMkDir path
  e = .FileDatabaseEngine~new(path)
  cat = .table~new
  cat["name"] = name; cat["formatVersion"] = 1; cat["tables"] = .array~new
  e~writeCatalog(cat)
  return path

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refusesWith: procedure expose fails checks store s s2 s3
  use arg rfLabel, rfCode, rfWords
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  co = condition("O")
  if co~at("CODE") \== "93.900" | co~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the store:" rfLabel "--" co~at("MESSAGE")
    fails = fails + 1
    return
  end
  if co~at("ADDITIONAL")[1]~pos(rfWords) = 0 then do
    say "  FAIL refused, not saying" rfWords":" rfLabel "--" co~at("ADDITIONAL")[1]
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" co~at("ADDITIONAL")[1]
  return


-- Tom's example, as a programmer would write it: no base class, no SQL
::class Person public
::annotate class Person table "ent.per" key "per_id" generate "max"
::attribute id
::annotate attribute id column "per_id"
::attribute name
::annotate attribute name column "per_name"
::attribute phone
::annotate attribute phone column "phone" table "ent.per_ext"
::attribute addresses
::annotate attribute addresses many "Address" link "ent.per_addr" from "per_id" to "addr_id"
::attribute notes
::annotate attribute notes many "Note" column "per_id"
::attribute employer
::annotate attribute employer one "Company" column "per_company"

::class Address public
::annotate class Address table "ent.addr" key "addr_id" generate "max"
::attribute street
::annotate attribute street column "addr_street"
::attribute town
::annotate attribute town column "addr_town"

::class Note public
::annotate class Note table "ent.note" key "note_id" generate "max"
::attribute text
::annotate attribute text column "note_text"

::class Company public
::annotate class Company table "ent.com" key "com_id"
::attribute name
::annotate attribute name column "com_name"

::class Badge public
::annotate class Badge table "hr.badge" key "badge_id"
::attribute code
::annotate attribute code column "badge_code"

-- a class written for a schema that has moved on
::class Drifted public
::annotate class Drifted table "ent.per" key "per_id"
::attribute nick
::annotate attribute nick column "per_nickname"
::attribute old
::annotate attribute old column "x" table "ent.nowhere"

::class NotMapped public

::requires "MappedObjects.cls"
::requires "NoSQLServer.cls"
