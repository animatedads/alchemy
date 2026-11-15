# Mapped Objects (oorexx_mapped_objects v0.1): one ooRexx object over several tables

Architecture: Tom Dyer. Code: Claude (Opus 5.5). README written by Claude (Opus 5.5).
It runs on ooRexx 5.3 (native or ooRexx/WASM) and on Alchemy NoSQLServer
(`nosqlserver_v0.92-dev1`: its FILE engine, its SQL, its transactions and its
parameter binder).

## The problem it answers

A business object is seldom one table. Tom Dyer's example: a Person comes
from `ent.per`, and its addresses come from `ent.addr` through a link table,
`ent.per_addr`. Delphi, Access and their kind were weak at exactly this:

- **The form is bound to a table, not to the object.** A data-aware control
  sits on one dataset: one table, or one query. A query over several tables
  is mostly read-only ("Recordset not updateable"; a live TQuery for one
  table only). So a Person form becomes a master and a detail dataset,
  wired together by hand.
- **The object exists nowhere.** Which row in which table, the link table,
  the order of the inserts: all of it lives in event handlers (BeforePost,
  AfterInsert, the subform's link fields), repeated on every form that
  shows a Person.
- **No identity.** The same person opened in two places is two copies that
  disagree.
- **Saving is per table, not per object.** The person's row is saved and its
  link row fails, and an orphan is left, unless someone wrote the
  transaction by hand.
- **Ownership is never written down.** Is the address the person's own
  (deleted with them) or shared (Rony lives there too)? The tool does not
  know, so every delete is decided again, by hand.
- **Schema drift is found at run time.** A renamed column breaks a form when
  a user opens it.

Bold for Delphi and ECO did model the object, but they demanded their own
base class, their own modeller and their own persistence. Here the map is on
the class, in ooRexx's own `::ANNOTATE`, read by reflection (as the ooRexx
Object Editor reads a class). The class needs no base class and no SQL.

## How a class says where it lives

```rexx
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
```

| An attribute's annotation | It is |
|---|---|
| `column C` | a value: column C of the class's table |
| `column C table T` | a value in an extension table T that shares the class's key (a one-to-one split: the "updatable join" Access never had) |
| `one K column C` | a reference to one K; C (here) holds K's key |
| `many K column C` | the K objects whose column C holds this one's key |
| `many K link L from F to T` | the K objects through link table L: F holds this one's key, T the K's key |
| `owned "yes"` / `"no"` | on a many: owned parts are deleted with the object and when taken out of the collection; shared parts lose only their link (or their reference, which must then allow NULL). Default: a column many is owned, a link many is shared. |

`"schema.table"`: the schema is the database the store attached under that
name.

## Using it

```rexx
store = .ObjectStore~new                 -- or .ObjectStore~new("de")
store~attach("ent", "/data/ent")         -- a FileDatabaseEngine, or its folder
s = store~session                        -- a unit of work
tom = s~find(.Person, 1)                 -- per, per_ext, per_addr, addr, note, com
tom~name = "Tom Dyer"
home = s~new(.Address); home~street = "Great Western Road"
tom~addresses~append(home)
say s~plan                               -- the statements, before they run
s~commit                                 -- one transaction: all or nothing
```

- `store~map(class)` reads the annotations and checks them against the
  catalogue, reporting every problem at once ("ENT.per has no column
  per_nickname; there is no table ENT.nowhere"). This happens when the class
  is first used, not on a form at run time.
- `session~find(class, key)` gives one object per key within a session. Tom
  and Rony's shared address is the same object for both.
- `session~where(class, attribute, value)` and `session~all(class)` find
  objects by an attribute's value, or all of them.
- `session~new(class)` and `session~delete(object)` add an object, or mark
  one for deletion.
- `session~plan` shows what a commit would run; `session~commit` runs it;
  `session~rollback` puts the objects back as the database has them.
- `store~graphLines` gives the objects for a graph of the database (below).

The commit works out the statements from what changed since the objects were
loaded:
- A changed value is an UPDATE of that one column, in its own table.
- New objects are inserted after the objects they refer to, and a child after
  its parent.
- Link rows are inserted after both of their ends.
- A deleted object goes in this order: its owned parts, its link rows, its
  extension rows, then its own row. Shared things stay.

All of it runs in one NoSQLServer transaction. If the database refuses any of
it, nothing is changed and the refusal says why. Values go through
NoSQLServer's own parameter binder, typed as the catalogue declares each
column: a phone number stays text, a key stays a number, and a quote in a
name is a quote.

## A graph of the database

`store~graphLines` answers tab-separated lines for the Database Lab's graph
(oorexx_oodialog_database_lab, ChatGPT's lane). That graph draws the logical
object around its tables:

```
OBJECT  PERSON  ENT.per
PART    PERSON  -          EXT   ENT.per_ext  -             OWNED
PART    PERSON  addresses  LINK  ENT.addr     ENT.per_addr  SHARED
PART    PERSON  employer   ONE   ENT.com      -             SHARED
PART    PERSON  notes      MANY  ENT.note     -             OWNED
```

## Limits of v0.1

- A commit covers one database, because a NoSQLServer transaction is one
  database's. A commit that holds two is refused.
- Parts are loaded with the object, one query per part and per object. There
  is no lazy loading, so a large graph of objects loads whole.
- `generate "max"` is MAX+1 within the unit of work. It is not safe for
  writers in several processes at once.
- A mapped class's `init` must take no arguments.
- New tables and columns are made by the Database Lab or by a DBA; the map
  only checks against them.

## Test

```
rexx tests/t_mapped.rex SCRATCH_DIR
```

`REXX_PATH` must hold this package's `src` and the `src` folders of
nosqlserver_v0.92-dev1, alchemy_objects_v0.8 and oorexx_crypto_v0.1.
`SCRATCH_DIR` must be a new, empty folder.

42 of 42 checks pass under ooRexx/WASM 0.2.4 in Node. They cover:
- the map read from the annotations, and a drifted map refused with every
  problem listed;
- one object over five tables, with one object per key;
- one-column updates in the right table;
- a new address inserted together with its link row, and a shared one taken
  out (only its link is deleted);
- an owned note taken out and deleted;
- a new Person with everything, inserted in order, with its key generated;
- a commit the database refuses changing nothing, and rollback;
- a delete in order, leaving shared things in place;
- a commit over two databases refused;
- German refusals, and `module_version`.

Pitfall lint (Boston Crab v0.24): clean.
