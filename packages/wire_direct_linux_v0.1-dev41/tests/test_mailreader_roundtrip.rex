call directory filespec('location', sourceLine(1))
call directory '..'

model = .WireApplicationModel~new
model~addElement("messages", .WireElementState~new("messages", "VirtualList"))
model~addElement("message", .WireElementState~new("message", "Document"))
model~addElement("status", .WireElementState~new("status", "Label"))
projection = .TraceProjection~new
model~projection = projection

allowed = .directory~new
allowed["message"] = .true
allowed["status"] = .true
scopes = .directory~new
scopes["messages"] = allowed

source = .MailSource~new
behaviour = .RoundTripMailBehaviour~new(source)
model~addBinding(.WireBinding~new("mail.select", "messages", "SelectionChanged", behaviour, "selectionChanged"))
controller = .WireApplicationController~new(model)
port = .WireRendererEventPort~new(controller, model, scopes)

results = port~dispatch("messages", "SelectionChanged", "identity", "INBOX|4242|8738", "gtk4")
call assert results~items == 1, "one binding dispatched"
call assert behaviour~lastIdentity == "INBOX|4242|8738", "stable identity reached Rexx behaviour"
call assert model~elementProperty("message", "value") == "Subject: ACTION REQUIRED", "message projection returned through Wire"
call assert model~elementProperty("status", "text") == "Selected INBOX|4242|8738", "status projection returned through Wire"
call assert projection~updates == 2, "two renderer-neutral projection updates"
call assert projection~entry(1) == "message|value|Subject: ACTION REQUIRED", "document update trace"
call assert projection~entry(2) == "status|text|Selected INBOX|4242|8738", "status update trace"
call assert behaviour~secretWasDenied, "event UI remained capability scoped"
say "wire-mailreader-roundtrip=PASS identity=INBOX|4242|8738 ingress=gtk4 effects=2"
exit 0

assert: procedure
  use strict arg condition, label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
return

::class RoundTripMailBehaviour
::method init
  expose source lastIdentity secretWasDenied
  use strict arg source
  lastIdentity = ""; secretWasDenied = .false
::method selectionChanged
  expose source lastIdentity secretWasDenied
  use strict arg event
  lastIdentity = event~context["identity"]
  message = source~message(lastIdentity)
  event~ui~byId("message")~value = message
  event~ui~byId("status")~text = "Selected " || lastIdentity
  secretWasDenied = (event~ui~byId("secretAdmin") == .nil)
  return lastIdentity
::attribute lastIdentity get
::attribute secretWasDenied get

::class MailSource
::method message
  use strict arg identity
  if identity == "INBOX|4242|8738" then return "Subject: ACTION REQUIRED"
  return .nil

::class TraceProjection
::method init
  expose entries
  entries = .array~new
::method setElementProperty
  expose entries
  use strict arg id, name, value
  entries~append(id || "|" || name || "|" || value)
  return .true
::method updates
  expose entries
  return entries~items
::method entry
  expose entries
  use strict arg n
  return entries[n]

::requires "../rexx/WireElementState.cls"
::requires "../rexx/WireApplicationModel.cls"
::requires "../rexx/WireBinding.cls"
::requires "../rexx/WireApplicationController.cls"
::requires "../rexx/WireRendererEventPort.cls"
