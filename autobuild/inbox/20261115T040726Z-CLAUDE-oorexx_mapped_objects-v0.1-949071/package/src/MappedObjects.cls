/* MappedObjects.cls -- one ooRexx object over several tables.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  German: Claude (Opus 5.5).

   A class says where its object lives with ::ANNOTATE, on the class itself:

     ::class Person public
     ::annotate class Person table "ent.per" key "per_id" generate "max"
     ::attribute name
     ::annotate attribute name column "per_name"
     ::attribute phone
     ::annotate attribute phone column "phone" table "ent.per_ext"
     ::attribute addresses
     ::annotate attribute addresses many "Address" link "ent.per_addr" from "per_id" to "addr_id"
     ::attribute notes
     ::annotate attribute notes many "Note" column "per_id" owned "yes"
     ::attribute employer
     ::annotate attribute employer one "Company" column "per_company"

   The kinds of attribute:
     column C [table T]        a value: column C of the class's table, or of an
                               extension table T that shares the class's key
     one K column C            a reference to one K: C (here) holds K's key
     many K column C           K objects whose column C holds this one's key
     many K link L from F to T K objects through link table L: F is this
                               one's key, T the K's key (one-to-many or
                               many-to-many, by the link's own keys)
     owned "yes"|"no"          on a many: owned parts are deleted with the
                               object and when taken out of the collection;
                               shared parts lose only their link (or their
                               reference, which must then be nullable).
                               Default: column many owned, link many shared.

   "schema.table": the schema is the database the store attached by that
   name (ObjectStore~attach); a table with no schema is in the store's first.

   ObjectStore~map(class) reads and checks a class's map against the
   databases' catalogues: every problem at once, when the class is first
   used, not at run time on a form.  ObjectStore~session gives a unit of
   work: find, where, new, delete, commit, rollback.  One object per key in
   a session (an identity map); commit works out the statements from what
   changed since the objects were loaded and runs them in one NoSQLServer
   transaction, all or nothing.  The classes need no base class and no
   database code: a class's init must take no arguments.

   Limits of v0.1: one database per commit (a transaction of NoSQLServer's
   is one database's); parts are loaded with the object (one level of
   queries per part, no lazy loading); generate "max" is MAX+1 in the unit
   of work, not for writers in several processes at once. */

::requires "NoSQLServer.cls"

::class ObjectStore public
::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.1.0"
::method module_lastChanged
  return "2026-11-15"

::attribute language

::method init
  expose engines sqls order maps language types
  use strict arg language = "en"
  engines = .directory~new; sqls = .directory~new; order = .array~new; maps = .table~new
  types = .directory~new

-- a database, by the name its tables are qualified with: a FileDatabaseEngine
-- (or its folder)
::method attach
  expose engines sqls order
  use strict arg schema, engine
  if engine~isA(.String) then engine = .FileDatabaseEngine~new(engine)
  engines[schema~upper] = engine
  sqls[schema~upper] = .NoSQLServerSQL~new(engine)
  if order~index(schema~upper) == .nil then order~append(schema~upper)
  return engine

::method engine
  expose engines
  use strict arg schema
  e = engines[schema~upper]
  if e == .nil then self~refuse("err.noSchema", schema)
  return e

::method sql
  expose sqls
  use strict arg schema
  s = sqls[schema~upper]
  if s == .nil then self~refuse("err.noSchema", schema)
  return s

-- a value for a column, typed as the catalogue declares the column (so that
-- 1 goes to an INTEGER as 1 and "0141" to a VARCHAR as '0141'); .nil is NULL
::method value
  expose types
  use strict arg where, column, v
  if v == .nil then return .nil
  k = where~upper"."column~upper
  t = types[k]
  if t == .nil then do
    parse var where schema "." table
    t = "VARCHAR"
    tb = self~engine(schema)~table(table)
    if tb \== .nil then do c over tb~definition~columns
      if c~name~caselessEquals(column) then t = c~type~upper
    end
    types[k] = t
  end
  select
    when t == "INTEGER" then return .DatabaseValue~integer(v)
    when t == "DECIMAL" then return .DatabaseValue~decimal(v)
    when t == "BOOLEAN" then return .DatabaseValue~boolean(v)
    when t == "DATE" then return .DatabaseValue~date(v)
    when t == "DATETIME" then return .DatabaseValue~datetime(v)
    otherwise return .DatabaseValue~varchar(v)
  end

-- "schema.table" (or "table": the first schema attached) -> schema, table
::method split
  expose order
  use strict arg qualified
  if qualified~pos(".") > 0 then do
    parse var qualified schema "." table
    return .array~of(schema~upper, table)
  end
  if order~items = 0 then self~refuse("err.noSchema", qualified)
  return .array~of(order[1], qualified)

-- the map of a class: read from its annotations, checked against the catalogue
::method map
  expose maps
  use strict arg cls
  m = maps[cls]
  if m \== .nil then return m
  m = .ObjectMap~new(self, cls)
  maps[cls] = m                       -- before the check: parts may come back to it
  signal on syntax name bad
  m~check
  return m
