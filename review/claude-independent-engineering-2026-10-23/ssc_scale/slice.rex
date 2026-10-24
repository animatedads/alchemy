/* SSC import cost vs store size: one GA file at a time, smallest first. Claude (Opus 5.5), 2026-10-24.
 * Args: list-file log-file db-root budget-seconds */
signal on syntax name onSyntax
parse arg listFile logFile dbRoot budget
installed = .CryptoForeignRuntimeInstaller~install
call SysMkDir dbRoot
sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))
boot = .SemanticSourceStore~new(dbRoot, sql, "nosqlserver")~bootstrap
repo = .SemanticSourceRepositoryService~new(sql, .AllowAll~new)
b = .directory~new; b["archive_filename"] = "ga_slice.zip"; b["archive_sha256"] = "ga-slice"; b["imported_by"] = "claude"
importId = repo~beginArchive(b)
call lineout logFile, "file# bytes objects cum_objects seconds ms_per_object cum_seconds path"
cum = 0; total = 0; n = 0
call time "R"
do while lines(listFile) > 0
  parse value linein(listFile) with bytes path
  text = charin(path, 1, chars(path)); call stream path, "C", "CLOSE"
  rel = path~substr(3)
  graph = .SemanticSourceOorexxStructuralAdapter~new~parse(text, rel, "")
  m = .directory~new
  m["import_id"] = importId; m["archive_filename"] = "ga_slice.zip"; m["archive_sha256"] = "ga-slice"
  m["member_path"] = rel; m["member_sha256"] = .SHA256~new(text)~digest; m["language"] = "oorexx"
  m["source_text"] = text; m["semantic_objects"] = graph~objects; m["projection_members"] = graph~projectionMembers
  m["relations"] = graph~relations; m["imported_by"] = "claude"
  t0 = time("E")
  r = repo~importArchiveMember(m)
  dt = time("E") - t0
  objs = r["object_count"]; cum += objs; n += 1
  call lineout logFile, n bytes objs cum format(dt,,1) format(dt / max(objs,1) * 1000,,0) format(time("E"),,0) rel
  if time("E") > budget then do; call lineout logFile, "BUDGET REACHED after" n "files"; leave; end
end
call lineout logFile, "DONE files="n "objects="cum "seconds="format(time("E"),,0)
exit 0
onSyntax:
  co = condition("O"); call lineout logFile, "SYNTAX rc="rc "sigl="sigl
  if co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; call lineout logFile, "  A=" || e; end
  exit 1
::class AllowAll
::method authorize
  return 1
::requires "SemanticSourceStore.cls"
::requires "SemanticSourceSqlCompatibility.cls"
::requires "SemanticSourceRepositoryService.cls"
::requires "SemanticSourceOorexxStructuralAdapter.cls"
::requires "NoSQLServer.cls"
::requires "CryptoForeignRuntimeProvider.cls"
