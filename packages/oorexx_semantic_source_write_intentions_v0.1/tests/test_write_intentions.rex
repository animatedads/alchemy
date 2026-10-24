/* SSC write-side intentions: meaning is always registered, feasibility is per-turn from the
 * live store, and a resolved intention dispatches into the MCP write authority.
 * Proven on a real store built by today's Rexx/SQL SQLite provider, with the real IntentionService.
 * Author: Claude (Opus 4.8), 2026-10-24. Architecture: Tom Dyer.
 * Needs librexxsql.so on LD_LIBRARY_PATH; SSC store, rexxsql backend+adapter, native backends,
 * intention_service, alchemy objects, crypto, runtime reference, foreign runtime on REXX_PATH.
 * Arg: scratch dir.
 */
signal on syntax name onSyntax
parse arg work
if work = "" then work = directory()
/* No Foreign Runtime: the store's SHA-256 has a pure-ooRexx path, and this test does a single
   tiny import, so it needs no native crypto build. (Foreign Runtime is a speed option elsewhere.) */

/* A store on SQLite through Rexx/SQL (today's provider), plus the write authority over it. */
store = .SemanticSourceRexxSqlProvider~newStore(work)
sql = store~sql
repo = .SemanticSourceRepositoryService~new(sql, .OnlyTom~new)
reader = .SemanticSourceLayoutPackageService~new(sql)
mcp = .SemanticSourceMcpOperations~new(repo, reader)

/* Register the write vocabulary + discovery provider with the real IntentionService. */
service = .IntentionService~new
provider = .SemanticSourceWriteIntentionInstaller~install(service, sql)
call check provider \== .nil, "installer registered and returned a discovery provider"
call check service~discoveryProviders~items >= 1, "discovery provider registered with IntentionService"

cap = .SemanticSourceWriteCapabilitySource~new(sql)

/* 1. No import yet: accept is understood but NOT feasible. */
call check \feasible(cap, "accept_import"), "accept is INFEASIBLE before any import exists"
call check advertisedActions(provider, service)~items = 0, "nothing write-feasible is advertised yet"

/* 2. Prior action: import one member and complete the archive -> a PROPOSED revision exists. */
nl = "0a"x
text = "::class Probe public" || nl || "::method a" || nl || "  return 'a'" || nl
b = .directory~new; b["archive_filename"] = "probe_v0.1.zip"; b["archive_sha256"] = "sha-probe"; b["imported_by"] = "tom"
importId = repo~beginArchive(b)
graph = .SemanticSourceOorexxStructuralAdapter~new~parse(text, "probe_v0.1/Probe.cls", "")
m = .directory~new
m["import_id"] = importId; m["archive_filename"] = "probe_v0.1.zip"; m["archive_sha256"] = "sha-probe"
m["member_path"] = "probe_v0.1/Probe.cls"; m["member_sha256"] = .SHA256~new(text)~digest; m["language"] = "oorexx"
m["source_text"] = text; m["semantic_objects"] = graph~objects; m["projection_members"] = graph~projectionMembers
m["relations"] = graph~relations; m["imported_by"] = "tom"
call check repo~importArchiveMember(m)["ok"] \== 0, "member imported"
repo~completeArchive(importId)

/* 3. Now accept is feasible, and the live import id is the discovered target. */
call check feasible(cap, "accept_import"), "accept is FEASIBLE once an import is pending"
ads = advertisedActions(provider, service)
call check ads~hasIndex("accept_import"), "accept is now advertised"
call check ads["accept_import"]~hasItem(importId), "the pending import id is the discovered target"
call check \feasible(cap, "propose_edit") = (editableNow(sql) = 0), "propose_edit feasibility tracks editable objects"

/* 4. Resolve + dispatch through the authority. Non-principal is denied; tom accepts. */
slots = .directory~new; slots["TARGET"] = importId
denied = .SemanticSourceWriteIntentionDispatcher~new(mcp, "")~dispatch("accept_import", slots)
call check denied["ok"] = 0, "dispatch with no session principal is denied by the authority"
ok = .SemanticSourceWriteIntentionDispatcher~new(mcp, "tom")~dispatch("accept_import", slots)
call check ok["ok"] = 1, "dispatch as tom accepts the import through the MCP authority"

/* 5. After acceptance the same intention is no longer feasible: feasibility is live. */
call check \feasible(cap, "accept_import"), "accept is INFEASIBLE again once the import is accepted"
accepted = sql~execute("SELECT status FROM ssc_source_revision WHERE origin_import_id='" || importId || "'")~rows
call check accepted[1]["status"] = "ACCEPTED", "the revision really is ACCEPTED in the store"

say "SSC WRITE INTENTIONS TEST: PASS (" || checks || " checks)"
exit 0

feasible: procedure
  use arg cap, action
  do d over cap~discoverWriteActions(.nil)
    if d["action"] = action then return d["feasible"]
  end
  return .false

editableNow: procedure
  use arg sql
  rs = sql~execute("SELECT object_id FROM ssc_source_object WHERE object_kind='METHOD'")
  if rs~status = "SUCCESS" then return rs~rows~items
  return 0

/* actions the discovery provider currently advertises -> directory action -> targets array */
advertisedActions: procedure
  use arg provider, service
  out = .directory~new
  snapshot = provider~discover(service)
  do ad over snapshot~surfaceAdvertisements
    md = ad~metadata
    out[ad~sourceObject] = md["TARGETS"]
  end
  return out

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 | ok == .true then do; say "PASS " label; return; end
  say "FAIL " label
  exit 1

onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl condition("D")
  if co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  if co~hasIndex("TRACEBACK") then do t over co["TRACEBACK"]; say "  T=" || t; end
  exit 1

::class OnlyTom
::method authorize
  use arg principal, action, target
  return (principal = "tom")

::requires "SemanticSourceWriteIntentions.cls"
::requires "SemanticSourceRexxSqlProvider.cls"
::requires "SemanticSourceRepositoryService.cls"
::requires "SemanticSourceLayoutPackageService.cls"
::requires "SemanticSourceMcpOperations.cls"
::requires "SemanticSourceOorexxStructuralAdapter.cls"
