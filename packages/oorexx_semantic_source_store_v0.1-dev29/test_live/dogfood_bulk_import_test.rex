/* SSC dogfood: a real package ZIP through the existing SemanticSourceBulkImporter
 * into SemanticSourceRepositoryService on a real database; every ooRexx member is
 * then rebuilt from accepted method-level revisions and compared byte-for-byte.
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 * Env: SSC_DOGFOOD_ZIP (required), SSC_TEST_DB (required), SSC_FAST_CRYPTO=1
 */
signal on syntax name onSyntax
zipPath = value("SSC_DOGFOOD_ZIP",,"ENVIRONMENT")
dbRoot = value("SSC_TEST_DB",,"ENVIRONMENT")
if zipPath = "" | dbRoot = "" then do; say "set SSC_DOGFOOD_ZIP and SSC_TEST_DB"; exit 2; end
if value("SSC_FAST_CRYPTO",,"ENVIRONMENT") = "1" then installed = .CryptoForeignRuntimeInstaller~install
call SysMkDir dbRoot
sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))
boot = .SemanticSourceStore~new(dbRoot, sql, "nosqlserver")~bootstrap
repo = .SemanticSourceRepositoryService~new(sql, .AllowAll~new)

drop = dbRoot || "/intake"
call SysMkDir drop
address command "cp" quoteArg(zipPath) quoteArg(drop || "/")
call time "R"
importer = .SemanticSourceBulkImporter~new(repo, .CommandZipArchiveReader~new)
report = importer~importDirectory(drop, 1, 1, "claude-dogfood", "oorexx-structural-v4")
tImport = time("E")
say "IMPORT archives="report~archivesImported "membersSeen="report~membersSeen "imported="report~membersImported "skipped="report~membersSkipped "failed="report~membersFailed "seconds="format(tImport,,1)
do e over report~errors
  say "  ERROR" e
end
if report~membersFailed > 0 then do; say "FAIL members failed"; exit 1; end

importId = col(sql~execute("SELECT import_id FROM ssc_import_batch")~rows[1], "import_id")
call time "R"
acc = repo~acceptImport(importId, "tom", "dogfood acceptance")
say "ACCEPT revisions="acc["revisions"] "seconds="format(time("E"),,1)

kinds = .table~new
do row over sql~execute("SELECT object_kind FROM ssc_source_object")~rows
  k = col(row, "object_kind")
  if kinds[k] == .nil then kinds[k] = 0
  kinds[k] = kinds[k] + 1
end
line = "OBJECTS"
do k over kinds~allIndexes~sort
  line = line k"="kinds[k]
end
say line

reader = .SemanticSourceLayoutPackageService~new(sql)
listing = dbRoot || "/members.txt"
address command "unzip -Z1" quoteArg(zipPath) ">" quoteArg(listing)
s = .stream~new(listing); names = s~arrayIn; s~close
checked = 0; identical = 0
call time "R"
do name over names
  lower = name~lower
  if lower~right(4) \= ".cls" & lower~right(4) \= ".rex" then iterate
  logical = name
  if name~pos("/") > 0 then logical = name~substr(name~pos("/") + 1)
  out = dbRoot || "/member.bin"
  address command "unzip -p" quoteArg(zipPath) quoteArg(name) ">" quoteArg(out)
  f = .stream~new(out); f~open("read"); original = f~charIn(1, f~chars); f~close
  if original == .nil then original = ""
  units = repo~sourceUnitsFor(logical)
  checked += 1
  if units~items \= 1 then do; say "FAIL no unique source unit for" logical "found" units~items; iterate; end
  pkg = reader~getPackage(.array~of(units[1]))
  if pkg~files[logical] == original then identical += 1
  else say "DIFF" logical "original="original~length "rebuilt="length(pkg~files[logical])
end
say "REBUILD checked="checked "byte_identical="identical "seconds="format(time("E"),,1)
if checked = 0 | identical \= checked then do; say "SSC DOGFOOD: FAIL"; exit 1; end
say "SSC DOGFOOD: PASS" identical "of" checked "ooRexx files rebuilt byte-identical from accepted method-level revisions"
exit 0

quoteArg: return "'" || arg(1)~changestr("'", "'\''") || "'"

col: procedure
  use arg row, name
  v = row[name]
  if v == .nil then v = row[name~upper]
  if v == .nil then return ""
  return v

onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C")
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
::requires "SemanticSourceBulkImporter.cls"
::requires "NoSQLServer.cls"
::requires "CryptoForeignRuntimeProvider.cls"
