/* RcArchiveEvidence -- verify the historical Windows RC development archives.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14, porting
 * tools/verify_release_archives.py (ChatGPT) to ooRexx.
 *
 * Per version: the archive is present, is a valid ZIP whose every member
 * passes its CRC-32 and size check, contains the required members, and has
 * the SHA-256 recorded in the sphere (SPHERE_RC_EXECUTABLE_TREE.md,
 * 2026-10-29 table).  The Python tool computed the hash but never compared
 * it; this one does, so its schema is /2.
 *
 * Archive integrity only: never compiler, semantic or corpus qualification.
 */
pk = filespec("location", .context~package~name)"../../"
-- oorexx_archive finds Compress.cls by search path; give it oorexx-compress (module level 5 >= 4).
call value "REXX_PATH", pk"oorexx_compress_v0.1-dev5/src:" || value("REXX_PATH",, "ENVIRONMENT"), "ENVIRONMENT"
.context~package~loadPackage(pk"oorexx_archive_v0.1-dev1/src/Archive.cls")

::options digits 12

::class RcArchiveEvidence public
::constant SCHEMA "alchemy.rc.historical-archive-evidence/2"

::method init
  expose log required
  log = .LogNullLogger~instance
  required = .array~new
  call add "v9",  "oorexx_executable_ui_tree_v9.zip", -
    "9843d0b6b5c77b9cecf586315a21e426602bb542603d7ef2e80d8bb1de0275d8", -
    "RcExecutableTree.cls test.rex test_append.rex test_reject.rex"
  call add "v10", "oorexx_rc_windows_first_v10.zip", -
    "4c987a9dbf646bca074b22862d4abb2e9d5572fcca7475e2d3be25b50d7de7b9", -
    "RcExecutableTree.cls RcRendererProjection.cls test_projection.rex"
  call add "v11", "oorexx_windows_rc_v11.zip", -
    "b3019b6142cd65e631efa5ca6fbe38865358f96a1b770e8dd7f197f7c06c31c9", -
    "rc_to_json_v11.rex test_v11.py"
  call add "v12", "oorexx_windows_rc_corpus_v12.zip", -
    "ce14d03a1afb976a71b4dc72fb8620142bf2f19f42e4471776f9f0b4a40e7ea1", -
    "corpus_runner.py base/rc_to_json_v11.rex"
  call add "v13", "oorexx_windows_rc_source_gate_v13.zip", -
    "0f91f97161f320bdc902ccad8c81cd77db05bb41fff583a730804d57b83d1e01", -
    "source_gate.py test_gate.py"
  call add "v14", "oorexx_windows_rc_qualification_v14.zip", -
    "69d2d1ff4c4f530b5d1b08dd19758e090b97d64c205ecdbba30511478dfb08ac", -
    "semantic_audit.py source_gate.py base/rc_to_json_v11.rex"
  return
add:
  use strict arg version, file, sha, members
  required~append(.array~of(version, file, sha, members))
  return

::method useLogger public
  expose log
  use strict arg log
  return self

/* Replace the manifest (tests use their own archives). Array of
 * (version, filename, sha256 or "", "member member ...") */
::method useManifest public
  expose required
  use strict arg required
  return self

::method run public
  expose log required
  use strict arg folder
  folder = strip(folder, "T", "/")
  versions = .directory~new
  allOk = .true
  do r over required
    log~log(.Log~INFO, "checking" r[1] r[2])
    res = self~inspect(folder, r[2], r[3], r[4])
    versions[r[1]] = res
    if res["ok"]~value then log~log(.Log~INFO, r[1] "ok")
    else do
      allOk = .false
      log~log(.Log~WARN, r[1] "NOT verified:" self~why(res))
    end
  end
  report = .directory~new
  report["schema"] = self~SCHEMA
  report["qualification"] = "archive-integrity-only; not compiler/semantic compatibility"
  report["all_verified"] = .JsonBoolean~of(allOk)
  report["versions"] = versions
  log~log(.Log~INFO, "all_verified" allOk)
  return report

::method inspect public
  expose log
  use strict arg folder, filename, expectedSha, members
  res = .directory~new
  res["name"] = .JsonString~new(filename)
  res["required"] = jsonStrings(members~makeArray(" "))
  path = folder"/"filename
  present = sysFileExists(path) & \sysIsFileDirectory(path)
  res["present"] = .JsonBoolean~of(present)
  if \present then do
    res["ok"] = .JsonBoolean~false
    return res
  end
  s = .stream~new(path)
  s~open("read")
  blob = s~charIn(1, s~chars)
  s~close
  log~log(.Log~INFO, "  hashing" blob~length "bytes")
  digest = .SHA256~new(blob)~digest
  res["sha256"] = .JsonString~new(digest)
  res["bytes"] = blob~length
  if expectedSha \== "" then do
    res["sha256_expected"] = .JsonString~new(expectedSha)
    res["sha256_matches"] = .JsonBoolean~of(digest == expectedSha)
  end
  signal on syntax name badZip
  archive = .ZipArchive~fromBytes(blob, 10000, 536870912, 1073741824)
  names = .set~new
  bad = .nil
  do e over archive~entries
    if e~isDirectory then iterate
    names~put(e~name)
    if bad == .nil then if \self~memberOk(archive, e) then bad = e~name
  end
  signal off syntax
  missing = .array~new
  do m over members~makeArray(" ")
    if \names~hasIndex(m) then missing~append(.JsonString~new(m))
  end
  res["missing_members"] = missing
  if bad == .nil then res["bad_member"] = .nil
  else res["bad_member"] = .JsonString~new(bad)
  ok = (bad == .nil & missing~items == 0)
  if expectedSha \== "" then ok = ok & (digest == expectedSha)
  res["ok"] = .JsonBoolean~of(ok)
  return res
badZip:
  res["ok"] = .JsonBoolean~false
  res["error"] = .JsonString~new(condition("O")~message)
  return res

/* CRC-32 and size check of one member (what Python's testzip() does) */
::method memberOk private
  use strict arg archive, entry
  signal on syntax name failed
  bytes = archive~extractBytes(entry)
  return .true
failed:
  return .false

::method why private
  use strict arg r
  if \r["present"]~value then return "archive not present"
  if r~hasIndex("error") then return "not a valid ZIP:" r["error"]
  out = ""
  if r~hasIndex("sha256_matches") then if \r["sha256_matches"]~value then out = out "SHA-256 differs from the sphere record;"
  if r["bad_member"] \== .nil then out = out "member fails CRC/size:" r["bad_member"]";"
  if r["missing_members"]~items > 0 then out = out "missing members:" r["missing_members"]~makeString("L", " ")";"
  return out~strip

::routine jsonStrings
  use strict arg a
  out = .array~new
  do x over a
    if x \== "" then out~append(.JsonString~new(x))
  end
  return out

::requires "../../oorexx_crypto_v0.8.3/src/crypto.cls"
::requires "../../oorexx_logging_v0.7/src/LoggingCore.cls"
::requires "json.cls"
