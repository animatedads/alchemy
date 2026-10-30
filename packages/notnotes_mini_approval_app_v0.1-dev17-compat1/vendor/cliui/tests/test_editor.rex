call test
exit 0
test: procedure
  words='say return method expose use strict arg select when otherwise end'~makeArray(' ')
  svc=.CliUiCompletionService~new; svc~register('oorexx',.CliUiWordCompletion~new(words))
  doc=.CliUiDocument~new('say "hello"' || "0a"x || 'ret','oorexx')
  doc~setCaret(doc~text~length+1)
  ed=.CliUiEditor~new(doc,.CliUiSimpleSyntax~new,svc,.CliUiViewport~new(5,20))
  spans=ed~spans; if spans~items<1 then raise syntax 88.900 array('syntax spans absent')
  items=ed~requestCompletion; if items~items<1 then raise syntax 88.900 array('completion absent')
  if items[1]~label~caselessCompare('return')<>0 then raise syntax 88.900 array('return completion absent')
  ed~acceptCompletion
  if doc~text~pos('retreturn')<>0 | doc~text~pos('return')=0 then raise syntax 88.900 array('completion replacement failed')
  ed~resize(3,8); ed~ensureCaretVisible
  lc=doc~lineColumn; if lc[1]<>2 then raise syntax 88.900 array('line tracking failed')
  say 'PASS editor model syntax completion resize caret'
  return
::requires 'CliUiDocument.cls'
::requires 'CliUiSyntax.cls'
::requires 'CliUiCompletion.cls'
::requires 'CliUiApplication.cls'
::requires 'CliUiEditor.cls'
