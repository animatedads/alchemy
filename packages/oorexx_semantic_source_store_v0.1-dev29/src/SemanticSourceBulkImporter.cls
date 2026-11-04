/*
 * Semantic Source Control - systematic archive importer
 *
 * This class deliberately does NOT write the semantic-source database.
 * Every discovered source member is submitted through an injected sourceClient,
 * which is expected to implement the MCP import authority contract.
 *
 * Source client messages:
 *   beginArchive(metaDirectory) -> archive import id
 *   importArchiveMember(requestDirectory) -> result object/directory
 *   importResourceMember(requestDirectory) -> result object/directory
 *   completeArchive(importId, summaryDirectory)
 *   failArchive(importId, summaryDirectory)
 *
 * Archive reader messages:
 *   sha256(path)
 *   members(path) -> Array of relative member names
 *   readText(path, memberName) -> String
 *   memberSha256(path, memberName)
 */

::class SemanticSourceBulkImportReport public
::method init
  self~archivesSeen = 0
  self~archivesImported = 0
  self~archivesFailed = 0
  self~membersSeen = 0
  self~membersImported = 0
  self~membersSkipped = 0
  self~membersFailed = 0
  self~errors = .array~new
::attribute archivesSeen
::attribute archivesImported
::attribute archivesFailed
::attribute membersSeen
::attribute membersImported
::attribute membersSkipped
::attribute membersFailed
::attribute errors

::class SemanticSourceBulkImporter public

::method init
  use strict arg sourceClient, archiveReader, adapterRegistry = .nil
  if sourceClient == .nil then raise syntax 88.900 array("sourceClient is required")
  if archiveReader == .nil then raise syntax 88.900 array("archiveReader is required")
  self~sourceClient = sourceClient
  self~archiveReader = archiveReader
  if adapterRegistry == .nil then adapterRegistry = .SemanticSourceStructuralAdapterRegistry~new
  self~adapterRegistry = adapterRegistry

::attribute sourceClient get
::attribute sourceClient set private
::attribute archiveReader get
::attribute archiveReader set private
::attribute adapterRegistry get
::attribute adapterRegistry set private

/*
 * Import all ZIP archives below rootDirectory in deterministic filename order.
 *
 * recursive    1 = include subdirectories, 0 = root only
 * resume       1 = client may report already-imported members as SKIPPED
 * actor        provenance identity recorded by MCP
 * parserId     parser/version hint supplied to MCP
 */
::method importDirectory
  use strict arg rootDirectory, recursive = 1, resume = 1, actor = "codex", parserId = "auto"

  if rootDirectory = "" then raise syntax 88.900 array("rootDirectory must not be empty")

  archives = self~discoverArchives(rootDirectory, recursive)
  report = .SemanticSourceBulkImportReport~new

  do archivePath over archives
    report~archivesSeen += 1
    ok = self~importArchive(archivePath, resume, actor, parserId, report)
    if ok then report~archivesImported += 1
    else report~archivesFailed += 1
  end

  return report

::method importArchive
  use strict arg archivePath, resume = 1, actor = "codex", parserId = "auto", report = .nil
  if report == .nil then report = .SemanticSourceBulkImportReport~new

  archiveSha = self~archiveReader~sha256(archivePath)
  archiveName = self~baseName(archivePath)

  meta = .directory~new
  meta["source_kind"] = "zip"
  meta["archive_path"] = archivePath
  meta["archive_filename"] = archiveName
  meta["archive_sha256"] = archiveSha
  meta["imported_by"] = actor
  meta["parser_id"] = parserId
  meta["resume"] = resume

  importId = ""
  signal on syntax name archiveFailure

  importId = self~sourceClient~beginArchive(meta)
  members = self~sortedCopy(self~archiveReader~members(archivePath))

  do member over members
    report~membersSeen += 1

    language = self~languageFor(member)
    resourceKind = self~resourceKindFor(member)
    if language = "" & resourceKind = "" then do
      report~membersSkipped += 1
      iterate
    end

    if language \= "" then result = self~importOneMember(archivePath, archiveName, archiveSha, importId, member, language, resume, actor, parserId)
    else result = self~importOneResource(archivePath, archiveName, archiveSha, importId, member, resourceKind, resume, actor)
    if result["ok"] then do
      status = result["status"]
      select
        when status = "IMPORTED" | status = "UPDATED" | status = "CREATED" then report~membersImported += 1
        when status = "SKIPPED" | status = "ALREADY_IMPORTED" then report~membersSkipped += 1
        otherwise report~membersImported += 1
      end
    end
    else do
      report~membersFailed += 1
      report~errors~append(archiveName || "!" || member || ": " || result["error"])
    end
  end

  summary = self~summaryDirectory(report, archiveName, archiveSha)
  self~sourceClient~completeArchive(importId, summary)
  signal off syntax
  return 1

