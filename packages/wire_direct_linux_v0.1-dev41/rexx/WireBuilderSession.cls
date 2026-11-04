/* Small public editing surface used by a visual Builder or scripts.
 * It edits symbolic application intent; it does not create widgets, callbacks,
 * behaviour objects, protocol sources, or scheduler policy.
 */
::class WireBuilderSession public
::method init
  expose specs selectedSource selectedTrigger
  specs = .array~new
  selectedSource = ""
  selectedTrigger = ""
::method selectElement
  expose selectedSource selectedTrigger
  use strict arg source
  if source == "" then raise syntax 88.900 array("WIRE_BUILDER_SOURCE_REQUIRED")
  -- Changing element invalidates any event selected for the previous element.
  if source \== selectedSource then selectedTrigger = ""
  selectedSource = source
  return self
::method selectEvent
  expose selectedSource selectedTrigger
  use strict arg trigger
  if selectedSource == "" then raise syntax 88.900 array("WIRE_BUILDER_SELECT_ELEMENT_FIRST")
  if trigger == "" then raise syntax 88.900 array("WIRE_BUILDER_TRIGGER_REQUIRED")
  selectedTrigger = trigger
  return self
::method bindBehaviour
  expose specs selectedSource selectedTrigger
  use strict arg id, behaviour, method
  if selectedSource == "" | selectedTrigger == "" then raise syntax 88.900 array("WIRE_BUILDER_SELECT_EVENT_FIRST")
  self~assertUnusedBindingId(id)
  spec = .WireBuilderBindingSpec~new(id, selectedSource, selectedTrigger, behaviour, method)
  specs~append(spec)
  return spec
/* Return an editable ordinary-ooRexx method draft.  No editor is loaded,
 * and this does not register or execute a behaviour. */
::method newBehaviourDraft
  expose selectedSource selectedTrigger
  use strict arg behaviour, method
  if selectedSource == '' | selectedTrigger == '' then raise syntax 88.900 array('WIRE_BUILDER_SELECT_EVENT_FIRST')
  return .WireBehaviourDraft~new(selectedSource, selectedTrigger, behaviour, method)
/* Explicit commit: editor edits a detached draft, Builder verifies that it
 * still belongs to the selected element/event before recording intent.
 * This never executes source or registers a runtime handler. */
::method commitBehaviourDraft
  expose selectedSource selectedTrigger specs
  use strict arg id, draft
  if draft == .nil then raise syntax 88.900 array('WIRE_BUILDER_DRAFT_REQUIRED')
  if \draft~isInstanceOf(.WireBehaviourDraft) then raise syntax 88.900 array('WIRE_BUILDER_DRAFT_TYPE')
  if \draft~matchesSelection(selectedSource, selectedTrigger) then raise syntax 88.900 array('WIRE_BUILDER_DRAFT_STALE')
  self~assertUnusedBindingId(id)
  spec = .WireBuilderBindingSpec~new(id, draft~element, draft~trigger, draft~behaviour, draft~method)
  -- Preserve edited source with the design-time binding, not in the editor.
  -- Metadata is descriptive; it is never evaluated or installed by commit.
  spec~metadata['wire.behaviour.source'] = draft~source
  spec~metadata['wire.behaviour.method'] = draft~method
  specs~append(spec)
  return spec
/* Editor transport is caller-owned. The Builder issues a detached draft and
 * accepts a returned source only through the draft validation boundary.
 * No editor is loaded, no code is evaluated, and no runtime handler is installed. */
::method acceptEditorSource
  use strict arg draft, editedSource
  if draft == .nil then raise syntax 88.900 array('WIRE_BUILDER_DRAFT_REQUIRED')
  if \draft~isInstanceOf(.WireBehaviourDraft) then raise syntax 88.900 array('WIRE_BUILDER_DRAFT_TYPE')
  draft~replaceSource(editedSource)
  return draft
/* One identity namespace for manual and editor-created bindings. */
::method assertUnusedBindingId private
  expose specs
  use strict arg id
  do spec over specs
    if spec~id == id then raise syntax 88.900 array('WIRE_BUILDER_DUPLICATE_BINDING')
  end
  return .true
::method bindingSpecs
  expose specs
  copy = .array~new
  do spec over specs
    copy~append(spec)
  end
  return copy
::requires "WireBuilderBindingSpec.cls"
::requires "WireBehaviourDraft.cls"
