/*
 * Semantic Source Control - human Code Examiner Wire application model
 *
 * This object owns server-side review semantics.  A Wire UI renderer presents
 * its snapshots and sends the semantic actions defined below.  The browser is
 * never authoritative for revisions, findings, work outcomes, package
 * resolution or test results.
 */

::class SemanticSourceCodeExaminer public

::constant ACTION_CATALOG "CODE.CATALOG"
::constant ACTION_SEARCH "CODE.SEARCH"
::constant ACTION_OPEN "CODE.OPEN"
::constant ACTION_FINDING_CREATE "CODE.FINDING.CREATE"
::constant ACTION_FINDING_RESOLVE "CODE.FINDING.RESOLVE"
::constant ACTION_PACKAGE_REQUEST "CODE.PACKAGE.REQUEST"
::constant ACTION_TEST_REQUEST "CODE.TEST.REQUEST"
::constant ACTION_WORK_ACCEPT "WORK.ACCEPT"
::constant ACTION_WORK_REFUSE "WORK.REFUSE"
::constant ACTION_REFRESH "CODE.REFRESH"
::constant ACTION_COMPARE "CODE.COMPARE"
::constant ACTION_REQUIREMENT_CREATE "METHOD.REQUIREMENT.CREATE"
::constant ACTION_NOTE_CREATE "METHOD.NOTE.CREATE"
::constant ACTION_RESOURCE_UPLOAD "RESOURCE.UPLOAD"
::constant ACTION_MODULE_REQUIREMENT_CREATE "MODULE.REQUIREMENT.CREATE"
::constant ACTION_DEPLOYMENT_PACKAGE_REQUEST "DEPLOYMENT.PACKAGE.REQUEST"
::constant ACTION_BRANCH_CLASSIFY "BRANCH.CLASSIFY"
::constant ACTION_BRANCH_PROTECT "BRANCH.PROTECT"
::constant ACTION_BRANCH_PACKAGE_REQUEST "BRANCH.PACKAGE.REQUEST"
::constant ACTION_BRANCH_CONFLICT_RESOLVE "BRANCH.CONFLICT.RESOLVE"
::constant ACTION_GOTO_DEFINITION "CODE.GOTO_DEFINITION"
::constant ACTION_FIND_USES "CODE.FIND_USES"
::constant ACTION_CALLERS "CODE.CALLERS"
::constant ACTION_CALLEES "CODE.CALLEES"
::constant ACTION_REFERENCE_EXPLAIN "CODE.REFERENCE.EXPLAIN"
::constant ACTION_CLASS_SURFACE "CODE.CLASS.SURFACE"
::constant ACTION_CLASS_OVERRIDES "CODE.CLASS.OVERRIDES"
::constant ACTION_CLASS_INSPECT "CODE.CLASS.INSPECT"

::method init
  use strict arg authority
  if authority == .nil then raise syntax 88.900 array("authority client is required")
  self~authority = authority

::attribute authority get
::attribute authority set private

/* Initial server-authored semantic projection for a human examiner. */
::method initialView
  use strict arg userId
  view = .directory~new
  view["view_id"] = "SSC.CODE.EXAMINER"
  view["title"] = "Semantic Source Code Examiner"
  view["user_id"] = userId
  view["revision"] = 1
  view["actions"] = self~allowedActions
  -- Navigation inventory is server-authoritative.  The browser must never
  -- enumerate modules/source files in HTML or local configuration.
  view["catalog"] = self~authority~examinerCatalog(userId)
  view["panels"] = self~panelDefinitions
  view["layout"] = self~layoutDefinition
  selection = .directory~new
  selection["object_id"] = ""
  selection["revision_id"] = ""
  selection["revision_state"] = ""
  view["selection"] = selection
  view["default_view"] = "CLASS_INSPECTION"
  view["message"] = "Select a class for its condensed semantic inspection; expand source or runtime details only when needed."
  return view

