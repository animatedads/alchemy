/* oorexx_python_gate v0.1 -- no unjustified Python in an estate package.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Rule: a package may carry Python, or call Python, only when its root holds a
 * PYTHON_JUSTIFICATION file naming each such file and saying why ooRexx (with
 * the estate's own packages) cannot do the job.  The gate cannot judge whether
 * a reason is good; it makes every reason visible in the build log so the
 * VERIFIER and the Architect can.  "Reading a file is complex" is not a reason.
 *
 * What counts as Python:
 *   - files named *.py, *.pyw, *.pyi
 *   - files whose first line is a #! line naming python (rename loophole)
 *   - Rexx (.rex .rexx .cls .orx) and shell (.sh) files that call python on
 *     a script, a module (-m) or inline code (-c); the justification for
 *     those is keyed by the calling file's path
 * Exempt, but listed in the report: anything under a vendor/, upstream/ or
 * third_party/ directory (third-party code the package carries unchanged).
 *
 * PYTHON_JUSTIFICATION format, one entry per line, # starts a comment:
 *   tools/foo.py | <reason, at least 10 words>
 */

::class PythonGate public
::constant SCHEMA "alchemy.python-gate.report/1"
::constant JUSTIFICATION_FILE "PYTHON_JUSTIFICATION"
::constant MIN_REASON_WORDS 10

::attribute root get
::attribute report get

::method init
  expose root report log
  use strict arg root
  root = strip(root, "T", "/")
  if root == "" then root = "/"
  log = .LogNullLogger~instance
  report = .nil

/* Progress logger for RUN, normally .ToolProgress~new(..., gate, "RUN")~logger */
::method useLogger public
  expose log
  use strict arg log
  return self

::method run public
  expose root report log
  if \sysIsFileDirectory(root) then do
    report = self~newReport
    report["status"] = "FAIL"
    report["findings"]~append("package root is not a directory:" root)
    return report
  end
  log~log(.Log~INFO, "scanning" root)
  report = self~newReport
  justifications = self~readJustifications(report)
  needs = .table~new                       -- relative path -> kind
  files = self~packageFiles
  log~log(.Log~INFO, files~items "files in package")
  do rel over files
    full = root"/"rel
    if self~isExempt(rel) then do
      if self~isPythonFile(full, rel) then report["exempt"]~append(.JsonString~new(rel))
      iterate
    end
    if self~isPythonFile(full, rel) then do
      needs[rel] = "python-source"
      iterate
    end
    if self~isCallerType(rel) then do
      calls = self~pythonCalls(full)
      if calls~items > 0 then do
        needs[rel] = "python-call"
        do c over calls
          entry = .directory~new
          entry["path"] = .JsonString~new(rel)
          entry["line"] = c[1]
          entry["text"] = .JsonString~new(c[2])
          report["calls"]~append(entry)
        end
      end
    end
  end

  failed = .false
  do rel over self~sorted(needs~allIndexes)
    item = .directory~new
    item["path"] = .JsonString~new(rel)
    item["kind"] = needs[rel]
    reason = justifications[rel]
    if reason == .nil then do
      item["justified"] = .JsonBoolean~of(.false)
      item["reason"] = .JsonString~new("")
      failed = .true
      report["findings"]~append(rel "("needs[rel]") has no entry in" self~JUSTIFICATION_FILE)
      log~log(.Log~WARN, "UNJUSTIFIED" needs[rel] rel)
    end
    else if words(reason) < self~MIN_REASON_WORDS then do
      item["justified"] = .JsonBoolean~of(.false)
      item["reason"] = .JsonString~new(reason)
      failed = .true
      report["findings"]~append(rel "justification has" words(reason) "words; minimum is" self~MIN_REASON_WORDS)
      log~log(.Log~WARN, "TOO SHORT" rel "-" reason)
    end
    else do
      item["justified"] = .JsonBoolean~of(.true)
      item["reason"] = .JsonString~new(reason)
      log~log(.Log~INFO, "justified" rel "-" reason)
    end
    report["python"]~append(item)
  end

  do rel over self~sorted(justifications~allIndexes)
    if \needs~hasIndex(rel) then do
      report["warnings"]~append(self~JUSTIFICATION_FILE "entry for" rel "matches no Python file or call")
      log~log(.Log~WARN, "stale justification entry" rel)
    end
  end
  do rel over report["exempt"]
    log~log(.Log~INFO, "exempt third-party" rel)
  end

  if failed then report["status"] = "FAIL"
  else report["status"] = "PASS"
  log~log(.Log~INFO, "result" report["status"] "-" report["python"]~items "needing justification," -
    report["findings"]~items "findings")
  return report

