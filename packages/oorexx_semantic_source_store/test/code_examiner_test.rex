say "CODE EXAMINER TEST START"
authority = .FakeAuthority~new
examiner = .SemanticSourceCodeExaminer~new(authority)
view = examiner~initialView("human-1")
call assert view["view_id"] = "SSC.CODE.EXAMINER", "initial view"
call assert view["actions"]~items = 28, "action count"
call assert view["default_view"] = "CLASS_INSPECTION", "class inspection is default view"
call assert view~hasIndex("catalog"), "catalog loaded from authority"
call assert view["catalog"]~items = 1, "catalog contains dynamic module"


catPayload = .directory~new
catPayload["module_id"] = "family"
catalog = examiner~handleAction("CODE.CATALOG", catPayload, "human-1")
call assert catalog~items = 1, "catalog action"

p = .directory~new
p["object_id"] = "oorexx://family/Family/instance/addChild"
open = examiner~handleAction("CODE.OPEN", p, "human-1")
call assert open["revision_id"] = "rev-17", "open exact revision"
call assert open~hasIndex("design"), "design attached"
call assert open~hasIndex("findings"), "findings attached"
call assert open~hasIndex("context"), "full semantic context attached"
call assert open["context"]["module_id"] = "family", "module context pulled"
call assert open["context"]~hasIndex("revision_history"), "revision history pulled"
call assert open["context"]~hasIndex("requirements"), "requirements pulled"
call assert open["context"]~hasIndex("notes"), "notes pulled"
call assert open["context"]~hasIndex("resources"), "resources pulled"
call assert open["context"]~hasIndex("branches"), "branches pulled"
call assert open["context"]~hasIndex("deployments"), "deployments pulled"
call assert open["context"]~hasIndex("references"), "references pulled"
call assert open["context"]~hasIndex("runtime_surfaces"), "runtime surfaces pulled"
call assert open["context"]~hasIndex("test_evidence"), "test evidence pulled"
call assert open["context"]~hasIndex("work_entries"), "work entries pulled"
call assert open["context"]~hasIndex("exports"), "exports pulled"
call assert open["context"]~hasIndex("dependencies"), "dependencies pulled"

f = .directory~new
f["object_id"] = p["object_id"]
f["revision_id"] = "rev-17"
f["summary"] = "duplicate child path"
f["detail"] = "second append can duplicate the child"
f["severity"] = "ERROR"
f["category"] = "CORRECTNESS"
f["line_start"] = 10
f["line_end"] = 12
r = examiner~handleAction("CODE.FINDING.CREATE", f, "human-1")
call assert r["status"] = "OPEN", "finding create"

b = .directory~new
roots = .array~new
roots~append("oorexx://family/Family")
b["roots"] = roots
pkg = examiner~handleAction("CODE.PACKAGE.REQUEST", b, "human-1")
call assert pkg["package_request_id"] = "pkg-1", "package request"

tr = .directory~new
tr["package_request_id"] = "pkg-1"
tr["test_profile"] = "qbtest"
testResult = examiner~handleAction("CODE.TEST.REQUEST", tr, "human-1")
call assert testResult["status"] = "QUEUED", "test request"

wr = .directory~new
wr["work_entry_id"] = "work-7"
wr["findings"] = "all findings addressed"
wr["evidence"] = "qbtest PASS"
review = examiner~handleAction("WORK.ACCEPT", wr, "human-1")
call assert review["outcome"] = "ACCEPTED", "work accept"


nav = .directory~new
nav["reference_id"] = "ref-1"
definition = examiner~handleAction("CODE.GOTO_DEFINITION", nav, "human-1")
call assert definition["target_object_id"] = "oorexx://family/Family/instance/addChild", "go to definition"

usesPayload = .directory~new
usesPayload["object_id"] = "oorexx://family/Family/instance/addChild"
uses = examiner~handleAction("CODE.FIND_USES", usesPayload, "human-1")
call assert uses~items = 1, "find uses"

surfacePayload = .directory~new
surfacePayload["snapshot_id"] = "snap-1"
surface = examiner~handleAction("CODE.CLASS.SURFACE", surfacePayload, "human-1")
call assert surface["snapshot_id"] = "snap-1", "class surface"
overrides = examiner~handleAction("CODE.CLASS.OVERRIDES", surfacePayload, "human-1")
call assert overrides~items = 1, "class overrides"

inspectPayload = .directory~new
inspectPayload["class_id"] = "Family"
inspectPayload["since"] = "2026-09-28T10:00:00Z"
compact = examiner~handleAction("CODE.CLASS.INSPECT", inspectPayload, "human-1")
call assert compact["class_id"] = "Family", "compact class inspection"
call assert compact["methods"]~items = 1, "compact methods"
call assert compact["methods"][1]["from"] = "Family", "method origin included"
call assert compact["methods"][1]["exposes"][1] = "children", "method exposes included"
call assert compact["methods"][1]["returns"]["class"] = "Family", "return class included"


transport=.directory~new
transport["websocketUrl"]="wss://example.invalid/wire"
transport["outboundQueue"]="SSC.CODE.EXAMINER.IN"
wire=.SemanticSourceCodeExaminerWireApplication~new(examiner, "SSC-CODE-EXAMINER", transport)
desc=wire~serviceDescriptor("human-1")
call assert desc["websocketUrl"] = "wss://example.invalid/wire", "server service descriptor"
call assert desc["outboundQueue"] = "SSC.CODE.EXAMINER.IN", "server queue descriptor"

