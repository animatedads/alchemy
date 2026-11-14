/* RcCorpusInventory -- inventory the original ooRexx Windows .rc corpus.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14, porting
 * tools/corpus_inventory.py (ChatGPT) to ooRexx; same report, same rules.
 *
 * For each manifest path: present / missing / incomplete_includes, SHA-256,
 * size, line count, quoted #include files and which are missing, and a
 * heuristic count of resource statements by kind.  Inventory only: no parser
 * or compiler compatibility is claimed.
 */
::options digits 12

::class RcCorpusInventory public
::constant SCHEMA "alchemy.rc.corpus.inventory/1"
::constant KINDS "DIALOGEX DIALOG MENU MENUEX ACCELERATORS STRINGTABLE ICON CURSOR BITMAP RCDATA VERSIONINFO MESSAGETABLE HTML"

::method init
  expose log
  log = .LogNullLogger~instance

::method useLogger public
  expose log
  use strict arg log
  return self

/* checkout: a directory; manifest: a file of relative paths (# comments) */
::method run public
  expose log
  use strict arg checkout, manifest
  checkout = strip(checkout, "T", "/")
  records = .array~new
  paths = self~manifestPaths(manifest)
  log~log(.Log~INFO, paths~items "paths in" manifest)
  n = 0
  do relative over paths
    n += 1
    record = self~inventoryOne(checkout, relative)
    log~log(.Log~INFO, n"/"paths~items relative "->" record["status"])
    records~append(record)
  end
  totals = .directory~new
  do key over .array~of("present", "missing", "incomplete_includes")
    totals[key] = 0
  end
  do r over records
    totals[r["status"]] += 1
  end
  report = .directory~new
  report["schema"] = self~SCHEMA
  report["note"] = "Inventory only; no parser or compiler compatibility proved"
  report["total"] = records~items
  report["totals"] = totals
  report["files"] = records
  log~log(.Log~INFO, "present" totals["present"] "missing" totals["missing"] "incomplete_includes" totals["incomplete_includes"])
  return report

::method passed public
  use strict arg report
  return report["total"] > 0 & report["totals"]["present"] = report["total"]

::method manifestPaths public
  use strict arg manifest
  s = .stream~new(manifest)
  if s~open("read") \= "READY:" then raise syntax 98.900 array("cannot read manifest" manifest)
  out = .array~new
  do while s~lines > 0
    line = s~lineIn~strip
    if line == "" | line~left(1) == "#" then iterate
    out~append(line)
  end
  s~close
  return out

::method inventoryOne public
  use strict arg checkout, relative
  record = .directory~new
  record["path"] = .JsonString~new(relative)
  record["status"] = "missing"
  source = checkout"/"relative
  if \sysFileExists(source) | sysIsFileDirectory(source) then return record
  s = .stream~new(source)
  s~open("read")
  data = s~charIn(1, s~chars)
  s~close
  text = data
  if text~left(3) == "EFBBBF"x then text = text~substr(4)           -- utf-8-sig
  lines = self~splitLines(text)
  includes = .array~new
  kinds = .directory~new
  do line over lines
    inc = self~quotedInclude(line)
    if inc \== .nil then includes~append(.JsonString~new(inc))
    kind = self~resourceKind(line)
    if kind \== "" then do
      if kinds~hasIndex(kind) then kinds[kind] += 1
      else kinds[kind] = 1
    end
  end
  folder = filespec("location", source)
  missing = .array~new
  do name over includes
    target = folder || name~changeStr("\", "/")
    if \sysFileExists(target) | sysIsFileDirectory(target) then missing~append(.JsonString~new(name))
  end
  if missing~items > 0 then record["status"] = "incomplete_includes"
  else record["status"] = "present"
  record["sha256"] = .JsonString~new(.SHA256~new(data)~digest)
  record["bytes"] = data~length
  record["lines"] = lines~items
  record["resource_kind_counts_heuristic"] = kinds
  record["local_includes"] = includes
  record["missing_local_includes"] = missing
  return record

/* Lines as Python str.splitlines() sees them for .rc text: \r\n, \r and \n
 * end a line; a final line ending does not start another line. */
::method splitLines public
  use strict arg text
  text = text~changeStr("0D0A"x, "0A"x)~changeStr("0D"x, "0A"x)
  out = .array~new
  if text == "" then return out
  if text~right(1) == "0A"x then text = text~left(text~length - 1)
  do forever                       -- "END" "0A0A"x is two lines: END and an empty one
    p = text~pos("0A"x)
    if p == 0 then do
      out~append(text)
      leave
    end
    out~append(text~left(p - 1))
    text = text~substr(p + 1)
  end
  return out

/* ^\s*#\s*include\s*"([^"]+)"   (case-insensitive) */
::method quotedInclude public
  use strict arg line
  rest = line~strip("L", " " || "09"x)
  if rest~left(1) \== "#" then return .nil
  rest = rest~substr(2)~strip("L", " " || "09"x)
  if rest~left(7)~upper \== "INCLUDE" then return .nil
  rest = rest~substr(8)~strip("L", " " || "09"x)
  if rest~left(1) \== '"' then return .nil
  close = rest~pos('"', 2)
  if close <= 2 then return .nil
  return rest~substr(2, close - 2)

/* ^\s*(?:[A-Za-z_]\w*|\d+)\s+(KIND)\b   (case-insensitive) -> KIND or "" */
::method resourceKind public
  use strict arg line
  text = line~translate(" ", "09"x)~strip("L")
  if text == "" then return ""
  space = text~pos(" ")
  if space == 0 then return ""
  first = text~left(space - 1)
  wordChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"
  if verify(first, wordChars) > 0 then return ""
  if \first~left(1)~datatype("M") & first~left(1) \== "_" then
    if \first~datatype("W") | verify(first, "0123456789") > 0 then return ""
  rest = text~substr(space)~strip("L")
  stop = verify(rest, wordChars)
  if stop == 0 then token = rest
  else token = rest~left(stop - 1)
  token = token~upper
  if wordpos(token, self~KINDS) > 0 then return token
  return ""

::requires "../../oorexx_crypto_v0.8.3/src/crypto.cls"
::requires "../../oorexx_logging_v0.7/src/LoggingCore.cls"
::requires "json.cls"
