parse arg ignored

/* Interrupted publication after live database was renamed: recovery completes
   the transaction stage because the backup still matches the expected base. */
root = .NoSQLServerTestSupport~createBlankDatabase("v015_recover_commit")
db = .FileDatabaseEngine~new(root)
call assertSuccess db~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL)"), "create recovery table"
call assertSuccess db~execute("INSERT INTO people (id,name) VALUES (1,'base')"), "insert recovery base"
stageInfo = .DatabaseFileSystem~stableClone(root, "recovery")
call assert stageInfo \== .nil, "stable recovery clone"
stageRoot = stageInfo["path"]
baseSignature = stageInfo["signature"]
stageDb = .FileDatabaseEngine~new(stageRoot)
call assertSuccess stageDb~execute("INSERT INTO people (id,name) VALUES (2,'staged')"), "mutate recovery stage"
backupRoot = root || ".manual-backup"
cleanup = .NoSQLServerTestSupport~removeDatabase(backupRoot)
call writeIntent root, stageRoot, backupRoot, baseSignature
call assert SysFileMove(root, backupRoot) = 0, "simulate live rename"
recoveredDb = .FileDatabaseEngine~new(root)
call assert recoveredDb~query("SELECT * FROM people WHERE id = 2")~rows~items = 1, "recovery completes staged commit"
call assert stream(root || ".txpublish.yaml", "c", "query exists") = "", "recovery removes journal"
call assert stream(backupRoot || "/database.yaml", "c", "query exists") = "", "recovery removes backup"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)

/* If the committed stage vanished before it could be published, recovery must
   restore the authoritative backup rather than inventing a commit. */
root = .NoSQLServerTestSupport~createBlankDatabase("v015_recover_restore")
db = .FileDatabaseEngine~new(root)
call assertSuccess db~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL)"), "create restore table"
call assertSuccess db~execute("INSERT INTO people (id,name) VALUES (1,'base')"), "insert restore base"
stageInfo = .DatabaseFileSystem~stableClone(root, "restore")
stageRoot = stageInfo["path"]
baseSignature = stageInfo["signature"]
stageDb = .FileDatabaseEngine~new(stageRoot)
call assertSuccess stageDb~execute("INSERT INTO people (id,name) VALUES (2,'must-not-appear')"), "mutate restore stage"
backupRoot = root || ".manual-backup"
cleanup = .NoSQLServerTestSupport~removeDatabase(backupRoot)
call writeIntent root, stageRoot, backupRoot, baseSignature
call assert SysFileMove(root, backupRoot) = 0, "simulate restore live rename"
cleanup = .NoSQLServerTestSupport~removeDatabase(stageRoot)
restoredDb = .FileDatabaseEngine~new(root)
call assert restoredDb~query("SELECT * FROM people WHERE id = 1")~rows~items = 1, "backup restored"
call assert restoredDb~query("SELECT * FROM people WHERE id = 2")~rows~items = 0, "missing stage not invented"
call assert stream(root || ".txpublish.yaml", "c", "query exists") = "", "restore removes journal"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)

/* If live changes after the transaction intent was created but before its
   directory rename, recovery preserves the newer live database and discards
   the stale stage. */
root = .NoSQLServerTestSupport~createBlankDatabase("v015_recover_conflict")
db = .FileDatabaseEngine~new(root)
call assertSuccess db~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL)"), "create conflict table"
call assertSuccess db~execute("INSERT INTO people (id,name) VALUES (1,'base')"), "insert conflict base"
stageInfo = .DatabaseFileSystem~stableClone(root, "conflict")
stageRoot = stageInfo["path"]
baseSignature = stageInfo["signature"]
stageDb = .FileDatabaseEngine~new(stageRoot)
call assertSuccess stageDb~execute("INSERT INTO people (id,name) VALUES (2,'stale-stage')"), "mutate stale stage"
backupRoot = root || ".manual-backup"
cleanup = .NoSQLServerTestSupport~removeDatabase(backupRoot)
call writeIntent root, stageRoot, backupRoot, baseSignature
call assertSuccess db~execute("INSERT INTO people (id,name) VALUES (3,'new-live')"), "mutate live after intent"
conflictDb = .FileDatabaseEngine~new(root)
call assert conflictDb~query("SELECT * FROM people WHERE id = 3")~rows~items = 1, "new live mutation preserved"
call assert conflictDb~query("SELECT * FROM people WHERE id = 2")~rows~items = 0, "stale stage discarded"
call assert stream(stageRoot || "/database.yaml", "c", "query exists") = "", "stale stage removed"
call assert stream(root || ".txpublish.yaml", "c", "query exists") = "", "conflict journal removed"
call assert conflictDb~version~supports("TRANSACTION_RECOVERY"), "recovery capability advertised"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)

say "NOSQLSERVER V0.15 TRANSACTION RECOVERY SMOKE: OK"
exit 0

writeIntent: procedure
  use arg liveRoot, stageRoot, backupRoot, signature
  raw = .table~new
  raw["formatVersion"] = 1
  raw["liveRoot"] = liveRoot
  raw["stageRoot"] = stageRoot
  raw["backupRoot"] = backupRoot
  raw["expectedSignature"] = signature
  raw["created"] = .DateTime~new~string
  .Yaml~toYamlFile(raw, liveRoot || ".txpublish.yaml")
  return

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label rs~status rs~error rs~message
    exit 1
  end
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
