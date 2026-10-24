/* SSC repository acceptance on a REAL database (no stub).
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 * Env: SSC_TEST_DB  directory for a fresh NoSQLServer database (required)
 *      SSC_FAST_CRYPTO=1  install Crypto's Foreign Runtime provider first
 */
signal on syntax name onSyntax
dbRoot = value("SSC_TEST_DB",,"ENVIRONMENT")
if dbRoot = "" then do; say "set SSC_TEST_DB"; exit 2; end
if value("SSC_FAST_CRYPTO",,"ENVIRONMENT") = "1" then do
  installed = .CryptoForeignRuntimeInstaller~install
  say "crypto: Foreign Runtime provider installed"
end
call SysMkDir dbRoot
sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))
store = .SemanticSourceStore~new(dbRoot, sql, "nosqlserver")
call time "R"
boot = store~bootstrap
call check boot~status = "SUCCESS", "schema bootstrap on real NoSQLServer"

nl = "0a"x
helperV1 = "::class Helper public" || nl || "::method help" || nl || "  return 1" || nl
familyV1 = "/* family package */" || nl ||,
           "::requires ""Helper.cls""" || nl ||,
           "::class Family public" || nl ||,
           "::attribute name" || nl ||,
           "::method init" || nl || "  expose name" || nl || "  use arg name" || nl ||,
           "::method greet" || nl || "  expose name" || nl || "  return ""hello"" name" || nl ||,
           "::method shout" || nl || "  return 'HEY | tab" || "09"x || "'" || nl
familyV2 = familyV1~changestr("return ""hello"" name", "return ""hello there,"" name")
familyV3 = familyV2 || "::method whisper" || nl || "  return ""psst""" || nl

repo = .SemanticSourceRepositoryService~new(sql, .AllowAll~new)
reader = .SemanticSourceLayoutPackageService~new(sql)

/* 1. import v1, accept, rebuild byte-identical */
imp1 = repo~beginArchive(meta("family_v0.1.zip", "sha-v1"))
r1 = repo~importArchiveMember(req(imp1, "family_v0.1.zip", "sha-v1", "family_v0.1/src/Family.cls", familyV1))
h1 = repo~importArchiveMember(req(imp1, "family_v0.1.zip", "sha-v1", "family_v0.1/src/Helper.cls", helperV1))
call check r1["status"] = "IMPORTED", "v1 Family imported"
call check r1["module_id"] = "family", "module derived from version folder"
call check r1["logical_path"] = "src/Family.cls", "logical path drops version folder"
call check r1["object_count"] = 7, "Family.cls held as 7 objects: header comment, requires, class, attribute, 3 methods"
call check r1["new_revisions"] = 7, "7 new revisions"
repo~completeArchive(imp1)
familyUnit = r1["source_unit_object_id"]
helperUnit = h1["source_unit_object_id"]
methods = 0
do m over repo~objectsIn(familyUnit)
  if m["object_kind"] = "METHOD" then methods += 1
end
call check methods = 3, "three METHOD objects, one per method (method-granular)"
acc1 = repo~acceptImport(imp1, "tom")
call check acc1["newly_accepted"] = 11, "accept v1: 7 Family objects + Family layout + Helper class, method and layout"
pkg = reader~getPackage(.array~of(familyUnit))
call check pkg~files["src/Family.cls"] == familyV1, "v1 Family.cls rebuilt byte-identical from method objects"
call check pkg~files["src/Helper.cls"] == helperV1, "::requires closure pulls Helper.cls, byte-identical"

/* 2. one method body changes */
imp2 = repo~beginArchive(meta("family_v0.2.zip", "sha-v2"))
r2 = repo~importArchiveMember(req(imp2, "family_v0.2.zip", "sha-v2", "family_v0.2/src/Family.cls", familyV2))
repo~completeArchive(imp2)
call check r2["new_revisions"] = 1, "v2: exactly one new revision (the changed method)"
call check r2["source_unit_revision_id"] = r1["source_unit_revision_id"], "v2: file layout unchanged, layout revision reused"
pkg = reader~getPackage(.array~of(familyUnit))
call check pkg~files["src/Family.cls"] == familyV1, "unaccepted method revision is not served"
greetId = ""
do m over repo~objectsIn(familyUnit)
  if m["name"] = "greet" then greetId = m["object_id"]
