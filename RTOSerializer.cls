/* ============================================================
 * RTOSerializer.cls  —  Runtime Object Serializer
 *
 * Modernised from the original rto.cls by Tom Dyer.
 * Uses built-in json.cls rather than a custom token protocol.
 *
 * Handles the full OORexx type spectrum:
 *   .nil          .true / .false
 *   String / Integer / Decimal
 *   Array  Directory  OrderedCollection  Queue  List  Set  Bag
 *   Custom objects — class reconstructed from stored method source
 *
 * Circular references are handled via an ID registry:
 *   first encounter  → encode fully with {"$id": N, ...}
 *   subsequent       → {"$ref": N}
 *
 * Public API:
 *   RTOSerializer~serialize(obj)        → JSON string
 *   RTOSerializer~deserialize(json)     → rebuilt object
 *   RTOSerializer~serializeSource(obj)  → include method source (default .true)
 * ============================================================ */

::class RTOSerializer public

/* ── Public class-method entry points ───────────────────── */

::method serialize class
  use arg obj
  if arg() < 1 then obj = .nil
  s = .RTOSerializer~new
  enc = s~_encode(obj)
  wrap = .Directory~new
  wrap["schema"]  = "oorexx.rto.v2"
  wrap["root"]    = enc
  wrap["classes"] = s~_classDefs
  json = .json~toJson(wrap)
  /* Debug: report what was captured */
  clsCount = s~_classDefs~items
  methodCount = 0
  do clsName over s~_classDefs~allIndexes
    methodCount = methodCount + s~_classDefs[clsName]~items
  end
  say "[RTOSerializer] captured:" clsCount "class(es)," methodCount "method(s) with source"
  return json

::method deserialize class
  use arg jsonStr, securityMgr
  if arg() < 2 then securityMgr = .nil
  d = .RTOSerializer~new
  wrap = .json~fromJson(jsonStr)
  d~_classDefs = wrap["classes"]
  obj = d~_decode(wrap["root"])
  /* Attach security manager to all reconstructed methods if supplied */
  if securityMgr \== .nil & obj \== .nil then
    d~_attachSecurity(obj, securityMgr)
  return obj

/* ── Instance ─────────────────────────────────────────────── */

::attribute _registry    /* Directory: id → encoded object (circular ref guard) */
::attribute _classDefs   /* Directory: className → method source Directory */
::attribute _nextId      /* Integer counter */
::attribute includeSource

::method init
  expose _registry _classDefs _nextId includeSource
  _registry    = .Directory~new
  _classDefs   = .Directory~new
  _nextId      = 0
  includeSource = .true


/* ── Encoder ─────────────────────────────────────────────── */

::method _nextRef private
  expose _nextId
  _nextId = _nextId + 1
  return _nextId

::method _encode
  expose _registry
  use arg val

  /* nil */
  if val == .nil then do
    d = .Directory~new; d["$t"] = "nil"; return d
  end

  /* Stream objects — OS handles don't survive process boundaries.
   * Encode as a typed marker carrying only the stream name/path.
   * The receiver creates a closed Stream; _rto_reconnect reopens it. */
  if val~isA(.Stream) then do
    d = .Directory~new
    d["$t"] = "stream"
    /* ~description returns implementation string; strip "Stream:" prefix if present */
    desc = val~description
    if desc~left(7)~upper = "STREAM:" then desc = desc~substr(8)~strip
    d["path"] = desc
    return d
  end

  /* booleans — check before String since .true isA .String in ooRexx */
  if val == .true then do
    d = .Directory~new; d["$t"] = "bool"; d["v"] = 1; return d
  end
  if val == .false then do
    d = .Directory~new; d["$t"] = "bool"; d["v"] = 0; return d
  end

  /* String (covers Integer and Decimal — all are strings in Rexx) */
  if val~isA(.String) then do
    d = .Directory~new
    d["$t"] = "str"
    d["v"]  = val
    return d
  end

  /* Collection types — all get an $id for circular reference detection */
  id = self~_checkRef(val)
  if id > 0 then do
    ref = .Directory~new; ref["$ref"] = id; return ref
  end
  id = self~_nextRef
  self~_registerRef(val, id)

  if val~isA(.Array) then          return self~_encArray(val, id)
  if val~isA(.Directory) then      return self~_encDirectory(val, id)
  if val~isA(.List) then           return self~_encList(val, id, "oc")
  if val~isA(.List) then           return self~_encList(val, id, "list")
  if val~isA(.Queue) then          return self~_encList(val, id, "queue")
  if val~isA(.Set) then            return self~_encList(val, id, "set")
  if val~isA(.Bag) then            return self~_encList(val, id, "bag")

  /* Custom object */
  return self~_encObject(val, id)

