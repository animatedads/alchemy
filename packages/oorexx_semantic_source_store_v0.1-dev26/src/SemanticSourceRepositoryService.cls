/*
 * Semantic Source Control - repository write authority (method-granular).
 *
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 *
 * This is the component the SSC design required and nothing implemented: the
 * authority that turns an import into semantic source objects and revisions,
 * accepts or refuses revisions, and records exactly what each import contained.
 * Before it, no code in the estate inserted into ssc_source_object,
 * ssc_source_revision or the import tables; every reader read empty tables.
 *
 * NoSQLServer v0.79 constraint: UPDATE evaluates quoted string literals as
 * expressions ('3*4' is stored as 12, '12-34' as -22).  UPDATE is therefore used
 * only with content ids (letters, '_' and hex), statuses and numbers; all free
 * text is written by INSERT.
 *
 * Model
 *   - Every structural object the ooRexx adapter emits (METHOD, ATTRIBUTE*,
 *     CONSTANT, ROUTINE, REQUIRES, OPTIONS, CLASS header, EXECUTABLE_SECTION,
 *     unknown directive fragments) is its own ssc_source_object with its own
 *     revision chain.  A changed method body is one new revision of one method.
 *   - Object identity is language + module + logical path + semantic key.  The
 *     version-wrapped archive folder (pkg_v0.1-dev24/...) is not identity, so the
 *     same method in dev24 and dev25 is the same object.
 *   - Each file is a SOURCE_UNIT object.  Its revision text is the ordered member
 *     list (ordinal, object id, kind, name, prefix, suffix), not the code.  It
 *     changes only when members are added, removed or reordered.
 *   - Every import also records an immutable per-import projection
 *     (project_id "import:<import_id>") so the exact imported bytes can be
 *     rebuilt later, independent of what has been accepted since.
 *   - New revisions are PROPOSED.  Acceptance is explicit, per revision or per
 *     import, and requires an authorizer; with no authorizer it is denied.
 *   - Every new revision is read back and its SHA-256 compared before the member
 *     is marked IMPORTED.  A backend that alters bytes is refused, never trusted.
 *   - All ids are content-derived, and the member row is written last, so a
 *     repeated or interrupted import is safe to re-run.
 *
 * Interface: beginArchive / importArchiveMember / importResourceMember /
 * completeArchive / failArchive are exactly the client calls made by
 * SemanticSourceBulkImporter, so the existing importer drives this class directly.
 *
 * Hashing uses Crypto's .SHA256.  Install Crypto's Foreign Runtime provider at the
 * composition root (.CryptoForeignRuntimeInstaller~install); pure ooRexx SHA-256
 * is ~1.5 s per KB and unusable at method granularity.
 */

::class SemanticSourceRepositoryService public

::method init
  expose sql authorizer
  use strict arg sqlExecutor, authorizerObject = .nil
  if sqlExecutor == .nil then raise syntax 88.900 array("sqlExecutor is required")
  sql = sqlExecutor
  authorizer = authorizerObject

/* ------------------------------------------------------------------ import */

::method beginArchive
  expose sql
  use strict arg meta
  archiveSha = self~field(meta, "archive_sha256")
  archiveName = self~field(meta, "archive_filename")
  if archiveSha = "" then raise syntax 88.900 array("archive_sha256 is required")
  if archiveName = "" then raise syntax 88.900 array("archive_filename is required")
  importId = "imp_" || self~sha(archiveSha || "|" || archiveName)~left(24)
  existing = self~one("SELECT import_id,status FROM ssc_import_batch WHERE import_id=" || self~q(importId))
  if existing \== .nil then do
    self~exec("UPDATE ssc_import_batch SET status='OPEN' WHERE import_id=" || self~q(importId))
    return importId
  end
  sourceKind = self~field(meta, "source_kind")
  if sourceKind = "" then sourceKind = "zip"
  self~exec("INSERT INTO ssc_import_batch (import_id,source_kind,archive_filename,archive_sha256,imported_at,imported_by,parser_id,status) VALUES (" ||,
            self~q(importId) || "," || self~q(sourceKind) || "," || self~q(archiveName) || "," || self~q(archiveSha) || "," ||,
            self~q(self~now) || "," || self~q(self~field(meta, "imported_by")) || "," || self~q(self~field(meta, "parser_id")) || ",'OPEN')")
  return importId

