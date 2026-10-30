call test
exit 0
test: procedure
  words='say return method expose use strict arg select when otherwise end'~makeArray(' ')
  svc=.CliUiCompletionService~new; svc~register('oorexx',.CliUiWordCompletion~new(words))
  doc=.CliUiDocument~new('abc'||'0a'x||'def','oorexx'); doc~setCaret(2)
  ed=.CliUiEditor~new(doc,.CliUiSimpleSyntax~new,svc,.CliUiViewport~new(3,10))
  trace=.CliUiSemanticTrace~new; ctl=.CliUiEditorController~new(ed,trace)
  ctl~key('end',,.true); s=doc~selection
  if s[1]<>2 | s[2]<>4 then raise syntax 88.900 array('shift-end selection failed')
  ctl~key('text','X'); if doc~text~left(4)<>'aX'||'0a'x||'d' then raise syntax 88.900 array('selection replacement failed')
  ctl~resize(2,4)
  if ed~viewport~rows<>2 | ed~viewport~cols<>4 then raise syntax 88.900 array('controller resize failed')
  ctl~key('q',,.false,.true)
  if \ctl~quitRequested then raise syntax 88.900 array('quit shortcut failed')
  if trace~entries~items<4 then raise syntax 88.900 array('controller trace incomplete')
  say 'PASS editor controller keys selection resize shortcuts'
  return
::requires 'CliUiDocument.cls'
::requires 'CliUiSyntax.cls'
::requires 'CliUiCompletion.cls'
::requires 'CliUiApplication.cls'
::requires 'CliUiEditor.cls'
::requires 'CliUiSemantic.cls'
::requires 'CliUiEditorController.cls'
