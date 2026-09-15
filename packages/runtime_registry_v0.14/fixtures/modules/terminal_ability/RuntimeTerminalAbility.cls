/* Runtime Registry v0.9 Terminal Machine safe automation ability fixture. */
::class RuntimeTerminalAbility public

::method runtimePrepare
  expose runtime automation
  use arg context
  runtime = .TN5250RuntimeSession~new("ABILITY-5250", "IBM-3179-2", "AIBOT01")
  automation = runtime~automationPort
  cp = .CodePage037~new

  /* Complete the 5250 Telnet profile using trusted runtime input. */
  negotiation = .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~TERMINAL_TYPE ||,
                .TelnetByte~IAC || .TelnetByte~SB || .TelnetOption~TERMINAL_TYPE || .TelnetTerminalType~SEND || .TelnetByte~IAC || .TelnetByte~SE ||,
                .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~EOR ||,
                .TelnetByte~IAC || .TelnetByte~WILL || .TelnetOption~EOR ||,
                .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~BINARY ||,
                .TelnetByte~IAC || .TelnetByte~WILL || .TelnetOption~BINARY
  feedResult = runtime~feedNetwork(negotiation)
  if \feedResult~ok then return .false

  /* Synthetic host-owned sign-on screen with user and nondisplay password fields. */
  wtd = "0411"x || "0008"x ||,
        "11"x || d2c(2) || d2c(5) || cp~encode("PUB400 SIGN ON") ||,
        "11"x || d2c(10) || d2c(19) || "1D400020000A"x ||,
        "11"x || d2c(11) || d2c(19) || "1D400027000A"x ||,
        "13"x || d2c(10) || d2c(20) ||,
        "04520000"x
  hostRecord = .TN5250RecordCodec~encode(.TN5250Opcode~PUT_GET, wtd)
  if \hostRecord~ok then return .false
  hostFeed = runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(hostRecord~value))
  if \hostFeed~ok then return .false
  return .true

::method runtimeSelfTest
  expose automation
  if automation == .nil then return .false
  if automation~hasMethod("RUNTIME") then return .false
  if automation~hasMethod("FEEDNETWORK") then return .false
  if automation~hasMethod("DRAINOUTBOUND") then return .false
  snapshot = automation~snapshot
  if pos("PUB400 SIGN ON", snapshot~visibleText) = 0 then return .false
  return .true

::method runtimeQuiesce
  return .true

::method runtimeStop
  expose runtime automation
  automation = .nil
  runtime = .nil
  return .true

::method runtimeInvokeAbility
  expose automation
  use arg abilityId, context
  select
    when abilityId = "terminal.snapshot" then return context~success(self~snapshotObject(context))
    when abilityId = "terminal.set-field" then do
      body = context~body
      generationValue = body~at("generation")
      fieldId = body~at("field_id")
      fieldValue = body~at("value")
      if generationValue == .nil | fieldId == .nil | fieldValue == .nil then return context~failure("TERMINAL_ARGUMENT_REQUIRED", "generation, field_id and value are required")
      actionResult = automation~setField(generationValue, fieldId, fieldValue, context~clientId)
      if \actionResult~ok then return context~failure(actionResult~code, actionResult~detail)
      responseData = .directory~new
      responseData["accepted"] = context~boolean(.true)
      responseData["snapshot"] = self~snapshotObject(context)
      /* Never echo the supplied field value. */
      return context~success(responseData)
    end
    when abilityId = "terminal.press" then do
      body = context~body
      generationValue = body~at("generation")
      aid = body~at("aid")
      if generationValue == .nil | aid == .nil then return context~failure("TERMINAL_ARGUMENT_REQUIRED", "generation and aid are required")
      actionResult = automation~press(generationValue, aid, context~clientId)
      if \actionResult~ok then return context~failure(actionResult~code, actionResult~detail)
      safeReceipt = actionResult~value
      responseData = .directory~new
      responseData["accepted"] = context~boolean(.true)
      responseData["transport_output_pending"] = context~boolean(safeReceipt~transportOutputPending)
      responseData["snapshot"] = self~snapshotObject(context)
      return context~success(responseData)
    end
    otherwise return context~failure("ABILITY_UNKNOWN", abilityId)
  end

::method snapshotObject private
  expose automation
  use arg context
  snapshot = automation~snapshot
  d = .directory~new
  d["generation"] = snapshot~generation
  d["terminal_type"] = snapshot~terminalType
  d["rows"] = snapshot~rows
  d["columns"] = snapshot~columns
  d["cursor_row"] = snapshot~cursorRow
  d["cursor_column"] = snapshot~cursorColumn
  d["keyboard_state"] = snapshot~keyboardState
  d["session_state"] = snapshot~sessionState
  d["visible_text"] = snapshot~visibleText
  fieldsOut = .array~new
  do fieldSnapshot over snapshot~fields
    f = .directory~new
    f["field_id"] = fieldSnapshot~fieldId
    f["row"] = fieldSnapshot~row
    f["column"] = fieldSnapshot~column
    f["length"] = fieldSnapshot~length
    f["display_value"] = fieldSnapshot~displayValue
    f["input_capable"] = context~boolean(fieldSnapshot~inputCapable)
    f["protected"] = context~boolean(fieldSnapshot~protected)
    f["non_display"] = context~boolean(fieldSnapshot~nonDisplay)
    fieldsOut~append(f)
  end
  d["fields"] = fieldsOut
  return d

::requires "TN5250Automation.cls"