archiveFailure:
  signal off syntax
  report~errors~append(archiveName || ": " || condition("D"))
  if importId \= "" then do
    summary = self~summaryDirectory(report, archiveName, archiveSha)
    self~sourceClient~failArchive(importId, summary)
  end
  return 0

::method importOneMember private
  use strict arg archivePath, archiveName, archiveSha, importId, member, language, resume, actor, parserId

  outcome = .directory~new
  outcome["ok"] = 0
  signal on syntax name memberFailure

  request = .directory~new
  request["import_id"] = importId
  request["source_kind"] = "zip"
  request["archive_filename"] = archiveName
  request["archive_sha256"] = archiveSha
  request["member_path"] = member
  request["member_sha256"] = self~archiveReader~memberSha256(archivePath, member)
  request["language"] = language
  request["parser_id"] = parserId
  request["imported_by"] = actor
  request["resume"] = resume
  sourceText = self~archiveReader~readText(archivePath, member)
  -- Full member text remains immutable carrier/provenance evidence, but is not
  -- the semantic authority when a structural adapter is available.
  request["source_text"] = sourceText
  request["semantic_source_authority"] = "STRUCTURAL_GRAPH"
  adapter = self~adapterRegistry~adapterFor(language)
  if adapter \= .nil then do
    graph = adapter~parse(sourceText, member, "")
    if graph~reconstruct \= sourceText then raise syntax 88.900 array("structural adapter failed lossless reconstruction: " || member)
    request["source_unit"] = graph~sourceUnit
    request["semantic_objects"] = graph~objects
    request["projection_members"] = graph~projectionMembers
    request["relations"] = graph~relations
    request["lossless_reconstruction_verified"] = 1
  end
  else request["semantic_source_authority"] = "WHOLE_SOURCE_FALLBACK"
  select
    when language = "oorexx" then do
      request["semantic_granularity"] = "method"
      request["language_adapter_id"] = "oorexx-structural-v4"
      request["source_unit_kind"] = "PACKAGE_SOURCE"
    end
    when language = "java" then do
      request["semantic_granularity"] = "member"
      request["language_adapter_id"] = "java-structural-v2"
      request["source_unit_kind"] = "COMPILATION_UNIT"
    end
    when language = "cpp" then do
      request["semantic_granularity"] = "member"
      request["language_adapter_id"] = "cpp-structural-v1"
      request["source_unit_kind"] = "TRANSLATION_UNIT"
    end
    when language = "rust" then do
      request["semantic_granularity"] = "item"
      request["language_adapter_id"] = "rust-structural-v1"
      request["source_unit_kind"] = "RUST_SOURCE_UNIT"
    end
    otherwise nop
  end

  result = self~sourceClient~importArchiveMember(request)
  outcome["ok"] = 1
  outcome["status"] = self~resultStatus(result)
  signal off syntax
  return outcome

memberFailure:
  signal off syntax
  outcome["error"] = condition("D")
  return outcome

::method importOneResource private
  use strict arg archivePath, archiveName, archiveSha, importId, member, resourceKind, resume, actor
  outcome = .directory~new
  outcome["ok"] = 0
  signal on syntax name resourceFailure
  request = .directory~new
  request["import_id"] = importId
  request["source_kind"] = "zip"
  request["archive_filename"] = archiveName
  request["archive_sha256"] = archiveSha
  request["member_path"] = member
  request["member_sha256"] = self~archiveReader~memberSha256(archivePath, member)
  request["resource_kind"] = resourceKind
  request["mime_type"] = self~mimeTypeFor(member)
  request["imported_by"] = actor
  request["resume"] = resume
  request["content_text"] = self~archiveReader~readText(archivePath, member)
  resourceResult = self~sourceClient~importResourceMember(request)
  outcome["ok"] = 1
  outcome["status"] = self~resultStatus(resourceResult)
  signal off syntax
  return outcome
resourceFailure:
  signal off syntax
  outcome["error"] = condition("D")
  return outcome

::method resourceKindFor private
  use strict arg member
  lower = member~lower
  if lower~right(5) = ".json" then return "JSON"
  if lower~right(7) = ".schema" then return "SCHEMA"
  if lower~right(4) = ".sql" then return "SQL"
  if lower~right(3) = ".md" then return "DOCUMENTATION"
  if lower~right(4) = ".txt" then return "TEXT"
  if lower~right(4) = ".csv" then return "DATA"
  if lower~right(4) = ".xml" then return "XML"
  if lower~right(5) = ".yaml" then return "YAML"
  if lower~right(4) = ".yml" then return "YAML"
  return ""

::method mimeTypeFor private
  use strict arg member
  lower = member~lower
  if lower~right(5) = ".json" then return "application/json"
  if lower~right(4) = ".sql" then return "application/sql"
  if lower~right(3) = ".md" then return "text/markdown"
  if lower~right(4) = ".csv" then return "text/csv"
  if lower~right(4) = ".xml" then return "application/xml"
  if lower~right(5) = ".yaml" | lower~right(4) = ".yml" then return "application/yaml"
  return "text/plain"

