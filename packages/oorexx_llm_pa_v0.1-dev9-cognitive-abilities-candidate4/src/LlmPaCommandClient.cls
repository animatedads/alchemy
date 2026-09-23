/* ooRexx command client for the PA loopback access point. */

::class LlmPaCliParser public
::method parse class
  use arg lineArg
  line = lineArg~string~strip
  if line = "" then return .LlmPaResult~failure("COMMAND_REQUIRED")
  parse var line command rest
  command = command~strip~lower
  rest = rest~strip
  d = .directory~new
  if command = "-remember" | command = "remember" then do
    pair = self~rememberPair(rest)
    if \pair~ok then return pair
    d["command"] = "remember"
    d["arg1"] = pair~value[1]
    d["arg2"] = pair~value[2]
  end
  else if command = "-remind" | command = "remind" then do
    /* Natural-language remind is intentionally not parsed for time here.
     * Real Gemma determines recall-vs-schedule and the initial delay. */
    d["command"] = "remind"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-remind-after" | command = "remind-after" | command = "-remind_after" | command = "remind_after" then do
    d["command"] = "remind_after"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-ask" | command = "ask" | command = "-message" | command = "message" then do
    d["command"] = "message"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-knowledge" | command = "knowledge" | command = "-local-knowledge" | command = "local-knowledge" | command = "-local_knowledge" | command = "local_knowledge" then do
    d["command"] = "knowledge"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-gopher" | command = "gopher" | command = "-gopher-read" | command = "gopher-read" | command = "-gopher_read" | command = "gopher_read" then do
    d["command"] = "gopher"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-calendar" | command = "calendar" | command = "-read-calendar" | command = "read-calendar" | command = "-read_calendar" | command = "read_calendar" then do
    d["command"] = "calendar"
    d["arg1"] = ""
    d["arg2"] = ""
  end
  else if command = "-handoff" | command = "handoff" | command = "-continuity" | command = "continuity" then do
    if rest~strip = "" | rest~strip~lower = "current" then do
      d["command"] = "ability_invoke"
      d["arg1"] = "continuity.current"
      d["arg2"] = "{}"
    end
    else return .LlmPaResult~failure("CONTINUITY_COMMAND_INVALID", rest)
  end
  else if command = "-refresh-handoff" | command = "refresh-handoff" | command = "-refresh_continuity" | command = "refresh_continuity" then do
    d["command"] = "refresh_continuity"
    d["arg1"] = ""
    d["arg2"] = ""
  end
  else if command = "-plan" | command = "plan" then do
    if rest~strip~lower = "current" then do
      d["command"] = "ability_invoke"
      d["arg1"] = "plan.current"
      d["arg2"] = "{}"
    end
    else do
      d["command"] = "plan"
      d["arg1"] = self~unquote(rest)
      d["arg2"] = ""
    end
  end
  else if command = "-plan-done" | command = "plan-done" | command = "-plan_done" | command = "plan_done" then do
    d["command"] = "plan_done"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-plan-verified" | command = "plan-verified" | command = "-plan_verified" | command = "plan_verified" then do
    d["command"] = "plan_verified"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "-lesson" | command = "lesson" | command = "-lessons" | command = "lessons" then do
    d["command"] = "lesson"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "abilities" | command = "ability-list" | command = "ability_list" then do
    d["command"] = "ability_catalogue"
    d["arg1"] = self~unquote(rest)
    d["arg2"] = ""
  end
  else if command = "ability" | command = "invoke" then do
    parse var rest abilityName requestJson
    abilityName = abilityName~strip~lower
    requestJson = requestJson~strip
    if abilityName = "" then return .LlmPaResult~failure("ABILITY_NAME_REQUIRED")
    if requestJson = "" then requestJson = "{}"
    d["command"] = "ability_invoke"
    d["arg1"] = abilityName
    d["arg2"] = requestJson
  end
  else if command = "package" then do
    parse var rest operation path
    operation = operation~lower~strip
    if path~strip = "" then return .LlmPaResult~failure("NAMED_ABILITY_REQUIRED", "usage: package stage ZIP | package release-analyse DIR | package release DIR")
    select
      when operation = "stage" then d["command"] = "package_stage"
      when operation = "release-analyse" | operation = "release_analyse" then d["command"] = "package_release_analyse"
      when operation = "release" then d["command"] = "package_release"
      otherwise return .LlmPaResult~failure("NAMED_ABILITY_REQUIRED", "usage: package stage ZIP | package release-analyse DIR | package release DIR")
    end
    d["arg1"] = self~unquote(path)
    d["arg2"] = ""
  end
  else if command = "-next" | command = "next" then do
    d["command"] = "_next"
    d["arg1"] = ""
    d["arg2"] = ""
  end
  else return .LlmPaResult~failure("UNKNOWN_COMMAND", command)
  return .LlmPaResult~success(d)

