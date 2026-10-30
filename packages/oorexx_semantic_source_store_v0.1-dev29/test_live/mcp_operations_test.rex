/* SSC MCP dispatcher on a real database.  Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 * Env: SSC_TEST_DB (required), SSC_FAST_CRYPTO=1
 */
signal on syntax name onSyntax
dbRoot = value("SSC_TEST_DB",,"ENVIRONMENT")
if dbRoot = "" then do; say "set SSC_TEST_DB"; exit 2; end
if value("SSC_FAST_CRYPTO",,"ENVIRONMENT") = "1" then installed = .CryptoForeignRuntimeInstaller~install
call SysMkDir dbRoot
sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))
boot = .SemanticSourceStore~new(dbRoot, sql, "nosqlserver")~bootstrap
ops = .SemanticSourceMcpOperations~new(.SemanticSourceRepositoryService~new(sql, .OnlyTom~new), .SemanticSourceLayoutPackageService~new(sql))

nl = "0a"x
text = "::class Probe public" || nl || "::method a" || nl || "  return 'a'" || nl || "::method b" || nl || "  return 'b'" || nl

b = .directory~new
b["archive_filename"] = "probe_v0.1.zip"; b["archive_sha256"] = "sha-probe"; b["imported_by"] = "mallory"
r = ops~dispatch("source.import_archive_begin", b, "tom")
call check r["ok"] = 1, "import_archive_begin"
importId = r["import_id"]

graph = .SemanticSourceOorexxStructuralAdapter~new~parse(text, "probe_v0.1/Probe.cls", "")
m = .directory~new
m["import_id"] = importId; m["archive_filename"] = "probe_v0.1.zip"; m["archive_sha256"] = "sha-probe"
m["member_path"] = "probe_v0.1/Probe.cls"; m["member_sha256"] = .SHA256~new(text)~digest; m["language"] = "oorexx"
m["source_text"] = text; m["semantic_objects"] = graph~objects; m["projection_members"] = graph~projectionMembers; m["relations"] = graph~relations
m["imported_by"] = "mallory"
r = ops~dispatch("source.import_archive_member", m, "tom")
call check r["ok"] = 1, "import_archive_member"
unit = r["result"]["source_unit_object_id"]
call check r["result"]["object_count"] = 3, "class header + 2 methods"
who = sql~execute("SELECT changed_by FROM ssc_source_revision WHERE origin_import_id='" || importId || "'")~rows
call check col(who[1], "changed_by") = "tom", "revision author is the session principal, not the claimed 'mallory'"

c = .directory~new; c["import_id"] = importId
call check ops~dispatch("source.import_archive_complete", c, "tom")["ok"] = 1, "import_archive_complete"

a = .directory~new; a["import_id"] = importId; a["reason"] = "reviewed: 3*4 - it's fine"
denied = ops~dispatch("source.accept_import", a, "")
call check denied["ok"] = 0 & denied["error"]~pos("DENIED") > 0, "accept without a session principal is DENIED"
notTom = ops~dispatch("source.accept_import", a, "mallory")
call check notTom["ok"] = 0 & notTom["error"]~pos("DENIED") > 0, "accept by a principal the authorizer rejects is DENIED"
ok = ops~dispatch("source.accept_import", a, "tom")
call check ok["ok"] = 1, "accept_import by tom"
decision = sql~execute("SELECT detail FROM ssc_relation WHERE relation_kind='DECISION'")~rows
call check decision~items > 0, "acceptance recorded as DECISION"
call check col(decision[1], "detail")~pos("reviewed: 3*4 - it's fine") > 0, "free-text reason stored verbatim (INSERT path, not evaluated)"

g = .directory~new; g["roots"] = .array~of(unit)
r = ops~dispatch("source.get_package", g, "tom")
call check r["ok"] = 1, "get_package"
call check r["files"]["Probe.cls"] == text, "get_package returns Probe.cls byte-identical"

h = .directory~new; h["object_id"] = unit
call check ops~dispatch("source.history", h, "tom")["revisions"]~items = 1, "history"
call check ops~dispatch("source.no_such_op", .directory~new, "tom")["ok"] = 0, "unknown operation returns ok=0, does not raise"
say "SSC MCP OPERATIONS TEST: PASS (" || checks || " checks)"
exit 0

col: procedure
  use arg row, name
  v = row[name]
  if v == .nil then v = row[name~upper]
  if v == .nil then return ""
  return v

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok then say "PASS " label
  else do; say "FAIL " label; exit 1; end
  return

onSyntax:
  say "SYNTAX rc="rc "sigl="sigl
  co = condition("O")
  if co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  if co~hasIndex("TRACEBACK") then do t over co["TRACEBACK"]; say "  T="t; end
  exit 1

::class OnlyTom
::method authorize
  use arg principal, action, target
  if principal = "tom" then return 1
  return 0

::requires "SemanticSourceStore.cls"
::requires "SemanticSourceSqlCompatibility.cls"
::requires "SemanticSourceMcpOperations.cls"
::requires "SemanticSourceOorexxStructuralAdapter.cls"
::requires "NoSQLServer.cls"
::requires "CryptoForeignRuntimeProvider.cls"