bad:
  maps~remove(cls)
  raise propagate

::method session
  return .ObjectSession~new(self)

-- for a graph of the database: an OBJECT line for each class mapped, a PART
-- line for each attribute that is not a plain column (tab-separated)
::method graphLines
  expose maps
  out = .array~new
  t = "09"x
  do cls over maps~allIndexes~sortWith(.ObjectStoreClassOrder~new)
    m = maps[cls]
    out~append("OBJECT" || t || cls~id || t || m~qualified)
    do e over m~extensions
      out~append("PART" || t || cls~id || t || "-" || t || "EXT" || t || e || t || "-" || t || "OWNED")
    end
    do p over m~parts
      own = "SHARED"
      if p~owned then own = "OWNED"
      link = p~link
      if link == "" then link = "-"
      out~append("PART" || t || cls~id || t || p~attribute || t || p~kind || t || p~targetMap~qualified || t || link || t || own)
    end
  end
  return out~makeString("L", "0a"x)

::method text
  expose language
  use strict arg key, a1 = "", a2 = "", a3 = ""
  t = .resources["STRINGS."language~left(2)~upper]
  if t == .nil then t = .resources["STRINGS.EN"]
  s = omLookup(t, key)
  if s == "" then s = omLookup(.resources["STRINGS.EN"], key)
  if s == "" then return "<"key">"
  out = ""
  do while s~pos("%") > 0
    parse var s before "%" rest
    n = rest~left(1)
    s = rest~substr(2)
    select
      when n == "1" then out = out || before || a1
      when n == "2" then out = out || before || a2
      when n == "3" then out = out || before || a3
      otherwise out = out || before || "%" || n
    end
  end
  return out || s

::method refuse
  use strict arg key, a1 = "", a2 = "", a3 = ""
  raise syntax 93.900 array(self~text(key, a1, a2, a3))


::class ObjectStoreClassOrder
::method compare
  use strict arg a, b
  return a~id~compareTo(b~id)


/* A class's map: its table and key, its columns (in its own table and in
   extension tables), its parts. */
::class ObjectMap public
::attribute cls get
::attribute schema get
::attribute table get
::attribute key get                 -- the key column
::attribute keyAttribute get        -- the attribute that holds the key, "" if none
::attribute generate get
::attribute columns get             -- array of ObjectColumn
::attribute parts get               -- array of ObjectPart
::attribute extensions get          -- array of qualified extension tables
::attribute store get

::method init
  expose store cls schema table key keyAttribute generate columns parts extensions
  use strict arg store, cls
  t = cls~annotation("table")
  if t == .nil then store~refuse("err.noTable", cls~id)
  sp = store~split(t)
  schema = sp[1]; table = sp[2]
  key = cls~annotation("key")
  if key == .nil then store~refuse("err.noKey", cls~id)
  generate = cls~annotation("generate")
  if generate == .nil then generate = ""
  generate = generate~lower
  if generate \== "" & generate \== "max" then store~refuse("err.generate", cls~id, generate)
  columns = .array~new; parts = .array~new; extensions = .array~new
  keyAttribute = ""
  s = cls~methods(cls)
  names = .array~new
  do while s~available
    if s~index~right(1) \== "=" then if s~item~annotations~items > 0 then names~append(s~index)
    s~next
  end
  do name over names~sort
    a = cls~method(name)~annotations
    if a~hasIndex("ONE") | a~hasIndex("MANY") then do
      parts~append(.ObjectPart~new(self, name~lower, a))
      iterate
    end
    if \a~hasIndex("COLUMN") then store~refuse("err.attrKind", cls~id, name~lower)
    where = self~qualified
    if a~hasIndex("TABLE") then do
      sp = store~split(a["TABLE"])
      if sp[1] \== schema then store~refuse("err.extSchema", cls~id, name~lower)
      where = sp[1]"."sp[2]
      if where~caselessEquals(self~qualified) then where = self~qualified
      else if extensions~index(where) == .nil then extensions~append(where)
    end
    columns~append(.ObjectColumn~new(name~lower, where, a["COLUMN"]))
    if where == self~qualified, a["COLUMN"]~caselessEquals(key) then keyAttribute = name~lower
  end

::method qualified
  expose schema table
  return schema"."table

-- the columns that live in one table (qualified)
::method columnsIn
  expose columns
  use strict arg where
  out = .array~new
  do c over columns
    if c~table == where then out~append(c)
  end
  return out

