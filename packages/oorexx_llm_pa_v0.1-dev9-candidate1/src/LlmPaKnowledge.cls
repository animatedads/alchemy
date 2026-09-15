/* Read-only local operational knowledge catalogue.
 * The PA may search only files already placed in the configured knowledge
 * directory by the operator/deployment. It receives no arbitrary filesystem
 * read capability through this class.
 */

::class LlmPaKnowledgeStore public
::attribute root get

::method init
  expose root
  use arg rootArg
  root = rootArg~string~strip
  if root = "" then raise syntax 88.900 array("LLM PA knowledge root is required")

::method context public
  expose root
  use arg queryArg = "", limitArg = 6
  query = queryArg~string~strip
  limit = limitArg
  if datatype(limit, "W") = 0 | limit < 1 then limit = 6
  exact = .array~new
  named = .array~new
  partial = .array~new
  mask = root || "/*"
  call SysFileTree mask, "files.", "FO"
  do i = 1 to files.0
    path = files.i~string
    lowerPath = path~lower
    if lowerPath~right(3) \= ".md" & lowerPath~right(4) \= ".txt" & lowerPath~right(5) \= ".help" then iterate
    text = self~readBounded(path, 12000)
    topic = self~topicFor(path)
    rec = self~record(topic, path, text)
    if query = "" then partial~append(rec)
    else do
      q = self~normalise(query)
      topicNorm = self~normalise(topic)
      textNorm = self~normalise(text)
      if q = topicNorm then exact~append(rec)
      else if q~pos(topicNorm) > 0 & topicNorm~length >= 2 then named~append(rec)
      else if topicNorm~pos(q) > 0 & q~length >= 2 then named~append(rec)
      else if self~tokenHit(q, topicNorm) then named~append(rec)
      else if textNorm~pos(q) > 0 | self~tokenHit(q, textNorm) then partial~append(rec)
    end
  end
  out = .array~new
  do rec over exact
    if out~items >= limit then leave
    out~append(rec)
  end
  do rec over named
    if out~items >= limit then leave
    out~append(rec)
  end
  do rec over partial
    if out~items >= limit then leave
    out~append(rec)
  end
  return .LlmPaResult~success(out)

::method topicFor private
  use arg pathArg
  path = pathArg~string
  slash = path~lastPos("/")
  if slash > 0 then name = path~substr(slash + 1)
  else name = path
  dot = name~lastPos(".")
  if dot > 1 then name = name~left(dot - 1)
  return name

::method normalise private
  use arg textArg
  text = textArg~string~lower
  do ch over .array~of(",", ";", ":", "(", ")", "[", "]", "{", "}", '"', "'", "?", "!", "=", "`", "*", "#", "0a"x, "0d"x, "09"x)
    text = text~changestr(ch, " ")
  end
  return space(text)

::method tokenHit private
  use arg queryNorm, haystackNorm
  do i = 1 to words(queryNorm)
    token = word(queryNorm, i)
    if token~length < 3 then iterate
    if haystackNorm~pos(token) > 0 then return .true
    if token~right(3) = ".sh" then do
      stem = token~left(token~length - 3)
      if stem~length >= 3 & haystackNorm~pos(stem) > 0 then return .true
    end
  end
  return .false

::method readBounded private
  use arg pathArg, maxCharsArg = 12000
  path = pathArg~string
  maxChars = maxCharsArg
  text = ""
  if stream(path, "c", "query exists") = "" then return text
  call stream path, "c", "open read"
  do while lines(path) > 0
    line = linein(path)
    if text = "" then candidate = line
    else candidate = text || "0a"x || line
    if candidate~length > maxChars then do
      remaining = maxChars - text~length
      if remaining > 1 then text = text || "0a"x || line~left(remaining - 1)
      leave
    end
    text = candidate
  end
  call stream path, "c", "close"
  return text

::method record private
  use arg topicArg, pathArg, textArg
  rec = .directory~new
  rec["topic"] = topicArg~string
  rec["path"] = pathArg~string
  rec["text"] = textArg~string
  rec["source_kind"] = "LOCAL_FILE"
  rec["authority"] = "LOCAL_KNOWLEDGE"
  return rec

::requires "LlmPaCore.cls"