say "CODE EXAMINER TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class FakeAuthority
::method examinerCatalog
  use arg userId, moduleId = "", branchId = ""
  a=.array~new
  d=.directory~new; d["module_id"]="family"; d["display_name"]="family"
  units=.array~new; u=.directory~new; u["source_unit_id"]="unit-family"; u["path"]="Family.cls"; units~append(u)
  d["source_units"]=units; a~append(d); return a
::method examinerObjectContext
  use arg objectId, revisionId, userId
  d=.directory~new; d["module_id"]="family"; d["source_unit_id"]="unit-family"
  d["object_kind"]="METHOD"; d["language"]="OOREXX"
  d["source_spelling"]="addChild"; d["runtime_spelling"]="ADDCHILD"; d["lookup_key"]="ADDCHILD"
  d["revision_history"]=.array~new
  d["requirements"]=.array~new; d["notes"]=.array~new; d["resources"]=.array~new
  d["branches"]=.array~new; d["deployments"]=.array~new; d["references"]=.array~new
  d["runtime_surfaces"]=.array~new; d["test_evidence"]=.array~new; d["work_entries"]=.array~new
  d["exports"]=.array~new; d["dependencies"]=.array~new
  return d
::method sourceGet
  use arg objectId, revisionId, userId
  d=.directory~new; d["object_id"]=objectId; d["revision_id"]="rev-17"; d["source_text"]="::method addChild"; return d
::method designGetForObject
  use arg objectId, userId
  d=.directory~new; d["purpose"]="maintain child membership"; return d
::method findingList
  use arg objectId, revisionId, userId
  return .array~new
::method findingCreate
  use arg finding, userId
  finding["finding_id"]="finding-1"; finding["status"]="OPEN"; return finding
::method findingResolve
  use arg findingId, resolution, userId
  d=.directory~new; d["finding_id"]=findingId; d["status"]="RESOLVED"; return d
::method sourceGetPackage
  use arg roots, pins, projectId, format, userId
  d=.directory~new; d["package_request_id"]="pkg-1"; d["status"]="BUILT"; return d
::method testRequest
  use arg packageRequestId, profile, workEntryId, userId
  d=.directory~new; d["test_request_id"]="test-1"; d["status"]="QUEUED"; return d
::method workReview
  use arg workEntryId, outcome, findings, evidence, userId
  d=.directory~new; d["work_entry_id"]=workEntryId; d["outcome"]=outcome; return d
::method sourceSearch
  use arg query, filters, userId
  return .array~new

::method semanticDefinition
  use arg referenceId, userId
  d=.directory~new; d["target_object_id"]="oorexx://family/Family/instance/addChild"; d["resolution_state"]="RESOLVED"; return d
::method semanticFindUses
  use arg objectId, userId
  a=.array~new; a~append("ref-1"); return a
::method semanticCallers
  use arg objectId, userId
  return .array~new
::method semanticCallees
  use arg objectId, userId
  return .array~new
::method semanticReferenceExplain
  use arg referenceId, userId
  d=.directory~new; d["reference_id"]=referenceId; return d
::method semanticClassSurface
  use arg snapshotId, userId
  d=.directory~new; d["snapshot_id"]=snapshotId; return d
::method semanticClassOverrides
  use arg snapshotId, userId
  a=.array~new; a~append("SAME"); return a
::method semanticClassInspection
  use arg classId, revisionId, since, userId
  d=.directory~new; d["schema"]="semantic-source.class-inspection/1"; d["class_id"]=classId
  tree=.array~new; tree~append("Family"); tree~append("Object"); d["class_tree"]=tree
  d["since"]=since; d["as_of"]="2026-09-28T12:43:00Z"
  methods=.array~new; m=.directory~new; m["name"]="addChild"; m["from"]="Family"
  ex=.array~new; ex~append("children"); m["exposes"]=ex
  ret=.directory~new; ret["kind"]="OBJECT"; ret["class"]="Family"; m["returns"]=ret
  methods~append(m); d["methods"]=methods; return d


::method sourceCompare
  use arg objectId, leftRevisionId, rightRevisionId, userId
  d=.directory~new; d["object_id"]=objectId; d["left_revision_id"]=leftRevisionId; d["right_revision_id"]=rightRevisionId; return d
::method methodRequirementCreate
  use arg objectId, requirementKind, requirementText, userId
  d=.directory~new; d["status"]="CREATED"; return d
::method methodNoteCreate
  use arg objectId, revisionId, noteKind, title, noteText, userId
  d=.directory~new; d["status"]="CREATED"; return d
::method resourceUpload
  use arg objectId, revisionId, logicalName, mimeType, content, materialisationPath, relationKind, userId
  d=.directory~new; d["status"]="UPLOADED"; return d
::method moduleRequirementCreate
  use arg requiringModuleId, scopeKind, scopeId, targetModuleId, constraintKind, requiredDeploymentId, reason, userId
  d=.directory~new; d["status"]="CREATED"; return d
::method sourceGetDeploymentPackage
  use arg deploymentId, projectId, format, userId
  d=.directory~new; d["status"]="BUILT"; return d
::method branchClassify
  use arg branchId, classification, upstreamPolicy, userId
  d=.directory~new; d["status"]="CLASSIFIED"; return d
::method branchProtect
  use arg branchId, scopeKind, scopeId, reason, userId
  d=.directory~new; d["status"]="PROTECTED"; return d
::method sourceGetBranchPackage
  use arg branchId, upstreamDeploymentId, projectId, format, userId
  d=.directory~new; d["status"]="BUILT"; return d
::method branchConflictResolve
  use arg branchId, conflictId, acceptedRevisionId, resolution, userId
  d=.directory~new; d["status"]="RESOLVED"; return d

::requires "../src/SemanticSourceCodeExaminer.cls"
