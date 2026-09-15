::class GeminiPokerStrategy public subclass PlayerStrategy
::attribute client get
::attribute fallback get
::method init
  expose client fallback
  use arg client, fallback
  forward class (super) array("gemini-agent", 0.50, 0.00, 1.00) continue
  self~recordRelationship("AI_CLIENT", client, "Gemini decision provider", "INTERNAL")
  self~recordRelationship("FALLBACK_STRATEGY", fallback, "deterministic fallback", "INTERNAL")
::method strategyType
  return "AI_GEMINI"
::method description
  expose client
  return "AI agent provider=Google model=" || client~model || " information=ordinary-player-view"
::method decide
  expose client fallback
  use arg player, table, toCall, minRaise, canRaise = .true
  prompt = table~agentPrompt(player, toCall, minRaise, canRaise)
  shadowMode = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
  probeMode = 0
  if shadowMode = "1" then probeMode = 1
  else if shadowMode = "2" then probeMode = 2
  probeEnabled = .false
  if probeMode > 0 then do
    if client~hasMethod("DECIDEWITHTEMPERATURE") then probeEnabled = .true
  end
  if probeEnabled then reply = client~decideWithTemperature(prompt, 0)
  else reply = client~decide(prompt)
  if reply == .nil then return fallback~decide(player, table, toCall, minRaise, canRaise)
  action = reply["action"]~upper
  amount = reply["amount"]
  if action = "FOLD" & toCall = 0 then action = "CHECK"
  if action = "CHECK" & toCall > 0 then action = "FOLD"
  if action = "CALL" & toCall = 0 then action = "CHECK"
  if action = "RAISE" & \canRaise then do
    if toCall > 0 then action = "CALL"
    else action = "CHECK"
  end
  if action = "RAISE" then do
    if \datatype(amount, "W") then amount = minRaise
    if amount < minRaise then amount = minRaise
  end
  else amount = 0
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (table~pot + toCall)
  talkToken = ""
  talkTarget = ""
  socialEvidenceId = "NONE"
  if reply~hasIndex("talk") then talkToken = reply["talk"]~strip~upper
  if reply~hasIndex("talk_target") then talkTarget = reply["talk_target"]~strip
  if reply~hasIndex("social_evidence") then socialEvidenceId = reply["social_evidence"]~strip~upper

  controlAction = ""
  controlAmount = 0
  if probeEnabled then do
    if probeMode = 2 then do
      controlReply = client~decideWithTemperature(prompt, 0)
      controlDecision = self~normalizeProbeReply(controlReply, toCall, minRaise, canRaise)
      if controlDecision \= .nil then do
        controlAction = controlDecision["action"]
        controlAmount = controlDecision["amount"]
      end
    end
  end

  shadowAction = ""
  shadowAmount = 0
  if probeEnabled then do
    shadowPrompt = table~agentPrompt(player, toCall, minRaise, canRaise, .false)
    shadowReply = client~decideWithTemperature(shadowPrompt, 0)
    shadowDecision = self~normalizeProbeReply(shadowReply, toCall, minRaise, canRaise)
    if shadowDecision \= .nil then do
      shadowAction = shadowDecision["action"]
      shadowAmount = shadowDecision["amount"]
    end
  end
  return .Decision~new(action, amount, 0, potOdds, 0, talkToken, talkTarget, socialEvidenceId, shadowAction, shadowAmount, controlAction, controlAmount)

::method normalizeProbeReply private
  use arg reply, toCall, minRaise, canRaise
  if reply == .nil then return .nil
  d = .directory~new
  probeAction = reply["action"]~upper
  probeAmount = reply["amount"]
  if probeAction = "FOLD" then do
    if toCall = 0 then probeAction = "CHECK"
  end
  if probeAction = "CHECK" then do
    if toCall > 0 then probeAction = "FOLD"
  end
  if probeAction = "CALL" then do
    if toCall = 0 then probeAction = "CHECK"
  end
  if probeAction = "RAISE" then do
    if \canRaise then do
      if toCall > 0 then probeAction = "CALL"
      else probeAction = "CHECK"
      probeAmount = 0
    end
    else do
      if \datatype(probeAmount, "W") then probeAmount = minRaise
      if probeAmount < minRaise then probeAmount = minRaise
    end
  end
  else probeAmount = 0
  d["action"] = probeAction
  d["amount"] = probeAmount
  return d


::class GeminiAPIClient public subclass PokerAlchemyObject
::attribute model get
::attribute endpointBase get
::attribute timeout get
::attribute lastRaw get

