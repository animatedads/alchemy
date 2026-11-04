/*
 * Semantic Source Control - semantic reference graph service.
 *
 * Source identifiers and dependency expressions are stored as graph edges,
 * not rediscovered with grep at review time.  Resolution state is explicit:
 * RESOLVED, POSSIBLE, DYNAMIC or UNRESOLVED.
 */

::class SemanticSourceGraphService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

::method createReference
  use strict arg referenceId, fromObjectId, fromRevisionId, referenceKind, lexeme, targetObjectId = "", targetRevisionId = "", targetModuleId = "", resolutionState = "UNRESOLVED", sourceLine = 0, sourceColumn = 0, detail = "", createdAt = "", createdBy = ""
  state = resolutionState~upper
  if state <> "RESOLVED" & state <> "POSSIBLE" & state <> "DYNAMIC" & state <> "UNRESOLVED" then,
    raise syntax 88.900 array("invalid semantic reference resolution state: " || resolutionState)

  kind = referenceKind~upper
  if referenceId = "" then raise syntax 88.900 array("referenceId must not be empty")
  if fromObjectId = "" then raise syntax 88.900 array("fromObjectId must not be empty")

  statement = "INSERT INTO ssc_semantic_reference (reference_id,from_object_id,from_revision_id,reference_kind,lexeme,target_object_id,target_revision_id,target_module_id,resolution_state,source_line,source_column,detail,created_at,created_by) VALUES (" ||,
              self~quote(referenceId) || "," || self~quote(fromObjectId) || "," || self~quote(fromRevisionId) || "," ||,
              self~quote(kind) || "," || self~quote(lexeme) || "," || self~quote(targetObjectId) || "," ||,
              self~quote(targetRevisionId) || "," || self~quote(targetModuleId) || "," || self~quote(state) || "," ||,
              sourceLine || "," || sourceColumn || "," || self~quote(detail) || "," || self~quote(createdAt) || "," || self~quote(createdBy) || ")"
  return self~query(statement)

::method observeReference
  use strict arg observationId, referenceId, targetObjectId, targetRevisionId = "", evidenceKind = "RUNTIME", evidenceId = "", observedAt = "", observedBy = "", detail = ""
  if referenceId = "" then raise syntax 88.900 array("referenceId must not be empty")
  if targetObjectId = "" then raise syntax 88.900 array("targetObjectId must not be empty")
  statement = "INSERT INTO ssc_reference_observation (observation_id,reference_id,observed_target_object_id,observed_target_revision_id,evidence_kind,evidence_id,observed_at,observed_by,detail) VALUES (" ||,
              self~quote(observationId) || "," || self~quote(referenceId) || "," || self~quote(targetObjectId) || "," ||,
              self~quote(targetRevisionId) || "," || self~quote(evidenceKind~upper) || "," || self~quote(evidenceId) || "," ||,
              self~quote(observedAt) || "," || self~quote(observedBy) || "," || self~quote(detail) || ")"
  return self~query(statement)

::method reference
  use strict arg referenceId
  rs = self~query("SELECT reference_id,from_object_id,from_revision_id,reference_kind,lexeme,target_object_id,target_revision_id,target_module_id,resolution_state,source_line,source_column,detail FROM ssc_semantic_reference WHERE reference_id=" || self~quote(referenceId))
  if rs~rows~items = 0 then raise syntax 88.900 array("semantic reference not found: " || referenceId)
  return rs~rows[1]

::method definition
  use strict arg referenceId
  ref = self~reference(referenceId)
  d = .directory~new
  d["reference"] = ref
  d["resolution_state"] = ref["resolution_state"]
  d["target_object_id"] = ref["target_object_id"]
  d["target_revision_id"] = ref["target_revision_id"]
  d["target_module_id"] = ref["target_module_id"]
  d["observations"] = self~observations(referenceId)
  return d

::method observations
  use strict arg referenceId
  return self~query("SELECT observation_id,reference_id,observed_target_object_id,observed_target_revision_id,evidence_kind,evidence_id,observed_at,observed_by,detail FROM ssc_reference_observation WHERE reference_id=" || self~quote(referenceId) || " ORDER BY observed_at,observation_id")

