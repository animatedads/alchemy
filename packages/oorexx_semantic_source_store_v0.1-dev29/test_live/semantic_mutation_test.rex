/* SSC semantic mutation acceptance on a REAL database (no stub).
 * Architecture: exact semantic-object edits, sparse conflict branches.
 * Env: SSC_TEST_DB (required), SSC_FAST_CRYPTO=1 recommended.
 */
signal on syntax name onSyntax

dbRoot = value("SSC_TEST_DB",,"ENVIRONMENT")
if dbRoot = "" then do; say "set SSC_TEST_DB"; exit 2; end
if value("SSC_FAST_CRYPTO",,"ENVIRONMENT") = "1" then installed = .CryptoForeignRuntimeInstaller~install
call SysMkDir dbRoot

sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))
boot = .SemanticSourceStore~new(dbRoot, sql, "nosqlserver")~bootstrap
repo = .SemanticSourceRepositoryService~new(sql, .OnlyTom~new)
reader = .SemanticSourceLayoutPackageService~new(sql)
branches = .SemanticSourceBranchService~new(sql)
mutations = .SemanticSourceMutationService~new(repo, branches, sql)

nl = "0a"x
original = "::class Probe public" || nl ||,
           "::method a" || nl || "  return 'a'" || nl ||,
           "::method b" || nl || "  return 'b'" || nl

imp = repo~beginArchive(meta("probe_v0.1.zip", "sha-probe-v1"))
r = repo~importArchiveMember(req(imp, "probe_v0.1.zip", "sha-probe-v1", "probe_v0.1/Probe.cls", original))
repo~completeArchive(imp)
unit = r["source_unit_object_id"]
repo~acceptImport(imp, "tom", "initial qualification")

methodId = ""
do o over repo~objectsIn(unit)
  if o["object_kind"] = "METHOD" & o["name"] = "a" then methodId = o["object_id"]
end
call check methodId \= "", "method a has its own semantic object"

state = sql~execute("SELECT accepted_revision_id,current_revision_id FROM ssc_source_object WHERE object_id='" || methodId || "'")~rows[1]
baseId = col(state, "accepted_revision_id")
baseText = col(sql~execute("SELECT source_text FROM ssc_source_revision WHERE revision_id='" || baseId || "'")~rows[1], "source_text")
call check baseText~pos("return 'a'") > 0, "base method revision retrieved independently"

layoutBefore = col(sql~execute("SELECT current_revision_id FROM ssc_source_object WHERE object_id='" || unit || "'")~rows[1], "current_revision_id")
replacement = baseText~changestr("return 'a'", "return 'A2'")
edit = mutations~proposeEdit(methodId, baseId, replacement, "tom", "method-level replacement")
call check edit["status"] = "PROPOSED", "exact-base edit creates PROPOSED semantic revision"
call check edit["conflict"] = 0, "exact-base edit is not a conflict"

layoutAfter = col(sql~execute("SELECT current_revision_id FROM ssc_source_object WHERE object_id='" || unit || "'")~rows[1], "current_revision_id")
call check layoutAfter = layoutBefore, "method body edit does not rewrite SOURCE_UNIT layout"

pkg = reader~getPackage(.array~of(unit))
call check pkg~files["Probe.cls"] == original, "unaccepted semantic edit is not materialised"

repo~acceptRevision(edit["revision_id"], "tom", "reviewed")
expected = original~changestr("return 'a'", "return 'A2'")
pkg = reader~getPackage(.array~of(unit))
call check pkg~files["Probe.cls"] == expected, "accepting one method revision rebuilds file with only that method changed"

-- Stale-base edit: retain both candidates and create a sparse conflict branch.
conflictText = baseText~changestr("return 'a'", "return 'A3'")
conflict = mutations~proposeEdit(methodId, baseId, conflictText, "tom", "parallel stale-base edit")
call check conflict["status"] = "BRANCH_CONFLICT", "stale-base edit becomes BRANCH_CONFLICT"
call check conflict["branch_id"] \= "", "conflict branch id returned"

