/* Controlled read-only LLM Gopher evidence function for the PA.
 *
 * The model never receives an arbitrary command executor. User text is used
 * only for local sphere/article scoring. Gopher itself is invoked solely with
 * validated sphere/article IDs originating from the bundled catalogue or a
 * Gopher context response. Mutating Gopher surfaces are intentionally absent.
 */

::class LlmPaGopherTool public
::attribute name get
::attribute accessMode get
::attribute eventable get
::attribute mutating get
::attribute authorityClass get
::attribute gopherRoot get
::attribute sphereRoot get
::attribute envRoot get

::method init
  expose name accessMode eventable mutating authorityClass gopherRoot sphereRoot envRoot catalogPath catalog
  use arg gopherRootArg, sphereRootArg, envRootArg, catalogPathArg
  gopherRoot = gopherRootArg~string~strip
  sphereRoot = sphereRootArg~string~strip
  envRoot = envRootArg~string~strip
  catalogPath = catalogPathArg~string~strip
  if gopherRoot = "" | sphereRoot = "" | envRoot = "" | catalogPath = "" then raise syntax 88.900 array("Gopher tool paths are required")
  name = "gopher_read"
  accessMode = "READ_ONLY"
  eventable = .true
  mutating = .false
  authorityClass = "EVIDENCE_ONLY"
  catalog = self~loadCatalog

::method probe public
  expose gopherRoot envRoot
  r = self~runBuiltInContext("gemma-oorexx")
  if \r~ok then return r
  payload = r~value
  if payload == .nil then return .LlmPaResult~failure("GOPHER_PROBE_INVALID")
  if \payload~hasIndex("schema") then return .LlmPaResult~failure("GOPHER_PROBE_INVALID", "missing schema")
  if payload["schema"]~string~left(15) \= "llm-gopher/0.21" then return .LlmPaResult~failure("GOPHER_VERSION_UNEXPECTED", payload["schema"])
  return .LlmPaResult~success(payload)

::method invoke public
  expose catalog
  use arg queryArg
  query = queryArg~string~strip
  if query = "" then return .LlmPaResult~failure("GOPHER_QUERY_REQUIRED")
  selected = self~selectSphere(query)
  if selected == .nil then do
    d = .directory~new
    d["matched"] = .false
    d["query"] = query
    return .LlmPaResult~success(d)
  end
  sphere = selected["id"]
  activated = self~activate(selected)
  if \activated~ok then return activated
  context = self~runContext(sphere)
  if \context~ok then return context
  articles = context~value["result"]["articles"]
  article = self~selectArticle(query, articles)
  d = .directory~new
  d["matched"] = .true
  d["query"] = query
  d["sphere"] = sphere
  d["sphere_title"] = selected["title"]
  d["sphere_version"] = selected["version"]
  d["sphere_archive"] = selected["archive"]
  d["access_mode"] = "READ_ONLY"
  d["authority_class"] = "EVIDENCE_ONLY"
  if activated~value \== .nil then do
    if activated~value~hasIndex("archive_sha256") then d["sphere_sha256"] = activated~value["archive_sha256"]~string
  end
  if article == .nil then do
    d["evidence_kind"] = "context"
    d["context"] = self~detachValue(context~value["result"])
    return .LlmPaResult~success(d)
  end
  opened = self~runOpen(sphere, article["id"])
  if \opened~ok then return opened
  articleData = opened~value["result"]
  d["evidence_kind"] = "article"
  d["article_id"] = articleData["id"]~string
  d["article_title"] = articleData["title"]~string
  if articleData~hasIndex("section") then d["section"] = articleData["section"]~string
  if articleData~hasIndex("summary") then d["summary"] = articleData["summary"]~string
  if articleData~hasIndex("authority") then d["article_authority"] = articleData["authority"]~string
  if articleData~hasIndex("provenance") then d["provenance"] = self~detachValue(articleData["provenance"])
  if articleData~hasIndex("invariants") then d["invariants"] = self~detachValue(articleData["invariants"])
  if opened~value~hasIndex("evidence") then do
    ev = opened~value["evidence"]
    if ev~hasIndex("article_digest") then d["article_digest"] = ev["article_digest"]~string
  end
  return .LlmPaResult~success(d)

::method catalogSummary public
  expose catalog
  out = .array~new
  do rec over catalog
    d = .directory~new
    d["id"] = rec["id"]
    d["title"] = rec["title"]
    d["version"] = rec["version"]
    out~append(d)
  end
  return .LlmPaResult~success(out)