::method allowedActions private
  actions = .array~new
  actions~append(self~ACTION_CATALOG)
  actions~append(self~ACTION_SEARCH)
  actions~append(self~ACTION_OPEN)
  actions~append(self~ACTION_FINDING_CREATE)
  actions~append(self~ACTION_FINDING_RESOLVE)
  actions~append(self~ACTION_PACKAGE_REQUEST)
  actions~append(self~ACTION_TEST_REQUEST)
  actions~append(self~ACTION_WORK_ACCEPT)
  actions~append(self~ACTION_WORK_REFUSE)
  actions~append(self~ACTION_REFRESH)
  actions~append(self~ACTION_COMPARE)
  actions~append(self~ACTION_REQUIREMENT_CREATE)
  actions~append(self~ACTION_NOTE_CREATE)
  actions~append(self~ACTION_RESOURCE_UPLOAD)
  actions~append(self~ACTION_MODULE_REQUIREMENT_CREATE)
  actions~append(self~ACTION_DEPLOYMENT_PACKAGE_REQUEST)
  actions~append(self~ACTION_BRANCH_CLASSIFY)
  actions~append(self~ACTION_BRANCH_PROTECT)
  actions~append(self~ACTION_BRANCH_PACKAGE_REQUEST)
  actions~append(self~ACTION_BRANCH_CONFLICT_RESOLVE)
  actions~append(self~ACTION_GOTO_DEFINITION)
  actions~append(self~ACTION_FIND_USES)
  actions~append(self~ACTION_CALLERS)
  actions~append(self~ACTION_CALLEES)
  actions~append(self~ACTION_REFERENCE_EXPLAIN)
  actions~append(self~ACTION_CLASS_SURFACE)
  actions~append(self~ACTION_CLASS_OVERRIDES)
  actions~append(self~ACTION_CLASS_INSPECT)
  return actions

/* Semantic meanings exposed to Intention Service.  These are not an
 * availability cache.  IntentionService discovery re-asks for active surfaces
 * on every fresh input; SecureExaminer remains authoritative at dispatch. */