::method newReport private
  expose root
  r = .directory~new
  r["schema"] = self~SCHEMA
  r["root"] = .JsonString~new(root)
  r["status"] = "NOT RUN"
  r["python"] = .array~new
  r["calls"] = .array~new
  r["exempt"] = .array~new
  r["findings"] = .array~new
  r["warnings"] = .array~new
  return r

/* Relative paths of every regular file under root, .git excluded, sorted. */
::method packageFiles private
  expose root
  out = .array~new
  rc = sysFileTree(root"/*", "found.", "FSO")
  if rc \= 0 then raise syntax 88.900 array("SysFileTree failed on" root "rc="rc)
  prefix = root"/"
  do i = 1 to found.0
    full = found.i
    if full~left(prefix~length) \== prefix then iterate
    rel = full~substr(prefix~length + 1)
    if rel == ".git" | rel~left(5) == ".git/" then iterate
    out~append(rel)
  end
  return self~sorted(out)

::method sorted private
  use strict arg collection
  a = .array~new
  do x over collection
    a~append(x)
  end
  return a~sort

::method isExempt public
  use strict arg rel
  segments = rel~makeArray("/")
  do i = 1 to segments~items - 1
    if wordpos(segments[i]~lower, "vendor upstream third_party") > 0 then return .true
  end
  return .false

::method extension private
  use strict arg rel
  name = rel~substr(rel~lastPos("/") + 1)
  dot = name~lastPos(".")
  if dot <= 1 then return ""
  return name~substr(dot + 1)~lower

::method isPythonFile public
  use strict arg full, rel
  if wordpos(self~extension(rel), "py pyw pyi") > 0 then return .true
  s = .stream~new(full)
  if s~open("read") \= "READY:" then return .false
  head = s~charIn(1, 2)
  first = ""
  if head == "#!" then first = s~lineIn(1)
  s~close
  return first~lower~pos("python") > 0

::method isCallerType public
  use strict arg rel
  return wordpos(self~extension(rel), "rex rexx cls orx sh") > 0

/* Returns an Array of (lineNumber, text) pairs for lines that run Python. */
::method pythonCalls public
  use strict arg full
  calls = .array~new
  s = .stream~new(full)
  if s~open("read") \= "READY:" then return calls
  n = 0
  do while s~lines > 0
    line = s~lineIn
    n += 1
    if self~callsPython(line) then calls~append(.array~of(n, line~strip))
  end
  s~close
  return calls

/* A python token (python, python3, python3.12, /usr/bin/python3) followed
 * by a .py path, -m or -c.  Plain mentions of the word are not calls. */
::method callsPython public
  use strict arg line
  text = line~strip
  if text~left(1) == "#" & text~left(2) \== "#!" then return .false   -- shell comment
  if text~left(2) == "--" | text~left(2) == "/*" | text~left(1) == "*" then return .false
  text = text~translate("   ", "'"",;")~lower
  do i = 1 to words(text) - 1
    w = word(text, i)
    base = w~substr(w~lastPos("/") + 1)
    if base~left(6) \== "python" then iterate
    if verify(base~substr(7), "0123456789.") > 0 then iterate
    nxt = word(text, i + 1)
    if nxt == "-m" | nxt == "-c" | nxt == "-u" then return .true
    if nxt~right(3) == ".py" then return .true
  end
  return .false

/* PYTHON_JUSTIFICATION -> Table(relative path -> reason). */
::method readJustifications private
  expose root log
  use strict arg report
  table = .table~new
  path = root"/"self~JUSTIFICATION_FILE
  if \sysFileExists(path) then return table
  s = .stream~new(path)
  if s~open("read") \= "READY:" then do
    report["findings"]~append("cannot read" self~JUSTIFICATION_FILE)
    return table
  end
  n = 0
  do while s~lines > 0
    line = s~lineIn
    n += 1
    if line~strip == "" | line~strip~left(1) == "#" then iterate
    parse var line rel "|" reason
    rel = rel~strip
    reason = reason~strip
    if rel == "" | line~pos("|") == 0 then do
      report["warnings"]~append(self~JUSTIFICATION_FILE "line" n "is not 'path | reason'")
      iterate
    end
    table[rel] = reason
  end
  s~close
  log~log(.Log~INFO, table~items "entries in" self~JUSTIFICATION_FILE)
  return table

::requires "../../oorexx_logging_v0.7/src/LoggingCore.cls"
::requires "json.cls"