::method importArchiveMember
  use strict arg request
  importId = self~field(request, "import_id")
  memberPath = self~field(request, "member_path")
  memberSha = self~field(request, "member_sha256")
  language = self~field(request, "language")
  if importId = "" | memberPath = "" | memberSha = "" | language = "" then
    raise syntax 88.900 array("import_id, member_path, member_sha256 and language are required")
  if \request~hasIndex("source_text") then raise syntax 88.900 array("source_text is required")
  sourceText = request["source_text"]
  actor = self~field(request, "imported_by")

  reply = .directory~new
  reply["member_path"] = memberPath
  memberId = "ssm_" || self~sha(importId || "|" || memberPath || "|" || memberSha)~left(32)
  previous = self~one("SELECT status,object_count FROM ssc_import_member WHERE import_member_id=" || self~q(memberId))
  if previous \== .nil then do
    if self~col(previous, "status") = "IMPORTED" then do
      reply["status"] = "ALREADY_IMPORTED"
      reply["object_count"] = self~col(previous, "object_count")
      return reply
    end
  end

  location = self~logicalLocation(request)
  moduleId = location["module_id"]
  logicalPath = location["logical_path"]

  -- Ordered (object, projection) pairs.  Structural graph when supplied,
  -- otherwise one whole-file object (e.g. Python before its adapter exists).
  members = .array~new
  if request~hasIndex("semantic_objects") & request~hasIndex("projection_members") then do
    byKey = .directory~new
    do o over request["semantic_objects"]
      if byKey~hasIndex(o["semantic_key"]) then do
        reply["status"] = "REJECTED"
        reply["error"] = "DUPLICATE_SEMANTIC_KEY " || o["semantic_key"]
        return reply
      end
      byKey[o["semantic_key"]] = o
    end
    rebuilt = ""
    lastOrdinal = 0
    do pm over request["projection_members"]
      if \byKey~hasIndex(pm["object_key"]) then raise syntax 88.900 array("projection member has no semantic object: " || pm["object_key"])
      if \datatype(pm["ordinal"], "W") then raise syntax 88.900 array("projection ordinal must be a whole number")
      if pm["ordinal"] <= lastOrdinal then raise syntax 88.900 array("projection ordinals must be strictly ascending in " || memberPath)
      lastOrdinal = pm["ordinal"]
      entry = .directory~new
      entry["object"] = byKey[pm["object_key"]]
      entry["ordinal"] = pm["ordinal"]
      entry["prefix"] = self~orEmpty(pm["prefix_text"])
      entry["suffix"] = self~orEmpty(pm["suffix_text"])
      entry["text"] = byKey[pm["object_key"]]["source_text"]
      rebuilt = rebuilt || entry["prefix"] || entry["text"] || entry["suffix"]
      members~append(entry)
    end
    if \(rebuilt == sourceText) then do
      reply["status"] = "REJECTED"
      reply["error"] = "PROJECTION_NOT_LOSSLESS"
      return reply
    end
    relations = request["relations"]
    if relations == .nil then relations = .array~new
  end
  else do
    o = .directory~new
    o["object_kind"] = "SOURCE_FILE"
    o["logical_name"] = logicalPath
    o["source_spelling"] = logicalPath
    o["runtime_spelling"] = logicalPath
    o["lookup_key"] = translate(logicalPath)
    o["semantic_key"] = "PACKAGE:" || memberPath || "/WHOLE_SOURCE"
    o["source_text"] = sourceText
    entry = .directory~new
    entry["object"] = o
    entry["ordinal"] = 1
    entry["prefix"] = ""
    entry["suffix"] = ""
    entry["text"] = sourceText
    members~append(entry)
    relations = .array~new
  end

  origin = .directory~new
  origin["import_id"] = importId
  origin["archive_filename"] = self~field(request, "archive_filename")
  origin["archive_sha256"] = self~field(request, "archive_sha256")
  origin["member_path"] = memberPath
  origin["actor"] = actor
  origin["logical_path"] = logicalPath

  newCount = 0
  reusedCount = 0
  layoutLines = .array~new
  keyToObjectId = .directory~new
  do entry over members
    o = entry["object"]
    logicalKey = self~rekey(o["semantic_key"], memberPath, logicalPath)
    objectId = "sso_" || self~sha(language || "|" || moduleId || "|" || logicalKey)~left(32)
    keyToObjectId[o["semantic_key"]] = objectId
    self~ensureObject(objectId, language, o, logicalKey, actor)
    rev = self~recordRevision(objectId, entry["text"], origin, logicalPath)
    if rev["new"] then newCount += 1
    else reusedCount += 1
    projectionId = "ssp_" || self~sha(importId || "|" || rev["revision_id"] || "|" || logicalPath || "|" || entry["ordinal"])~left(32)
    if self~one("SELECT projection_member_id FROM ssc_projection_member WHERE projection_member_id=" || self~q(projectionId)) == .nil then
      self~exec("INSERT INTO ssc_projection_member (projection_member_id,revision_id,project_id,relative_path,ordinal,prefix_text,suffix_text) VALUES (" ||,
                self~q(projectionId) || "," || self~q(rev["revision_id"]) || "," || self~q("import:" || importId) || "," ||,
                self~q(logicalPath) || "," || entry["ordinal"] || "," || self~q(entry["prefix"]) || "," || self~q(entry["suffix"]) || ")")
    layoutLines~append(entry["ordinal"] || "09"x || objectId || "09"x || self~orEmpty(o["object_kind"]) || "09"x ||,
                       self~orEmpty(o["source_spelling"]) || "09"x || c2x(entry["prefix"]) || "09"x || c2x(entry["suffix"]))
  end

  -- File layout: the SOURCE_UNIT object.
  layoutText = ""
  do line over layoutLines
    layoutText = layoutText || line || "0a"x
  end
  unitKey = "PACKAGE:" || logicalPath
  unitId = "sso_" || self~sha(language || "|" || moduleId || "|" || unitKey)~left(32)
  unitObject = .directory~new
  unitObject["object_kind"] = "SOURCE_UNIT"
  unitObject["logical_name"] = logicalPath
  unitObject["source_spelling"] = logicalPath
  unitObject["runtime_spelling"] = logicalPath
  unitObject["lookup_key"] = translate(logicalPath)
  self~ensureObject(unitId, language, unitObject, unitKey, actor)
  self~ensureSourceUnit(unitId, moduleId, language, logicalPath, actor)
  unitRev = self~recordRevision(unitId, layoutText, origin, logicalPath)
  if unitRev["new"] then do
    do entry over members
      memberObjectId = keyToObjectId[entry["object"]["semantic_key"]]
      self~addRelation(unitId, "DEPENDS_ON", memberObjectId, "CONTAINS " || entry["ordinal"], unitRev["revision_id"])
    end
    do r over relations
      if r["relation_kind"] = "REQUIRES" then
        self~addRelation(unitId, "IMPORTS", "", "REQUIRES:" || self~orEmpty(r["to_symbol"]), unitRev["revision_id"])
    end
  end
  layoutProjection = "ssp_" || self~sha(importId || "|layout|" || unitRev["revision_id"])~left(32)
  if self~one("SELECT projection_member_id FROM ssc_projection_member WHERE projection_member_id=" || self~q(layoutProjection)) == .nil then
    self~exec("INSERT INTO ssc_projection_member (projection_member_id,revision_id,project_id,relative_path,ordinal,prefix_text,suffix_text) VALUES (" ||,
              self~q(layoutProjection) || "," || self~q(unitRev["revision_id"]) || "," || self~q("import-layout:" || importId) || "," ||,
              self~q(logicalPath) || ",0,'','')")

  -- Written last: a crash before this line leaves the member re-runnable.
  if previous == .nil then
    self~exec("INSERT INTO ssc_import_member (import_member_id,import_id,member_path,member_sha256,language,status,object_count,error_text) VALUES (" ||,
              self~q(memberId) || "," || self~q(importId) || "," || self~q(memberPath) || "," || self~q(memberSha) || "," ||,
              self~q(language) || ",'IMPORTED'," || members~items || ",'')")
  else
    self~exec("UPDATE ssc_import_member SET status='IMPORTED', object_count=" || members~items || " WHERE import_member_id=" || self~q(memberId))

  reply["status"] = "IMPORTED"
  reply["object_count"] = members~items
  reply["new_revisions"] = newCount
  reply["reused_revisions"] = reusedCount
  reply["source_unit_object_id"] = unitId
  reply["source_unit_revision_id"] = unitRev["revision_id"]
  reply["module_id"] = moduleId
  reply["logical_path"] = logicalPath
  return reply