::method intentionDefinitions
  use arg context = .nil
  definitions = .array~new
  definitions~append(self~intentionDefinition(self~ACTION_CATALOG, "browse source catalog", "browse catalog,list modules,show source catalog,what code exists", "BROWSE LIST SHOW", "SOURCE CATALOG MODULES", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_SEARCH, "search source", "find code,search code,look for source,find class,find method", "SEARCH FIND LOOK", "SOURCE CODE CLASS METHOD", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_OPEN, "open semantic element", "open code,show method,show class,inspect source element", "OPEN SHOW INSPECT", "SEMANTIC ELEMENT SOURCE", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_FINDING_CREATE, "create review finding", "add finding,record problem,raise finding", "CREATE ADD RECORD RAISE", "REVIEW FINDING PROBLEM", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_FINDING_RESOLVE, "resolve review finding", "close finding,resolve finding", "RESOLVE CLOSE", "REVIEW FINDING", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_PACKAGE_REQUEST, "build source package", "build package,get package,materialise package", "BUILD GET MATERIALISE", "SOURCE PACKAGE", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_TEST_REQUEST, "request source test", "run tests,test package,request test", "TEST RUN REQUEST", "SOURCE PACKAGE TEST", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_WORK_ACCEPT, "accept submitted work", "accept work,approve work", "ACCEPT APPROVE", "SUBMITTED WORK", "PRIVILEGED"))
  definitions~append(self~intentionDefinition(self~ACTION_WORK_REFUSE, "refuse submitted work", "refuse work,reject work", "REFUSE REJECT", "SUBMITTED WORK", "PRIVILEGED"))
  definitions~append(self~intentionDefinition(self~ACTION_REFRESH, "refresh code examiner", "refresh examiner,reload examiner,refresh code", "REFRESH RELOAD", "CODE EXAMINER", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_COMPARE, "compare source revisions", "compare revisions,diff revisions,what changed", "COMPARE DIFF", "SOURCE REVISIONS CHANGES", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_REQUIREMENT_CREATE, "add method requirement", "create method requirement,require method behavior,add requirement", "ADD CREATE REQUIRE", "METHOD REQUIREMENT", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_NOTE_CREATE, "add method documentation", "add method note,document method,add documentation", "ADD DOCUMENT", "METHOD NOTE DOCUMENTATION", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_RESOURCE_UPLOAD, "attach source resource", "upload resource,attach resource,link resource", "UPLOAD ATTACH LINK", "SOURCE RESOURCE", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_MODULE_REQUIREMENT_CREATE, "add module requirement", "create module requirement,require module deployment", "ADD CREATE REQUIRE", "MODULE REQUIREMENT DEPLOYMENT", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_DEPLOYMENT_PACKAGE_REQUEST, "build deployment package", "materialise deployment,package deployment", "BUILD MATERIALISE PACKAGE", "DEPLOYMENT PACKAGE", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_BRANCH_CLASSIFY, "classify source branch", "classify branch,mark intentional branch,mark conflict branch", "CLASSIFY MARK", "SOURCE BRANCH", "PRIVILEGED"))
  definitions~append(self~intentionDefinition(self~ACTION_BRANCH_PROTECT, "protect branch element", "protect branch,protect method,protect class", "PROTECT", "BRANCH METHOD CLASS", "PRIVILEGED"))
  definitions~append(self~intentionDefinition(self~ACTION_BRANCH_PACKAGE_REQUEST, "build branch package", "package branch,materialise branch", "BUILD PACKAGE MATERIALISE", "BRANCH PACKAGE", "WRITE"))
  definitions~append(self~intentionDefinition(self~ACTION_BRANCH_CONFLICT_RESOLVE, "resolve branch conflict", "resolve conflict,choose branch revision,merge semantic conflict", "RESOLVE MERGE", "BRANCH CONFLICT REVISION", "PRIVILEGED"))
  definitions~append(self~intentionDefinition(self~ACTION_GOTO_DEFINITION, "go to definition", "goto definition,show definition,where is this defined", "GO SHOW FIND", "DEFINITION SYMBOL", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_FIND_USES, "find uses", "find references,who uses this,show uses", "FIND SHOW", "USES REFERENCES", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_CALLERS, "show callers", "who calls this,find callers", "SHOW FIND", "CALLERS METHOD", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_CALLEES, "show callees", "what does this call,find callees", "SHOW FIND", "CALLEES METHOD", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_REFERENCE_EXPLAIN, "explain source reference", "why is this reference here,explain dependency,explain reference", "EXPLAIN", "SOURCE REFERENCE DEPENDENCY", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_CLASS_SURFACE, "show runtime class surface", "show class surface,effective methods,runtime methods", "SHOW INSPECT", "RUNTIME CLASS SURFACE METHODS", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_CLASS_OVERRIDES, "inspect class overrides", "show overrides,inheritance inspection,what overrides this", "SHOW INSPECT", "CLASS OVERRIDES INHERITANCE", "NONE"))
  definitions~append(self~intentionDefinition(self~ACTION_CLASS_INSPECT, "inspect class", "class summary,condensed class,show class tree,inspect class", "INSPECT SHOW", "CLASS TREE METHODS", "NONE"))
  return definitions

::method intentionDefinition private
  use strict arg action, phrase, aliasText, verbs, nouns, sideEffect
  d = .directory~new
  d["action"] = action
  d["phrase"] = phrase
  d["intention_id"] = translate(changestr(" ", strip(phrase), "_"))
  d["verbs"] = verbs
  d["nouns"] = nouns
  d["side_effect"] = sideEffect
  aliases = .array~new
  remaining = aliasText
  do while remaining \= ""
    parse var remaining alias ',' remaining
    alias = strip(alias)
    if alias \= "" then aliases~append(alias)
  end
  aliases~append(phrase)
  d["aliases"] = aliases
  return d

::method layoutDefinition private
  layout = .directory~new
  layout["schema"] = "semantic-source.code-examiner.layout/1"
  layout["root_role"] = "code-examiner"

  regions = .array~new
  regions~append(self~region("NAV", "examiner-nav", "Search, tickets and work entries"))
  regions~append(self~region("CODE", "examiner-code", "Exact source revision"))
  regions~append(self~region("CONTEXT", "examiner-context", "Design, findings and evidence"))
  regions~append(self~region("ACTIONS", "examiner-actions", "Human review actions"))
  layout["regions"] = regions
  return layout

::method region private
  use strict arg regionId, role, purpose
  d = .directory~new
  d["region_id"] = regionId
  d["role"] = role
  d["purpose"] = purpose
  return d

