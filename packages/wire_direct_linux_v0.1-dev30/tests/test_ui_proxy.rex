call directory filespec('location', sourceLine(1))
call directory '..'

model = .WireApplicationModel~new
model~addElement("detailsPanel", .WireElementState~new("detailsPanel", "Panel"))
model~addElement("status", .WireElementState~new("status", "Label"))
model~addElement("closeButton", .WireElementState~new("closeButton", "Button"))
model~addElement("secretAdmin", .WireElementState~new("secretAdmin", "Panel"))

projection = .TestProjection~new
model~projection = projection
actions = .TestActions~new
model~actionTarget = actions

allowed = .directory~new
allowed["detailsPanel"] = .true
allowed["status"] = .true
allowed["closeButton"] = .true
ui = model~scopedUI(allowed)

event = .WireApplicationEvent~new("showDetails", "Click", .nil, 0, .nil, ui)
behaviour = .FixtureBehaviour~new
behaviour~showDetails(event)

call assert ui~byId("detailsPanel")~visible == .true, "details visible"
call assert ui~byId("status")~text == "Ready", "status text"
call assert ui~byId("closeButton")~enabled == .true, "close enabled"
call assert projection~updates == 3, "three semantic projection updates"
call assert ui~byId("secretAdmin") == .nil, "scope denies undisclosed element"
call assert actions~activations == 0, "state changes are not actions"
call assert ui~byId("closeButton")~activate == .true, "semantic activate"
call assert actions~activations == 1, "one semantic activation"
call assert actions~lastId == "closeButton", "activation keeps element identity"
call assert model~elementProperty("status", "text") == "Ready", "model is authoritative"
say "wire-ui-proxy=PASS"
exit 0

assert: procedure
  use strict arg condition, label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
return

::class FixtureBehaviour
::method showDetails
  use strict arg event
  event~ui~byId("detailsPanel")~visible = .true
  event~ui~byId("status")~text = "Ready"
  event~ui~byId("closeButton")~enabled = .true

::class TestProjection
::method init
  expose updates
  updates = 0
::method setElementProperty
  expose updates
  use strict arg id, name, value
  updates += 1
  return .true
::attribute updates get

::class TestActions
::method init
  expose activations lastId
  activations = 0; lastId = ""
::method activateElement
  expose activations lastId
  use strict arg id
  activations += 1; lastId = id
  return .true
::attribute activations get
::attribute lastId get

::requires "../rexx/WireElementState.cls"
::requires "../rexx/WireApplicationModel.cls"
::requires "../rexx/WireApplicationEvent.cls"
