/*
 * IBM 5250 device identity evidence v0.1.
 *
 * Enhanced Telnet DEVNAME tells us which device name the client requested or
 * selected during negotiation.  A server-assigned QPADEV name is different:
 * the current RFC 1205/NEW-ENVIRON exchange does not necessarily echo that
 * host allocation back to the client.  IBM i does, however, show the active
 * display name on the confirmed sign-on panel.
 *
 * This object keeps those evidence sources separate.  A screen observation is
 * never relabelled as a Telnet negotiation fact.
 */

::class TN5250DeviceIdentityBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.tn5250.device-identity/0.1"

::class TN5250DeviceIdentitySource public
::constant UNKNOWN "UNKNOWN"
::constant REQUESTED "REQUESTED_DEVNAME"
::constant NEGOTIATED "TELNET_DEVNAME"
::constant HOST_SIGNON "HOST_SIGNON_SCREEN"

::class TN5250DeviceIdentity public
::attribute requestedDeviceName get
::attribute negotiatedDeviceName get
::attribute assignedDeviceName get
::attribute effectiveDeviceName get
::attribute source get
::attribute generation get
::attribute evidenceRow get
::attribute consistent get

::method init
  expose requestedDeviceName negotiatedDeviceName assignedDeviceName effectiveDeviceName source generation evidenceRow consistent
  use arg requestedArg = "", negotiatedArg = "", assignedArg = "", sourceArg = "UNKNOWN", generationArg = 0, evidenceRowArg = 0
  requestedDeviceName = requestedArg~string~strip~upper
  negotiatedDeviceName = negotiatedArg~string~strip~upper
  assignedDeviceName = assignedArg~string~strip~upper
  source = sourceArg~string~strip~upper
  generation = generationArg
  evidenceRow = evidenceRowArg
  consistent = .true
  if assignedDeviceName \== "" then do
    if negotiatedDeviceName \== "" then do
      if assignedDeviceName \== negotiatedDeviceName then consistent = .false
    end
  end

  if assignedDeviceName \== "" then effectiveDeviceName = assignedDeviceName
  else if negotiatedDeviceName \== "" then effectiveDeviceName = negotiatedDeviceName
  else effectiveDeviceName = requestedDeviceName

::method copyDetached
  expose requestedDeviceName negotiatedDeviceName assignedDeviceName source generation evidenceRow
  return .TN5250DeviceIdentity~new(requestedDeviceName, negotiatedDeviceName, assignedDeviceName, source, generation, evidenceRow)

::method safeDirectory
  expose requestedDeviceName negotiatedDeviceName assignedDeviceName effectiveDeviceName source generation evidenceRow consistent
  d = .directory~new
  d["requested_device"] = requestedDeviceName
  d["negotiated_device"] = negotiatedDeviceName
  d["assigned_device"] = assignedDeviceName
  d["effective_device"] = effectiveDeviceName
  d["source"] = source
  d["generation"] = generation
  d["evidence_row"] = evidenceRow
  d["consistent"] = consistent
  return d

/* Build the best identity available without a screen observation. */
::method fromNegotiation class
  use arg requestedArg = "", negotiatedArg = ""
  requested = requestedArg~string~strip~upper
  negotiated = negotiatedArg~string~strip~upper
  if negotiated \== "" then source = .TN5250DeviceIdentitySource~NEGOTIATED
  else if requested \== "" then source = .TN5250DeviceIdentitySource~REQUESTED
  else source = .TN5250DeviceIdentitySource~UNKNOWN
  return .TN5250DeviceIdentity~new(requested, negotiated, "", source, 0, 0)

/* Observe the host-assigned display identity only on a structurally plausible
 * IBM i sign-on screen.  The value is evidence from presentation space, not a
 * claimed NEW-ENVIRON acknowledgement. */
::method observeSignon class
  use arg snapshot, requestedArg = "", negotiatedArg = ""
  if snapshot == .nil then return .TerminalResult~failure("DEVICE_IDENTITY_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("DEVICE_IDENTITY_WRONG_TERMINAL", snapshot~terminalType)

  pair = .KnownState5250Factory~findCredentialFields(snapshot)
  if \pair~ok then return .TerminalResult~failure("DEVICE_IDENTITY_NOT_SIGNON", pair~code || ":" || pair~detail)

  displayRow = 0
  displayText = ""
  do r = 1 to snapshot~rows
    line = snapshot~rowText(r)
    if pos("DISPLAY NAME", line~upper) > 0 then do
      displayRow = r
      displayText = line
      leave
    end
  end
  if displayRow = 0 then return .TerminalResult~failure("DEVICE_IDENTITY_DISPLAY_LABEL_NOT_FOUND", "Display name")

  separator = lastpos(":", displayText)
  if separator = 0 then return .TerminalResult~failure("DEVICE_IDENTITY_DISPLAY_VALUE_NOT_FOUND", displayText~strip)
  assigned = displayText~substr(separator + 1)~strip~upper
  if assigned == "" then return .TerminalResult~failure("DEVICE_IDENTITY_DISPLAY_VALUE_NOT_FOUND", "blank display name")
  if \self~validDeviceName(assigned) then return .TerminalResult~failure("DEVICE_IDENTITY_DISPLAY_VALUE_INVALID", assigned)

  requested = requestedArg~string~strip~upper
  negotiated = negotiatedArg~string~strip~upper
  identity = .TN5250DeviceIdentity~new(requested, negotiated, assigned, .TN5250DeviceIdentitySource~HOST_SIGNON, snapshot~generation, displayRow)
  return .TerminalResult~success(identity)

::method validDeviceName class private
  use arg nameArg
  name = nameArg~string~strip~upper
  if name == "" then return .false
  if name~length > 10 then return .false
  allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$#@"
  return name~verify(allowed) = 0

::requires "TN5250CredentialLogin.cls"