end
hist = repo~history(greetId)
call check hist~items = 2, "greet has two revisions"
call check col(hist[2], "status") = "PROPOSED", "new greet revision is PROPOSED"
repo~acceptRevision(col(hist[2], "revision_id"), "tom", "review ok")
pkg = reader~getPackage(.array~of(familyUnit))
call check pkg~files["src/Family.cls"] == familyV2, "accepting one method revision updates the file"
hist = repo~history(greetId)
call check col(hist[1], "status") = "SUPERSEDED", "old greet revision SUPERSEDED"

/* 3. a method is added */
imp3 = repo~beginArchive(meta("family_v0.3.zip", "sha-v3"))
r3 = repo~importArchiveMember(req(imp3, "family_v0.3.zip", "sha-v3", "family_v0.3/src/Family.cls", familyV3))
repo~completeArchive(imp3)
call check r3["new_revisions"] = 1, "v3: one new member revision (the added method)"
call check r3["source_unit_revision_id"] \= r1["source_unit_revision_id"], "v3: layout changed"
repo~acceptImport(imp3, "tom")
pkg = reader~getPackage(.array~of(familyUnit))
call check pkg~files["src/Family.cls"] == familyV3, "v3 rebuilt byte-identical"

/* 4. same content in another version folder: no new objects or revisions; re-import idempotent */
imp4 = repo~beginArchive(meta("family_v0.3-repack.zip", "sha-v3b"))
r4 = repo~importArchiveMember(req(imp4, "family_v0.3-repack.zip", "sha-v3b", "family_v0.3-dev9/src/Family.cls", familyV3))
call check r4["new_revisions"] = 0, "identical content under a different version folder: 0 new revisions"
call check r4["source_unit_object_id"] = familyUnit, "same semantic identity across version folders"
again = repo~importArchiveMember(req(imp4, "family_v0.3-repack.zip", "sha-v3b", "family_v0.3-dev9/src/Family.cls", familyV3))
call check again["status"] = "ALREADY_IMPORTED", "repeated member is ALREADY_IMPORTED"
call check repo~beginArchive(meta("family_v0.1.zip", "sha-v1")) = imp1, "beginArchive resumes the same archive"

/* 5. exact rebuild of the v1 import after v3 was accepted */
pins = .directory~new
roots = .array~new
do row over sql~execute("SELECT r.object_id,r.revision_id FROM ssc_projection_member p JOIN ssc_source_revision r ON r.revision_id=p.revision_id WHERE p.project_id='import:" || imp1 || "'")~rows
  pins[col(row, "object_id")] = col(row, "revision_id")
  roots~append(col(row, "object_id"))
end
old = reader~getPackage(roots, pins, "import:" || imp1)
call check old~files["src/Family.cls"] == familyV1, "v1 import rebuilt exactly from its own projection after v3 accepted"

/* 6. authorization fails closed */
call checkDenied .SemanticSourceRepositoryService~new(sql), "acceptImport", imp3
call checkDeniedPrincipal repo, imp3

/* 7. CRLF: the backend must not alter bytes silently */
imp5 = repo~beginArchive(meta("crlf_v0.1.zip", "sha-crlf"))
crlf = "::class Win public" || "0d0a"x || "::method m" || "0d0a"x || "  return 1" || "0d0a"x
crlfOutcome = "IMPORTED"
signal on syntax name crlfRefused
r5 = repo~importArchiveMember(req(imp5, "crlf_v0.1.zip", "sha-crlf", "crlf_v0.1/src/Win.cls", crlf))
signal on syntax name onSyntax
pkg = reader~getPackage(.array~of(r5["source_unit_object_id"]), pinsFor(sql, imp5), "import:" || imp5)
if pkg~files["src/Win.cls"] == crlf then say "INFO  CRLF stored losslessly by this backend"
else call check 0, "CRLF accepted but altered"
signal afterCrlf
crlfRefused:
  signal on syntax name onSyntax
  crlfOutcome = "REFUSED"
  call check errText()~pos("STORAGE_NOT_LOSSLESS") > 0, "CRLF altered by backend is refused (STORAGE_NOT_LOSSLESS), not stored"
  m = sql~execute("SELECT status FROM ssc_import_member WHERE import_id='" || imp5 || "'")~rows
  call check m~items = 0, "refused member is not marked IMPORTED"
