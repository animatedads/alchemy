/* test_piledriver.rex - Piledriver v0.1 qualification.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 *
 * Arg: WORK|REPO   WORK a scratch directory; REPO the alchemy checkout (the real files below are read from it).
 *
 * Gemini's claim: about 0.5 billion parameters are needed to read the header of a CSV file, work out the
 * tables, and read an error file.  Every check below runs with no model and no weights.
 *
 *  1. what kind of file: real estate files of each kind; content beats the extension
 *  2. a compile log: 1,033 lines are 9 patterns, no error
 *  3. the Rexx/SQL tester: codes in the record, "seen before" kept apart from "is this an error code"
 *  4. two runs of one test, before and after a patch: what went away
 *  5. PASS/FAIL logs: a FAIL record with its lines; "PASS ... returns an error" is a mention
 *  6. a crash log: the abort, exit=134, rc=-1; after the patch, exit=0
 *  7. an emulator trace with no error word in it: the status key is found by counts
 *  8. the gateway traffic log is a table of hex-encoded text
 *  9. ooRexx's own error output, made now by the interpreter
 * 10. standard formats: syslog, log4j with a stack trace, Python with a traceback, an Apache access log
 * 11. a table with status columns and spreadsheet error values
 * 12. real tables: 35,672 LSOA rows (a "code" column that is an identifier), police outcomes (free text is data)
 * 13. the independent review's cases (Claude (Opus 5.5), a separate agent that had not seen the work): each one
 *     failed before its fix
 */
parse arg work '|' repo
signal on syntax name failed
.local['PDPASS'] = 0
.local['PDFAIL'] = 0
P = repo || '/packages'
EV = P || '/oorexx_rexxsql_backend_v0.1/evidence'
IBM = P || '/ibm_4361_oorexx_v0.3-recovery2-journal2-safety24/evidence'
call SysMkDir work

say '== 1. what kind of file'
call kind IBM || '/safety17_compile.log', 'LOG'
call kind EV || '/test_rexxsql_driver_unpatched.log', 'LOG'
call kind P || '/oorexx_queue_fabric_web_gateway_v0.2/tests/GWWIREUI/traffic.log', 'DELIMITED'
call kind P || '/oorexx_slam_v0.1/corpus/senses.csv', 'CSV'
call kind P || '/oorexx_wire3d_v0.1-dev29-national-crime/dependencies/crime_area_analytics_v0.3/data/lsoa_2021_reference.csv', 'CSV'
pkg = work || '/pd_package.json'
call put pkg, '{ "name": "x",' || '0a'x || '  "version": "1" }'
call kind pkg, 'JSON'
jl = work || '/pd_lines.jsonl'
call put jl, '{"a": 1}' || '0a'x || '{"b": 2}'
call kind jl, 'JSONL'
/* zip headers only: tests the sniff rule (the first bytes), not a workbook */
zx = work || '/pd_book.xlsx'
call put zx, 'PK' || '0304'x || copies('00'x, 26) || '[Content_Types].xml' || 'PK' || '0304'x || copies('00'x, 26) || 'xl/workbook.xml'
call kind zx, 'XLSX'
zo = work || '/pd_book.ods'
call put zo, 'PK' || '0304'x || copies('00'x, 26) || 'mimetypeapplication/vnd.oasis.opendocument.spreadsheet'
call kind zo, 'ODS'

say '== 2. a compile log: the same banner 129 times'
log = .PiledriverLog~new
log~readFile(IBM || '/safety17_compile.log')
call check log~lineCount == 1033, 'read 1,033 lines'
call check log~counts~items == 9, '9 patterns (' || log~counts~items || ')'
call check log~counts['Open Object Rexx Version #.#.# r# - Internal Test Version'] == 129, 'the banner line 129 times, one pattern'
call check log~errors('ERROR WARN')~items == 0, 'no error and no warning in a clean compile'
call check log~records[1033]~status == 'NEW', 'the last line, COMPILE PASS, is the one new thing at the end'

