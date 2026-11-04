say "GRAPH SERVICE TEST START"
sql = .GraphFakeSQL~new
svc = .SemanticSourceGraphService~new(sql)

r = svc~createReference("ref-1", "caller-1", "rev-1", "CALL", "family~addChild", "target-1", "target-rev-2", "family", "RESOLVED", 12, 8, "typed receiver", "2026-09-27T18:00:00Z", "tester")
call assert r~status = .Error~SUCCESS, "create reference"

obs = svc~observeReference("obs-1", "ref-1", "target-1", "target-rev-2", "TEST", "test-77", "2026-09-27T18:01:00Z", "tester", "observed during qualification")
call assert obs~status = .Error~SUCCESS, "observe reference"

defn = svc~definition("ref-1")
call assert defn["resolution_state"] = "RESOLVED", "definition state"
call assert defn["target_object_id"] = "target-1", "definition target"
call assert defn["observations"]~rows~items = 1, "definition observations"

uses = svc~findUses("target-1")
call assert uses~rows~items = 1, "find uses"

callers = svc~callers("target-1")
call assert callers~rows~items = 1, "callers"

callees = svc~callees("caller-1")
call assert callees~rows~items = 1, "callees"

why = svc~explain("ref-1")
call assert why["reference_kind"] = "CALL", "explain kind"
call assert why["detail"] = "typed receiver", "explain detail"

runtime = svc~runtimeClassSurface("snap-1")
call assert runtime~hasIndex("snapshot"), "runtime class snapshot"
call assert runtime~hasIndex("parents"), "runtime parents"
call assert runtime~hasIndex("methods"), "runtime methods"
effective = svc~runtimeEffectiveMethods("snap-1", "INSTANCE")
call assert effective~rows~items = 1, "runtime effective methods"
overrides = svc~runtimeOverrides("snap-1")
call assert overrides~rows~items = 1, "runtime overrides"

say "GRAPH SERVICE TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class GraphFakeSQL
::method execute
  use arg statement
  dbResult = .GraphFakeResult~new
  upper = statement~upper
  if upper~pos("SELECT REFERENCE_ID,FROM_OBJECT_ID,FROM_REVISION_ID,REFERENCE_KIND,LEXEME,TARGET_OBJECT_ID,TARGET_REVISION_ID,TARGET_MODULE_ID,RESOLUTION_STATE,SOURCE_LINE,SOURCE_COLUMN,DETAIL FROM SSC_SEMANTIC_REFERENCE WHERE REFERENCE_ID=") > 0 then do
    row = .directory~new
    row["reference_id"]="ref-1"; row["from_object_id"]="caller-1"; row["from_revision_id"]="rev-1"
    row["reference_kind"]="CALL"; row["lexeme"]="family~addChild"; row["target_object_id"]="target-1"
    row["target_revision_id"]="target-rev-2"; row["target_module_id"]="family"; row["resolution_state"]="RESOLVED"
    row["source_line"]=12; row["source_column"]=8; row["detail"]="typed receiver"
    dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_REFERENCE_OBSERVATION WHERE REFERENCE_ID=") > 0 then do
    row=.directory~new; row["observation_id"]="obs-1"; row["reference_id"]="ref-1"; row["observed_target_object_id"]="target-1"; row["evidence_kind"]="TEST"
    dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_SEMANTIC_REFERENCE WHERE TARGET_OBJECT_ID=") > 0 then do
    row=.directory~new; row["reference_id"]="ref-1"; row["from_object_id"]="caller-1"; row["reference_kind"]="CALL"; row["target_object_id"]="target-1"; row["resolution_state"]="RESOLVED"
    dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_SEMANTIC_REFERENCE WHERE FROM_OBJECT_ID=") > 0 then do
    row=.directory~new; row["reference_id"]="ref-1"; row["from_object_id"]="caller-1"; row["reference_kind"]="CALL"; row["target_object_id"]="target-1"; row["resolution_state"]="RESOLVED"
    dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_RUNTIME_CLASS_SNAPSHOT WHERE SNAPSHOT_ID=") > 0 then do
    row=.directory~new; row["snapshot_id"]="snap-1"; row["class_id"]="CHILD"; dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_RUNTIME_INHERITANCE_EDGE WHERE SNAPSHOT_ID=") > 0 then do
    row=.directory~new; row["snapshot_id"]="snap-1"; row["parent_class_id"]="PARENT"; dbResult~rows~append(row)
  end
  else if upper~pos("FROM SSC_RUNTIME_METHOD_SURFACE WHERE SNAPSHOT_ID=") > 0 then do
    row=.directory~new; row["snapshot_id"]="snap-1"; row["method_scope"]="INSTANCE"; row["method_name"]="SAME"; row["origin_class_id"]="CHILD"; row["relation_kind"]="OVERRIDES"; row["is_effective"]=1; dbResult~rows~append(row)
  end
  return dbResult

::class GraphFakeResult
::attribute status
::attribute error
::attribute message
::attribute rows
::method init
  self~status=.Error~SUCCESS
  self~error=0
  self~message=""
  self~rows=.array~new

::requires "NoSQLServer.cls"
::requires "../src/SemanticSourceGraphService.cls"
