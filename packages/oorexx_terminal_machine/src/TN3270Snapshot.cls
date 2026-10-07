/* Detached native IBM 3270 snapshot projection.
 *
 * PresentationSpace3270 remains the mutable protocol truth.  This adapter
 * projects that truth into the generic immutable TerminalSnapshot contract
 * without flattening field semantics or exposing NONDISPLAY contents.
 */
::class TN3270Snapshot public

::method fromWire class
  use arg wire, sessionStateArg = "OPEN"
  if wire == .nil then return .TerminalResult~failure("3270_SNAPSHOT_WIRE_REQUIRED")
  if \wire~hasMethod("MODEL") | \wire~hasMethod("STREAM") then return .TerminalResult~failure("3270_SNAPSHOT_WIRE_INVALID")
  profile = .nil
  if wire~hasMethod("PROFILE") then profile = wire~profile
  return self~fromModel(wire~model, wire~stream~codepage, profile, sessionStateArg)

::method fromModel class
  use arg model, codepage, profile = .nil, sessionStateArg = "OPEN"
  if model == .nil | codepage == .nil then return .TerminalResult~failure("3270_SNAPSHOT_MODEL_REQUIRED")

  rows = model~rows
  columns = model~columns
  textRows = model~text(codepage)~makeArray("0a"x)
  fieldsOut = .array~new
  layout = rows || "x" || columns

  do f over model~fields
    start = (f~address + 1) // model~size
    row = model~rowForAddress(start)
    column = model~columnForAddress(start)
    length = model~fieldDataBytes(f)~length
    safeValue = model~fieldText(f, codepage)
    if f~nonDisplay then safeValue = "<SECRET>"

    attrs = .directory~new
    attrs["basic"] = f~attribute~c2x
    ext = f~extendedAttributes
    do key over ext
      attrs["x" || key] = ext[key]~c2x
    end

    id = "A" || right(d2x(f~address), 4, "0")
    fieldsOut~append(.TerminalFieldSnapshot~new(id, row, column, length, safeValue, \f~protected, f~protected, f~nonDisplay, f~modified, f~numeric, attrs))
    layout ||= "|" || id || ":" || row || "," || column || "," || length || "," || f~attribute~c2x
    do key over ext
      layout ||= ",x" || key || "=" || ext[key]~c2x
    end
  end

  cursorRow = model~rowForAddress(model~cursor)
  cursorColumn = model~columnForAddress(model~cursor)
  keyboardState = "UNLOCKED"
  if model~keyboardLocked then keyboardState = "LOCKED"

  capabilities = .TerminalCapabilities~new
  capabilities~add("CHARACTER_GRID")
  capabilities~add("FIELD_TERMINAL")
  capabilities~add("IBM_3270")
  capabilities~add("TN3270")
  capabilities~add("3270_EXTENDED_ATTRIBUTES")
  capabilities~add("3270_STRUCTURED_FIELDS")

  metadata = .directory~new
  metadata["protocol"] = "TN3270"
  metadata["model"] = rows || "x" || columns
  metadata["replyMode"] = "FIELD"
  if profile \== .nil then do
    if profile~hasMethod("TN3270EACTIVE") then do
      if profile~tn3270eActive then do
        capabilities~add("TN3270E")
        metadata["protocol"] = "TN3270E"
      end
    end
    if profile~hasMethod("TERMINALTYPE") then metadata["terminalTypeNegotiated"] = profile~terminalType
    if profile~hasMethod("DEVICENAME") then metadata["deviceName"] = profile~deviceName
  end

  visible = ""
  do i = 1 to textRows~items
    if i > 1 then visible ||= "0a"x
    visible ||= textRows[i]
  end
  contentDigest = .TerminalUtil~stableDigest(visible)
  layoutFingerprint = .TerminalUtil~stableDigest(layout)
  terminalType = "IBM-3270"
  if profile \== .nil then if profile~hasMethod("TERMINALTYPE") then terminalType = profile~terminalType

  snap = .TerminalSnapshot~new(model~generation, terminalType, rows, columns, cursorRow, cursorColumn, keyboardState, sessionStateArg, textRows, fieldsOut, capabilities, metadata, contentDigest, layoutFingerprint)
  return .TerminalResult~success(snap)

::requires "DataStream3270.cls"
