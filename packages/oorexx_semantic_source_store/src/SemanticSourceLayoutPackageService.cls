/*
 * Semantic Source Control - layout-driven package materialisation.
 *
 * Author: Claude (Opus 5.5), 2026-10-23.  Architecture: Tom Dyer.
 *
 * SemanticSourcePackageService resolves the dependency closure correctly, but
 * assembles files in the iteration order of resolved~allIndexes, which is an
 * unordered .Directory; ordinals are honoured only inside one revision.  A file
 * held as many method objects therefore comes back in arbitrary order.
 *
 * This subclass keeps closure, pins, manifest and resources exactly as they are
 * and replaces only file assembly:
 *   - project "default": every resolved SOURCE_UNIT revision (written by
 *     SemanticSourceRepositoryService) is an ordered member list; the file is the
 *     concatenation, in ordinal order, of each member's resolved revision text
 *     (accepted, or pinned) with its recorded prefix/suffix.  A changed method is
 *     picked up without touching the layout.
 *   - any other project (e.g. "import:<id>", the exact record of one import):
 *     projection rows, sorted by path then numeric ordinal.
 */

::class SemanticSourceLayoutPackageService subclass SemanticSourcePackageService public

::method materialiseResolved private
  use strict arg package, resolved, projectId
  objectIds = resolved~allIndexes
  if objectIds~items = 0 then return

  kinds = .directory~new
  do row over self~queryRows("SELECT object_id,object_kind FROM ssc_source_object WHERE object_id IN (" || self~quotedList(objectIds) || ")")
    kinds[self~cell(row, "object_id")] = self~cell(row, "object_kind")
  end

  consumed = .directory~new
  if projectId = "default" then do
    do objectId over objectIds
      if kinds[objectId] \= "SOURCE_UNIT" then iterate
      consumed[objectId] = 1
      revision = resolved[objectId]
      path = revision["materialisation_path"]
      if path == .nil | path = "" then raise syntax 88.900 array("source unit has no materialisation path: " || objectId)
      lines = .array~new
      do line over self~orBlank(revision["source_text"])~makeArray("0a"x)
        if line \= "" then lines~append(line)
      end
      byOrdinal = .table~new
      do line over lines
        parse var line ordinal "09"x memberId "09"x . "09"x . "09"x prefixHex "09"x suffixHex
        if \resolved~hasIndex(memberId) then raise syntax 88.900 array("layout member not resolved (not accepted and not pinned): " || memberId || " in " || path)
        entry = .directory~new
        entry["id"] = memberId
        entry["prefix"] = x2c(prefixHex)
        entry["suffix"] = x2c(suffixHex)
        byOrdinal[format(ordinal)] = entry
        consumed[memberId] = 1
      end
      text = ""
      do ordinal over byOrdinal~allIndexes~sortWith(.NumericComparator~new)
        entry = byOrdinal[ordinal]
        text = text || entry["prefix"] || resolved[entry["id"]]["source_text"] || entry["suffix"]
      end
      package~files[path] = text
    end
  end
  else do objectId over objectIds
    if kinds[objectId] = "SOURCE_UNIT" then consumed[objectId] = 1
  end

  -- Everything not assembled by a layout: projection rows, sorted by path and ordinal.
  remaining = .array~new
  do objectId over objectIds
    if \consumed~hasIndex(objectId) then remaining~append(objectId)
  end
  if remaining~items = 0 then return
  revisionIds = .array~new
  revisionById = .directory~new
  do objectId over remaining
    revision = resolved[objectId]
    revisionIds~append(revision["revision_id"])
    revisionById[revision["revision_id"]] = revision
  end
  byPath = .directory~new
  covered = .directory~new
  do row over self~queryRows("SELECT revision_id,relative_path,ordinal,prefix_text,suffix_text FROM ssc_projection_member WHERE project_id=" ||,
                             self~q(projectId) || " AND revision_id IN (" || self~quotedList(revisionIds) || ")")
    path = self~cell(row, "relative_path")
    if \byPath~hasIndex(path) then byPath[path] = .table~new
    entry = .directory~new
    entry["revision_id"] = self~cell(row, "revision_id")
    entry["prefix"] = self~orBlank(self~cell(row, "prefix_text"))
    entry["suffix"] = self~orBlank(self~cell(row, "suffix_text"))
    byPath[path][format(self~cell(row, "ordinal"))] = entry
    covered[entry["revision_id"]] = 1
  end
  do path over byPath~allIndexes
    text = ""
    t = byPath[path]
    do ordinal over t~allIndexes~sortWith(.NumericComparator~new)
      entry = t[ordinal]
      text = text || entry["prefix"] || revisionById[entry["revision_id"]]["source_text"] || entry["suffix"]
    end
    package~files[path] = text
  end
  do revisionId over revisionIds
    if covered~hasIndex(revisionId) then iterate
    revision = revisionById[revisionId]
    path = revision["materialisation_path"]
    if path == .nil | path = "" then raise syntax 88.900 array("no materialisation path for revision " || revisionId)
    if package~files~hasIndex(path) then package~files[path] = package~files[path] || revision["source_text"]
    else package~files[path] = revision["source_text"]
  end

/* Identical to the parent's loadRevisionBatch except for one variable name.
 * The parent stores its answer in a variable called RESULT, then runs the bare
 * message instruction  unpinned~append(objectId) , which sets RESULT to the
 * returned index (1).  Its "latest accepted" path therefore always failed with
 * Error 97 ("1" does not understand "[]=").  Proven on r13196. */
::method loadRevisionBatch private
  use strict arg objectIds, pins
  byObject = .directory~new
  unpinned = .array~new
  pinnedRevisionIds = .array~new

  do objectId over objectIds
    if pins~hasIndex(objectId) then do
      revisionId = pins[objectId]
      if revisionId = "" then raise syntax 88.900 array("empty revision pin for " || objectId)
      pinnedRevisionIds~append(revisionId)
    end
    else unpinned~append(objectId)
  end

  columns = "r.revision_id,r.object_id,r.revision_no,r.source_text,r.source_sha256," ||,
            "r.origin_archive_filename,r.origin_archive_sha256,r.origin_member_path,r.materialisation_path"
  if unpinned~items > 0 then do
    statement = "SELECT " || columns || " FROM ssc_source_object o JOIN ssc_source_revision r " ||,
                "ON r.object_id=o.object_id AND r.revision_id=o.accepted_revision_id " ||,
                "WHERE o.object_id IN (" || self~quotedList(unpinned) || ")"
    do row over self~queryRows(statement)
      byObject[self~cell(row, "object_id")] = row
    end
  end

  if pinnedRevisionIds~items > 0 then do
    statement = "SELECT " || columns || " FROM ssc_source_revision r WHERE r.revision_id IN (" || self~quotedList(pinnedRevisionIds) || ")"
    do row over self~queryRows(statement)
      objectId = self~cell(row, "object_id")
      if pins~hasIndex(objectId) then if pins[objectId] = self~cell(row, "revision_id") then byObject[objectId] = row
    end
  end
  return byObject

::method cell private
  use strict arg row, name
  v = row[name]
  if v == .nil then v = row[name~upper]
  return v

::method orBlank private
  use strict arg v
  if v == .nil then return ""
  return v

::method q private
  use strict arg value
  return "'" || value~changestr("'", "''") || "'"

::requires "SemanticSourcePackageService.cls"
