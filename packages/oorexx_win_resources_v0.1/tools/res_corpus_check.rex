#!/usr/bin/env rexx
/* res_corpus_check.rex -- read a folder of .res files with oorexx_win_resources.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 *   rexx tools/res_corpus_check.rex --dir DIR [--readobj] [--output report.json]
 *
 * For every .res in DIR: list its resources, decode every DIALOG/DIALOGEX
 * through the ooDialog/WASM contract and every MENU/MENUEX, and tally the
 * control kinds and the window classes the contract has no kind for.
 * --readobj also converts each .res with llvm-cvtres and lists it with
 * llvm-readobj --coff-resources: an independent reader.  Every resource
 * (type, name, language, size) must appear in both lists.
 * Progress goes to stderr; the JSON report to stdout or --output.
 * Exit 0 when nothing failed to decode and, with --readobj, both lists agree.
 */
parse arg argline
dir = ""; output = ""; readobj = .false
do while argline \= ""
  parse var argline word argline
  select
    when word == "--dir" then parse var argline dir argline
    when word == "--output" then parse var argline output argline
    when word == "--readobj" then readobj = .true
    otherwise do
      .error~lineout("res_corpus_check: unexpected argument" word)
      exit 2
    end
  end
end
if dir == "" then do
  .error~lineout("usage: rexx res_corpus_check.rex --dir DIR [--readobj] [--output FILE]")
  exit 2
end
checker = .ResCorpusCheck~new
checker~useLogger(.ToolProgress~new("res-corpus-check", checker, "RUN")~logger)
report = checker~run(strip(dir, "T", "/"), readobj)
text = .json~toJSON(report, .true)
if output \= "" then .stream~new(output)~~open("write replace")~~lineout(text)~~close
else say text
if report["ok"]~value then exit 0
exit 1


::class ResCorpusCheck
::method init
  expose log
  log = .LogNullLogger~instance
::method useLogger
  expose log
  use strict arg log

::method run
  expose log
  use strict arg dir, readobj
  call sysFileTree dir"/*.res", "f.", "FO"
  files = .array~new
  do i = 1 to f.0; files~append(f.i); end
  files = files~sort
  log~log(.Log~INFO, files~items ".res files in" dir)
  kinds = .directory~new
  unsupported = .directory~new
  totals = .directory~new
  do k over .array~of("resources", "dialogs", "controls", "menus", "menu_items", "decode_errors", "readobj_mismatches")
    totals[k] = 0
  end
  results = .array~new
  ok = .true
  do path over files
    r = .directory~new
    r["file"] = .JsonString~new(filespec("name", path))
    errors = .array~new
    set = self~readSet(path, errors)
    dialogs = 0; controls = 0; menus = 0; items = 0
    if set \== .nil then do
      r["resources"] = set~entries~items
      totals["resources"] += set~entries~items
      do e over set~entries
        got = self~decodeEntry(e, errors)
        if got == .nil then iterate
        if e~type == 5 then do
          dialogs += 1
          do c over got~controls
            controls += 1
            call bump kinds, c~kind
          end
          do c over got~unsupported
            call bump unsupported, c~windowClass
          end
        end
        else do
          menus += 1
          items += got~records~items
        end
      end
      if readobj then do
        diff = self~compareWithReadobj(path, set)
        r["readobj_mismatches"] = diff
        totals["readobj_mismatches"] += diff~items
        if diff~items > 0 then ok = .false
      end
    end
    r["dialogs"] = dialogs; r["controls"] = controls; r["menus"] = menus; r["menu_items"] = items
    totals["dialogs"] += dialogs; totals["controls"] += controls
    totals["menus"] += menus; totals["menu_items"] += items
    r["errors"] = errors
    totals["decode_errors"] += errors~items
    if errors~items > 0 then ok = .false
    note = ""
    if readobj & r~hasIndex("readobj_mismatches") then note = " readobj_mismatches="r["readobj_mismatches"]~items
    log~log(.Log~INFO, r["file"] "dialogs="dialogs "controls="controls "menus="menus "errors="errors~items || note)
    results~append(r)
  end
  report = .directory~new
  report["schema"] = "alchemy.win-resources.corpus-check/1"
  report["dir"] = .JsonString~new(dir)
  report["readobj_crosscheck"] = .JsonBoolean~of(readobj)
  report["totals"] = totals
  report["control_kinds"] = kinds
  report["unsupported_classes"] = unsupported
  report["files"] = results
  report["ok"] = .JsonBoolean~of(ok)
  log~log(.Log~INFO, "files="files~items "resources="totals["resources"] "dialogs="totals["dialogs"] -
    "controls="totals["controls"] "menus="totals["menus"] "decode_errors="totals["decode_errors"] -
    "readobj_mismatches="totals["readobj_mismatches"] "ok="ok)
  return report

/* type|name|language|size of every resource, from llvm-readobj, set against ours */
::method compareWithReadobj
  use strict arg path, set
  tmp = value("TMPDIR",, "ENVIRONMENT")
  if tmp == "" then tmp = "/tmp"
  stem = tmp"/res_corpus_check_"random(1, 999999)
  address system 'llvm-cvtres /machine:x64 /out:"'stem'.obj" "'path'" >/dev/null 2>&1'
  address system 'llvm-readobj --coff-resources "'stem'.obj" > "'stem'.txt" 2>&1'
  theirs = .array~new
  s = .stream~new(stem".txt")
  type = ""; name = ""; lang = ""
  do while s~lines > 0
    line = s~lineIn~strip
    select
      when line~abbrev("Type:") then type = self~idOf(line~substr(6))
      when line~abbrev("Name:") then name = self~idOf(line~substr(6))
      when line~abbrev("Language:") then lang = self~idOf(line~substr(10))
      when line~abbrev("DataSize:") then theirs~append(type"|"name"|"lang"|"line~substr(10)~strip)
      otherwise nop
    end
  end
  s~close
  call sysFileDelete stem".obj"; call sysFileDelete stem".txt"
  ours = .array~new
  do e over set~entries
    ours~append(e~type"|"e~name"|"e~language"|"e~data~length)
  end
  diff = .array~new
  do k over ours
    if theirs~index(k) == .nil then diff~append(.JsonString~new("only ours:" k))
  end
  do k over theirs
    if ours~index(k) == .nil then diff~append(.JsonString~new("only llvm-readobj:" k))
  end
  return diff

/* "MENU (ID 4) [" -> 4 ;  "NAMEDDLG [" -> NAMEDDLG */
::method idOf
  use strict arg text
  if text~pos("(ID ") > 0 then do
    parse var text "(ID " id ")"
    return id~strip
  end
  return text~strip~strip("T", "[")~strip~upper

::requires "../src/WinResources.cls"
::requires "../../oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
::requires "json.cls"

::method readSet
  use strict arg path, errors
  signal on syntax name failed
  return .WinResourceSet~fromFile(path)
failed:
  errors~append(.JsonString~new("cannot read:" condition("O")~message))
  return .nil

/* a dialog's contract directory or a menu template; .nil for other types or on error */
::method decodeEntry
  use strict arg e, errors
  signal on syntax name failed
  if e~type == 5 then return .WinDialogTemplate~parse(e~data)~asContract
  if e~type == 4 then return .WinMenuTemplate~parse(e~data)
  return .nil
failed:
  errors~append(.JsonString~new(e~string ":" condition("O")~message))
  return .nil

::routine bump
  use strict arg tally, key
  if tally~hasIndex(key) then tally[key] += 1
  else tally[key] = 1