::method importResourceMember
  use strict arg request
  importId = self~field(request, "import_id")
  memberPath = self~field(request, "member_path")
  if importId = "" | memberPath = "" then raise syntax 88.900 array("import_id and member_path are required")
  content = self~orEmpty(request["content_text"])
  location = self~logicalLocation(request)
  resourceId = "res_" || self~sha(location["module_id"] || "|" || location["logical_path"])~left(32)
  actor = self~field(request, "imported_by")
  mime = self~field(request, "mime_type")
  if self~one("SELECT resource_id FROM ssc_resource_object WHERE resource_id=" || self~q(resourceId)) == .nil then
    self~exec("INSERT INTO ssc_resource_object (resource_id,logical_name,resource_kind,mime_type,description,created_at,created_by,accepted_revision_id) VALUES (" ||,
              self~q(resourceId) || "," || self~q(location["logical_path"]) || "," || self~q(self~field(request, "resource_kind")) || "," ||,
              self~q(mime) || ",''," || self~q(self~now) || "," || self~q(actor) || ",'')")
  contentSha = self~sha(content)
  latest = self~one("SELECT resource_revision_id,revision_no,content_sha256 FROM ssc_resource_revision WHERE resource_id=" || self~q(resourceId) ||,
                    " ORDER BY revision_no DESC")
  reply = .directory~new
  reply["resource_id"] = resourceId
  if latest \== .nil then if self~col(latest, "content_sha256") == contentSha then do
    reply["status"] = "ALREADY_IMPORTED"
    reply["resource_revision_id"] = self~col(latest, "resource_revision_id")
    return reply
  end
  revisionNo = 1
  parentId = ""
  if latest \== .nil then do
    revisionNo = self~col(latest, "revision_no") + 1
    parentId = self~col(latest, "resource_revision_id")
  end
  revisionId = "rsr_" || self~sha(resourceId || "|" || contentSha || "|" || parentId)~left(32)
  self~exec("INSERT INTO ssc_resource_revision (resource_revision_id,resource_id,parent_revision_id,revision_no,content_text,content_base64,content_sha256,mime_type,status,changed_at,changed_by,origin_archive_filename,origin_archive_sha256,origin_member_path,materialisation_path) VALUES (" ||,
            self~q(revisionId) || "," || self~q(resourceId) || "," || self~q(parentId) || "," || revisionNo || "," || self~q(content) || ",''," ||,
            self~q(contentSha) || "," || self~q(mime) || ",'PROPOSED'," || self~q(self~now) || "," || self~q(actor) || "," ||,
            self~q(self~field(request, "archive_filename")) || "," || self~q(self~field(request, "archive_sha256")) || "," ||,
            self~q(memberPath) || "," || self~q(location["logical_path"]) || ")")
  stored = self~one("SELECT content_text FROM ssc_resource_revision WHERE resource_revision_id=" || self~q(revisionId))
  if \(self~sha(self~orEmpty(self~col(stored, "content_text"))) == contentSha) then do
    self~exec("UPDATE ssc_resource_revision SET status='STORAGE_MISMATCH' WHERE resource_revision_id=" || self~q(revisionId))
    reply["status"] = "REJECTED"
    reply["error"] = "STORAGE_NOT_LOSSLESS"
    return reply
  end
  reply["status"] = "IMPORTED"
  reply["resource_revision_id"] = revisionId
  return reply