::method panelDefinitions private
  panels = .array~new
  panels~append(self~panel("SEARCH", "Search", "Find semantic objects, tickets and work entries"))
  panels~append(self~panel("CODE", "Code", "Inspect exact accepted/candidate source revisions"))
  panels~append(self~panel("DESIGN", "Design", "Read the attached design authority for the selected element"))
  panels~append(self~panel("FINDINGS", "Findings", "Create and resolve human review findings"))
  panels~append(self~panel("BUILD", "Build / Test", "Request a dependency-complete package and qualification"))
  panels~append(self~panel("WORK", "Work Review", "Accept or refuse a submitted work entry with evidence"))
  panels~append(self~panel("METHOD_META", "Requirements / Notes", "Maintain method requirements and documentation"))
  panels~append(self~panel("RESOURCES", "Resources", "Upload and attach JSON, schemas, data and other resources"))
  panels~append(self~panel("MODULES", "Modules / Deployments", "Inspect module requirements and request exact qualified deployment packages"))
  panels~append(self~panel("BRANCHES", "Branches", "Classify conflict branches, protect semantic elements, resolve conflicts and build sparse branch projections"))
  panels~append(self~panel("SEMANTIC_GRAPH", "Semantic Graph", "Navigate definitions, uses, callers, callees and dependency reasons"))
  return panels

::method panel private
  use strict arg panelId, title, purpose
  d = .directory~new
  d["panel_id"] = panelId
  d["title"] = title
  d["purpose"] = purpose
  return d

/*
 * Handle a semantic Wire UI action.  payload is a Directory.  The authority
 * object is expected to be the MCP/server adapter, not a direct database
 * connection.  Every mutating operation therefore stays on the same authority
 * path as coding agents.
 */
::method handleAction
  use strict arg actionName, payload, userId
  if payload == .nil then payload = .directory~new

  select
    when actionName = self~ACTION_CATALOG then return self~catalog(payload, userId)
    when actionName = self~ACTION_SEARCH then return self~search(payload, userId)
    when actionName = self~ACTION_OPEN then return self~open(payload, userId)
    when actionName = self~ACTION_FINDING_CREATE then return self~createFinding(payload, userId)
    when actionName = self~ACTION_FINDING_RESOLVE then return self~resolveFinding(payload, userId)
    when actionName = self~ACTION_PACKAGE_REQUEST then return self~requestPackage(payload, userId)
    when actionName = self~ACTION_TEST_REQUEST then return self~requestTest(payload, userId)
    when actionName = self~ACTION_WORK_ACCEPT then return self~reviewWork(payload, userId, "ACCEPTED")
    when actionName = self~ACTION_WORK_REFUSE then return self~reviewWork(payload, userId, "REFUSED")
    when actionName = self~ACTION_REFRESH then return self~refresh(payload, userId)
    when actionName = self~ACTION_COMPARE then return self~compare(payload, userId)
    when actionName = self~ACTION_REQUIREMENT_CREATE then return self~createRequirement(payload, userId)
    when actionName = self~ACTION_NOTE_CREATE then return self~createNote(payload, userId)
    when actionName = self~ACTION_RESOURCE_UPLOAD then return self~uploadResource(payload, userId)
    when actionName = self~ACTION_MODULE_REQUIREMENT_CREATE then return self~createModuleRequirement(payload, userId)
    when actionName = self~ACTION_DEPLOYMENT_PACKAGE_REQUEST then return self~requestDeploymentPackage(payload, userId)
    when actionName = self~ACTION_BRANCH_CLASSIFY then return self~classifyBranch(payload, userId)
    when actionName = self~ACTION_BRANCH_PROTECT then return self~protectBranch(payload, userId)
    when actionName = self~ACTION_BRANCH_PACKAGE_REQUEST then return self~requestBranchPackage(payload, userId)
    when actionName = self~ACTION_BRANCH_CONFLICT_RESOLVE then return self~resolveBranchConflict(payload, userId)
    when actionName = self~ACTION_GOTO_DEFINITION then return self~gotoDefinition(payload, userId)
    when actionName = self~ACTION_FIND_USES then return self~findUses(payload, userId)
    when actionName = self~ACTION_CALLERS then return self~callers(payload, userId)
    when actionName = self~ACTION_CALLEES then return self~callees(payload, userId)
    when actionName = self~ACTION_REFERENCE_EXPLAIN then return self~explainReference(payload, userId)
    when actionName = self~ACTION_CLASS_SURFACE then return self~classSurface(payload, userId)
    when actionName = self~ACTION_CLASS_OVERRIDES then return self~classOverrides(payload, userId)
    when actionName = self~ACTION_CLASS_INSPECT then return self~classInspect(payload, userId)
    otherwise raise syntax 88.900 array("unsupported examiner action: " || actionName)
  end

