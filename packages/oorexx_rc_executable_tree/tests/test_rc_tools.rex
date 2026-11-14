/* test_rc_tools.rex -- acceptance for the ooRexx corpus inventory and
 * archive evidence tools (replacing tests/test_corpus_inventory.py).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 * Fixtures are written into a fresh temporary directory; ZIPs are made with
 * the estate's own ZipWriter.
 */
base = value("TMPDIR",, "ENVIRONMENT")
if base == "" then base = "/tmp"
base = base"/rc_tools_test_"date("S")time("S")random(1, 99999)
call mkdirs base
passed = 0; failed = 0
inv = .RcCorpusInventory~new

/* ---- corpus inventory: the three Python tests, then more ---------------- */
root = base"/missing"; call mkdirs root
call put root"/files.txt", "samples/example.rc"
r = inv~run(root, root"/files.txt")
call check r["files"][1]["status"] == "missing", "missing file is reported missing"
call check \inv~passed(r), "a missing file fails the inventory"

root = base"/noinclude"; call mkdirs root"/samples"
call put root"/samples/example.rc", '#include "resource.h"', "IDD_TEST DIALOGEX 0,0,20,20"
call put root"/files.txt", "samples/example.rc"
r = inv~run(root, root"/files.txt")
f = r["files"][1]
call check f["status"] == "incomplete_includes", "missing quoted include -> incomplete_includes"
call check f["missing_local_includes"]~items == 1 & f["missing_local_includes"][1] == "resource.h", "names the missing include"

root = base"/complete"; call mkdirs root"/samples"
call put root"/samples/resource.h", "#define IDD_TEST 100"
call put root"/samples/example.rc", '#include "resource.h"', "IDD_TEST DIALOGEX 0,0,20,20"
call put root"/files.txt", "samples/example.rc"
r = inv~run(root, root"/files.txt")
f = r["files"][1]
call check f["status"] == "present", "complete source is present"
call check f["resource_kind_counts_heuristic"]["DIALOGEX"] == 1, "DIALOGEX counted"
call check f["sha256"]~length == 64, "SHA-256 recorded"
call check inv~passed(r), "complete corpus passes"

root = base"/kinds"; call mkdirs root"/s"
call put root"/s/k.rc", "EFBBBF"x || '  #  INCLUDE "sub\inc.h"', "1 MENU", "IDR_X menuex", "100 ICON ""a.ico""", -
  "IDD_A   DIALOG 0,0,1,1", "  STRINGTABLE", "#define X DIALOG", "9x DIALOG", "IDD_B DIALOGEXTRA", ""
call put root"/s/sub/inc.h", ""
call put root"/files.txt", "# comment", "", "s/k.rc"
r = inv~run(root, root"/files.txt")
f = r["files"][1]
k = f["resource_kind_counts_heuristic"]
call check f["status"] == "present", "backslash include resolved as a path"
call check k["MENU"] == 1 & k["MENUEX"] == 1 & k["ICON"] == 1 & k["DIALOG"] == 1, "kinds counted case-insensitively"
call check \k~hasIndex("STRINGTABLE") & \k~hasIndex("DIALOGEXTRA"), "no name before kind, or kind not a whole word: not counted"
call check k~items == 4, "#define and 9x lines not counted"
call check f["lines"] == 10, "line count as splitlines (BOM stripped, trailing empty line kept)"

/* ---- archive evidence -------------------------------------------------- */
dir = base"/archives"; call mkdirs dir
call zip dir"/good.zip", "a.cls", "::class A", "base/b.rex", "say 1"
call zip dir"/short.zip", "a.cls", "::class A"
call zip dir"/corrupt.zip", "a.cls", "::class A A A A A A A A A A A A A A A A A", "base/b.rex", "say 1"
call corrupt dir"/corrupt.zip"
call put dir"/notzip.zip", "this is not a zip"
good = .stream~new(dir"/good.zip")~charIn(1, .stream~new(dir"/good.zip")~chars)
goodSha = .SHA256~new(good)~digest
ev = .RcArchiveEvidence~new
ev~useManifest(.array~of( -
  .array~of("g", "good.zip", goodSha, "a.cls base/b.rex"), -
  .array~of("h", "good.zip", "0"~copies(64), "a.cls base/b.rex"), -
  .array~of("s", "short.zip", "", "a.cls base/b.rex"), -
  .array~of("c", "corrupt.zip", "", "a.cls base/b.rex"), -
  .array~of("n", "notzip.zip", "", "a.cls"), -
  .array~of("m", "absent.zip", "", "a.cls")))
r = ev~run(dir)
v = r["versions"]
call check v["g"]["ok"]~value, "good archive with matching SHA-256 verifies"
call check \v["h"]["ok"]~value & \v["h"]["sha256_matches"]~value, "good archive with the wrong recorded SHA-256 fails"
call check \v["s"]["ok"]~value & v["s"]["missing_members"][1] == "base/b.rex", "missing member reported"
call check \v["c"]["ok"]~value & v["c"]["bad_member"] == "a.cls", "CRC failure names the member"
call check \v["n"]["ok"]~value & v["n"]~hasIndex("error"), "not a ZIP: error recorded"
call check \v["m"]["ok"]~value & \v["m"]["present"]~value, "absent archive not present"
call check \r["all_verified"]~value, "all_verified false when any fails"
call check r["schema"] == "alchemy.rc.historical-archive-evidence/2", "schema /2"

say "rc tools tests:" passed "passed," failed "failed"
call removeTree base
if failed > 0 then exit 1
say "PASS test_rc_tools"
exit 0

zip: procedure
  use strict arg path, ...
  w = .ZipWriter~new
  do i = 2 to arg() by 2
    w~addBytes(arg(i), arg(i + 1), 8)
  end
  w~writeFile(path)
  return

/* Flip one byte inside the first member's compressed data. */
corrupt: procedure
  use strict arg path
  s = .stream~new(path)
  b = s~charIn(1, s~chars)
  s~close
  nameLen = b~substr(27, 2)~reverse~c2d
  extraLen = b~substr(29, 2)~reverse~c2d
  at = 31 + nameLen + extraLen + 2
  b = b~overlay(b~substr(at, 1)~bitXor("FF"x), at)
  .stream~new(path)~~open("write replace")~~charOut(b)~~close
  return

put: procedure
  use strict arg path, ...
  call mkdirs filespec("location", path)
  s = .stream~new(path)
  s~open("write replace")
  do i = 2 to arg()
    s~lineout(arg(i))
  end
  s~close
  return

mkdirs: procedure
  use strict arg path
  path = strip(path, "T", "/")
  if path == "" | sysIsFileDirectory(path) then return
  call mkdirs filespec("location", path)
  call sysMkDir path
  return

removeTree: procedure
  use strict arg path
  call sysFileTree path"/*", "f.", "FSO"
  do i = 1 to f.0
    call sysFileDelete f.i
  end
  call sysFileTree path"/*", "d.", "DSO"
  do i = d.0 to 1 by -1
    call sysRmDir d.i
  end
  call sysRmDir path
  return

check: procedure expose passed failed
  use strict arg ok, label
  if ok == .true then do
    passed += 1; say "ok   " label
  end
  else do
    failed += 1; say "FAIL " label
  end
  return

::requires "../src/RcCorpusInventory.cls"
::requires "../src/RcArchiveEvidence.cls"