afterCrlf:

/* 8. the original reader's assembly order, isolated (members only, exact v1 projection) */
memberRoots = .array~new
memberPins = .directory~new
do row over sql~execute("SELECT r.object_id,r.revision_id FROM ssc_projection_member p JOIN ssc_source_revision r ON r.revision_id=p.revision_id WHERE p.project_id='import:" || imp1 || "' AND p.relative_path='src/Family.cls'")~rows
  memberPins[col(row, "object_id")] = col(row, "revision_id")
  memberRoots~append(col(row, "object_id"))
end
fixed = reader~getPackage(memberRoots, memberPins, "import:" || imp1)
call check fixed~files["src/Family.cls"] == familyV1, "fixed reader: exact order from projection ordinals"
signal on syntax name legacyCrashed
legacy = .SemanticSourcePackageService~new(sql)~getPackage(memberRoots, memberPins, "import:" || imp1)
signal on syntax name onSyntax
if legacy~files["src/Family.cls"] == familyV1 then say "INFO  original reader produced the right order this run"
else say "INFO  original reader ORDER DEFECT reproduced: Family.cls reassembled out of order"
signal afterLegacy
legacyCrashed:
  signal on syntax name onSyntax
  say "INFO  original SemanticSourcePackageService~getPackage crashes on a real database:" errText()~space
afterLegacy:

say "SSC REPOSITORY ROUND-TRIP TEST: PASS  (" || checks || " checks, " || format(time("E"),,1) || " s)"
exit 0

/* ------------------------------------------------------------------ */
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

pinsFor: procedure
  use arg sql, importId
  pins = .directory~new
  -- Pin the member revisions (import:<id>) and the SOURCE_UNIT layout revision (import-layout:<id>):
  -- an import that was never accepted has no accepted layout to fall back on.
  do row over sql~execute("SELECT r.object_id,r.revision_id FROM ssc_projection_member p JOIN ssc_source_revision r ON r.revision_id=p.revision_id WHERE p.project_id IN ('import:" || importId || "','import-layout:" || importId || "')")~rows
    pins[col(row, "object_id")] = col(row, "revision_id")
  end
  return pins

errText: procedure
  co = condition("O")
  t = condition("D")
  if co \== .nil then if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]; t = t a; end
  return t

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
  else do
    say "FAIL " label
    exit 1
  end
  return

checkDenied:
  use arg target, op, arg1
  signal on syntax name deniedOk
  if op = "acceptImport" then ignored = target~acceptImport(arg1, "tom")
  signal on syntax name onSyntax
  call check 0, "acceptance without an authorizer must be denied"
  return
deniedOk:
  signal on syntax name onSyntax
  call check errText()~pos("DENIED") > 0, "acceptance without an authorizer is DENIED"
  return

checkDeniedPrincipal:
  use arg target, importId
  signal on syntax name deniedPrincipalOk
  ignored = target~acceptImport(importId, "")
  signal on syntax name onSyntax
  call check 0, "acceptance without a principal must be denied"
  return
deniedPrincipalOk:
  signal on syntax name onSyntax
  call check errText()~pos("DENIED") > 0, "acceptance without a principal is DENIED"
  return

onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C")
  say "  D="condition("D")
  co = condition("O")
  if co~hasIndex("ADDITIONAL") then do a over co["ADDITIONAL"]; say "  A="a; end
  if co~hasIndex("TRACEBACK") then do t over co["TRACEBACK"]; say "  T="t; end
  exit 1

::class AllowAll
::method authorize
  return 1

::requires "SemanticSourceStore.cls"
::requires "SemanticSourceSqlCompatibility.cls"
::requires "SemanticSourceRepositoryService.cls"
::requires "SemanticSourceLayoutPackageService.cls"
::requires "SemanticSourceOorexxStructuralAdapter.cls"
::requires "NoSQLServer.cls"
::requires "CryptoForeignRuntimeProvider.cls"