::method discoverArchives
  use strict arg rootDirectory, recursive = 1

  stem. = ""
  if recursive then options = "FOS"
  else options = "FO"
  call SysFileTree rootDirectory || "/" || "*.zip", "stem.", options

  archives = .array~new
  do i = 1 to stem.0
    archives~append(stem.i)
  end
  return self~sortedCopy(archives)

::method languageFor private
  use strict arg member
  lower = member~lower
  if lower~right(4) = ".cls" then return "oorexx"
  if lower~right(4) = ".rex" then return "oorexx"
  if lower~right(5) = ".java" then return "java"
  if lower~right(4) = ".cpp" | lower~right(3) = ".cc" | lower~right(4) = ".cxx" | lower~right(4) = ".c++" then return "cpp"
  if lower~right(4) = ".hpp" | lower~right(3) = ".hh" | lower~right(4) = ".hxx" | lower~right(2) = ".h" then return "cpp"
  if lower~right(3) = ".rs" then return "rust"
  if lower~right(3) = ".py" then return "python"
  return ""

::method resultStatus private
  use strict arg result
  if result == .nil then return ""
  if result~isA(.Directory) then do
    if result~hasIndex("status") then return result["status"]~upper
  end
  return ""

::method summaryDirectory private
  use strict arg report, archiveName, archiveSha
  d = .directory~new
  d["archive_filename"] = archiveName
  d["archive_sha256"] = archiveSha
  d["members_seen"] = report~membersSeen
  d["members_imported"] = report~membersImported
  d["members_skipped"] = report~membersSkipped
  d["members_failed"] = report~membersFailed
  return d

::method sortedCopy private
  use strict arg input
  work = .array~new
  do item over input
    work~append(item)
  end
  /* deterministic insertion sort avoids relying on optional collection helpers */
  do i = 2 to work~items
    key = work[i]
    j = i - 1
    do while j >= 1
      if work[j] <= key then leave
      work[j + 1] = work[j]
      j -= 1
    end
    work[j + 1] = key
  end
  return work

::method baseName private
  use strict arg path
  normalized = path~changestr("\\", "/")
  p = normalized~lastpos("/")
  if p = 0 then return normalized
  return normalized~substr(p + 1)


/*
 * CommandZipArchiveReader
 *
 * Portable-enough Linux adapter for Codex/CI environments.  It uses the system
 * `unzip` and `sha256sum` commands only for archive mechanics; semantic parsing
 * and persistence remain behind the MCP sourceClient.
 */
::class CommandZipArchiveReader public
::method init
  expose sequence
  sequence = 0

::method sha256
  use strict arg path
  tmp = self~tempName("sha")
  address command "sha256sum" self~shellQuote(path) ">" self~shellQuote(tmp)
  if rc \= 0 then raise syntax 88.900 array("sha256sum failed for " || path)
  line = linein(tmp)
  call stream tmp, "C", "CLOSE"
  call SysFileDelete tmp
  parse var line hash .
  return hash

::method members
  use strict arg path
  tmp = self~tempName("members")
  address command "unzip -Z1" self~shellQuote(path) ">" self~shellQuote(tmp)
  if rc \= 0 then raise syntax 88.900 array("cannot list zip " || path)
  members = .array~new
  s = .stream~new(tmp)
  s~open("READ")
  do while s~lines > 0
    member = s~linein
    if member \= "" & member~right(1) \= "/" then members~append(member)
  end
  s~close
  call SysFileDelete tmp
  return members

::method readText
  use strict arg path, member
  tmp = self~extractMember(path, member)
  s = .stream~new(tmp)
  s~open("READ BINARY")
  count = s~chars
  if count > 0 then text = s~charin(, count)
  else text = ""
  s~close
  call SysFileDelete tmp
  return text

::method memberSha256
  use strict arg path, member
  tmp = self~extractMember(path, member)
  hash = self~sha256(tmp)
  call SysFileDelete tmp
  return hash

::method extractMember private
  use strict arg path, member
  tmp = self~tempName("member")
  address command "unzip -p" self~shellQuote(path) self~shellQuote(member) ">" self~shellQuote(tmp)
  if rc \= 0 then do
    call SysFileDelete tmp
    raise syntax 88.900 array("cannot extract " || member || " from " || path)
  end
  return tmp

::method tempName private
  expose sequence
  use strict arg kind
  sequence += 1
  return "/tmp/ssc-import-" || kind || "-" || time("S") || "-" || sequence || ".tmp"

::method shellQuote private
  use strict arg value
  /* POSIX single-quote escaping: ' -> '\'' */
  return "'" || value~changestr("'", "'\\''") || "'"

::requires "SemanticSourceStructuralAdapterRegistry.cls"