::method activate private
  use arg selected
  archive = selected["archive"]~string
  sphere = selected["id"]~string
  if archive = "(builtin)" then return .LlmPaResult~success(.directory~new)
  if self~safeId(sphere) = .false then return .LlmPaResult~failure("GOPHER_SPHERE_ID_INVALID", sphere)
  fullArchive = self~sphereArchivePath(archive)
  args = "sphere load " || sphere || " --override " || self~shellQuote(fullArchive) || " --env " || self~shellQuote(self~envRoot)
  r = self~run(args)
  if \r~ok then return r
  payload = r~value
  if \self~toolOk(payload) then return .LlmPaResult~failure("GOPHER_SPHERE_LOAD_FAILED", self~statusDetail(payload))
  d = .directory~new
  loadData = payload["result"]
  if loadData~hasIndex("selected") then do
    s = loadData["selected"]
    if s~hasIndex("archive_sha256") then d["archive_sha256"] = s["archive_sha256"]~string
  end
  return .LlmPaResult~success(d)

::method runContext private
  use arg sphere
  if self~safeId(sphere) = .false then return .LlmPaResult~failure("GOPHER_SPHERE_ID_INVALID", sphere)
  r = self~run("--profile " || sphere || " context " || sphere)
  if \r~ok then return r
  if \self~toolOk(r~value) then return .LlmPaResult~failure("GOPHER_CONTEXT_FAILED", self~statusDetail(r~value))
  return r

::method runBuiltInContext private
  use arg sphere
  if self~safeId(sphere) = .false then return .LlmPaResult~failure("GOPHER_SPHERE_ID_INVALID", sphere)
  r = self~run("--profile " || sphere || " context " || sphere)
  if \r~ok then return r
  if \self~toolOk(r~value) then return .LlmPaResult~failure("GOPHER_CONTEXT_FAILED", self~statusDetail(r~value))
  return r

::method runOpen private
  use arg sphere, article
  if self~safeId(sphere) = .false then return .LlmPaResult~failure("GOPHER_SPHERE_ID_INVALID", sphere)
  if self~safeId(article) = .false then return .LlmPaResult~failure("GOPHER_ARTICLE_ID_INVALID", article)
  r = self~run("--profile " || sphere || " open " || article)
  if \r~ok then return r
  if \self~toolOk(r~value) then return .LlmPaResult~failure("GOPHER_OPEN_FAILED", self~statusDetail(r~value))
  return r

::method run private
  expose gopherRoot envRoot sphereRoot
  use arg args
  gopher = gopherRoot || "/gopher"
  work = envRoot || "/work"
  ignore = self~mkdir(work)
  stamp = date("S") || "-" || time("L")~changestr(":", "")~changestr(".", "") || "-" || random(1000,9999)
  outPath = work || "/pa-gopher-" || stamp || ".json"
  errPath = work || "/pa-gopher-" || stamp || ".err"
  cmd = "LLM_GOPHER_ENV=" || self~shellQuote(envRoot) || " LLM_GOPHER_SPHERE_OVERRIDE_DIR=" || self~shellQuote(sphereRoot) || " " || -
        self~shellQuote(gopher) || " " || args || " >" || self~shellQuote(outPath) || " 2>" || self~shellQuote(errPath)
  address command cmd
  cmdRc = rc
  text = self~readFile(outPath, 1048576)
  errText = self~readFile(errPath, 16384)
  ignore = self~removeFile(outPath)
  ignore = self~removeFile(errPath)
  if text = "" then return .LlmPaResult~failure("GOPHER_NO_RESPONSE", "rc=" || cmdRc || " " || errText)
  signal on syntax name badJson
  payload = .JSON~fromJSON(text)
  signal off syntax
  return .LlmPaResult~success(payload)
badJson:
  signal off syntax
  return .LlmPaResult~failure("GOPHER_INVALID_JSON", text~left(500))

::method detachValue private
  use arg value
  if value == .nil then return ""
  classId = value~class~id
  if classId = "String" then return value~string
  if classId = "Array" then do
    out = .array~new
    do item over value
      out~append(self~detachValue(item))
    end
    return out
  end
  if classId = "Directory" | classId = "Table" | classId = "IdentityTable" then do
    out = .directory~new
    supplier = value~supplier
    do while supplier~available
      key = supplier~index~string
      out[key] = self~detachValue(supplier~item)
      supplier~next
    end
    return out
  end
  /* JSON helper objects (for example JsonBoolean/JsonNull) are evidence
   * values, never authority-bearing objects. Flatten them to detached text
   * before crossing Queue Fabric's persistent payload boundary. */
  return value~string