::method completeArchive
  use strict arg importId, summary = .nil
  self~resolveRequires
  self~exec("UPDATE ssc_import_batch SET status='COMPLETE' WHERE import_id=" || self~q(importId))
  return 1

::method failArchive
  use strict arg importId, summary = .nil
  self~exec("UPDATE ssc_import_batch SET status='FAILED' WHERE import_id=" || self~q(importId))
  return 1

/* -------------------------------------------------------------- decisions */

::method acceptRevision
  use strict arg revisionId, principal, reason = ""
  self~authorize(principal, "source.accept_revision", revisionId)
  rev = self~one("SELECT revision_id,object_id,status FROM ssc_source_revision WHERE revision_id=" || self~q(revisionId))
  if rev == .nil then raise syntax 88.900 array("unknown revision: " || revisionId)
  if self~col(rev, "status") = "STORAGE_MISMATCH" then raise syntax 88.900 array("revision failed storage verification and cannot be accepted: " || revisionId)
  objectId = self~col(rev, "object_id")
  obj = self~one("SELECT accepted_revision_id FROM ssc_source_object WHERE object_id=" || self~q(objectId))
  prior = self~orEmpty(self~col(obj, "accepted_revision_id"))
  if prior \= "" & prior \= revisionId then
    self~exec("UPDATE ssc_source_revision SET status='SUPERSEDED' WHERE revision_id=" || self~q(prior))
  self~exec("UPDATE ssc_source_revision SET status='ACCEPTED' WHERE revision_id=" || self~q(revisionId))
  self~recordDecision(objectId, revisionId, "ACCEPTED", principal, reason)
  self~exec("UPDATE ssc_source_object SET accepted_revision_id=" || self~q(revisionId) || " WHERE object_id=" || self~q(objectId))
  return 1