::method catalog private
  use strict arg payload, userId
  moduleId = self~optional(payload, "module_id", "")
  branchId = self~optional(payload, "branch_id", "")
  return self~authority~examinerCatalog(userId, moduleId, branchId)

::method search private
  use strict arg payload, userId
  query = self~required(payload, "query")
  filters = self~optional(payload, "filters", .directory~new)
  return self~authority~sourceSearch(query, filters, userId)

::method open private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  revisionId = self~optional(payload, "revision_id", "")
  sourceRecord = self~authority~sourceGet(objectId, revisionId, userId)

  -- Pull the complete examiner context from authority for this exact revision.
  -- Nothing about the selected source element is maintained in browser HTML.
  sourceRecord["design"] = self~authority~designGetForObject(objectId, userId)
  sourceRecord["findings"] = self~authority~findingList(objectId, sourceRecord["revision_id"], userId)
  context = self~authority~examinerObjectContext(objectId, sourceRecord["revision_id"], userId)
  self~validateObjectContext(context)
  sourceRecord["context"] = context
  return sourceRecord

/*
 * The examiner context is an explicit authority contract.  Empty arrays are
 * valid where a semantic feature is not applicable; missing sections are not.
 * This prevents a UI/backend combination from silently losing agreed review
 * information as the store evolves.
 */
::method validateObjectContext private
  use strict arg context
  if context == .nil then raise syntax 88.900 array("examiner object context is required")

  required = .array~of( -
    "module_id", "source_unit_id", "object_kind", "language", -
    "source_spelling", "runtime_spelling", "lookup_key", -
    "revision_history", "requirements", "notes", "resources", -
    "branches", "deployments", "references", "runtime_surfaces", -
    "test_evidence", "work_entries", "exports", "dependencies")

  do key over required
    if \context~hasIndex(key) then -
      raise syntax 88.900 array("examiner context missing required section: " || key)
  end
  return

::method createFinding private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  revisionId = self~required(payload, "revision_id")
  summary = self~required(payload, "summary")
  detail = self~required(payload, "detail")
  severity = self~required(payload, "severity")
  category = self~required(payload, "category")

  finding = .directory~new
  finding["object_id"] = objectId
  finding["revision_id"] = revisionId
  finding["work_entry_id"] = self~optional(payload, "work_entry_id", "")
  finding["ticket_id"] = self~optional(payload, "ticket_id", "")
  finding["category"] = category
  finding["severity"] = severity
  finding["summary"] = summary
  finding["detail"] = detail
  finding["line_start"] = self~optional(payload, "line_start", 0)
  finding["line_end"] = self~optional(payload, "line_end", 0)
  return self~authority~findingCreate(finding, userId)

::method resolveFinding private
  use strict arg payload, userId
  findingId = self~required(payload, "finding_id")
  resolution = self~required(payload, "resolution")
  return self~authority~findingResolve(findingId, resolution, userId)

::method requestPackage private
  use strict arg payload, userId
  roots = self~required(payload, "roots")
  pins = self~optional(payload, "pins", .directory~new)
  projectId = self~optional(payload, "project_id", "default")
  format = self~optional(payload, "format", "files")
  return self~authority~sourceGetPackage(roots, pins, projectId, format, userId)

::method requestTest private
  use strict arg payload, userId
  packageRequestId = self~required(payload, "package_request_id")
  testProfile = self~required(payload, "test_profile")
  workEntryId = self~optional(payload, "work_entry_id", "")
  return self~authority~testRequest(packageRequestId, testProfile, workEntryId, userId)

::method reviewWork private
  use strict arg payload, userId, outcome
  workEntryId = self~required(payload, "work_entry_id")
  findings = self~required(payload, "findings")
  evidence = self~required(payload, "evidence")

  -- Accept/refuse is explicit human authority.  Do not derive it from UI state.
  return self~authority~workReview(workEntryId, outcome, findings, evidence, userId)

