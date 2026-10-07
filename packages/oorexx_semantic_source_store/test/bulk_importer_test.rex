root = directory() || "/fixtures"
client = .FakeSourceClient~new
reader = .CommandZipArchiveReader~new
imp = .SemanticSourceBulkImporter~new(client, reader)
report = imp~importDirectory(root, 1, 1, "codex", "test-parser")
call assert report~archivesSeen = 2, "two archives seen"
call assert report~archivesImported = 2, "two archives imported"
call assert report~archivesFailed = 0, "no archive failures"
call assert report~membersSeen = 4, "four non-directory members seen"
call assert report~membersImported = 4, "three code members and one resource imported"
call assert report~membersSkipped = 0, "supported resource imported"
call assert report~membersFailed = 0, "no source member failures"
call assert client~begins~items = 2, "two begin calls"
call assert client~members~items = 3, "three code member calls"
call assert client~resources~items = 1, "one resource member call"
call assert client~begins[1]["archive_filename"] = "family.zip", "original filename kept"
call assert client~begins[2]["archive_filename"] = "family.zip", "collision filename kept"
call assert client~begins[1]["archive_sha256"] \= client~begins[2]["archive_sha256"], "same name distinct hashes"
call assert client~members[1]["member_sha256"] \= "", "member hash supplied"
call assert client~members[1]["source_text"]~pos("::class Family") > 0, "source bytes supplied"
call assert client~members[1]["semantic_granularity"] = "method", "ooRexx import requests method granularity"
call assert client~members[1]["semantic_source_authority"] = "STRUCTURAL_GRAPH", "structural graph is semantic authority"
call assert client~members[1]["lossless_reconstruction_verified"] = 1, "lossless structural reconstruction verified"
call assert client~members[1]["semantic_objects"]~items > 1, "source member decomposed into semantic objects"
call assert client~members[1]["projection_members"]~items = client~members[1]["semantic_objects"]~items, "projection covers every semantic object"
call assert client~resources[1]["mime_type"] = "text/markdown", "resource MIME supplied"
say "BULK IMPORTER TEST: PASS"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class FakeSourceClient
::method init
  self~begins = .array~new
  self~members = .array~new
  self~resources = .array~new
  self~completes = .array~new
::attribute begins
::attribute members
::attribute resources
::attribute completes
::method beginArchive
  use strict arg meta
  self~begins~append(meta)
  return "imp-" || self~begins~items
::method importArchiveMember
  use strict arg request
  self~members~append(request)
  d = .directory~new
  d["status"] = "IMPORTED"
  return d
::method importResourceMember
  use strict arg request
  self~resources~append(request)
  d = .directory~new
  d["status"] = "IMPORTED"
  return d
::method completeArchive
  use strict arg importId, summary
  d = .directory~new
  d["import_id"] = importId
  d["summary"] = summary
  self~completes~append(d)
  return 1
::method failArchive
  use strict arg importId, summary
  return 1

::requires '../src/SemanticSourceBulkImporter.cls'
