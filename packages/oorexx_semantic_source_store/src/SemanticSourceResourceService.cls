/*
 * Semantic Source Control - non-code resource service.
 * Resources include JSON/schema/config/test vectors/docs and arbitrary binary
 * assets. Text resources use content_text; binary resources use content_base64.
 */

::class SemanticSourceResourceService public

::method init
  use strict arg sql
  self~sql = sql

::attribute sql get
::attribute sql set private

::method createResource
  use strict arg resourceId, logicalName, resourceKind, mimeType, description, createdAt, createdBy
  statement = "INSERT INTO ssc_resource_object (resource_id,logical_name,resource_kind,mime_type,description,created_at,created_by,accepted_revision_id) VALUES (" ||,
              self~quote(resourceId) || "," || self~quote(logicalName) || "," || self~quote(resourceKind) || "," || self~quote(mimeType) || "," ||,
              self~quote(description) || "," || self~quote(createdAt) || "," || self~quote(createdBy) || ",'')"
  return self~query(statement)

::method addRevision
  use strict arg revisionId, resourceId, parentRevisionId, revisionNo, contentText, contentBase64, contentSha256, mimeType, status, changedAt, changedBy, materialisationPath, archiveFilename = "", archiveSha256 = "", memberPath = ""
  if contentText = "" & contentBase64 = "" then raise syntax 88.900 array("resource revision must contain text or base64 content")
  statement = "INSERT INTO ssc_resource_revision (resource_revision_id,resource_id,parent_revision_id,revision_no,content_text,content_base64,content_sha256,mime_type,status,changed_at,changed_by,origin_archive_filename,origin_archive_sha256,origin_member_path,materialisation_path) VALUES (" ||,
              self~quote(revisionId) || "," || self~quote(resourceId) || "," || self~quote(parentRevisionId) || "," || revisionNo || "," ||,
              self~quote(contentText) || "," || self~quote(contentBase64) || "," || self~quote(contentSha256) || "," || self~quote(mimeType) || "," ||,
              self~quote(status) || "," || self~quote(changedAt) || "," || self~quote(changedBy) || "," || self~quote(archiveFilename) || "," ||,
              self~quote(archiveSha256) || "," || self~quote(memberPath) || "," || self~quote(materialisationPath) || ")"
  return self~query(statement)

::method attachToObject
  use strict arg relationId, objectId, revisionId, relationKind, resourceId, requiredRevisionId = "", detail = ""
  statement = "INSERT INTO ssc_resource_relation (resource_relation_id,from_object_id,from_revision_id,relation_kind,resource_id,required_revision_id,detail) VALUES (" ||,
              self~quote(relationId) || "," || self~quote(objectId) || "," || self~quote(revisionId) || "," || self~quote(relationKind) || "," ||,
              self~quote(resourceId) || "," || self~quote(requiredRevisionId) || "," || self~quote(detail) || ")"
  return self~query(statement)

::method validateJsonText
  use strict arg jsonText
  -- Syntax validation is delegated to the repository's JSON provider at the MCP boundary.
  -- The database stores MIME identity and exact bytes/hash; it does not reinterpret JSON.
  if jsonText = "" then raise syntax 88.900 array("JSON resource must not be empty")
  return 1

::method query private
  use strict arg statement
  dbResult = self~sql~execute(statement)
  if dbResult~status = "SUCCESS" then return dbResult
  raise syntax 88.900 array("Database operation failed: " || statement || "; " || dbResult~message)

::method quote private
  use strict arg value
  if value == .nil then value = ""
  return "'" || value~changestr("'", "''") || "'"

