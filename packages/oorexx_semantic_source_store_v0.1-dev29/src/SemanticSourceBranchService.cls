/*
 * Semantic Source Control - sparse semantic branches.
 *
 * A hard conflict does not fail the edit.  It creates a CONFLICT branch with
 * branch-local overrides.  A human/authority may later classify it INTENTIONAL.
 * Intentional branches either ACCEPT_NON_CONFLICTING or REJECT_NON_CONFLICTING
 * upstream changes.  Protection rules always reject matching upstream changes.
 */

::class SemanticSourceBranchService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

::method createConflictBranch
  use strict arg branchId, moduleId, baseDeploymentId, elementId, parentRevisionId, candidateRevisionA, candidateRevisionB, createdAt, createdBy
  if branchId = "" then raise syntax 88.900 array("branchId must not be empty")
  self~query("INSERT INTO ssc_branch (branch_id,module_id,parent_branch_id,base_deployment_id,classification,upstream_policy,status,created_at,created_by,confirmed_at,confirmed_by) VALUES (" ||,
             self~quote(branchId) || "," || self~quote(moduleId) || ",''," || self~quote(baseDeploymentId) || "," ||,
             self~quote("CONFLICT") || "," || self~quote("UNDECIDED") || "," || self~quote("OPEN") || "," ||,
             self~quote(createdAt) || "," || self~quote(createdBy) || ",'','')")

  conflictId = branchId || ":conflict:1"
  self~query("INSERT INTO ssc_branch_conflict (branch_conflict_id,branch_id,object_id,parent_revision_id,candidate_revision_a,candidate_revision_b,status,created_at,resolved_at,resolution) VALUES (" ||,
             self~quote(conflictId) || "," || self~quote(branchId) || "," || self~quote(elementId) || "," || self~quote(parentRevisionId) || "," ||,
             self~quote(candidateRevisionA) || "," || self~quote(candidateRevisionB) || "," || self~quote("OPEN") || "," || self~quote(createdAt) || ",'','')")

  -- Both candidates are retained as explicit branch alternatives.  Neither is silently promoted.
  self~addOverride(branchId || ":override:a", branchId, elementId, candidateRevisionA, "CONFLICT_CANDIDATE_A", createdAt, createdBy)
  self~addOverride(branchId || ":override:b", branchId, elementId, candidateRevisionB, "CONFLICT_CANDIDATE_B", createdAt, createdBy)
  return self~branch(branchId)

::method confirmIntentional
  use strict arg branchId, upstreamPolicy, confirmedAt, confirmedBy
  policy = upstreamPolicy~upper
  if policy <> "ACCEPT_NON_CONFLICTING" & policy <> "REJECT_NON_CONFLICTING" then,
    raise syntax 88.900 array("upstreamPolicy must be ACCEPT_NON_CONFLICTING or REJECT_NON_CONFLICTING")
  current = self~branch(branchId)
  if current["status"] <> "OPEN" then raise syntax 88.900 array("branch is not open")
  self~query("UPDATE ssc_branch SET classification='INTENTIONAL',upstream_policy=" || self~quote(policy) || ",confirmed_at=" || self~quote(confirmedAt) || ",confirmed_by=" || self~quote(confirmedBy) || " WHERE branch_id=" || self~quote(branchId))
  return self~branch(branchId)

::method keepAsConflict
  use strict arg branchId, confirmedAt, confirmedBy
  self~query("UPDATE ssc_branch SET classification='CONFLICT',confirmed_at=" || self~quote(confirmedAt) || ",confirmed_by=" || self~quote(confirmedBy) || " WHERE branch_id=" || self~quote(branchId))
  return self~branch(branchId)

::method addOverride
  use strict arg overrideId, branchId, objectId, revisionId, reason, createdAt, createdBy
  return self~query("INSERT INTO ssc_branch_override (branch_override_id,branch_id,object_id,revision_id,reason,status,created_at,created_by) VALUES (" ||,
                    self~quote(overrideId) || "," || self~quote(branchId) || "," || self~quote(objectId) || "," || self~quote(revisionId) || "," ||,
                    self~quote(reason) || "," || self~quote("ACTIVE") || "," || self~quote(createdAt) || "," || self~quote(createdBy) || ")")

::method protect
  use strict arg protectionId, branchId, scopeKind, scopeId, reason, createdAt, createdBy
  scope = scopeKind~upper
  if scope <> "MODULE" & scope <> "FILE" & scope <> "CLASS" & scope <> "ATTRIBUTE" & scope <> "METHOD" then,
    raise syntax 88.900 array("scopeKind must be MODULE, FILE, CLASS, ATTRIBUTE or METHOD")
  return self~query("INSERT INTO ssc_branch_protection (branch_protection_id,branch_id,scope_kind,scope_id,policy,reason,status,created_at,created_by) VALUES (" ||,
                    self~quote(protectionId) || "," || self~quote(branchId) || "," || self~quote(scope) || "," || self~quote(scopeId) || "," ||,
                    self~quote("REJECT_UPSTREAM") || "," || self~quote(reason) || "," || self~quote("ACTIVE") || "," || self~quote(createdAt) || "," || self~quote(createdBy) || ")")

