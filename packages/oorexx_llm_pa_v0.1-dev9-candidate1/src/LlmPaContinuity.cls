/* Prepared handoff for a stateless LLM after chat compaction.
 * Reading this file is local and immediate; it never calls Gemma. */

::class LlmPaContinuityBrief public
::attribute path get
::attribute refreshSeconds get

::method init
  expose path refreshSeconds
  use arg pathArg, refreshArg = 900
  path = pathArg~string~strip
  refreshSeconds = refreshArg + 0
  if path = "" then raise syntax 88.900 array("continuity brief path is required")
  if refreshSeconds < 60 then raise syntax 88.900 array("continuity brief refresh must be at least 60 seconds")

::method publish
  expose path
  use arg briefArg, sourceArg = "gemma", generatedAtArg = ""
  brief = briefArg~string~strip
  if brief = "" then return .LlmPaResult~failure("CONTINUITY_BRIEF_EMPTY")
  if brief~length > 65536 then return .LlmPaResult~failure("CONTINUITY_BRIEF_TOO_LARGE", brief~length)
  source = sourceArg~string~strip
  if source = "" then source = "gemma"
  generatedAt = generatedAtArg~string~strip
  if generatedAt = "" then generatedAt = .LlmPaUtil~timestamp
  header = "LLMPA_CONTINUITY/2" || "09"x || generatedAt || "09"x || source || "09"x || time("S")
  call lineout path, header
  call lineout path, brief
  call lineout path
  ignore = stream(path, "C", "CLOSE")
  return .LlmPaResult~success(self~metadata(generatedAt, source, brief))

::method read
  expose path refreshSeconds
  header = linein(path)
  if header = "" then return .LlmPaResult~failure("CONTINUITY_BRIEF_UNAVAILABLE", path)
  tab = "09"x
  firstTab = header~pos(tab)
  secondTab = header~pos(tab, firstTab + 1)
  if firstTab = 0 | secondTab = 0 then return .LlmPaResult~failure("CONTINUITY_BRIEF_INVALID", "header fields missing")
  schema = header~left(firstTab - 1)
  generatedAt = header~substr(firstTab + 1, secondTab - firstTab - 1)
  source = header~substr(secondTab + 1)
  if schema \= "LLMPA_CONTINUITY/1" & schema \= "LLMPA_CONTINUITY/2" then return .LlmPaResult~failure("CONTINUITY_BRIEF_INVALID", schema)
  epochSeconds = ""
  if schema = "LLMPA_CONTINUITY/2" then do
    thirdTab = header~pos(tab, secondTab + 1)
    if thirdTab = 0 then return .LlmPaResult~failure("CONTINUITY_BRIEF_INVALID", "epoch missing")
    source = header~substr(secondTab + 1, thirdTab - secondTab - 1)
    epochSeconds = header~substr(thirdTab + 1)
  end
  brief = linein(path)
  ignore = stream(path, "C", "CLOSE")
  if brief = "" then return .LlmPaResult~failure("CONTINUITY_BRIEF_INVALID", "body missing")
  /* Briefs are deliberately one logical line in the first cut. Gemma should
   * use compact headings separated by semicolons or escaped newlines. */
  return .LlmPaResult~success(self~metadata(generatedAt, source, brief, epochSeconds))

::method needsRefresh
  use arg nowArg = .nil
  current = self~read
  if \current~ok then return .true
  generatedAt = current~value["generated_at"]
  epochSeconds = current~value["generated_epoch_seconds"]
  if epochSeconds <> "" then do
    nowSeconds = nowArg
    if nowArg == .nil then nowSeconds = time("S")
    if datatype(nowSeconds, "W") then return nowSeconds - epochSeconds >= refreshSeconds
  end
  /* Legacy v1 briefs have no epoch field; retain the conservative date test. */
  if generatedAt = "" then return .true
  if nowArg == .nil then nowArg = .LlmPaUtil~timestamp
  return generatedAt~left(8) \= nowArg~string~left(8)

::method metadata private
  use arg generatedAt, source, brief, epochSeconds = ""
  d = .directory~new
  d["available"] = .true
  d["generated_at"] = generatedAt
  d["source"] = source
  d["text"] = brief
  d["generated_epoch_seconds"] = epochSeconds
  d["delivery"] = "PREPARED_LOCAL_READ"
  return d

::requires "LlmPaCore.cls"