say '== 3. the Rexx/SQL tester: codes, and seen before'
log = .PiledriverLog~new
log~readFile(EV || '/mark_tester_unpatched.log')
r = log~recordAt(162)
call check r~heading, '"Testing error conditions..." between two banners is a heading, not an error:' r~verdict
call check r~verdict == 'NONE', '... its verdict is NONE'
r = log~recordAt(183)
call check r~lines~items == 3, '"Error in open:" takes its INTCODE and INTERRM lines (' || r~lines~items 'lines)'
call check r~verdict == 'ERROR' & r~strength == 'STRONG', 'it is a STRONG error:' r~reasons~makeString('L', '; ')
call check r~codes~index('INTCODE=-24') \== .nil & r~codes~index('REXX/SQL-24') \== .nil, 'its codes: INTCODE=-24 and REXX/SQL-24'
r = log~recordAt(191)
call check r~status == 'NEW_CODES', 'line 191: "Error in open:" was seen before, INTCODE=-62 was not: NEW_CODES'
call check r~seen == 1, '... seen once before'
r = log~recordAt(173)
call check r~reasons~index('CODE SQLSTATE=ZZZZZ') \== .nil, 'SQLSTATE ZZZZZ is not 00000: an error code'
r62 = log~recordAt(62); r63 = log~recordAt(63)
call check r62~template == "rm: cannot remove '<FILE>': No such file or directory", 'two file names, one pattern'
call check r62~status == 'NEW' & r63~status == 'REPEAT', 'the first is NEW, the second a REPEAT'
call check r62~strength == 'WEAK', 'a keyword alone is a WEAK error'
call check log~recordAt(62)~section == 'Testing sqlcommand with placemarkers...', 'the errors carry their section'

say '== 4. before and after a patch'
cat = work || '/pd_tester.catalog'
call SysFileDelete cat
before = .PiledriverLog~new
before~readFile(EV || '/mark_tester_unpatched.log')
before~saveCatalog(cat)
after = .PiledriverLog~new
call check after~loadCatalog(cat) > 0, 'catalog written and read back'
after~readFile(EV || '/mark_tester_patched.log')
gone = after~gone
call check gone~items == 1, 'one pattern went away (' || gone~items || ')'
if gone~items > 0 then do
  call check gone[1][1] == "rm: cannot remove '<FILE>': No such file or directory", 'it is the rm error'
  call check gone[1][2] == 2 & gone[1][3] == 'ERROR', '... seen twice before, an ERROR'
end
call check after~arrived~items == 0, 'nothing new after the patch'
call check after~records[1]~status == 'KNOWN', 'every record of the patched run is KNOWN from the catalog'

say '== 5. PASS/FAIL logs'
log = .PiledriverLog~new
log~readFile(EV || '/test_rexxsql_driver_unpatched.log')
errs = log~errors
call check errs~items == 1, 'one error in the unpatched run'
if errs~items > 0 then do
  call check errs[1]~lineNo == 13 & errs[1]~lines~items == 3, 'the FAIL at line 13, with its two indented lines'
  call check errs[1]~reasons~index('LEVEL FAIL') \== .nil, 'by its level word: FAIL'
end
log = .PiledriverLog~new
log~readFile(EV || '/test_rexxsql_driver_patched.log')
call check log~errors~items == 0, 'no error in the patched run'
m = log~errors('MENTION')
call check m~items == 1, 'one mention'
call check m[1]~template~pos('returns an error instead of aborting') > 0, '"PASS ... returns an error instead of aborting (rc=-16)" mentions an error; it is not one'
call check log~counts['PASS round trip byte-exact case # length #'] == 9, 'nine round trips, one pattern'

say '== 6. a crash, then the fix'
log = .PiledriverLog~new
log~readFile(EV || '/defects_unpatched.log')
r = log~recordAt(3)
call check r~verdict == 'ERROR' & r~strength == 'STRONG', '"*** buffer overflow detected ***: terminated" is a strong error'
call check log~recordAt(5)~reasons~index('CODE EXIT=134') \== .nil, 'exit=134 is an error code'
call check log~recordAt(10)~reasons~index('CODE RC=-1') \== .nil, '"rc= -1": the value after "rc=" is a code'
call check log~recordAt(4)~reasons~index('KEYWORD overflow') == .nil, 'overflow.rex is a file name, not the word overflow'
log = .PiledriverLog~new
log~readFile(EV || '/defects_patched.log')
call check log~recordAt(5)~verdict == 'NONE', 'exit=0 is the OK value'
call check log~recordAt(3)~reasons~index('CODE RC=-16') \== .nil, 'rc= -16: the error the patch now returns, in place of the abort'