cr = sql~execute("SELECT candidate_revision_a,candidate_revision_b,status FROM ssc_branch_conflict WHERE branch_id='" || conflict["branch_id"] || "'")~rows
call check cr~items = 1, "one conflict record created"
call check col(cr[1], "candidate_revision_a") = edit["revision_id"], "current candidate retained as conflict A"
call check col(cr[1], "candidate_revision_b") = conflict["revision_id"], "stale-base candidate retained as conflict B"
call check col(cr[1], "status") = "OPEN", "conflict remains unresolved"

current = col(sql~execute("SELECT current_revision_id FROM ssc_source_object WHERE object_id='" || methodId || "'")~rows[1], "current_revision_id")
call check current = edit["revision_id"], "stale candidate does not replace upstream current revision"
pkg = reader~getPackage(.array~of(unit))
call check pkg~files["Probe.cls"] == expected, "unresolved conflict never silently changes materialised source"

again = mutations~proposeEdit(methodId, baseId, conflictText, "tom", "parallel stale-base edit")
call check again["branch_id"] = conflict["branch_id"], "same candidate is idempotent and reuses open conflict branch"

-- Whole-file editing is deliberately forbidden on the semantic edit path.
signal on syntax name wholeFileDenied
ignored = mutations~proposeEdit(unit, layoutAfter, "not a layout", "tom")
signal on syntax name onSyntax
call check 0, "SOURCE_UNIT edit must be denied"
signal afterWholeFile
wholeFileDenied:
  signal on syntax name onSyntax
  call check errText()~pos("SEMANTIC_EDIT_REQUIRED") > 0, "SOURCE_UNIT edit fails with SEMANTIC_EDIT_REQUIRED"
afterWholeFile:

signal on syntax name unauthorized
ignored = mutations~proposeEdit(methodId, edit["revision_id"], replacement, "mallory")
signal on syntax name onSyntax
call check 0, "unauthorized edit must be denied"
signal afterUnauthorized
unauthorized:
  signal on syntax name onSyntax
  call check errText()~pos("DENIED") > 0, "semantic edit authorization fails closed"
afterUnauthorized:

say "SSC SEMANTIC MUTATION TEST: PASS (" || checks || " checks)"
exit 0

meta: procedure
  use arg name, sha
  d = .directory~new
  d["source_kind"] = "zip"; d["archive_filename"] = name; d["archive_sha256"] = sha
  d["imported_by"] = "test"; d["parser_id"] = "oorexx-structural-v4"; d["resume"] = 1
  return d

req: procedure
  use arg importId, name, sha, path, text
  graph = .SemanticSourceOorexxStructuralAdapter~new~parse(text, path, "")
  d = .directory~new
  d["import_id"] = importId; d["archive_filename"] = name; d["archive_sha256"] = sha
  d["member_path"] = path; d["member_sha256"] = .SHA256~new(text)~digest; d["language"] = "oorexx"
  d["imported_by"] = "test"; d["source_text"] = text; d["semantic_source_authority"] = "STRUCTURAL_GRAPH"
  d["semantic_objects"] = graph~objects; d["projection_members"] = graph~projectionMembers; d["relations"] = graph~relations
  return d

col: procedure
  use arg row, name
  v = row[name]
  if v == .nil then v = row[name~upper]
  if v == .nil then return ""
  return v

errText: procedure
  co = condition("O")
  t = condition("D")
  if co \== .nil then if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]; t = t a; end
  return t

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok then say "PASS " label
  else do; say "FAIL " label; exit 1; end
  return

onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C")
  say "  D="condition("D")
  co = condition("O")
  if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]; say "  A="a; end
  if co~hasIndex("TRACEBACK") then do t over co["TRACEBACK"]; say "  T="t; end
  exit 1

::class OnlyTom
::method authorize
  use arg principal, action, target
  if principal = "tom" then return 1
  return 0

::requires "SemanticSourceStore.cls"
::requires "SemanticSourceSqlCompatibility.cls"
::requires "SemanticSourceRepositoryService.cls"
::requires "SemanticSourceLayoutPackageService.cls"
::requires "SemanticSourceMutationService.cls"
::requires "SemanticSourceBranchService.cls"
::requires "SemanticSourceOorexxStructuralAdapter.cls"
::requires "NoSQLServer.cls"
::requires "CryptoForeignRuntimeProvider.cls"
