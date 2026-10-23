/*
 * Semantic Source Control - semantic element mutation coordinator.
 *
 * Existing semantic objects are edited by exact base revision.  This service
 * deliberately refuses whole SOURCE_UNIT/SOURCE_FILE replacement: callers edit
 * METHOD/ATTRIBUTE/CONSTANT/ROUTINE/CLASS-header/etc. objects and the package
 * materialiser rebuilds the file from the accepted object revisions.
 *
 * When the requested base is no longer current, RepositoryService records the
 * candidate without moving the upstream current pointer and this coordinator
 * creates the existing sparse CONFLICT branch.  Both candidates are retained.
 */

::class SemanticSourceMutationService public

::method init
  expose repository branches sql
  use strict arg repositoryService, branchService, sqlExecutor
  if repositoryService == .nil | branchService == .nil | sqlExecutor == .nil then,
    raise syntax 88.900 array("repositoryService, branchService and sqlExecutor are required")
  repository = repositoryService
  branches = branchService
  sql = sqlExecutor

::method proposeEdit
  expose repository branches
  use strict arg objectId, baseRevisionId, sourceText, principal, reason = "", baseDeploymentId = ""

  kind = self~objectKind(objectId)
  if kind = "" then raise syntax 88.900 array("unknown semantic object: " || objectId)
  if kind = "SOURCE_UNIT" | kind = "SOURCE_FILE" then,
    raise syntax 88.900 array("SEMANTIC_EDIT_REQUIRED: whole-file/source-unit replacement is not allowed for " || objectId)

  proposal = repository~proposeRevision(objectId, baseRevisionId, sourceText, principal, reason)
  if proposal["conflict"] \= 1 then return proposal

  branchId = self~openConflictBranchFor(objectId, proposal["revision_id"])
  if branchId = "" then do
    branchId = "br_conflict_" || proposal["revision_id"]~substr(5)
    moduleId = self~moduleForObject(objectId)
    if moduleId = "" then moduleId = "<unassigned>"
    createdAt = .DateTime~new~isoDate
    ignored = branches~createConflictBranch(branchId, moduleId, baseDeploymentId, objectId, baseRevisionId,,
                                             proposal["current_revision_id"], proposal["revision_id"], createdAt, principal)
  end

  proposal["branch_id"] = branchId
  proposal["branch_classification"] = "CONFLICT"
  proposal["status"] = "BRANCH_CONFLICT"
  return proposal

::method objectKind private
  expose sql
  use strict arg objectId
  rs = self~query("SELECT object_kind FROM ssc_source_object WHERE object_id=" || self~q(objectId))
  if rs~rows~items = 0 then return ""
  return self~col(rs~rows[1], "object_kind")

::method moduleForObject private
  expose sql
  use strict arg objectId
  statement = "SELECT u.module_id FROM ssc_source_unit u JOIN ssc_relation r ON r.from_object_id=u.source_unit_id " ||,
              "WHERE r.relation_kind='DEPENDS_ON' AND r.to_object_id=" || self~q(objectId)
  rs = self~query(statement)
  if rs~rows~items = 0 then return ""
  return self~col(rs~rows[1], "module_id")

::method openConflictBranchFor private
  expose sql
  use strict arg objectId, candidateRevisionId
  statement = "SELECT c.branch_id FROM ssc_branch_conflict c JOIN ssc_branch b ON b.branch_id=c.branch_id " ||,
              "WHERE c.object_id=" || self~q(objectId) || " AND c.candidate_revision_b=" || self~q(candidateRevisionId) ||,
              " AND c.status='OPEN' AND b.status='OPEN'"
  rs = self~query(statement)
  if rs~rows~items = 0 then return ""
  return self~col(rs~rows[1], "branch_id")

::method query private
  expose sql
  use strict arg statement
  rs = sql~execute(statement)
  if rs~status \= "SUCCESS" then,
    raise syntax 88.900 array("Semantic Source mutation SQL failed: " || statement~left(240) || "; status=" || rs~status || "; " || rs~message)
  return rs

::method col private
  use strict arg row, name
  v = row[name]
  if v == .nil then v = row[name~upper]
  if v == .nil then return ""
  return v

::method q private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~string~changestr("'", "''") || "'"