::method compare private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  leftRevisionId = self~required(payload, "left_revision_id")
  rightRevisionId = self~required(payload, "right_revision_id")
  return self~authority~sourceCompare(objectId, leftRevisionId, rightRevisionId, userId)

::method createRequirement private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  requirementKind = self~required(payload, "requirement_kind")
  requirementText = self~required(payload, "requirement_text")
  return self~authority~methodRequirementCreate(objectId, requirementKind, requirementText, userId)

::method createNote private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  revisionId = self~optional(payload, "revision_id", "")
  noteKind = self~required(payload, "note_kind")
  title = self~optional(payload, "title", "")
  noteText = self~required(payload, "note_text")
  return self~authority~methodNoteCreate(objectId, revisionId, noteKind, title, noteText, userId)

::method uploadResource private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  revisionId = self~optional(payload, "revision_id", "")
  logicalName = self~required(payload, "logical_name")
  mimeType = self~required(payload, "mime_type")
  content = self~required(payload, "content")
  materialisationPath = self~required(payload, "materialisation_path")
  relationKind = self~optional(payload, "relation_kind", "RESOURCE")
  return self~authority~resourceUpload(objectId, revisionId, logicalName, mimeType, content, materialisationPath, relationKind, userId)

::method createModuleRequirement private
  use strict arg payload, userId
  requiringModuleId = self~required(payload, "requiring_module_id")
  scopeKind = self~required(payload, "scope_kind")
  scopeId = self~required(payload, "scope_id")
  targetModuleId = self~required(payload, "target_module_id")
  constraintKind = self~required(payload, "constraint_kind")
  requiredDeploymentId = self~required(payload, "required_deployment_id")
  reason = self~required(payload, "reason")
  return self~authority~moduleRequirementCreate(requiringModuleId, scopeKind, scopeId, targetModuleId, constraintKind, requiredDeploymentId, reason, userId)

::method requestDeploymentPackage private
  use strict arg payload, userId
  deploymentId = self~required(payload, "deployment_id")
  projectId = self~optional(payload, "project_id", "default")
  format = self~optional(payload, "format", "files")
  return self~authority~sourceGetDeploymentPackage(deploymentId, projectId, format, userId)

::method classifyBranch private
  use strict arg payload, userId
  branchId = self~required(payload, "branch_id")
  classification = self~required(payload, "classification")
  upstreamPolicy = self~optional(payload, "upstream_policy", "")
  return self~authority~branchClassify(branchId, classification, upstreamPolicy, userId)

::method protectBranch private
  use strict arg payload, userId
  branchId = self~required(payload, "branch_id")
  scopeKind = self~required(payload, "scope_kind")
  scopeId = self~required(payload, "scope_id")
  reason = self~required(payload, "reason")
  return self~authority~branchProtect(branchId, scopeKind, scopeId, reason, userId)

::method requestBranchPackage private
  use strict arg payload, userId
  branchId = self~required(payload, "branch_id")
  upstreamDeploymentId = self~optional(payload, "upstream_deployment_id", "")
  projectId = self~optional(payload, "project_id", "default")
  format = self~optional(payload, "format", "files")
  return self~authority~sourceGetBranchPackage(branchId, upstreamDeploymentId, projectId, format, userId)

::method resolveBranchConflict private
  use strict arg payload, userId
  branchId = self~required(payload, "branch_id")
  conflictId = self~required(payload, "conflict_id")
  acceptedRevisionId = self~required(payload, "accepted_revision_id")
  resolution = self~required(payload, "resolution")
  return self~authority~branchConflictResolve(branchId, conflictId, acceptedRevisionId, resolution, userId)

::method gotoDefinition private
  use strict arg payload, userId
  referenceId = self~required(payload, "reference_id")
  return self~authority~semanticDefinition(referenceId, userId)

::method findUses private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  return self~authority~semanticFindUses(objectId, userId)

::method callers private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  return self~authority~semanticCallers(objectId, userId)

::method callees private
  use strict arg payload, userId
  objectId = self~required(payload, "object_id")
  return self~authority~semanticCallees(objectId, userId)

::method explainReference private
  use strict arg payload, userId
  referenceId = self~required(payload, "reference_id")
  return self~authority~semanticReferenceExplain(referenceId, userId)