::method refuseRevision
  use strict arg revisionId, principal, reason = ""
  self~authorize(principal, "source.refuse_revision", revisionId)
  rev = self~one("SELECT revision_id,object_id,status FROM ssc_source_revision WHERE revision_id=" || self~q(revisionId))
  if rev == .nil then raise syntax 88.900 array("unknown revision: " || revisionId)
  if self~col(rev, "status") = "ACCEPTED" then raise syntax 88.900 array("an accepted revision is superseded by accepting another, not refused: " || revisionId)
  self~exec("UPDATE ssc_source_revision SET status='REFUSED' WHERE revision_id=" || self~q(revisionId))
  self~recordDecision(self~col(rev, "object_id"), revisionId, "REFUSED", principal, reason)
  return 1

/* Accept everything one import contained: each file layout and every member revision. */
::method acceptImport
  use strict arg importId, principal, reason = ""
  self~authorize(principal, "source.accept_import", importId)
  revisionIds = .array~new
  seen = .directory~new
  do row over self~rows("SELECT revision_id FROM ssc_projection_member WHERE project_id=" || self~q("import:" || importId) ||,
                        " OR project_id=" || self~q("import-layout:" || importId))
    id = self~col(row, "revision_id")
    if \seen~hasIndex(id) then do
      seen[id] = 1
      revisionIds~append(id)
    end
  end
  if revisionIds~items = 0 then raise syntax 88.900 array("import has no recorded revisions: " || importId)
  accepted = 0
  do id over revisionIds
    rev = self~one("SELECT status FROM ssc_source_revision WHERE revision_id=" || self~q(id))
    if self~col(rev, "status") = "ACCEPTED" then iterate
    self~acceptRevision(id, principal, reason)
    accepted += 1
  end
  out = .directory~new
  out["import_id"] = importId
  out["revisions"] = revisionIds~items
  out["newly_accepted"] = accepted
  return out