::method rememberPair private class
  use arg textArg
  text = textArg~strip
  if text~left(1) = "{" & text~right(1) = "}" then text = text~substr(2, text~length - 2)~strip
  if text~pos('"') > 0 then do
    parse var text . '"' key '"' remainder
    parse var remainder . '"' value '"' .
    if key~strip = "" then return .LlmPaResult~failure("MEMORY_KEY_REQUIRED")
    return .LlmPaResult~success(.array~of(key, value))
  end
  parse var text key value
  if key = "" | value = "" then return .LlmPaResult~failure("REMEMBER_REQUIRES_KEY_AND_VALUE")
  return .LlmPaResult~success(.array~of(self~unquote(key), self~unquote(value)))

::method unquote private class
  use arg textArg
  text = textArg~strip
  if text~length >= 2 then do
    if text~left(1) = "{" & text~right(1) = "}" then text = text~substr(2, text~length - 2)~strip
  end
  if text~length >= 2 then do
    if (text~left(1) = '"' & text~right(1) = '"') | (text~left(1) = "'" & text~right(1) = "'") then text = text~substr(2, text~length - 2)
  end
  return text

::class LlmPaCommandClient public
::method init
  expose host port bridgeToken
  use arg hostArg = "127.0.0.1", portArg, tokenArg
  host = hostArg~string
  port = portArg
  bridgeToken = tokenArg~string
  if port = "" | bridgeToken = "" then raise syntax 88.900 array("LLM PA bridge port and token are required")

::method submit
  use arg payload
  fields = .directory~new
  fields["payload"] = payload
  fields["correlationId"] = payload["request_id"]
  fields["replyTo"] = payload["reply_to"]
  r = self~request("PUT", fields)
  if \r~ok then return r
  d = .directory~new
  d["request_id"] = payload["request_id"]
  d["package_id"] = r~value["packageId"]
  d["status"] = .LlmPaStatus~QUEUED
  return .LlmPaResult~success(d)

::method nextReply
  r = self~request("CLAIM")
  if \r~ok then return r
  claim = r~value
  package = claim["package"]
  fields = .directory~new
  fields["packageId"] = package["packageId"]
  fields["claimToken"] = claim["claimToken"]
  ack = self~request("ACK", fields)
  if \ack~ok then return ack
  return .LlmPaResult~success(package["payload"])

::method request private
  expose host port bridgeToken
  use arg operation, fields = .nil
  req = .directory~new
  req["bridgeToken"] = bridgeToken
  req["op"] = operation
  if fields \== .nil then do key over fields~allIndexes
    req[key] = fields[key]
  end
  client = .StreamSocket~new(host, port)
  if client~open = -1 | client~state \= "READY" then return .LlmPaResult~failure("BRIDGE_CONNECT_FAILED", host || ":" || port)
  ignore = client~lineOut(.JSON~toJSON(req))
  line = client~lineIn
  ignore = client~close
  signal on syntax name badReply
  response = .JSON~fromJSON(line)
  signal off syntax
  if \response["ok"] then do
    detail = ""
    if response~hasIndex("detail") then detail = response["detail"]
    return .LlmPaResult~failure(response["code"], detail)
  end
  if response~hasIndex("value") then return .LlmPaResult~success(response["value"])
  return .LlmPaResult~success(.nil)
badReply:
  signal off syntax
  return .LlmPaResult~failure("BRIDGE_REPLY_INVALID")

::requires "LlmPaCore.cls"
::requires "json.cls"
::requires "socket.cls"
::requires "streamsocket.cls"