say '== 7. an emulator trace: no error word, no level'
log = .PiledriverLog~new
log~readFile(IBM || '/mvt_safety8_permanent_bal_progress.log')
call check log~counts~items == 9, '209 lines, 9 patterns (' || log~counts~items || ')'
errs = log~errors
call check errs~items == 2, 'two errors (' || errs~items || ')'
if errs~items == 2 then do
  call check errs[1]~lineNo == 205 & errs[2]~lineNo == 206, 'lines 205 and 206: ST=UNSUPPORTED'
  call check errs[1]~reasons[1] == 'STATUS ST=UNSUPPORTED (key found by counts)', 'ST is a status key by counts: OK x101, UNSUPPORTED x2'
end
call check log~counts['POST ST=OK IC=# IA=# PSW=#'] == 101, 'POST ST=OK 101 times: register values are masked, not codes'

say '== 8. the gateway traffic log is a table'
t = .PiledriverTable~new~readFile(P || '/oorexx_queue_fabric_web_gateway_v0.2/tests/GWWIREUI/traffic.log')
call check t~columns~items == 11, '11 columns'
c4 = t~columns[4]
call check c4~mainKind == 'HEXTEXT' & c4~role == 'CATEGORY', 'column 4 is hex-encoded text, 5 values'
call check c4~values~hasIndex('4352454154455F5155455545'), 'one of them is CREATE_QUEUE'
call check t~columns[2]~role == 'ID', 'column 2 is an identifier (178 values in 178 rows)'

say '== 9. ooRexx error output, made now'
prog = work || '/pd_bad.rex'
out = work || '/pd_bad.out'
call put prog, 'x = .object~new' || '0a'x || 'say x~foo'
address system 'rexx "' || prog || '" > "' || out || '" 2>&1'
log = .PiledriverLog~new
log~readFile(out)
e97 = .nil
do r over log~records
  if r~head~left(9) == 'Error 97 ' then e97 = r
end
call check e97 \== .nil, 'the interpreter wrote "Error 97 running ..."'
if e97 \== .nil then do
  call check e97~verdict == 'ERROR' & e97~strength == 'STRONG', '... a strong error'
  call check e97~codes~index('ERROR=97') \== .nil, '... with its code: the number after "Error"'
end
call check log~errors~items == 2, 'two error lines (97 and 97.1)'