::method findUses
  use strict arg targetObjectId
  return self~query("SELECT reference_id,from_object_id,from_revision_id,reference_kind,lexeme,target_object_id,target_revision_id,target_module_id,resolution_state,source_line,source_column,detail FROM ssc_semantic_reference WHERE target_object_id=" || self~quote(targetObjectId) || " ORDER BY from_object_id,source_line,source_column")

::method outgoing
  use strict arg fromObjectId, referenceKind = ""
  statement = "SELECT reference_id,from_object_id,from_revision_id,reference_kind,lexeme,target_object_id,target_revision_id,target_module_id,resolution_state,source_line,source_column,detail FROM ssc_semantic_reference WHERE from_object_id=" || self~quote(fromObjectId)
  if referenceKind <> "" then statement ||= " AND reference_kind=" || self~quote(referenceKind~upper)
  statement ||= " ORDER BY source_line,source_column,reference_id"
  return self~query(statement)

::method callers
  use strict arg targetObjectId
  return self~query("SELECT reference_id,from_object_id,from_revision_id,lexeme,resolution_state,source_line,source_column,detail FROM ssc_semantic_reference WHERE target_object_id=" || self~quote(targetObjectId) || " AND reference_kind='CALL' ORDER BY from_object_id,source_line,source_column")

::method callees
  use strict arg fromObjectId
  return self~query("SELECT reference_id,target_object_id,target_revision_id,lexeme,resolution_state,source_line,source_column,detail FROM ssc_semantic_reference WHERE from_object_id=" || self~quote(fromObjectId) || " AND reference_kind='CALL' ORDER BY source_line,source_column")

::method explain
  use strict arg referenceId
  ref = self~reference(referenceId)
  d = .directory~new
  d["reference_id"] = referenceId
  d["reference_kind"] = ref["reference_kind"]
  d["lexeme"] = ref["lexeme"]
  d["from_object_id"] = ref["from_object_id"]
  d["from_revision_id"] = ref["from_revision_id"]
  d["target_object_id"] = ref["target_object_id"]
  d["target_revision_id"] = ref["target_revision_id"]
  d["target_module_id"] = ref["target_module_id"]
  d["resolution_state"] = ref["resolution_state"]
  d["detail"] = ref["detail"]
  d["observations"] = self~observations(referenceId)
  return d

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"


/* Runtime-effective ooRexx class graph captured by SemanticSourceRexxIntrospector. */
::method runtimeClassSurface
  use strict arg snapshotId
  d = .directory~new
  d["snapshot"] = self~query("SELECT snapshot_id,module_id,source_object_id,source_revision_id,package_name,class_id,runtime_name,runtime_version,captured_at,captured_by FROM ssc_runtime_class_snapshot WHERE snapshot_id=" || self~quote(snapshotId))
  d["parents"] = self~query("SELECT edge_id,snapshot_id,child_class_id,parent_class_id,parent_ordinal,depth FROM ssc_runtime_inheritance_edge WHERE snapshot_id=" || self~quote(snapshotId) || " ORDER BY parent_ordinal,edge_id")
  d["methods"] = self~query("SELECT surface_id,snapshot_id,method_scope,method_name,origin_package_name,origin_class_id,relation_kind,is_effective,is_hidden,overrides_package_name,overrides_class_id,depth FROM ssc_runtime_method_surface WHERE snapshot_id=" || self~quote(snapshotId) || " ORDER BY method_scope,method_name,depth,surface_id")
  return d

::method runtimeEffectiveMethods
  use strict arg snapshotId, methodScope = ""
  statement = "SELECT surface_id,snapshot_id,method_scope,method_name,origin_package_name,origin_class_id,relation_kind,is_effective,is_hidden,overrides_package_name,overrides_class_id,depth FROM ssc_runtime_method_surface WHERE snapshot_id=" || self~quote(snapshotId) || " AND is_effective=1"
  if methodScope <> "" then statement ||= " AND method_scope=" || self~quote(methodScope~upper)
  statement ||= " ORDER BY method_scope,method_name,surface_id"
  return self~query(statement)

::method runtimeOverrides
  use strict arg snapshotId
  return self~query("SELECT surface_id,snapshot_id,method_scope,method_name,origin_package_name,origin_class_id,relation_kind,is_effective,is_hidden,overrides_package_name,overrides_class_id,depth FROM ssc_runtime_method_surface WHERE snapshot_id=" || self~quote(snapshotId) || " AND relation_kind='OVERRIDES' ORDER BY method_scope,method_name,surface_id")