::method resolveElementRevision
  use strict arg branchId, objectId, upstreamRevisionId
  statement = "SELECT revision_id FROM ssc_branch_override WHERE branch_id=" || self~quote(branchId) ||,
              " AND object_id=" || self~quote(objectId) || " AND status='ACTIVE' ORDER BY created_at DESC,branch_override_id DESC"
  rs = self~query(statement)
  if rs~rows~items = 0 then return upstreamRevisionId

  -- A conflict branch may intentionally retain multiple candidate overrides.
  branch = self~branch(branchId)
  if branch["classification"] = "CONFLICT" & rs~rows~items > 1 then,
    raise syntax 88.900 array("BRANCH_CONFLICT: unresolved alternatives for " || objectId || " on " || branchId)
  return rs~rows[1]["revision_id"]

::method branchNoticeForModule
  use strict arg moduleId
  rs = self~query("SELECT branch_id,classification,upstream_policy,status,base_deployment_id FROM ssc_branch WHERE module_id=" || self~quote(moduleId) || " AND status='OPEN' ORDER BY created_at,branch_id")
  notice = .directory~new
  notice["module_id"] = moduleId
  notice["has_branch"] = (rs~rows~items > 0)
  notice["branches"] = rs~rows
  notice["has_conflict_branch"] = 0
  do row over rs~rows
    if row["classification"] = "CONFLICT" then notice["has_conflict_branch"] = 1
  end
  return notice

/*
 * Decide what happens to one upstream change for an INTENTIONAL branch.
 * context keys: module_id, file_path, class_id, attribute_id, method_id, object_id.
 * localChanged tells us whether the branch has independently changed the same semantic object.
 */
::method decideUpstreamChange
  use strict arg branchId, context, localChanged = 0
  branch = self~branch(branchId)
  if branch["classification"] <> "INTENTIONAL" then return "REJECTED_CONFLICT"

  if self~isProtected(branchId, context) then return "REJECTED_PROTECTED"
  if localChanged then return "REJECTED_CONFLICT"
  if branch["upstream_policy"] = "ACCEPT_NON_CONFLICTING" then return "ADOPTED"
  return "REJECTED_POLICY"

::method recordUpstreamDecision
  use strict arg eventId, branchId, objectId, upstreamRevisionId, outcome, detail, eventAt
  return self~query("INSERT INTO ssc_branch_event (branch_event_id,branch_id,event_kind,object_id,upstream_revision_id,outcome,detail,event_at) VALUES (" ||,
                    self~quote(eventId) || "," || self~quote(branchId) || "," || self~quote("UPSTREAM_CHANGE") || "," || self~quote(objectId) || "," ||,
                    self~quote(upstreamRevisionId) || "," || self~quote(outcome) || "," || self~quote(detail) || "," || self~quote(eventAt) || ")")

::method resolveConflict
  use strict arg branchId, conflictId, acceptedRevisionId, resolvedAt, resolution
  self~query("UPDATE ssc_branch_conflict SET status='RESOLVED',resolved_at=" || self~quote(resolvedAt) || ",resolution=" || self~quote(resolution) || " WHERE branch_conflict_id=" || self~quote(conflictId) || " AND branch_id=" || self~quote(branchId))
  -- Retire all candidate overrides for the object and install the accepted branch-local edition.
  c = self~query("SELECT object_id FROM ssc_branch_conflict WHERE branch_conflict_id=" || self~quote(conflictId))
  if c~rows~items = 0 then raise syntax 88.900 array("branch conflict not found: " || conflictId)
  objectId = c~rows[1]["object_id"]
  self~query("UPDATE ssc_branch_override SET status='SUPERSEDED' WHERE branch_id=" || self~quote(branchId) || " AND object_id=" || self~quote(objectId) || " AND status='ACTIVE'")
  self~addOverride(branchId || ":resolved:" || conflictId, branchId, objectId, acceptedRevisionId, "CONFLICT_RESOLUTION", resolvedAt, "resolver")
  return self~branch(branchId)

::method isProtected private
  use strict arg branchId, context
  statement = "SELECT scope_kind,scope_id FROM ssc_branch_protection WHERE branch_id=" || self~quote(branchId) || " AND status='ACTIVE'"
  rs = self~query(statement)
  do p over rs~rows
    scope = p["scope_kind"]
    id = p["scope_id"]
    select
      when scope = "MODULE" then if context~hasIndex("module_id") & context["module_id"] = id then return 1
      when scope = "FILE" then if context~hasIndex("file_path") & context["file_path"] = id then return 1
      when scope = "CLASS" then if context~hasIndex("class_id") & context["class_id"] = id then return 1
      when scope = "ATTRIBUTE" then if context~hasIndex("attribute_id") & context["attribute_id"] = id then return 1
      when scope = "METHOD" then if context~hasIndex("method_id") & context["method_id"] = id then return 1
      otherwise nop
    end
  end
  return 0

::method branch private
  use strict arg branchId
  rs = self~query("SELECT branch_id,module_id,parent_branch_id,base_deployment_id,classification,upstream_policy,status,created_at,created_by,confirmed_at,confirmed_by FROM ssc_branch WHERE branch_id=" || self~quote(branchId))
  if rs~rows~items = 0 then raise syntax 88.900 array("branch not found: " || branchId)
  return rs~rows[1]

::method query private
  use strict arg statement
  rs = self~sql~execute(statement)
  if rs~status <> "SUCCESS" then,
    raise syntax 88.900 array("database operation failed: " || statement || "; " || rs~message)
  return rs

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~string~changestr("'", "''") || "'"

