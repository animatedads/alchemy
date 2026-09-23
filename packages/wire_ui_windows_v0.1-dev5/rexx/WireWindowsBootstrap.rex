/* Windows qualification entrypoint.
 * dev5 keeps the semantic application model resident in the embedded ooRexx
 * interpreter. Native controls are projections; the model is authoritative.
 */
use strict arg source, trigger, detailKey = "", detailValue = ""

modelKey = "WIRE.WINDOWS.QUALIFICATION.MODEL"
if .environment~hasIndex(modelKey) then do
    model = .environment[modelKey]
end
else do
    model = .WireApplicationModel~new
    status = .WireSemanticElement~new("status", "Label")
    status~setProperty("text", "Ready")
    model~addElement("status", status)
    heading = .WireSemanticElement~new("heading", "Label")
    heading~setProperty("text", "Same Wire application. Native Windows renderer.")
    model~addElement("heading", heading)
    button = .WireSemanticElement~new("qualifyButton", "Button")
    button~setProperty("text", "Run ooRexx Wire event")
    button~setProperty("activationCount", 0)
    model~addElement("qualifyButton", button)
    target = .WireWindowsQualificationBehaviour~new
    model~addBinding(.WireBinding~new("windows.qualify", "qualifyButton", "Click", target, "onEvent"))
    .environment[modelKey] = model
end

context = .collection~new
if detailKey <> "" then context[detailKey] = detailValue
ui = model~ui
event = .WireApplicationEvent~new(source, trigger, context, 0, .nil, ui)
controller = .WireApplicationController~new(model)
results = controller~dispatch(event)
if results~items = 0 then return "WIRE_NO_BINDING"

/* Renderer-neutral semantic patch envelope. */
return "WIRE_PATCH|status|text|" || model~elementProperty("status", "text") || "\n" || -
       "WIRE_PATCH|qualifyButton|text|" || model~elementProperty("qualifyButton", "text")

::class WireWindowsQualificationBehaviour public
::method onEvent
  use strict arg event
  button = event~ui~byId("qualifyButton")
  count = button~getProperty("activationCount")
  if count == .nil then count = 0
  count += 1
  button~setProperty("activationCount", count)
  event~ui~byId("status")~text = "ooRexx handled " || event~source || "." || event~trigger || -
      " - semantic activation " || count
  if count = 1 then button~text = "Run it again"
  else button~text = "Run it again (" || count || ")"
  return .true

::requires "WireApplicationEvent.cls"
::requires "WireBinding.cls"
::requires "WireApplicationController.cls"
::requires "WireApplicationModel.cls"
::requires "WireSemanticElement.cls"