/* -------------------------------------------------------------- queries */

::method sourceUnitsFor
  use strict arg logicalPath, moduleId = ""
  sqlText = "SELECT source_unit_id,module_id FROM ssc_source_unit WHERE projection_path=" || self~q(logicalPath)
  if moduleId \= "" then sqlText = sqlText || " AND module_id=" || self~q(moduleId)
  out = .array~new
  do row over self~rows(sqlText)
    out~append(self~col(row, "source_unit_id"))
  end
  return out

::method history
  use strict arg objectId
  return self~rows("SELECT revision_id,revision_no,status,source_sha256,changed_at,changed_by,origin_import_id,origin_member_path FROM ssc_source_revision WHERE object_id=" ||,
                   self~q(objectId) || " ORDER BY revision_no")

::method objectsIn
  use strict arg sourceUnitObjectId
  obj = self~one("SELECT current_revision_id FROM ssc_source_object WHERE object_id=" || self~q(sourceUnitObjectId))
  if obj == .nil then return .array~new
  rev = self~one("SELECT source_text FROM ssc_source_revision WHERE revision_id=" || self~q(self~col(obj, "current_revision_id")))
  out = .array~new
  do line over self~orEmpty(self~col(rev, "source_text"))~makeArray("0a"x)
    if line = "" then iterate
    parse var line ordinal "09"x objectId "09"x kind "09"x name "09"x .
    d = .directory~new
    d["ordinal"] = ordinal
    d["object_id"] = objectId
    d["object_kind"] = kind
    d["name"] = name
    out~append(d)
  end
  return out

/* -------------------------------------------------------------- internals */

::method ensureObject private
  use strict arg objectId, language, o, logicalKey, actor
  if self~one("SELECT object_id FROM ssc_source_object WHERE object_id=" || self~q(objectId)) \== .nil then return
  self~exec("INSERT INTO ssc_source_object (object_id,language,object_kind,logical_name,source_spelling,runtime_spelling,lookup_key,semantic_key,description,created_at,created_by,current_revision_id,accepted_revision_id,design_document_id) VALUES (" ||,
            self~q(objectId) || "," || self~q(language) || "," || self~q(self~orEmpty(o["object_kind"])) || "," ||,
            self~q(self~orEmpty(o["logical_name"])) || "," || self~q(self~orEmpty(o["source_spelling"])) || "," ||,
            self~q(self~orEmpty(o["runtime_spelling"])) || "," || self~q(self~orEmpty(o["lookup_key"])) || "," ||,
            self~q(logicalKey) || ",''," || self~q(self~now) || "," || self~q(actor) || ",'','','')")

::method ensureSourceUnit private
  use strict arg unitId, moduleId, language, logicalPath, actor
  if self~one("SELECT source_unit_id FROM ssc_source_unit WHERE source_unit_id=" || self~q(unitId)) \== .nil then return
  extension = ""
  if logicalPath~lastPos(".") > 0 then extension = logicalPath~substr(logicalPath~lastPos(".") + 1)
  self~exec("INSERT INTO ssc_source_unit (source_unit_id,module_id,language,source_unit_kind,projection_path,projection_extension,executable_object_id,created_at,created_by) VALUES (" ||,
            self~q(unitId) || "," || self~q(moduleId) || "," || self~q(language) || ",'PACKAGE_SOURCE'," || self~q(logicalPath) || "," ||,
            self~q(extension) || ",''," || self~q(self~now) || "," || self~q(actor) || ")")