say '== 10. standard formats'
lines = .array~new
lines~append('Oct 30 20:34:01 ed209a sshd[1234]: Accepted publickey for tom from 10.0.0.5 port 50022 ssh2')
lines~append('Oct 30 20:34:09 ed209a sshd[1240]: Failed password for root from 10.0.0.9 port 50110 ssh2')
lines~append('Oct 30 20:34:11 ed209a CRON[1301]: (root) CMD (run-parts /etc/cron.hourly)')
log = .PiledriverLog~new
log~readLines(lines, 'syslog')
call check log~prefixed, 'syslog: time stamps, so PREFIXED'
call check log~records[1]~stamp == 'Oct 30 20:34:01', 'the stamp is three words'
call check log~records[2]~verdict == 'ERROR' & log~records[2]~strength == 'WEAK', '"Failed password" is a weak error'
call check log~records[2]~template == '# sshd[#]: Failed password for root from #.#.#.# port # ssh#', 'pid, address and port masked; the host ed209a too (all its letters are hex digits)'
lines = .array~new
lines~append('2026-10-30 20:34:01,120 INFO  [main] com.acme.Server - started on port 8080')
lines~append('2026-10-30 20:34:02,551 ERROR [worker-3] com.acme.Handler - request failed')
lines~append('java.lang.NullPointerException: name')
lines~append(09x || 'at com.acme.Handler.handle(Handler.java:42)')
lines~append(09x || 'at com.acme.Server.run(Server.java:17)')
lines~append('Caused by: java.io.IOException: closed')
lines~append(09x || '... 2 more')
lines~append('2026-10-30 20:34:03,002 INFO  [main] com.acme.Server - still up')
log = .PiledriverLog~new
log~readLines(lines, 'log4j')
call check log~records~items == 3, 'log4j: 8 lines, 3 records'
r = log~records[2]
call check r~lines~items == 6, 'the ERROR record holds its stack trace (6 lines)'
call check r~reasons~index('STACK') \== .nil & r~reasons~index('LEVEL ERROR') \== .nil, 'STACK and LEVEL ERROR'
call check log~records[1]~verdict == 'INFO', 'INFO lines are INFO'
lines = .array~new
lines~append('2026-10-30 20:34:01,120 - loader - INFO - loading 12 files')
lines~append('2026-10-30 20:34:01,377 - loader - ERROR - cannot parse row 7')
lines~append('Traceback (most recent call last):')
lines~append('  File "loader.py", line 88, in parse')
lines~append('    value = int(cell)')
lines~append("ValueError: invalid literal for int() with base 10: 'x'")
log = .PiledriverLog~new
log~readLines(lines, 'python')
call check log~records~items == 2, 'python logging: the traceback joins the ERROR record'
call check log~records[2]~level == 'ERROR' & log~records[2]~reasons~index('STACK') \== .nil, 'level ERROR, four words in, and a STACK'
lines = .array~new
do i = 1 to 46
  status = 200
  if i // 12 == 0 then status = 404
  if i == 23 | i == 41 then status = 500
  lines~append('10.0.0.' || (i // 7) '- - [30/Oct/2026:20:' || right(i, 2, '0') || ':01 +0000] "GET /page/' || i || '.html HTTP/1.1"' status (100 + i * 37))
end
log = .PiledriverLog~new
log~readLines(lines, 'access')
call check log~slots~items >= 1, 'access log: the status is found as a code slot by counts'
http = .false
do s over log~slots
  if s['HTTP'] then http = .true
end
call check http, '... and its values are all 100 to 599: an HTTP status'
call check log~errors~items == 2, 'two 500s are errors (' || log~errors~items || ')'
call check log~errors('WARN')~items == 3, 'three 404s are warnings (' || log~errors('WARN')~items || ')'
call check log~counts~items == 3, 'three patterns: 200, 404, 500 (' || log~counts~items || ')'

say '== 11. a table with status columns and sheet errors'
csv = work || '/pd_jobs.csv'
rows = .array~of('job,rc,result,ratio,owner')
do i = 1 to 20
  rc = 0
  if i == 7 then rc = 8
  if i == 15 then rc = 12
  res = 'PASS'
  if i == 15 then res = 'FAIL'
  ratio = i / 4
  if i == 9 then ratio = '#DIV/0!'
  if i == 18 then ratio = 'Err:502'
  rows~append('job' || i || ',' || rc || ',' || res || ',' || ratio || ',' || word('tom claude chatgpt', i // 3 + 1))
end
call put csv, rows~makeString('L', '0a'x)
t = .PiledriverTable~new~readFile(csv)
call check t~header, 'the header is found'
call check t~columns[2]~role == 'STATUS', 'rc is a STATUS column:' t~columns[2]~evidence~makeString('L', '; ')
call check t~columns[3]~role == 'STATUS', 'result is a STATUS column (level words)'
call check t~columns[1]~role == 'ID', 'job is an identifier'
call check t~columns[5]~role == 'CATEGORY', 'owner is a category'
call check t~errorRows~items == 3, 'three error rows: rc=8, rc=12, result=FAIL (' || t~errorRows~items || ')'
call check t~sheetErrors~items == 2, 'two sheet error values'
call check t~sheetErrors[1][1] == 'D10' & t~sheetErrors[1][2] == '#DIV/0!', '#DIV/0! at D10'
call check t~sheetErrors[2][2] == 'Err:502', "LibreOffice's Err:502 too: an ODS error saved as text is still an error"

say '== 12. real tables'
t0 = time('E')
t = .PiledriverTable~new~readFile(P || '/oorexx_wire3d_v0.1-dev29-national-crime/dependencies/crime_area_analytics_v0.3/data/lsoa_2021_reference.csv')
secs = time('E') - t0
call check t~rows~items == 35673, '35,672 rows and a header'
c1 = t~columns[1]
call check c1~name == 'lsoa_code' & c1~role == 'ID', 'lsoa_code: the name says code, the values say identifier, and the values decide'
call check c1~mainKind == 'CODE', '... its values are code-shaped (E01000001)'
call check t~columns[4]~role == 'CONSTANT', 'area_type is one value'
call check t~errorRows~items == 0, 'no status column, no error rows'
say '      (' || format(secs, , 1) 'seconds, csvStream.cls reading)'
t = .PiledriverTable~new~readFile(P || '/oorexx_wire3d_v0.1-dev29-national-crime/dependencies/crime_area_analytics_v0.3/tests/fixtures/police/2025-08/2025-08-test-outcomes.csv')
call check t~errorRows~items + t~sheetErrors~items == 0, '"Unable to prosecute suspect" is an outcome: a table is not searched for error words'

say '== 13. the review: each case failed before its fix'
log = .PiledriverLog~new
log~readLines(.array~of('job 1 STATUS: running', 'job 2 status=queued', 'reply error=false in reply'), 'words')
call check log~errors~items == 0, 'a word after a code key is not an error code (STATUS: running, status=queued, error=false)'
lines = .array~new
do i = 1 to 12
  st = 'done'
  if i == 9 then st = 'failed_hard'
  lines~append('job' i 'status=' || st)
end
log = .PiledriverLog~new
log~readLines(lines, 'status words')
errs = log~errors
first = 0
if errs~items > 0 then first = errs[1]~lineNo
call check errs~items == 1 & first == 9, 'status= with word values: the key is found by counts (done x11), and the odd one is the error'
log = .PiledriverLog~new
log~readLines(.array~of('Compiling module:', 'WARNING: deprecated API used', 'ERROR: link failed'), 'block')
call check log~records~items == 3, 'WARNING: and ERROR: lines do not join a block ("Compiling module:")'
if log~records~items == 3 then call check log~records[2]~verdict == 'WARN' & log~records[3]~reasons~index('LEVEL ERROR') \== .nil, '... WARN, and ERROR by its level'
bom = work || '/pd_bom.log'
call put bom, 'EFBBBF'x || 'ERROR disk full'
log = .PiledriverLog~new
log~readFile(bom)
call check log~records[1]~verdict == 'ERROR', 'a UTF-8 byte order mark is removed from a log'
bomcsv = work || '/pd_bom.csv'
rows = .array~of('EFBBBF'x || 'outcome,n')
do i = 1 to 12
  v = 'OK'
  if i == 5 then v = 'TIMEOUT'
  rows~append(v || ',' || i)
end
call put bomcsv, rows~makeString('L', '0a'x)
t = .PiledriverTable~new~readFile(bomcsv)
call check t~columns[1]~name == 'outcome', '... and from a table header'
call check t~columns[1]~role == 'STATUS' & t~errorRows~items == 1, 'outcome OK x11, TIMEOUT x1 is a status column; the TIMEOUT row is its error (OK before level words)'
blankcsv = work || '/pd_blank.csv'
call put blankcsv, '0a'x || 'a,b' || '0a'x || '1,x' || '0a'x || '2,y'
t = .PiledriverTable~new~readFile(blankcsv)
call check t~header & t~columns[1]~name == 'a' & t~rows~items == 3, 'a leading blank line: the header is still line 1 of the table'
idx = work || '/pd_index.log'
call put idx, '[0] starting' || '0a'x || '[1] loading' || '0a'x || '[2] done'
call kind idx, 'LOG'
log = .PiledriverLog~new
log~readLines(.array~of('## ERROR: build failed', '-- 3 tests FAILED', '--- overflow.rex (long unaliased expression)'), 'headings')
call check log~records[1]~verdict == 'ERROR' & log~records[2]~verdict == 'ERROR', 'a "heading" with ERROR or FAILED in it reports a result: an error'
call check log~records[3]~heading, '"--- overflow.rex (...)" is still a heading'
log = .PiledriverLog~new
log~readLines(.array~of('checksum SHA256 failed'), 'names')
call check log~records[1]~strength == 'WEAK' & log~records[1]~codes~items == 0, 'SHA256 is a name, not a code'
cat2 = work || '/pd_twice.catalog'
call SysFileDelete cat2
log = .PiledriverLog~new
log~readLines(.array~of('a 1', 'a 2'), 'twice')
log~saveCatalog(cat2)
log~saveCatalog(cat2)
again = .PiledriverLog~new
again~loadCatalog(cat2)
call check again~catalog['a #'] == '2 NONE', 'saving one log twice does not count it twice'

say ''
say 'PILEDRIVER TEST:' word('PASS FAIL', 1 + (.local['PDFAIL'] > 0)) '(' || .local['PDPASS'] 'passed,' .local['PDFAIL'] 'failed; no model, no weights)'
exit .local['PDFAIL'] > 0

kind: procedure
  use arg path, want
  r = .PiledriverSource~sniff(path)
  call check r['KIND'] == want, path~substr(path~lastPos('/') + 1) 'is' r['KIND'] '(' || r['EVIDENCE']~makeString('L', '; ') || ')'
  return

put: procedure
  use arg path, text
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  s~charOut(text || '0a'x)
  s~close
  return

check: procedure
  use arg ok, text
  if ok then do
    .local['PDPASS'] = .local['PDPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['PDFAIL'] = .local['PDFAIL'] + 1
    say 'FAIL ' text
  end
  return

failed:
  say 'PILEDRIVER TEST: ERROR' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 2

::requires 'PiledriverSource.cls'
::requires 'PiledriverLog.cls'
::requires 'PiledriverTable.cls'
