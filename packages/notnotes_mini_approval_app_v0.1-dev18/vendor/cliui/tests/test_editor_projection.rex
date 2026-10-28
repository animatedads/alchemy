call test
exit 0
test: procedure
  words='say return method expose use strict arg select when otherwise end'~makeArray(' ')
  svc=.CliUiCompletionService~new; svc~register('oorexx',.CliUiWordCompletion~new(words))
  doc=.CliUiDocument~new('say "hello"' || "0a"x || 'ret','oorexx')
  doc~setCaret(doc~text~length+1)
  ed=.CliUiEditor~new(doc,.CliUiSimpleSyntax~new,svc,.CliUiViewport~new(4,20))
  items=ed~requestCompletion
  ed~acceptCompletion
  if doc~text~pos('retreturn')<>0 then raise syntax 88.900 array('completion duplicated prefix')
  if doc~text~pos('return')=0 then raise syntax 88.900 array('completion replacement absent')
  r=.CliUiHeadlessRenderer~new(4,20)
  .CliUiEditorProjection~new(ed,r)~render
  if r~cell(2,1)<>'default:return' then raise syntax 88.900 array('projected document mismatch')
  if r~cell(4,1)==.nil then raise syntax 88.900 array('status projection absent')
  trace=.CliUiSemanticTrace~new
  trace~record(.CliUiSemanticEvent~new('TextChanged','editor','document','completion','return'),'text=return')
  trace~record(.CliUiSemanticEvent~new('SelectionChanged','editor','document','range','1:4'),'selection')
  expected='TextChanged|editor|document|completion|return|text=return'||"0a"x||'SelectionChanged|editor|document|range|1:4|selection'
  if trace~text<>expected then raise syntax 88.900 array('golden semantic trace mismatch')
  say 'PASS editor projection completion replacement golden semantic trace'
  return
::requires 'CliUiDocument.cls'
::requires 'CliUiSyntax.cls'
::requires 'CliUiCompletion.cls'
::requires 'CliUiApplication.cls'
::requires 'CliUiEditor.cls'
::requires 'CliUiSemantic.cls'
::requires 'CliUiHeadlessRenderer.cls'
::requires 'CliUiEditorProjection.cls'