/* Returns Directory: revision_id, new (1/0). Reuses the current revision when bytes are identical. */
::method recordRevision private
  use strict arg objectId, text, origin, logicalPath
  textSha = self~sha(text)
  obj = self~one("SELECT current_revision_id FROM ssc_source_object WHERE object_id=" || self~q(objectId))
  currentId = self~orEmpty(self~col(obj, "current_revision_id"))
  out = .directory~new
  revisionNo = 1
  if currentId \= "" then do
    cur = self~one("SELECT revision_no,source_sha256 FROM ssc_source_revision WHERE revision_id=" || self~q(currentId))
    if self~col(cur, "source_sha256") == textSha then do
      out["revision_id"] = currentId
      out["new"] = 0
      return out
    end
    revisionNo = self~col(cur, "revision_no") + 1
  end
  revisionId = "ssr_" || self~sha(objectId || "|" || textSha || "|" || currentId)~left(32)
  if self~one("SELECT revision_id FROM ssc_source_revision WHERE revision_id=" || self~q(revisionId)) == .nil then
    self~exec("INSERT INTO ssc_source_revision (revision_id,object_id,parent_revision_id,revision_no,source_text,source_sha256,status,changed_at,changed_by,change_reason,origin_import_id,origin_archive_filename,origin_archive_sha256,origin_member_path,materialisation_path) VALUES (" ||,
              self~q(revisionId) || "," || self~q(objectId) || "," || self~q(currentId) || "," || revisionNo || "," || self~q(text) || "," ||,
              self~q(textSha) || ",'PROPOSED'," || self~q(self~now) || "," || self~q(origin["actor"]) || ",''," || self~q(origin["import_id"]) || "," ||,
              self~q(origin["archive_filename"]) || "," || self~q(origin["archive_sha256"]) || "," || self~q(origin["member_path"]) || "," ||,
              self~q(logicalPath) || ")")
  stored = self~one("SELECT source_text FROM ssc_source_revision WHERE revision_id=" || self~q(revisionId))
  if \(self~sha(self~orEmpty(self~col(stored, "source_text"))) == textSha) then do
    self~exec("UPDATE ssc_source_revision SET status='STORAGE_MISMATCH' WHERE revision_id=" || self~q(revisionId))
    raise syntax 88.900 array("STORAGE_NOT_LOSSLESS: backend altered revision bytes for " || origin["member_path"] || " (" || objectId || ")")
  end
  self~exec("UPDATE ssc_source_object SET current_revision_id=" || self~q(revisionId) || " WHERE object_id=" || self~q(objectId))
  out["revision_id"] = revisionId
  out["new"] = 1
  return out

/* Decisions are appended by INSERT (never UPDATE): free text must not pass through UPDATE.
 * NoSQLServer v0.79 evaluates quoted UPDATE literals as expressions ('3*4' is stored as 12). */
::method recordDecision private
  use strict arg objectId, revisionId, decision, principal, reason
  self~addRelation(objectId, "DECISION", "", decision || " by " || principal || " at " || self~now || ": " || reason, revisionId)

::method addRelation private
  use strict arg fromId, kind, toId, detail, revisionId
  relationId = "ssl_" || self~sha(fromId || "|" || kind || "|" || toId || "|" || detail || "|" || revisionId)~left(32)
  if self~one("SELECT relation_id FROM ssc_relation WHERE relation_id=" || self~q(relationId)) \== .nil then return
  self~exec("INSERT INTO ssc_relation (relation_id,from_object_id,relation_kind,to_object_id,detail,revision_id) VALUES (" ||,
            self~q(relationId) || "," || self~q(fromId) || "," || self~q(kind) || "," || self~q(toId) || "," || self~q(detail) || "," || self~q(revisionId) || ")")

/* ::requires "X.cls" between files of the same module becomes an IMPORTS edge to X's SOURCE_UNIT. */
::method resolveRequires private
  do row over self~rows("SELECT relation_id,from_object_id,detail FROM ssc_relation WHERE relation_kind='IMPORTS' AND to_object_id=''")
    detail = self~orEmpty(self~col(row, "detail"))
    if detail~left(9) \= "REQUIRES:" then iterate
    target = strip(strip(detail~substr(10)), "B", '"')
    target = strip(target, "B", "'")
    fromUnit = self~one("SELECT module_id,projection_path FROM ssc_source_unit WHERE source_unit_id=" || self~q(self~col(row, "from_object_id")))
    if fromUnit == .nil then iterate
    moduleId = self~col(fromUnit, "module_id")
    fromPath = self~col(fromUnit, "projection_path")
    directory = ""
    if fromPath~lastPos("/") > 0 then directory = fromPath~left(fromPath~lastPos("/"))
    match = ""
    do unit over self~rows("SELECT source_unit_id,projection_path FROM ssc_source_unit WHERE module_id=" || self~q(moduleId))
      path = self~col(unit, "projection_path")
      base = path
      if path~lastPos("/") > 0 then base = path~substr(path~lastPos("/") + 1)
      if path == directory || target then do
        match = self~col(unit, "source_unit_id")
        leave
      end
      if match = "" then if base~upper == target~upper then match = self~col(unit, "source_unit_id")
    end
    if match \= "" then
      self~exec("UPDATE ssc_relation SET to_object_id=" || self~q(match) || " WHERE relation_id=" || self~q(self~col(row, "relation_id")))
  end