::method selectSphere private
  expose catalog
  use arg query
  q = self~normalise(query)
  tokens = self~tokens(q)
  best = .nil
  bestScore = 0
  do rec over catalog
    id = rec["id"]~string~lower
    title = rec["title"]~string~lower
    terms = rec["terms"]~string~lower
    score = 0
    idWords = id~changestr("-", " ")
    if q~pos(id) > 0 | q~pos(idWords) > 0 then score = score + 100
    do token over tokens
      if id~pos(token) > 0 then score = score + 12
      else if title~pos(token) > 0 then score = score + 7
      else if terms~pos(token) > 0 then score = score + 1
    end
    if score > bestScore then do
      bestScore = score
      best = rec
    end
  end
  /* One weak corpus-word overlap is not enough to route a PA question. */
  if bestScore < 3 then return .nil
  return best

::method selectArticle private
  use arg query, articles
  if articles == .nil then return .nil
  q = self~normalise(query)
  tokens = self~tokens(q)
  best = .nil
  bestScore = -1
  fallback = .nil
  do article over articles
    id = article["id"]~string~lower
    title = article["title"]~string~lower
    section = ""
    if article~hasIndex("section") then section = article["section"]~string~lower
    if fallback == .nil then do
      if section = "start" | id~right(6) = ".start" | title~left(10) = "start here" then fallback = article
    end
    text = id || " " || title || " " || section
    if article~hasIndex("topics") then do topic over article["topics"]
      text = text || " " || topic~string~lower
    end
    score = 0
    do token over tokens
      if id~pos(token) > 0 then score = score + 8
      else if title~pos(token) > 0 then score = score + 5
      else if text~pos(token) > 0 then score = score + 1
    end
    if score > bestScore then do
      bestScore = score
      best = article
    end
  end
  if bestScore <= 0 & fallback \== .nil then return fallback
  return best

::method loadCatalog private
  expose catalogPath
  out = .array~new
  do while lines(catalogPath) > 0
    line = linein(catalogPath)
    parts = line~makeArray("09"x)
    if parts == .nil | parts~items < 5 then iterate
    d = .directory~new
    d["id"] = parts[1]
    d["version"] = parts[2]
    d["title"] = parts[3]
    d["archive"] = parts[4]
    d["terms"] = parts[5]
    out~append(d)
  end
  call stream catalogPath, "c", "close"
  return out

::method tokens private
  use arg q
  out = .array~new
  seen = .directory~new
  do i = 1 to words(q)
    token = word(q, i)~strip
    if token~length < 3 then iterate
    if self~stopword(token) then iterate
    if seen~hasIndex(token) then iterate
    seen[token] = .true
    out~append(token)
  end
  return out

::method stopword private
  use arg token
  stop = "the and for with from what when where which who why how does did are was were have has had about into your our this that then than can could would should will just tell explain please use using help more some any all its it's codex gemma"
  return wordpos(token, stop) > 0

::method normalise private
  use arg textArg
  text = textArg~string~lower
  do ch over .array~of(",", ";", ":", "(", ")", "[", "]", "{", "}", '"', "'", "?", "!", "=", "/", "\\")
    text = text~changestr(ch, " ")
  end
  return space(text)

::method toolOk private
  use arg payload
  if payload == .nil then return .false
  if \payload~hasIndex("tool_status") then return .false
  status = payload["tool_status"]
  if status == .nil then return .false
  if \status~hasIndex("class") then return .false
  return status["class"] = "OK"

::method statusDetail private
  use arg payload
  detail = ""
  if payload \== .nil then do
    if payload~hasIndex("operation_status") then do
      op = payload["operation_status"]
      if op~hasIndex("class") then detail = op["class"]
    end
  end
  return detail

::method safeId private
  use arg valueArg
  value = valueArg~string
  if value = "" then return .false
  allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
  return verify(value, allowed) = 0

::method sphereArchivePath private
  expose sphereRoot
  use arg archive
  return sphereRoot || "/" || archive

::method shellQuote private
  use arg textArg
  text = textArg~string
  if text~pos("'") > 0 then raise syntax 88.900 array("Gopher path contains unsupported quote")
  return "'" || text || "'"

::method mkdir private
  use arg path
  address command "mkdir -p " || self~shellQuote(path)
  return rc = 0

::method removeFile private
  use arg path
  address command "rm -f " || self~shellQuote(path)
  return rc = 0

::method readFile private
  use arg path, maxBytes = 1048576
  text = ""
  if stream(path, "c", "query exists") = "" then return text
  do while lines(path) > 0
    line = linein(path)
    if text = "" then text = line
    else text = text || "0a"x || line
    if text~length >= maxBytes then leave
  end
  call stream path, "c", "close"
  return text~left(maxBytes)

::requires "LlmPaCore.cls"
::requires "json.cls"
