/* test_win_resources.rex -- acceptance for oorexx_win_resources v0.1.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Fixtures: tests/fixtures/app.rc compiled by llvm-rc (app.res) and linked by
 * lld-link (app.dll).  Every answer is checked against the .rc source, and
 * the .res and .dll must give identical answers.  Dialog 100 and menu 300
 * are the ones ooDialog/WASM's tests/t06_resdialog.rex stand-in returns.
 */
here = filespec("location", .context~package~name)
res = here"fixtures/app.res"
dll = here"fixtures/app.dll"
passed = 0; failed = 0

/* --- the containers ----------------------------------------------------- */
sr = .WinResourceSet~fromFile(res)
sd = .WinResourceSet~fromFile(dll)
call check sr~source == "res" & sd~source == "pe", "file kind detected from content"
call check sr~entries~items == 7 & sd~entries~items == 7, "7 resources in each (6 + one German dialog)"
p = .WinResourceProvider~new

/* --- .res and .dll agree on every template ------------------------------ */
same = .true
do id over 100, 200, "NAMEDDLG"
  if .json~toJSON(p~dialogTemplate(res, id)) \== .json~toJSON(p~dialogTemplate(dll, id)) then same = .false
end
do id over 300, 400, 500
  if .json~toJSON(p~menuTemplate(res, id)) \== .json~toJSON(p~menuTemplate(dll, id)) then same = .false
end
call check same, ".res and .dll give identical dialogs and menus"

/* --- dialog 100: the t06 stand-in's answers, from a real binary ---------- */
t = p~dialogTemplate(dll, 100)
call check t~x t~y t~cx t~cy == "20 20 180 80", "dialog 100 geometry"
call check t~title == "From app.dll", "dialog 100 title"
call check t~opts == "CENTER", "dialog 100 opts CENTER (has a system menu)"
call check t~fontName == "MS Shell Dlg" & t~fontSize == 8, "dialog 100 font"
call check t~controls~items == 4 & t~unsupported~items == 0, "dialog 100 has 4 controls"
expect = .array~of("STATIC -1 10 12 30 10 &Name", "EDIT 11 44 10 120 12", -
                   "CHECK 12 10 30 100 10 I &agree", "BUTTON 1 120 58 50 14 OK")
do i = 1 to 4
  c = t~controls[i]
  call check (c~kind c~id c~x c~y c~cx c~cy c~text)~strip == expect[i], "dialog 100 control" i "=" expect[i]
end
call check t~controls[4]~opts == "DEFAULT", "DEFPUSHBUTTON is DEFAULT"
call check t~controls[2]~opts == "AUTOSCROLLH", "EDITTEXT ES_AUTOHSCROLL"

/* --- language choice ------------------------------------------------------ */
call check t~controls~items == 4, "no preference: en-US chosen over German"
de = .WinResourceProvider~new(1031)
call check de~dialogTemplate(dll, 100)~title == "Aus app.dll", "preferred language 0x407 honoured"
call check de~dialogTemplate(dll, 200)~title~left(4) == "Gr" || "C3B6"x, "fallback when the language is absent"

/* --- menu 300: the t06 stand-in's menu ----------------------------------- */
m = p~menuTemplate(dll, 300)
call check rows(m) == "0 0 &Demo | 1 301 &Hello | 1 302 &Other GRAYED", "menu 300 records"

/* --- dialog 200: every kind, classic DIALOG, text outside ASCII ---------- */
t = p~dialogTemplate(res, 200)
call check t~title~c2x == "4772C3B6C39F6520E282AC20F09D849E", "UTF-16 title -> UTF-8, surrogate pair included"
call check t~opts == "NOMENU MINIMIZEBOX THICKFRAME", "dialog style keywords"
call check t~fontName == "Segoe UI" & t~fontSize == 9, "DIALOG font"
kinds = ""
do c over t~controls; kinds = kinds c~kind; end
call check kinds~strip == "GROUP RADIO RADIO CHECK BUTTON STATIC STATIC FRAME FRAME FRAME EDIT EDIT LIST COMBO COMBO" -
  "PROGRESS LISTVIEW TREEVIEW TAB UPDOWN TRACKBAR DATETIMEPICKER STATIC STATIC", "every contract kind, in creation order"
