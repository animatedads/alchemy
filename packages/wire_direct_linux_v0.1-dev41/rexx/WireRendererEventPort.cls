/* Renderer-neutral ingress. The caller must capture revision, workspace
 * context and definition identity at native event time, before queuing.
 * This port forwards those values unchanged and never reads current view state.
 */
::class WireRendererEventPort public
::method init
  expose controller model scopes
  use strict arg controller, model, scopes = .nil
::method dispatch
  expose controller model scopes
  use strict arg source, trigger, detailKey = "", detailValue = .nil, rendererContext = .nil, renderedRevision = .nil, workspaceContext = .nil, definitionId = .nil, definitionVersion = .nil
  context = .directory~new
  if detailKey \== "" then context[detailKey] = detailValue
  ui = model~ui
  if scopes \== .nil then do
    if scopes~hasIndex(source) then ui = model~scopedUI(scopes[source])
  end
  event = .WireApplicationEvent~new(source, trigger, context, 0, rendererContext, ui, renderedRevision, workspaceContext, definitionId, definitionVersion)
  return controller~dispatch(event)
::requires "WireApplicationEvent.cls"