::method _checkRef private
  expose _registry
  use arg val
  /* Check if we've encoded this object before by identity */
  do k over _registry~allIndexes
    if _registry[k] == val then return k~strip + 0
  end
  return 0

::method _registerRef private
  expose _registry
  use arg val, id
  _registry[id~string] = val

::method _encArray private
  use arg arr, id
  d = .Directory~new
  d["$t"] = "arr"; d["$id"] = id
  items = .Array~new
  do i = 1 to arr~size
    if arr~hasIndex(i) then items~append(self~_encode(arr[i]))
    else items~append(.nil)
  end
  d["v"] = items
  return d

::method _encDirectory private
  use arg dir, id
  d = .Directory~new
  d["$t"] = "dir"; d["$id"] = id
  entries = .Directory~new
  do k over dir~allIndexes
    entries[k] = self~_encode(dir[k])
  end
  d["v"] = entries
  return d

::method _encList private
  use arg col, id, typeName
  d = .Directory~new
  d["$t"] = typeName; d["$id"] = id
  items = .Array~new
  do item over col; items~append(self~_encode(item)); end
  d["v"] = items
  return d

::method _encObject private
  expose _classDefs includeSource
  use arg obj, id
  cls     = obj~class
  clsName = cls~id

  /* Capture method source for class reconstruction */
  if includeSource & \(_classDefs~hasIndex(clsName)) then
    self~_captureClass(cls)

  /* Capture state — explicit protocol preferred over introspection.
   * If the class defines ~_rto_export, use it.  Otherwise fall back
   * to looking for setter methods (works when method~source is available). */
  attrs = .Directory~new
  /* Merge explicit method source export if available */
  if obj~hasMethod("_RTO_SOURCES") then do
    clsName2 = cls~id
    extraSrc  = obj~send("_RTO_SOURCES")
    if \(_classDefs~hasIndex(clsName2)) then _classDefs[clsName2] = .Directory~new
    do k over extraSrc~allIndexes
      _classDefs[clsName2][k] = extraSrc[k]
    end
  end

  if obj~hasMethod("_RTO_EXPORT") then do
    raw = obj~send("_RTO_EXPORT")
    do k over raw~allIndexes
      v = raw[k]
      if v \== .nil & \v~isA(.Alarm) then
        attrs[k] = self~_encode(v)
    end
  end
  else do
    skipKeys = .Set~of("_ALARM", "CLASS")
    mSup     = cls~instanceMethods(cls)
    do while mSup~available
      mName = mSup~index
      if mName~right(1) = "=" then do
        attrName = mName~left(mName~length - 1)
        if \skipKeys~hasIndex(attrName) then do
          attrVal = obj~send(attrName)
          if attrVal \== .nil & \attrVal~isA(.Alarm) then
            attrs[attrName] = self~_encode(attrVal)
        end
      end
      mSup~next
    end
  end

  /* Detect mixins by duck-typing known marker interfaces */
  mixins = .Array~new
  if obj~isA(.AlarmNotification) then mixins~append("ALARMNOTIFICATION")

  d = .Directory~new
  d["$t"]       = "obj"
  d["$id"]      = id
  d["cls"]      = clsName
  d["mixins"]   = mixins
  d["attrs"]    = attrs
  return d

::method _captureClass private
  expose _classDefs
  use arg cls
  clsName  = cls~id
  methods  = .Directory~new
  mSup     = cls~instanceMethods(cls)
  do while mSup~available
    mName = mSup~index
    meth  = mSup~item
    src   = meth~source
    if src~isA(.Array) & src~items > 0 then do
      lines = .Array~new
      do line over src; lines~append(line); end
      methods[mName] = lines
    end
    mSup~next
  end
  _classDefs[clsName] = methods


/* ── Decoder ─────────────────────────────────────────────── */

::method _decode
  expose _registry _classDefs
  use arg enc

  if enc == .nil then return .nil
  if \enc~isA(.Directory) then return enc

  t = enc["$t"]
  if t == .nil then return enc

  select
    when t = "nil"  then return .nil
    when t = "bool" then do
      if enc["v"] = 1 then return .true; return .false
    end
    when t = "str"    then return enc["v"]
    when t = "stream" then do
      /* Restore as a closed Stream object — caller must reconnect */
      path = enc["path"]
      if path \== .nil & path \= "" then return .Stream~new(path)
      return .nil
    end
    when t = "arr"  then return self~_decArray(enc)
    when t = "dir"  then return self~_decDirectory(enc)
    when t = "oc"   then return self~_decList(enc, .List~new)
    when t = "list" then return self~_decList(enc, .List~new)
    when t = "queue" then return self~_decList(enc, .Queue~new)
    when t = "set"  then return self~_decList(enc, .Set~new)
    when t = "bag"  then return self~_decList(enc, .Bag~new)
    when t = "obj"  then return self~_decObject(enc)
    otherwise
      /* $ref — look up registered object */
      ref = enc["$ref"]
      if ref \== .nil then return _registry[ref~string]
      return .nil
  end

