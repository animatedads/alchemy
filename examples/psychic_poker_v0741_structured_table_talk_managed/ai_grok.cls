::class GrokAPIClient public subclass PokerAlchemyObject
::attribute model get
::attribute endpoint get
::attribute timeout get
::attribute lastRaw get
::attribute lastError get
::attribute lastHttp get
::attribute attempts get

::method init
  expose model endpoint timeout lastRaw lastError lastHttp attempts
  use arg model = "grok-4.5", endpoint = "https://api.x.ai/v1/chat/completions", timeout = 75
  lastRaw = ""
  lastError = ""
  lastHttp = ""
  attempts = 0
  self~initPokerAlchemy("AI_CLIENT_GROK", "xAI Grok HTTP decision client")
  self~registerStateVariable("model", "CUSTOMER", "configured xAI model")
  self~registerStateVariable("endpoint", "INTERNAL", "configured xAI endpoint")
  self~registerStateVariable("timeout", "INTERNAL", "HTTP timeout seconds")
  self~registerStateVariable("lastError", "INTERNAL", "last bounded transport/parser error")
  self~registerEnvironmentRequirement("XAI_API_KEY", "optional; absence activates deterministic fallback", .false)
  self~registerExternalRequirement("service", "xAI chat completions API", "v1", .false)
  self~registerMethodContract("DECIDEWITHTEMPERATURE", "Request one constrained poker decision from Grok", .array~of("PROMPT", "TEMPERATURE"), "ANY", .false, "AUTO", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")

::method decide
  use arg prompt
  return self~decideWithTemperature(prompt, 0.2)

::method decideWithTemperature
  expose lastError lastHttp attempts
  use arg prompt, temperature = 0.2
  self~alchemyTouch("AI_DECIDE")
  apiKey = value("XAI_API_KEY",, "ENVIRONMENT")
  if apiKey = "" then do
    lastError = "XAI_API_KEY is not set"
    lastHttp = ""
    attempts = 0
    say "GROK unavailable:" lastError "- using fallback strategy."
    return .nil
  end

  maxTries = 3
  attempts = 0
  do tryNo = 1 to maxTries
    attempts = tryNo
    decision = self~once(prompt, temperature)
    if decision \= .nil then return decision

    if tryNo < maxTries then do
      if \self~retryable then leave
      say "GROK attempt" tryNo "failed (" || lastError || ") - retrying..."
      call SysSleep 1
    end
  end

  if attempts > 1 then
    say "GROK API failed after" attempts "attempts (" || lastError || ") - using fallback strategy."
  else
    say "GROK API failed (" || lastError || ") - using fallback strategy."
  return .nil

::method once private
  expose model endpoint timeout lastRaw lastError lastHttp
  use arg prompt, temperature = 0.2

  tmpBase = "/tmp/hardworld_grok_" || time("S") || "_" || random(100000, 999999)
  req  = tmpBase || ".json"
  resp = tmpBase || ".out"
  err  = tmpBase || ".err"
  code = tmpBase || ".status"

  systemText = "You are the decision engine for one player in a no-limit Texas Hold'em game. Use only the supplied game state. Never invent or assume hidden cards. Choose a legal action that maximises your long-run chip bankroll. Return only the requested output lines, including the optional dictionary-constrained TALK fields and the constrained SOCIAL_EVIDENCE attribution field."
  body = '{"model":"' || self~jsonEscape(model) || '","temperature":' || temperature || ',"messages":['
  body ||= '{"role":"system","content":"' || self~jsonEscape(systemText) || '"},'
  body ||= '{"role":"user","content":"' || self~jsonEscape(prompt) || '"}]}'
  call lineout req, body
  call lineout req

  /* Keep the API key in the environment rather than embedding it in the
     command line, request body, database or casino audit tables. */
  cmd = 'curl -sS --max-time ' || timeout
  cmd ||= ' -o ' || self~shellQuote(resp)
  cmd ||= ' -w "%{http_code}"'
  cmd ||= ' -H "Content-Type: application/json"'
  cmd ||= ' -H "Authorization: Bearer $XAI_API_KEY"'
  cmd ||= ' --data-binary @' || self~shellQuote(req)
  cmd ||= ' ' || self~shellQuote(endpoint)
  cmd ||= ' >' || self~shellQuote(code)
  cmd ||= ' 2>' || self~shellQuote(err)

  address system cmd
  commandRc = rc

  lastHttp = self~readAll(code)~strip
  lastRaw  = self~readAll(resp)
  errText  = self~readAll(err)~strip

  call SysFileDelete req
  call SysFileDelete resp
  call SysFileDelete err
  call SysFileDelete code

  if lastHttp = "" then lastHttp = "000"

  transportFailed = .false
  if commandRc \= 0 then transportFailed = .true
  if lastHttp = "000" then transportFailed = .true
  if transportFailed then do
    lastError = "transport rc=" || commandRc || " http=" || lastHttp
    if errText \= "" then lastError ||= " stderr=" || errText
    return .nil
  end

  if lastHttp \= "200" then do
    lastError = "http=" || lastHttp
    if errText \= "" then lastError ||= " stderr=" || errText
    return .nil
  end

  content = self~extractContent(lastRaw)
  if content = "" then do
    lastError = "empty or unparseable content"
    return .nil
  end

  decision = self~parseDecision(content)
  if decision = .nil then do
    lastError = "could not parse action response"
    return .nil
  end

  lastError = ""
  return decision

::method retryable private
  expose lastError lastHttp
  if lastHttp = "000" then return .true
  if lastHttp = "408" then return .true
  if lastHttp = "425" then return .true
  if lastHttp = "429" then return .true
  if lastHttp~left(1) = "5" then return .true
  if lastError = "empty or unparseable content" then return .true
  if lastError = "could not parse action response" then return .true
  return .false

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
    if line~caselessPos("ACTION=") = 1 then
      d["action"] = line~substr(8)~strip~upper
    if line~caselessPos("AMOUNT=") = 1 then do
      n = line~substr(8)~strip
      if datatype(n, "W") then d["amount"] = n
    end
    if line~caselessPos("TALK=") = 1 then d["talk"] = line~substr(6)~strip~upper
    if line~caselessPos("TALK_TARGET=") = 1 then d["talk_target"] = line~substr(13)~strip
    if line~caselessPos("SOCIAL_EVIDENCE=") = 1 then d["social_evidence"] = line~substr(17)~strip~upper
  end
  a = d["action"]
  if a \= "FOLD" then do
    if a \= "CHECK" then do
      if a \= "CALL" then do
        if a \= "RAISE" then return .nil
      end
    end
  end
  return d

::method extractContent private
  use arg json
  marker = '"content":'
  p = json~pos(marker)
  if p = 0 then return ""
  p += marker~length
  do while p <= json~length
    if json~substr(p, 1) \= " " then leave
    p += 1
  end
  if p > json~length then return ""
  if json~substr(p, 1) \= '"' then return ""
  p += 1
  out = ""
  escaped = .false
  do i = p to json~length
    ch = json~substr(i, 1)
    if escaped then do
      if ch = "n" then out ||= "0a"x
      else if ch = "r" then out ||= "0d"x
      else if ch = "t" then out ||= "09"x
      else out ||= ch
      escaped = .false
    end
    else do
      if ch = "\" then escaped = .true
      else if ch = '"' then return out
      else out ||= ch
    end
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
  if stream(path, "C", "QUERY EXISTS") = "" then return ""
  txt = ""
  do while lines(path) > 0
    line = linein(path)
    if txt \= "" then txt ||= "0a"x
    txt ||= line
  end
  call linein path, 1, 0
  return txt

::requires "poker.cls"