call check optsOf(t, 21) == "GROUP", "first radio starts a group"
call check optsOf(t, 22) == "NOTAB", "second radio has no tab stop"
call check optsOf(t, 23) == "3STATE LTEXT", "AUTO3STATE with BS_LEFTTEXT"
call check optsOf(t, 24) == "DISABLED", "WS_DISABLED"
call check optsOf(t, 25) == "GROUP CENTER NOTIFY", "CTEXT with SS_NOTIFY"
call check optsOf(t, 27) == "GRAY" & optsOf(t, 28) == "RECT WHITE" & optsOf(t, 29) == "ETCHED", "frames and rectangles"
call check optsOf(t, 30) == "VSCROLL MULTILINE WANTRETURN READONLY", "multi-line edit"
call check optsOf(t, 31) == "PASSWORD NUMBER NOBORDER", "password edit without border"
call check optsOf(t, 32) == "VSCROLL NOTIFY SORT EXTSEL MULTI PARTIAL", "list box"
call check optsOf(t, 33) == "LIST SORT" & optsOf(t, 34) == "SIMPLE", "combo boxes"
call check optsOf(t, 35) == "VERTICAL SMOOTH", "progress bar"
call check optsOf(t, 36) == "REPORT SINGLESEL", "list-view"
call check optsOf(t, 39) == "SETBUDDYINT RIGHT AUTOBUDDY ARROWKEYS", "up-down"
call check optsOf(t, 41) == "TIME", "date-time picker in time format"
c = control(t, 44)
call check c~kind == "STATIC" & c~opts == "ICON" & c~text == "" & c~resource == 7, "ICON static: no text, resource 7"
call check optsOf(t, 45) == "HIDDEN GROUP", "NOT WS_VISIBLE is HIDDEN"
u = ""
do c over t~unsupported; u = u c~windowClass"/"c~id; end
call check u~strip == "SYSMONTHCAL32/42 132/43", "month calendar and scroll bar reported, not dropped silently"

/* --- MENUEX and MENU ------------------------------------------------------ */
call check rows(p~menuTemplate(res, 400)) == "0 410 &File | 1 401 &Open" || "09"x || "Ctrl+O | 1 0  SEPARATOR | 1 411 &Recent" -
  "| 2 402 one.txt RADIO CHECKED | 2 403 two.txt RADIO | 1 404 E&xit DEFAULT | 0 405 &Help GRAYED HELP", "MENUEX: nesting, separator, radio, default, right-justify"
call check rows(p~menuTemplate(res, 500)) == "0 0 &Edit | 1 501 &Copy CHECKED | 1 0  SEPARATOR | 1 502 &Paste DISABLED | 0 503 &Go", -
  "MENU: popup, separator, checked, inactive, bar item"

/* --- names, absences, damage --------------------------------------------- */
call check p~dialogTemplate(dll, "nameddlg")~title == "Named", "string name, any case"
call check p~dialogTemplate(dll, 999) == .nil & p~menuTemplate(dll, 999) == .nil, "absent id answers .nil"
call check raises(.WinResourceProvider~new, "dialogTemplate", here"fixtures/no_such.dll", 100), "missing library raises"
b = .stream~new(res)~charIn(1, 600)
call check raisesBytes(b), "truncated .res raises, does not loop"
call check raisesBytes("MZ" || "00"x~copies(200)), "PE without a PE signature raises"

say "win_resources tests:" passed "passed," failed "failed"
if failed > 0 then exit 1
say "PASS test_win_resources"
exit 0

rows: procedure
  use strict arg records
  out = ""
  do r over records
    out = out "|" (r~depth r~id r~text r~flags)~strip
  end
  return out~substr(4)~strip

control: procedure
  use strict arg t, id
  do c over t~controls
    if c~id = id then return c
  end
  return .nil

optsOf: procedure
  use strict arg t, id
  c = control(t, id)
  if c == .nil then return "<no control" id">"
  return c~opts

raises: procedure
  use strict arg target, msg, a1, a2
  signal on syntax name raised
  ignore = target~send(msg, a1, a2)
  return .false
raised:
  return .true

raisesBytes: procedure
  use strict arg bytes
  signal on syntax name raisedB
  s = .WinResourceSet~fromBytes(bytes)
  return .false
raisedB:
  return .true

check: procedure expose passed failed
  use strict arg ok, label
  if ok == .true then do
    passed += 1; say "ok   " label
  end
  else do
    failed += 1; say "FAIL " label
  end
  return

::requires "../src/WinResources.cls"
::requires "json.cls"
