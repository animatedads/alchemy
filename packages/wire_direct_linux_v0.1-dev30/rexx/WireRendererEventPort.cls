/* Renderer-neutral ingress from renderer semantic events into the application.
 * Native renderers must translate toolkit activity before this boundary.
 */
::class WireRendererEventPort public
::method init
  expose controller model scopes
  use strict arg controller, model, scopes = .nil
::method dispatch
  expose controller model scopes
  use strict arg source, trigger, detailKey = "", detailValue = .nil, rendererContext = .nil
  context = .directory~new
  if detailKey \== "" then context[detailKey] = detailValue
  ui = model~ui
  if scopes \== .nil then do
    if scopes~hasIndex(source) then ui = model~scopedUI(scopes[source])
  end
  event = .WireApplicationEvent~new(source, trigger, context, 0, rendererContext, ui)
  return controller~dispatch(event)
::requires "WireApplicationEvent.cls"
