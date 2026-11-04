/* A source-editor-neutral handoff for a Builder-selected event.
 * Drafts carry ordinary ooRexx source, not toolkit callback code.
 * An editor may replace the source; Builder alone owns binding intent.
 */
::class WireBehaviourDraft public
::method init
  expose element trigger behaviour method source
  use strict arg element, trigger, behaviour, method
  if element == '' | trigger == '' | behaviour == '' | method == '' then raise syntax 88.900 array('WIRE_DRAFT_INVALID')
  -- A generated method declaration must not accept newline/directive injection.
  -- Restrict generated entry points to portable ASCII Rexx identifiers.
  letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_'
  chars = letters || '0123456789'
  if verify(substr(method, 1, 1), letters) \== 0 | verify(method, chars) \== 0 then raise syntax 88.900 array('WIRE_DRAFT_METHOD_INVALID')
  source = '::method ' || method || '0a'x || '  use strict arg event' || '0a'x || '  -- Add ordinary ooRexx behaviour here.' || '0a'x
::attribute element get
::attribute trigger get
::attribute behaviour get
::attribute method get
::attribute source get
::method matchesSelection
  expose element trigger
  use strict arg selectedElement, selectedTrigger
  return element == selectedElement & trigger == selectedTrigger
::method methodDeclaration
  expose method
  return '::method ' || method
::method replaceSource
  expose source
  use strict arg newSource
  if newSource == '' then raise syntax 88.900 array('WIRE_DRAFT_EMPTY_SOURCE')
  -- Refuse a changed or missing entry point: never silently bind a different method.
  declaration = self~methodDeclaration
  -- Require the entire first line to be exactly the declared entry point.
  -- No trailing tokens, alternate visibility, or prefixed method names.
  lf = pos('0a'x, newSource)
  if lf = 0 then raise syntax 88.900 array('WIRE_DRAFT_METHOD_MISMATCH')
  first = substr(newSource, 1, lf - 1)
  if right(first, 1) == '0d'x then first = left(first, length(first) - 1)
  if first \== declaration then raise syntax 88.900 array('WIRE_DRAFT_METHOD_MISMATCH')
  -- A behaviour draft is one method body, not an arbitrary ooRexx package.
  -- Reject a second directive at the start of any subsequent source line.
  -- This is a structural guard, not a replacement for an ooRexx parser.
  remaining = substr(newSource, lf + 1)
  do while remaining \== ''
    nextLf = pos('0a'x, remaining)
    if nextLf = 0 then
      line = remaining
    else
      line = substr(remaining, 1, nextLf - 1)
    if right(line, 1) == '0d'x then line = left(line, length(line) - 1)
    trimmed = strip(line, 'L')
    if left(trimmed, 2) == '::' then raise syntax 88.900 array('WIRE_DRAFT_EXTRA_DIRECTIVE')
    if nextLf = 0 then leave
    remaining = substr(remaining, nextLf + 1)
  end
  source = newSource
  return self