::method init
  expose model endpointBase timeout lastRaw
  use arg model = "gemini-3.6-flash", endpointBase = "https://generativelanguage.googleapis.com/v1beta/models/", timeout = 60
  lastRaw = ""
  self~initPokerAlchemy("AI_CLIENT_GEMINI", "Google Gemini HTTP decision client")
  self~registerStateVariable("model", "CUSTOMER", "configured Gemini model")
  self~registerStateVariable("endpointBase", "INTERNAL", "configured Gemini endpoint base")
  self~registerStateVariable("timeout", "INTERNAL", "HTTP timeout seconds")
  self~registerEnvironmentRequirement("GEMINI_API_KEY", "optional; absence activates deterministic fallback", .false)
  self~registerExternalRequirement("service", "Google Generative Language API", "v1beta", .false)
  self~registerMethodContract("DECIDEWITHTEMPERATURE", "Request one constrained poker decision from Gemini", .array~of("PROMPT", "TEMPERATURE"), "ANY", .false, "AUTO", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")

::method decide
  use arg prompt
  return self~decideWithTemperature(prompt, 0.2)

::method decideWithTemperature
  expose model endpointBase timeout lastRaw
  use arg prompt, temperature = 0.2
  self~alchemyTouch("AI_DECIDE")
  apiKey = value("GEMINI_API_KEY",, "ENVIRONMENT")
  if apiKey = "" then do
    say "GEMINI unavailable: GEMINI_API_KEY is not set; using fallback strategy."
    return .nil
  end

  tmpBase = "/tmp/hardworld_gemini_" || time("S") || "_" || random(100000,999999)
  req = tmpBase || ".json"
  resp = tmpBase || ".out"
  err = tmpBase || ".err"
  statusFile = tmpBase || ".status"

  systemText = "You are the decision engine for one player in a no-limit Texas Hold'em game. Use only the supplied game state. Never invent or assume hidden cards. Choose a legal action that maximises your long-run chip bankroll. Return only the requested output lines, including the optional dictionary-constrained TALK fields and the constrained SOCIAL_EVIDENCE attribution field."

  body = '{"systemInstruction":{"parts":[{"text":"' || self~jsonEscape(systemText) || '"}]},'
  body ||= '"contents":[{"role":"user","parts":[{"text":"' || self~jsonEscape(prompt) || '"}]}],'
  body ||= '"generationConfig":{"temperature":' || temperature || '}}'
  call lineout req, body
  call lineout req

  endpoint = endpointBase || model || ":generateContent"
  cmd = 'curl -sS --max-time' timeout '-o' self~shellQuote(resp) '-w "%{http_code}"'
  cmd ||= ' -H "Content-Type: application/json"'
  cmd ||= ' -H "x-goog-api-key: $GEMINI_API_KEY"'
  cmd ||= ' --data-binary @' || self~shellQuote(req) self~shellQuote(endpoint)
  cmd ||= ' 2>' || self~shellQuote(err)
  address system cmd '>' || self~shellQuote(statusFile)

  http = linein(statusFile)
  call linein statusFile, 1, 0
  lastRaw = self~readAll(resp)

  call SysFileDelete req
  call SysFileDelete resp
  call SysFileDelete err
  call SysFileDelete statusFile

  if http \= "200" then do
    say "GEMINI API HTTP" http "- using fallback strategy."
    return .nil
  end

  content = self~extractText(lastRaw)
  if content = "" then do
    say "GEMINI response could not be parsed - using fallback strategy."
    return .nil
  end
  return self~parseDecision(content)

::method parseDecision private
  use arg text
  d = .directory~new
  d["action"] = ""
  d["amount"] = 0
  d["talk"] = "NONE"
  d["talk_target"] = "NONE"
  d["social_evidence"] = "NONE"
  normalized = changestr("0d0a"x, text, "0a"x)
  normalized = changestr("0d"x, normalized, "0a"x)
  do while normalized <> ""
    parse var normalized line "0a"x normalized
    line = line~strip
    if line~caselessPos("ACTION=") = 1 then d["action"] = line~substr(8)~strip~upper
    if line~caselessPos("AMOUNT=") = 1 then do
      n = line~substr(8)~strip
      if datatype(n, "W") then d["amount"] = n
    end
    if line~caselessPos("TALK=") = 1 then d["talk"] = line~substr(6)~strip~upper
    if line~caselessPos("TALK_TARGET=") = 1 then d["talk_target"] = line~substr(13)~strip
    if line~caselessPos("SOCIAL_EVIDENCE=") = 1 then d["social_evidence"] = line~substr(17)~strip~upper
  end
  a = d["action"]
  if a \= "FOLD" & a \= "CHECK" & a \= "CALL" & a \= "RAISE" then return .nil
  return d

::method extractText private
  use arg json
  marker = '"text":'
  p = json~pos(marker)
  if p = 0 then return ""
  p += marker~length
  do while p <= json~length & json~substr(p,1) = " "
    p += 1
  end
  if json~substr(p,1) \= '"' then return ""
  p += 1
  out = ""
  escaped = .false
  do i = p to json~length
    ch = json~substr(i,1)
    if escaped then do
      if ch = "n" then out ||= "0a"x
      else if ch = "r" then out ||= "0d"x
      else if ch = "t" then out ||= "09"x
      else out ||= ch
      escaped = .false
    end
    else if ch = "\" then escaped = .true
    else if ch = '"' then return out
    else out ||= ch
  end
  return ""

::method jsonEscape private
  use arg s
  s = changestr("\", s, "\\")
  s = changestr('"', s, '\"')
  s = changestr("0d"x, s, "\r")
  s = changestr("0a"x, s, "\n")
  s = changestr("09"x, s, "\t")
  return s

::method shellQuote private
  use arg s
  return '"' || s || '"'

::method readAll private
  use arg path
  txt = ""
  do while lines(path) > 0
    line = linein(path)
    if txt <> "" then txt ||= "0a"x
    txt ||= line
  end
  call linein path, 1, 0
  return txt

::requires "poker.cls"