-- every problem with the map at once, against the attached catalogues
::method check
  expose store cls schema table key columns parts extensions
  problems = .array~new
  engine = .nil
  signal on syntax name noSchema
  engine = store~engine(schema)
  signal off syntax
  if engine~table(table) == .nil then problems~append(store~text("chk.table", self~qualified))
  else if \omHasColumn(engine, table, key) then problems~append(store~text("chk.column", self~qualified, key))
  do c over columns
    parse value c~table with . "." t
    if engine~table(t) == .nil then do
      if problems~index(store~text("chk.table", c~table)) == .nil then problems~append(store~text("chk.table", c~table))
      iterate
    end
    if \omHasColumn(engine, t, c~column) then problems~append(store~text("chk.column", c~table, c~column))
  end
  do e over extensions
    parse var e . "." t
    if engine~table(t) \== .nil then if \omHasColumn(engine, t, key) then problems~append(store~text("chk.extKey", e, key))
  end
  do p over parts
    p~checkInto(problems)
  end
  if problems~items > 0 then store~refuse("err.map", cls~id, problems~makeString("L", "; "))
  return 0
noSchema:
  store~refuse("err.map", cls~id, condition("O")~at("ADDITIONAL")[1])

::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-15"


::class ObjectColumn public
::attribute attribute get
::attribute table get               -- qualified
::attribute column get
::method init
  expose attribute table column
  use strict arg attribute, table, column


/* A part: ONE (a reference: our column holds its key), MANY (its column holds
   our key) or LINK (a link table between our key and its key). */
::class ObjectPart public
::attribute attribute get
::attribute kind get
::attribute target get              -- the class's name
::attribute column get
::attribute link get                -- qualified link table, "" if none
::attribute from get
::attribute to get
::attribute owned get
::attribute map get

::method init
  expose map attribute kind target column link from to owned
  use strict arg map, attribute, a
  store = map~store
  link = ""; from = ""; to = ""; column = ""
  if a~hasIndex("ONE") then do
    kind = "ONE"; target = a["ONE"]
  end
  else do
    target = a["MANY"]
    if a~hasIndex("LINK") then do
      kind = "LINK"
      sp = store~split(a["LINK"])
      link = sp[1]"."sp[2]
      from = a["FROM"]; to = a["TO"]
      if from == .nil | to == .nil then store~refuse("err.linkEnds", map~cls~id, attribute)
    end
    else kind = "MANY"
  end
  if kind \== "LINK" then do
    column = a["COLUMN"]
    if column == .nil then store~refuse("err.partColumn", map~cls~id, attribute)
  end
  owned = (kind == "MANY")
  if a~hasIndex("OWNED") then owned = a["OWNED"]~caselessEquals("yes")
  if kind == "ONE" & owned then store~refuse("err.ownedOne", map~cls~id, attribute)

-- the class it holds, found beside the mapped class
::method targetClass
  expose map target
  c = map~cls~package~findClass(target)
  if c == .nil then c = .context~package~findClass(target)
  if c == .nil then map~store~refuse("err.noClass", map~cls~id, target)
  return c

::method targetMap
  return self~map~store~map(self~targetClass)

-- its problems, into the list (a refusal on the way is one of them)
::method checkInto
  use strict arg problems
  signal on syntax name failed
  self~check(problems)
  return 0
failed:
  problems~append(condition("O")~at("ADDITIONAL")[1])
  return 0

::method check
  expose map kind column link from to owned attribute
  use strict arg problems
  store = map~store
  tm = self~targetMap
  engine = store~engine(map~schema)
  select
    when kind == "ONE" then if \omHasColumn(engine, map~table, column) then problems~append(store~text("chk.column", map~qualified, column))
    when kind == "MANY" then do
      if tm~schema \== map~schema then problems~append(store~text("chk.oneSchema", map~cls~id, attribute))
      else if \omHasColumn(engine, tm~table, column) then problems~append(store~text("chk.column", tm~qualified, column))
      else if \owned then if \omNullable(engine, tm~table, column) then problems~append(store~text("chk.sharedNull", tm~qualified, column))
    end
    otherwise do
      parse var link ls "." lt
      if ls \== map~schema | tm~schema \== map~schema then problems~append(store~text("chk.oneSchema", map~cls~id, attribute))
      else if engine~table(lt) == .nil then problems~append(store~text("chk.table", link))
      else do
        if \omHasColumn(engine, lt, from) then problems~append(store~text("chk.column", link, from))
        if \omHasColumn(engine, lt, to) then problems~append(store~text("chk.column", link, to))
      end
    end
  end
  return 0


/* A unit of work: one object per key, what changed since it was loaded,
   committed in one transaction. */
::class ObjectSession public
::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-15"

::attribute store get

::method init
  expose store objects records counters
  use strict arg store
  objects = .directory~new          -- "CLASS|key" -> object
  records = .identityTable~new      -- object -> its record
  counters = .directory~new         -- "schema.table" -> the next key (generate "max")

-- the record of an object of this session
::method record private
  expose records
  use strict arg obj
  r = records[obj]
  if r == .nil then store~refuse("err.notInSession", obj~class~id)
  return r

::method stateOf
  expose records
  use strict arg obj
  r = records[obj]
  if r == .nil then return ""
  return r["STATE"]

::method keyOf
  use strict arg obj
  return self~record(obj)["KEY"]