::method classSurface private
  use strict arg payload, userId
  snapshotId = self~required(payload, "snapshot_id")
  return self~authority~semanticClassSurface(snapshotId, userId)

::method classOverrides private
  use strict arg payload, userId
  snapshotId = self~required(payload, "snapshot_id")
  return self~authority~semanticClassOverrides(snapshotId, userId)

/*
 * Token-efficient default class inspection.  The authority returns the class
 * hierarchy and compact effective method facts only; source bodies are fetched
 * through CODE.OPEN / CODE.CLASS.SURFACE on demand.  `since` permits an LLM to
 * request only semantic changes observed after a prior inspection timestamp.
 */
::method classInspect private
  use strict arg payload, userId
  classId = self~required(payload, "class_id")
  revisionId = self~optional(payload, "revision_id", "")
  since = self~optional(payload, "since", "")
  summary = self~authority~semanticClassInspection(classId, revisionId, since, userId)
  self~validateClassInspection(summary)
  return summary

::method validateClassInspection private
  use strict arg summary
  if summary == .nil then raise syntax 88.900 array("class inspection summary is required")
  required = .array~of("schema", "class_id", "class_tree", "since", "as_of", "methods")
  do key over required
    if \summary~hasIndex(key) then raise syntax 88.900 array("class inspection missing required section: " || key)
  end
  do methodInfo over summary["methods"]
    do key over .array~of("name", "from", "exposes", "returns")
      if \methodInfo~hasIndex(key) then raise syntax 88.900 array("class inspection method missing field: " || key)
    end
    returns = methodInfo["returns"]
    if returns == .nil | \returns~hasIndex("kind") | \returns~hasIndex("class") then -
      raise syntax 88.900 array("class inspection return descriptor requires kind and class")
  end
  return

::method refresh private
  use strict arg payload, userId
  if payload~hasIndex("object_id") then return self~open(payload, userId)
  return self~initialView(userId)

::method required private
  use strict arg payload, key
  if \payload~hasIndex(key) then raise syntax 88.900 array("missing required field: " || key)
  value = payload[key]
  if value == .nil then raise syntax 88.900 array("missing required field: " || key)
  if value~isA(.String), value = "" then raise syntax 88.900 array("empty required field: " || key)
  return value

::method optional private
  use strict arg payload, key, defaultValue
  if \payload~hasIndex(key) then return defaultValue
  value = payload[key]
  if value == .nil then return defaultValue
  return value

/*
 * Thin Wire-facing adapter.  WireUIServer can register this application object
 * and map its semantic action payloads to onWireAction().  The adapter does not
 * contain HTML/DOM behaviour; it only returns authoritative semantic snapshots.
 */
::class SemanticSourceCodeExaminerWireApplication public

::method init
  use strict arg examiner, applicationId = "SSC-CODE-EXAMINER", transportConfig = .nil
  self~examiner = examiner
  self~applicationId = applicationId
  if transportConfig == .nil then transportConfig = .directory~new
  self~transportConfig = transportConfig

::attribute examiner get
::attribute examiner set private
::attribute applicationId get
::attribute applicationId set private
::attribute transportConfig get
::attribute transportConfig set private

/*
 * Same-origin browser bootstrap descriptor.  The host/gateway publishes this
 * object at its service-descriptor endpoint.  Deployments therefore configure
 * queues/URLs once at the server boundary, never by editing browser source.
 */
::method serviceDescriptor
  use strict arg userId = ""
  d = .directory~new
  d["schema"] = "semantic-source.code-examiner.service/1"
  d["applicationId"] = self~applicationId
  d["userId"] = userId
  d["websocketUrl"] = self~transportValue("websocketUrl", "")
  d["outboundQueue"] = self~transportValue("outboundQueue", "")
  d["source"] = self~transportValue("source", "SSC.CODE.EXAMINER.WEB")
  d["accessPointId"] = self~transportValue("accessPointId", "WEB")
  d["sessionId"] = self~transportValue("sessionId", "")
  return d

::method transportValue private
  use strict arg key, defaultValue
  if self~transportConfig~hasIndex(key) then return self~transportConfig[key]
  return defaultValue

::method initialProjection
  use strict arg userId
  return self~examiner~initialView(userId)

::method onWireAction
  use strict arg actionName, payload, userId
  return self~examiner~handleAction(actionName, payload, userId)
