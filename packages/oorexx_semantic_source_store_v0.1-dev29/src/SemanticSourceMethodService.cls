/*
 * Semantic Source Control - ooRexx method metadata and comparison service.
 *
 * ooRexx methods are primary semantic source objects.  This service keeps
 * requirements, notes/documentation and revision comparison separate from the
 * source text while referring to exact semantic object/revision identities.
 */

::class SemanticSourceMethodService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

::method createRequirement
  use strict arg requirementId, objectId, requirementKind, requirementText, createdAt, createdBy, supersedes = ""
  self~assertMethod(objectId)
  if requirementText = "" then raise syntax 88.900 array("requirementText must not be empty")
  statement = "INSERT INTO ssc_method_requirement (requirement_id,object_id,requirement_kind,requirement_text,status,created_at,created_by,supersedes_requirement_id) VALUES (" ||,
              self~quote(requirementId) || "," || self~quote(objectId) || "," || self~quote(requirementKind) || "," || self~quote(requirementText) || "," ||,
              self~quote("ACTIVE") || "," || self~quote(createdAt) || "," || self~quote(createdBy) || "," || self~quote(supersedes) || ")"
  return self~query(statement)

::method requirementsFor
  use strict arg objectId
  self~assertMethod(objectId)
  return self~query("SELECT * FROM ssc_method_requirement WHERE object_id=" || self~quote(objectId) || " AND status='ACTIVE' ORDER BY created_at, requirement_id")

::method addNote
  use strict arg noteId, objectId, revisionId, noteKind, title, noteText, createdAt, createdBy, supersedes = ""
  self~assertMethod(objectId)
  if noteText = "" then raise syntax 88.900 array("noteText must not be empty")
  statement = "INSERT INTO ssc_method_note (note_id,object_id,revision_id,note_kind,title,note_text,created_at,created_by,supersedes_note_id) VALUES (" ||,
              self~quote(noteId) || "," || self~quote(objectId) || "," || self~quote(revisionId) || "," || self~quote(noteKind) || "," ||,
              self~quote(title) || "," || self~quote(noteText) || "," || self~quote(createdAt) || "," || self~quote(createdBy) || "," || self~quote(supersedes) || ")"
  return self~query(statement)

::method notesFor
  use strict arg objectId, revisionId = ""
  self~assertMethod(objectId)
  statement = "SELECT * FROM ssc_method_note WHERE object_id=" || self~quote(objectId)
  if revisionId \= "" then statement ||= " AND (revision_id='' OR revision_id=" || self~quote(revisionId) || ")"
  statement ||= " ORDER BY created_at, note_id"
  return self~query(statement)

::method compareRevisions
  use strict arg objectId, leftRevisionId, rightRevisionId
  self~assertMethod(objectId)
  left = self~loadRevision(objectId, leftRevisionId)
  right = self~loadRevision(objectId, rightRevisionId)
  comparison = .directory~new
  comparison["object_id"] = objectId
  comparison["left_revision_id"] = leftRevisionId
  comparison["right_revision_id"] = rightRevisionId
  comparison["left_source"] = left["source_text"]
  comparison["right_source"] = right["source_text"]
  comparison["left_sha256"] = left["source_sha256"]
  comparison["right_sha256"] = right["source_sha256"]
  comparison["changed"] = left["source_sha256"] \= right["source_sha256"]
  comparison["left_reason"] = left["change_reason"]
  comparison["right_reason"] = right["change_reason"]
  return comparison

::method loadRevision private
  use strict arg objectId, revisionId
  rs = self~query("SELECT revision_id,source_text,source_sha256,change_reason FROM ssc_source_revision WHERE object_id=" || self~quote(objectId) || " AND revision_id=" || self~quote(revisionId))
  if rs~rows~items = 0 then raise syntax 88.900 array("revision not found for method: " || revisionId)
  return rs~rows[1]

::method assertMethod private
  use strict arg objectId
  rs = self~query("SELECT object_kind FROM ssc_source_object WHERE object_id=" || self~quote(objectId))
  if rs~rows~items = 0 then raise syntax 88.900 array("source object not found: " || objectId)
  kind = rs~rows[1]["object_kind"]
  if kind~upper \= "METHOD" then raise syntax 88.900 array("object is not an ooRexx method: " || objectId)

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"