-- the object with this key, loaded with its parts (.nil if there is none)
::method find
  expose store objects records
  use strict arg cls, key
  m = store~map(cls)
  id = cls~id"|"key
  if objects~hasIndex(id) then return objects[id]
  row = self~rowOf(m, m~qualified, key)
  if row == .nil then return .nil
  obj = self~make(cls)
  r = .directory~new
  r["MAP"] = m; r["KEY"] = key; r["STATE"] = "CLEAN"; r["ROWS"] = .directory~new; r["PARTS"] = .directory~new
  records[obj] = r; objects[id] = obj
  r["ROWS"][m~qualified] = row
  do e over m~extensions
    er = self~rowOf(m, e, key)
    if er == .nil then er = .directory~new         -- no row yet: one is inserted when a value is set
    r["ROWS"][e] = er
  end
  do c over m~columns
    obj~send(c~attribute"=", r["ROWS"][c~table][c~column~upper])
  end
  do p over m~parts
    self~loadPart(obj, r, p)
  end
  return obj

-- the keys where an attribute (a plain column of the class's table) has a value
::method where
  expose store
  use strict arg cls, attribute, value
  m = store~map(cls)
  col = ""
  do c over m~columns
    if c~attribute~caselessEquals(attribute) then col = c
  end
  if col == "" then store~refuse("err.noAttr", cls~id, attribute)
  parse value col~table with schema "." t
  rows = self~query(schema, "SELECT" m~key "FROM" t "WHERE" col~column "= ?", .array~of(store~value(col~table, col~column, value)))
  out = .array~new
  do row over rows
    out~append(self~find(cls, row[m~key~upper]))
  end
  return out

::method all
  expose store
  use strict arg cls
  m = store~map(cls)
  out = .array~new
  do row over self~query(m~schema, "SELECT" m~key "FROM" m~table "ORDER BY" m~key, .array~new)
    out~append(self~find(cls, row[m~key~upper]))
  end
  return out

-- a new object of a mapped class, to be inserted at the commit
::method new
  expose store records
  use strict arg cls
  m = store~map(cls)
  obj = self~make(cls)
  -- an attribute init did not set answers its own name: it is nil here
  do c over m~columns
    v = obj~send(c~attribute)
    if v~isA(.String) then if v == c~attribute~upper then obj~send(c~attribute"=", .nil)
  end
  do p over m~parts
    if p~kind \== "ONE" then iterate
    v = obj~send(p~attribute)
    if v~isA(.String) then if v == p~attribute~upper then obj~send(p~attribute"=", .nil)
  end
  r = .directory~new
  r["MAP"] = m; r["KEY"] = ""; r["STATE"] = "NEW"; r["ROWS"] = .directory~new; r["PARTS"] = .directory~new
  do p over m~parts
    if p~kind \== "ONE" then do
      obj~send(p~attribute"=", .array~new)
      r["PARTS"][p~attribute] = .array~new
    end
  end
  records[obj] = r
  return obj

::method delete
  use strict arg obj
  r = self~record(obj)
  if r["STATE"] == "NEW" then r["STATE"] = "DROPPED"
  else r["STATE"] = "DELETED"
  return 0

-- the statements the commit would run, without running them (for a log, a test, a review)
::method plan
  use strict arg
  return self~statements~makeArray

-- run what changed, in one transaction; all or nothing
::method commit
  expose store records objects counters
  stmts = self~statements
  if stmts~items = 0 then return 0
  schema = stmts[1]~schema
  do s over stmts
    if s~schema \== schema then store~refuse("err.twoSchemas", schema, s~schema)
  end
  tx = store~engine(schema)~transaction
  do s over stmts
    q = tx~execute(s~text)
    if q~status \== "NOTEXECUTED" & q~status \== .Error~SUCCESS then do
      tx~rollback
      self~forgetKeys
      store~refuse("err.commit", q~error q~message, s~text)
    end
  end
  c = tx~commit
  if c~status \== "COMMITTED" then do
    self~forgetKeys
    store~refuse("err.commit", c~error c~message, "")
  end
  -- what is in the database now is what the objects say
  do obj over records~allIndexes
    r = records[obj]
    select
      when r["STATE"] == "DELETED" | r["STATE"] == "DROPPED" then do
        objects~remove(r["MAP"]~cls~id"|"r["KEY"])
        records~remove(obj)
      end
      otherwise do
        if r["STATE"] == "NEW" then objects[r["MAP"]~cls~id"|"r["KEY"]] = obj
        r["STATE"] = "CLEAN"
        m = r["MAP"]
        do e over m~extensions                      -- an extension row with no values was not written
          if \omAnyValue(r["WANT"][e], m~key) then if r["ROWS"][e] == .nil | r["ROWS"]~hasIndex(e) & r["ROWS"][e]~items = 0 then r["WANT"][e] = .directory~new
        end
        r["ROWS"] = r["WANT"]
        r["PARTS"] = r["WANTPARTS"]
        r~remove("GENERATED")
      end
    end
  end
  return stmts~items

-- the session's objects back to the database's values
::method rollback
  expose records objects
  do obj over records~allIndexes
    r = records[obj]
    if r["STATE"] == "NEW" | r["STATE"] == "DROPPED" then do
      records~remove(obj)
      iterate
    end
    r["STATE"] = "CLEAN"
    m = r["MAP"]
    do c over m~columns
      obj~send(c~attribute"=", r["ROWS"][c~table][c~column~upper])
    end
    do p over m~parts
      if p~kind == "ONE" then obj~send(p~attribute"=", r["PARTS"][p~attribute])
      else obj~send(p~attribute"=", r["PARTS"][p~attribute]~copy)
    end
  end
  return 0

/* ---------------------------------------------------------------- internals */

::method make private
  expose store
  use strict arg cls
  signal on syntax name noInit
  return cls~new
noInit:
  store~refuse("err.init", cls~id, condition("O")~at("MESSAGE"))

::method query private
  expose store
  use strict arg schema, text, args
  r = store~sql(schema)~execute(omBind(text, args))
  if r~status \== .Error~SUCCESS then store~refuse("err.query", r~error r~message, text)
  out = .array~new
  do d over r~asDirectories
    row = .directory~new
    do k over d~allIndexes
      n = k
      if n~pos(".") > 0 then n = n~substr(n~lastPos(".") + 1)
      row[n~upper] = d[k]
    end
    out~append(row)
  end
  return out

-- one row of a table by the class's key (.nil if none)
::method rowOf private
  expose store
  use strict arg m, where, key
  parse var where schema "." t
  rows = self~query(schema, "SELECT * FROM" t "WHERE" m~key "= ?", .array~of(store~value(where, m~key, key)))
  if rows~items = 0 then return .nil
  return rows[1]

::method loadPart private
  expose store
  use strict arg obj, r, p
  m = r["MAP"]; key = r["KEY"]
  tm = p~targetMap
  select
    when p~kind == "ONE" then do
      fk = r["ROWS"][m~qualified][p~column~upper]
      t = .nil
      if fk \== .nil, fk \== "" then t = self~find(tm~cls, fk)
      obj~send(p~attribute"=", t)
      r["PARTS"][p~attribute] = t
    end
    when p~kind == "MANY" then do
      list = .array~new
      do row over self~query(tm~schema, "SELECT" tm~key "FROM" tm~table "WHERE" p~column "= ? ORDER BY" tm~key, .array~of(store~value(tm~qualified, p~column, key)))
        list~append(self~find(tm~cls, row[tm~key~upper]))
      end
      obj~send(p~attribute"=", list)
      r["PARTS"][p~attribute] = list~copy
    end
    otherwise do
      parse value p~link with schema "." lt
      list = .array~new
      do row over self~query(schema, "SELECT" p~to "FROM" lt "WHERE" p~from "= ? ORDER BY" p~to, .array~of(store~value(p~link, p~from, key)))
        list~append(self~find(tm~cls, row[p~to~upper]))
      end
      obj~send(p~attribute"=", list)
      r["PARTS"][p~attribute] = list~copy
    end
  end
  return 0

::method forgetKeys private
  expose records counters
  counters = .directory~new
  do obj over records~allIndexes
    r = records[obj]
    if r["STATE"] == "NEW" then if r["GENERATED"] == 1 then do
      r["KEY"] = ""
      r~remove("GENERATED")
      m = r["MAP"]
      if m~keyAttribute \== "" then obj~send(m~keyAttribute"=", .nil)
    end
  end

-- the key of an object: its key attribute, a generated one for a new object
::method keyFor private
  expose store counters
  use strict arg obj, r
  m = r["MAP"]
  if r["KEY"] \== "" then return r["KEY"]
  k = ""
  if m~keyAttribute \== "" then do
    k = obj~send(m~keyAttribute)
    if k == .nil then k = ""
  end
  if k == "" then do
    if m~generate \== "max" then store~refuse("err.needKey", m~cls~id)
    q = m~qualified
    if \counters~hasIndex(q) then do
      rows = self~query(m~schema, "SELECT MAX("m~key") AS mx FROM" m~table, .array~new)
      top = 0
      if rows~items > 0 then if rows[1]["MX"] \== .nil then if datatype(rows[1]["MX"], "W") then top = rows[1]["MX"]
      counters[q] = top + 1
    end
    k = counters[q]
    counters[q] = k + 1
    r["GENERATED"] = 1
    if m~keyAttribute \== "" then obj~send(m~keyAttribute"=", k)
  end
  r["KEY"] = k
  return k

/* What the database must become: for each object, the rows it wants (its
   columns, its references' keys, the keys of the objects whose many-parts
   hold it) and the links it wants; then the statements that get there. */
::method statements private
  expose store records
  live = .array~new; gone = .array~new
  do obj over records~allIndexes
    s = records[obj]["STATE"]
    if s == "DELETED" then gone~append(obj)
    else if s \== "DROPPED" then live~append(obj)
  end
  -- deleting an object deletes its owned parts
  i = 0
  do while i < gone~items
    i = i + 1
    r = records[gone[i]]
    do p over r["MAP"]~parts
      if p~kind == "ONE" | \p~owned then iterate
      do child over r["PARTS"][p~attribute]
        cr = records[child]
        if cr == .nil then iterate
        if cr["STATE"] == "CLEAN" then do
          cr["STATE"] = "DELETED"
          gone~append(child)
          live~removeItem(child)
        end
      end
    end
  end
  -- owned parts taken out of their collection are deleted too
  do obj over live~copy
    r = records[obj]
    if r["STATE"] == "NEW" then iterate
    do p over r["MAP"]~parts
      if p~kind == "ONE" | \p~owned then iterate
      now = omList(obj~send(p~attribute))
      do child over r["PARTS"][p~attribute]
        if now~hasItem(child) then iterate
        cr = records[child]
        if cr == .nil then iterate
        if cr["STATE"] == "CLEAN" then do
          cr["STATE"] = "DELETED"
          gone~append(child)
          live~removeItem(child)
        end
      end
    end
  end
  -- objects reached through parts must be in the session
  do obj over live
    r = records[obj]
    do p over r["MAP"]~parts
      v = obj~send(p~attribute)
      if p~kind == "ONE" then v = omList(v)
      else v = omList(v)
      do t over v
        if records[t] == .nil then store~refuse("err.foreign", r["MAP"]~cls~id, p~attribute)
        if records[t]["STATE"] == "DELETED" | records[t]["STATE"] == "DROPPED" then store~refuse("err.holdsDeleted", r["MAP"]~cls~id, p~attribute)
      end
    end
  end
  -- keys first (a reference needs its target's key)
  do obj over live
    ignore = self~keyFor(obj, records[obj])
  end
  -- the rows each live object wants
  do obj over live
    r = records[obj]; m = r["MAP"]
    want = .directory~new
    want[m~qualified] = .directory~new
    want[m~qualified][m~key~upper] = r["KEY"]
    do e over m~extensions
      want[e] = .directory~new
      want[e][m~key~upper] = r["KEY"]
    end
    do c over m~columns
      v = obj~send(c~attribute)
      want[c~table][c~column~upper] = v
    end
    do p over m~parts
      if p~kind \== "ONE" then iterate
      t = obj~send(p~attribute)
      if t == .nil then want[m~qualified][p~column~upper] = .nil
      else want[m~qualified][p~column~upper] = records[t]["KEY"]
    end
    r["WANT"] = want
  end
  -- many-parts: a shared child taken out of its parent's collection, or
  -- whose parent is deleted, loses the reference; then each child in a
  -- collection gets its parent's key (so a child moved between parents ends
  -- with its new one)
  do obj over live~copy~appendAll(gone)
    r = records[obj]
    if r["STATE"] == "NEW" then iterate
    do p over r["MAP"]~parts
      if p~kind \== "MANY" then iterate
      now = .array~new
      if r["STATE"] \== "DELETED" then now = omList(obj~send(p~attribute))
      tm = p~targetMap
      do child over r["PARTS"][p~attribute]
        if now~hasItem(child) then iterate
        cr = records[child]
        if cr == .nil then iterate
        if cr["STATE"] == "CLEAN" then cr["WANT"][tm~qualified][p~column~upper] = .nil
      end
    end
  end
  do obj over live
    r = records[obj]
    wantParts = .directory~new
    do p over r["MAP"]~parts
      if p~kind == "ONE" then do
        wantParts[p~attribute] = obj~send(p~attribute)
        iterate
      end
      now = omList(obj~send(p~attribute))
      wantParts[p~attribute] = now~copy
      if p~kind \== "MANY" then iterate
      tm = p~targetMap
      do child over now
        records[child]["WANT"][tm~qualified][p~column~upper] = r["KEY"]
      end
    end
    r["WANTPARTS"] = wantParts
  end
  -- the statements: inserts (references before those that hold them),
  -- updates, links, deletes (holders before what they hold)
  out = .array~new
  done = .set~new
  do obj over live
    self~insertsFor(obj, out, done, .set~new)
  end
  do obj over live
    r = records[obj]
    if r["STATE"] \== "CLEAN" then iterate
    m = r["MAP"]
    do where over r["WANT"]~allIndexes~sort
      had = r["ROWS"][where]
      if had == .nil then had = .directory~new
      if had~items = 0 & where \== m~qualified then do              -- an extension row not there yet
        if omAnyValue(r["WANT"][where], m~key) then out~append(omInsert(store, where, r["WANT"][where]))
        iterate
      end
      sets = .array~new; args = .array~new
      do col over r["WANT"][where]~allIndexes~sort
        if col == m~key~upper then iterate
        old = had[col]; new = r["WANT"][where][col]
        if omSame(old, new) then iterate
        sets~append(col~lower "= ?"); args~append(store~value(where, col, new))
      end
      if sets~items = 0 then iterate
      parse var where schema "." t
      args~append(store~value(where, m~key, r["KEY"]))
      out~append(.ObjectStatement~new(schema, omBind("UPDATE" t "SET" sets~makeString("L", ", ") "WHERE" m~key "= ?", args)))
    end
  end
  do obj over live
    r = records[obj]
    do p over r["MAP"]~parts
      if p~kind \== "LINK" then iterate
      parse value p~link with schema "." lt
      had = .array~new
      if r["STATE"] == "CLEAN" then had = r["PARTS"][p~attribute]
      now = omList(obj~send(p~attribute))
      do t over now
        if had~hasItem(t) then iterate
        out~append(.ObjectStatement~new(schema, omBind("INSERT INTO" lt "("p~from"," p~to") VALUES (?, ?)", .array~of(store~value(p~link, p~from, r["KEY"]), store~value(p~link, p~to, records[t]["KEY"])))))
      end
      do t over had
        if now~hasItem(t) then iterate
        tr = records[t]
        if tr == .nil then iterate
        out~append(.ObjectStatement~new(schema, omBind("DELETE FROM" lt "WHERE" p~from "= ? AND" p~to "= ?", .array~of(store~value(p~link, p~from, r["KEY"]), store~value(p~link, p~to, tr["KEY"])))))
      end
    end
  end
  -- owned parts were added after their holders: the last first, so a child's
  -- row goes before its parent's
  done = .set~new
  do i = gone~items to 1 by -1
    self~deletesFor(gone[i], out, done)
  end
  return out

-- the inserts for a new object, after those for the objects it refers to
::method insertsFor private
  expose records store
  use strict arg obj, out, done, path
  r = records[obj]
  if r["STATE"] \== "NEW" | done~hasIndex(obj) then return
  if path~hasIndex(obj) then r["MAP"]~store~refuse("err.cycle", r["MAP"]~cls~id)
  path~put(obj)
  m = r["MAP"]
  do p over m~parts
    if p~kind == "ONE" then do
      t = obj~send(p~attribute)
      if t \== .nil then self~insertsFor(t, out, done, path)
    end
  end
  -- a child of a many-part: its parent first
  do other over records~allIndexes
    orr = records[other]
    if orr["STATE"] \== "NEW" | other == obj then iterate
    do p over orr["MAP"]~parts
      if p~kind \== "MANY" then iterate
      if omList(other~send(p~attribute))~hasItem(obj) then self~insertsFor(other, out, done, path)
    end
  end
  done~put(obj)
  out~append(omInsert(store, m~qualified, r["WANT"][m~qualified]))
  do e over m~extensions
    if omAnyValue(r["WANT"][e], m~key) then out~append(omInsert(store, e, r["WANT"][e]))
  end
  return

-- the deletes for a deleted object: its links, its extension rows, its row
::method deletesFor private
  expose records store
  use strict arg obj, out, done
  if done~hasIndex(obj) then return
  done~put(obj)
  r = records[obj]; m = r["MAP"]
  do p over m~parts
    if p~kind \== "LINK" then iterate
    parse value p~link with schema "." lt
    out~append(.ObjectStatement~new(schema, omBind("DELETE FROM" lt "WHERE" p~from "= ?", .array~of(store~value(p~link, p~from, r["KEY"])))))
  end
  do e over m~extensions
    parse var e schema "." t
    out~append(.ObjectStatement~new(schema, omBind("DELETE FROM" t "WHERE" m~key "= ?", .array~of(store~value(e, m~key, r["KEY"])))))
  end
  out~append(.ObjectStatement~new(m~schema, omBind("DELETE FROM" m~table "WHERE" m~key "= ?", .array~of(store~value(m~qualified, m~key, r["KEY"])))))
  return


::class ObjectStatement public
::attribute schema get
::attribute text get
::method init
  expose schema text
  use strict arg schema, text
::method string
  expose text
  return text


/* --------------------------------------------------------------- routines */

-- SQL with ? placeholders, the values put in by NoSQLServer's own binder
-- (text quoted, NULL kept): never a caller's string pasted in
::routine omBind
  use strict arg text, args
  if args~items = 0 then return text
  stmt = .DatabasePreparedStatement~new("om", text, args~items, "")
  out = .DatabaseParameterBinder~bind(stmt, args)
  if out~isA(.DatabaseResult) then do
    what = ""
    do v over args
      if v == .nil then what = what "NULL"
      else what = what v~typeName"("v~value")"
    end
    raise syntax 93.900 array("MappedObjects: " || out~message || ":" what "in" text)
  end
  return out

::routine omInsert
  use strict arg store, where, row
  parse var where schema "." t
  cols = .array~new; qs = .array~new; args = .array~new
  do c over row~allIndexes~sort
    if row[c] == .nil then iterate
    cols~append(c~lower); qs~append("?"); args~append(store~value(where, c, row[c]))
  end
  return .ObjectStatement~new(schema, omBind("INSERT INTO" t "(" || cols~makeString("L", ", ") || ") VALUES (" || qs~makeString("L", ", ") || ")", args))

-- a row with a value besides its key
::routine omAnyValue
  use strict arg row, key
  do c over row~allIndexes
    if c == key~upper then iterate
    if row[c] \== .nil then return .true
  end
  return .false

::routine omSame
  use strict arg a, b
  if a == .nil | b == .nil then return a == b
  if datatype(a, "N") & datatype(b, "N") then return a = b
  return a == b

-- a collection as an array (.nil: an empty one)
::routine omList
  use strict arg v
  if v == .nil then return .array~new
  if v~isA(.Array) then return v
  if v~hasMethod("MAKEARRAY") then return v~makeArray
  return .array~of(v)

::routine omHasColumn
  use strict arg engine, table, column
  t = engine~table(table)
  if t == .nil then return .false
  do c over t~definition~columns
    if c~name~caselessEquals(column) then return .true
  end
  return .false

::routine omNullable
  use strict arg engine, table, column
  do c over engine~table(table)~definition~columns
    if c~name~caselessEquals(column) then return c~nullable == 1 | c~nullable == .true
  end
  return .false

-- key = text, one a line, from a string table resource
::routine omLookup
  use strict arg lines, key
  if lines == .nil then return ""
  do l over lines
    parse var l k "=" v
    if k~strip == key then return v~strip
  end
  return ""

::resource strings.en
err.noSchema = No database attached as %1.
err.noTable = %1 says no table (::annotate class ... table "schema.table").
err.noKey = %1 says no key column (::annotate class ... key "column").
err.generate = %1: generate %2 is not known; "max" is.
err.attrKind = %1~%2: an annotated attribute needs column, one or many.
err.extSchema = %1~%2: an extension table must be in the class's own database.
err.linkEnds = %1~%2: a link needs from and to.
err.partColumn = %1~%2: one or many without a link needs column.
err.ownedOne = %1~%2: a reference (one) cannot be owned.
err.noClass = %1 refers to %2, which is not found.
err.map = The map of %1 does not fit the database: %2
err.notInSession = The %1 is not an object of this session.
err.noAttr = %1 has no mapped attribute %2.
err.init = %1~new failed (a mapped class's init takes no arguments): %2
err.query = The database refused a query (%1): %2
err.needKey = A new %1 needs its key: set its key attribute, or say generate "max".
err.twoSchemas = A commit is one database's: it holds %1 and %2.
err.commit = The commit was refused and nothing was changed (%1). %2
err.foreign = %1~%2 holds an object that is not in this session.
err.holdsDeleted = %1~%2 still holds an object that is deleted.
err.cycle = The new objects refer to each other in a circle (%1): save one first.
chk.table = there is no table %1
chk.column = %1 has no column %2
chk.extKey = the extension table %1 has no key column %2
chk.oneSchema = %1~%2: its tables must be in one database
chk.sharedNull = %1.%2 must allow NULL for a shared part to be taken out
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
err.noSchema = Keine Datenbank als %1 angehängt.
err.noTable = %1 nennt keine Tabelle (::annotate class ... table "schema.tabelle").
err.noKey = %1 nennt keine Schlüsselspalte (::annotate class ... key "spalte").
err.generate = %1: generate %2 ist unbekannt; "max" ist bekannt.
err.attrKind = %1~%2: ein annotiertes Attribut braucht column, one oder many.
err.extSchema = %1~%2: eine Erweiterungstabelle muss in der Datenbank der Klasse liegen.
err.linkEnds = %1~%2: eine Verknüpfung braucht from und to.
err.partColumn = %1~%2: one oder many ohne Verknüpfung braucht column.
err.ownedOne = %1~%2: ein Verweis (one) kann nicht besessen werden.
err.noClass = %1 verweist auf %2, das nicht gefunden wird.
err.map = Die Abbildung von %1 passt nicht zur Datenbank: %2
err.notInSession = Das %1 ist kein Objekt dieser Sitzung.
err.noAttr = %1 hat kein abgebildetes Attribut %2.
err.init = %1~new schlug fehl (das init einer abgebildeten Klasse nimmt keine Argumente): %2
err.query = Die Datenbank wies eine Abfrage zurück (%1): %2
err.needKey = Ein neues %1 braucht seinen Schlüssel: das Schlüsselattribut setzen oder generate "max" angeben.
err.twoSchemas = Ein Commit gehört zu einer Datenbank: er enthält %1 und %2.
err.commit = Der Commit wurde zurückgewiesen, nichts wurde geändert (%1). %2
err.foreign = %1~%2 hält ein Objekt, das nicht in dieser Sitzung ist.
err.holdsDeleted = %1~%2 hält noch ein gelöschtes Objekt.
err.cycle = Die neuen Objekte verweisen im Kreis aufeinander (%1): eines zuerst speichern.
chk.table = es gibt keine Tabelle %1
chk.column = %1 hat keine Spalte %2
chk.extKey = die Erweiterungstabelle %1 hat keine Schlüsselspalte %2
chk.oneSchema = %1~%2: seine Tabellen müssen in einer Datenbank liegen
chk.sharedNull = %1.%2 muss NULL erlauben, damit ein geteilter Teil herausgenommen werden kann
::END