::method _decArray private
  expose _registry
  use arg enc
  arr = .Array~new
  id  = enc["$id"]
  if id \== .nil then _registry[id~string] = arr
  do item over enc["v"]
    arr~append(self~_decode(item))
  end
  return arr

::method _decDirectory private
  expose _registry
  use arg enc
  dir = .Directory~new
  id  = enc["$id"]
  if id \== .nil then _registry[id~string] = dir
  entries = enc["v"]
  do k over entries~allIndexes
    dir[k] = self~_decode(entries[k])
  end
  return dir

::method _decList private
  expose _registry
  use arg enc, col
  id = enc["$id"]
  if id \== .nil then _registry[id~string] = col
  do item over enc["v"]
    val = self~_decode(item)
    /* Each collection type has its own add method */
    if col~isA(.Set)   then col~put(val)
    else if col~isA(.Bag)   then col~put(val)
    else if col~isA(.Queue) then col~queue(val)
    else col~append(val)   /* Array, List, OrderedCollection */
  end
  return col

::method _decObject private
  expose _registry _classDefs
  use arg enc

  clsName = enc["cls"]
  mixins  = enc["mixins"]
  attrs   = enc["attrs"]
  id      = enc["$id"]

  /* Reconstruct the class from stored method source */
  newClass = .Object~subclass(clsName)

  /* Apply mixins */
  do mixin over mixins
    if mixin = "ALARMNOTIFICATION" then
      newClass~inherit(.AlarmNotification)
  end

  /* Define methods from stored source */
  clsMethods = _classDefs[clsName]
  if clsMethods \== .nil then do
    do mName over clsMethods~allIndexes
      srcLines = clsMethods[mName]
      src      = .Array~new
      do line over srcLines; src~append(line); end
      newClass~define(mName, .Method~new("", src))
    end
  end

  /* ── Proxy class ───────────────────────────────────────────
   * Create a proxy subclass of the reconstructed class.
   * Methods defined on the proxy run in obj's class scope —
   * expose, setMethod, etc. are all permitted from there.
   * The proxy IS the instance; it inherits everything from
   * newClass including any captured methods and mixins. */
  /* Build bootstrap — defines on newClass (same scope as TICK/STOP/REPORT)
   * All defines BEFORE first instantiation. No proxy subclass — a proxy
   * would create a separate variable scope, leaving TICK's expose looking
   * at uninitialised variables while bootstrap set them in proxy scope. */
  exposeList = ""
  do attrName over attrs~allIndexes
    exposeList = exposeList || " " || attrName~lower
  end
  bStr = "expose" || exposeList || "; use arg d"
  do attrName over attrs~allIndexes
    bStr = bStr || "; " || attrName~lower || " = d['" || attrName || "']"
  end
  newClass~define("_rto_bootstrap", bStr)
  newClass~define("_rto_restart", ,
    "expose _running _interval _alarm; _running = .true; " || ,
    "_alarm = .Alarm~new(_interval, .Message~new(self, 'tick'))")

  do attrName over attrs~allIndexes
    aLower = attrName~lower
    newClass~define(attrName, "expose " || aLower || "; return " || aLower)
  end

  obj = newClass~new
  if id \== .nil then _registry[id~string] = obj

  rawAttrs = .Directory~new
  do attrName over attrs~allIndexes
    rawAttrs[attrName] = self~_decode(attrs[attrName])
  end
  obj~send("_rto_bootstrap", rawAttrs)
  say "[RTOSerializer] state restored (newClass scope)"

  /* Give the object a chance to reopen OS resources (streams, sockets)
   * that can't survive transport.  The receiver may supply a path override. */
  if obj~hasMethod("_RTO_RECONNECT") then do
    say "[RTOSerializer] calling _rto_reconnect..."
    .Message~new(obj, "_RTO_RECONNECT")~send
  end

  runningEnc = attrs["_RUNNING"]
  if runningEnc \== .nil then do
    wasRunning = self~_decode(runningEnc)
    if wasRunning == .true then do
      if obj~hasMethod("START") then do
        say "[RTOSerializer] object was running — restarting..."
        .Message~new(obj, "_rto_restart")~send
      end
    end
  end

  return obj

::method _attachSecurity private
  use arg obj, mgr
  /* Attach the security manager to every method defined on the
   * reconstructed class — method~setSecurityManager sandboxes
   * execution of that method */
  mSup = obj~class~instanceMethods(obj~class)
  count = 0
  do while mSup~available
    meth = mSup~item
    meth~setSecurityManager(mgr)
    count = count + 1
    mSup~next
  end
  say "[RTOSerializer] security manager attached to" count "methods"

::requires "json.cls"