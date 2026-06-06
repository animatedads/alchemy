/* ============================================================
 * RTOTransport.cls  —  Transport layer
 *
 * Pipeline:   object
 *               ↓  RTOSerializer~serialize
 *             JSON string
 *               ↓  ~toBase64
 *             base64 string (single line, no wrapping)
 *               ↓  ~md5
 *             transport envelope  { schema, md5, payload }
 *               ↓  ~send
 *             OORexx Queue  (.local["rto.transport.queue"])
 *             OR file queue  (/tmp/rto_queue.json)
 *               ↑  ~receive
 *             verify MD5
 *               ↑  ~fromBase64
 *             JSON string
 *               ↑  RTOSerializer~deserialize
 *             reconstructed object
 *
 * Two transport modes:
 *   in-process:  uses .local Queue (sender and receiver in same session)
 *   cross-process: uses /tmp/rto_queue.json as persistent file queue
 *
 * Usage:
 *   .RTOTransport~send(jsonStr)
 *   jsonStr = .RTOTransport~receive()
 * ============================================================ */

::class RTOTransport public

::attribute queueFile class    /* cross-process queue file path */

::method init class
  self~queueFile = "/tmp/rto_transport_queue.json"

/* ── Public send/receive ──────────────────────────────────── */

::method send class
  use arg jsonStr
  b64      = self~toBase64(jsonStr)
  md5      = self~md5(b64)
  envelope = .Directory~new
  envelope["schema"]  = "oorexx.transport.v1"
  envelope["md5"]     = md5
  envelope["payload"] = b64
  envJson  = .json~toJson(envelope)
  self~_pushToQueue(envJson)
  say "[Transport]  sent" jsonStr~length "bytes  →  b64:" b64~length "  md5:" md5

::method receive class
  envJson = self~_pullFromQueue
  if envJson == .nil | envJson = "" then do
    say "[Transport]  queue is empty"
    return .nil
  end
  envelope = .json~fromJson(envJson)
  b64      = envelope["payload"]
  md5      = envelope["md5"]
  computed = self~md5(b64)
  if computed \= md5 then do
    say "[Transport]  MD5 MISMATCH  expected:" md5 "  got:" computed
    return .nil
  end
  say "[Transport]  MD5 verified:" md5
  return self~fromBase64(b64)


/* ── Base64 ───────────────────────────────────────────────── */

::method toBase64 class
  use arg text
  return text~encodeBase64

::method fromBase64 class
  use arg b64
  return b64~decodeBase64


/* ── MD5 ──────────────────────────────────────────────────── */

::method md5 class
  use arg text
  h = .md5~new(text)
  return h~digest


/* ── Queue: in-process (.local) or cross-process (file) ──── */

::method _pushToQueue class
  use arg data

  /* In-process: .local Queue */
  q = .local["rto.transport.queue"]
  if q == .nil then do
    q = .Queue~new
    .local["rto.transport.queue"] = q
  end
  q~queue(data)

  /* Cross-process: also persist to file */
  self~_filePush(data)

::method _pullFromQueue class
  /* Try in-process first — nested if because & never short-circuits */
  q = .local["rto.transport.queue"]
  if q \== .nil then
    if \q~isEmpty then
      return q~pull

  /* Fall back to file queue */
  return self~_filePull

::method _filePush class
  use arg data
  qf = self~queueFile
  items = self~_fileLoad
  items~append(data)
  self~_fileSave(items)

::method _filePull class
  qf    = self~queueFile
  items = self~_fileLoad
  if items~items = 0 then return .nil
  first = items~at(1)
  rest  = .Array~new
  do i = 2 to items~items; rest~append(items~at(i)); end
  self~_fileSave(rest)
  return first

::method _fileLoad class
  qf = self~queueFile
  if \SysFileExists(qf) then return .Array~new
  s = .Stream~new(qf); s~open("READ")
  txt = s~charIn(, s~chars); s~close
  if txt~strip = "" then return .Array~new
  parsed = .json~fromJson(txt)
  if parsed~isA(.Array) then return parsed
  return .Array~new

::method _fileSave class
  use arg items
  qf  = self~queueFile
  txt = .json~toJson(items)
  s   = .Stream~new(qf); s~open("WRITE REPLACE")
  rc  = s~charOut(txt); s~close

::requires "json.cls"
::requires "crypto.cls"