/* Module and module-relative path. A leading "<name>_v<digit>..." folder is version packaging, not identity. */
::method logicalLocation private
  use strict arg request
  memberPath = self~field(request, "member_path")
  moduleId = self~field(request, "module_id")
  logicalPath = memberPath
  if memberPath~pos("/") > 0 then do
    first = memberPath~left(memberPath~pos("/") - 1)
    cut = self~versionCut(first)
    if cut > 0 then do
      if moduleId = "" then moduleId = first~left(cut - 1)
      logicalPath = memberPath~substr(memberPath~pos("/") + 1)
    end
  end
  if moduleId = "" then do
    stem = self~field(request, "archive_filename")
    if stem~lastPos(".") > 0 then stem = stem~left(stem~lastPos(".") - 1)
    cut = self~versionCut(stem)
    if cut > 0 then stem = stem~left(cut - 1)
    moduleId = stem
  end
  if moduleId = "" then moduleId = "<unassigned>"
  out = .directory~new
  out["module_id"] = moduleId
  out["logical_path"] = logicalPath
  return out

/* Position of "_v" followed by a digit (the version suffix), or 0. */
::method versionCut private
  use strict arg text
  p = 0
  do forever
    p = text~pos("_v", p + 1)
    if p = 0 then return 0
    if p + 2 <= text~length then if datatype(text~substr(p + 2, 1), "W") then return p
  end

::method rekey private
  use strict arg key, memberPath, logicalPath
  prefix = "PACKAGE:" || memberPath
  if key~left(prefix~length) == prefix then return "PACKAGE:" || logicalPath || key~substr(prefix~length + 1)
  return key

::method authorize private
  expose authorizer
  use strict arg principal, action, target
  if principal = "" then raise syntax 88.900 array("DENIED: " || action || " requires an authenticated principal")
  if authorizer == .nil then raise syntax 88.900 array("DENIED: no authorizer configured for " || action)
  if authorizer~authorize(principal, action, target) \== 1 then
    raise syntax 88.900 array("DENIED: " || principal || " may not " || action || " " || target)

::method sha private
  use strict arg text
  return .SHA256~new(text)~digest~lower

::method now private
  return .DateTime~new~isoDate

::method field private
  use strict arg d, name
  if \d~hasIndex(name) then return ""
  v = d[name]
  if v == .nil then return ""
  return v

::method orEmpty private
  use strict arg v
  if v == .nil then return ""
  return v

::method col private
  use strict arg row, name
  if row == .nil then return ""
  v = row[name]
  if v == .nil then v = row[name~upper]
  if v == .nil then return ""
  return v

::method q private
  use strict arg value
  return "'" || value~changestr("'", "''") || "'"

::method exec private
  expose sql
  use strict arg statement
  rs = sql~execute(statement)
  if rs~status \= "SUCCESS" then
    raise syntax 88.900 array("Semantic Source repository SQL failed: " || statement~left(240) || "; status=" || rs~status || "; " || rs~message)
  return rs

::method rows private
  use strict arg statement
  return self~exec(statement)~rows

::method one private
  use strict arg statement
  r = self~exec(statement)~rows
  if r~items = 0 then return .nil
  return r[1]

::requires "crypto.cls"
