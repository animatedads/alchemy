::class CliUiEditorController public
::method init
  expose editor trace quitRequested
  use strict arg editor, trace=.nil
  quitRequested=.false
::attribute quitRequested get
::method key
  expose editor trace quitRequested
  use strict arg key, text="", shift=.false, ctrl=.false
  doc=editor~document
  k=key~lower
  if ctrl then do
    select
      when k='s' then do; editor~save; self~event('Command','save'); return .true; end
      when k='space' then do; editor~requestCompletion; self~event('Command','complete'); return .true; end
      when k='q' then do; quitRequested=.true; self~event('Command','quit'); return .true; end
      otherwise return .false
    end
  end
  select
    when k='text' then doc~insert(text)
    when k='left' then doc~moveCaret(-1,shift)
    when k='right' then doc~moveCaret(1,shift)
    when k='up' then doc~moveLine(-1,shift)
    when k='down' then doc~moveLine(1,shift)
    when k='home' then doc~moveLineHome(shift)
    when k='end' then doc~moveLineEnd(shift)
    when k='backspace' then doc~backspace
    when k='delete' then doc~delete
    when k='enter' then doc~insert('0a'x)
    when k='tab' then doc~insert('  ')
    when k='completionnext' then editor~completionNext
    when k='completionaccept' then editor~acceptCompletion
    otherwise return .false
  end
  editor~ensureCaretVisible
  self~event('Key',k)
  return .true
::method resize
  expose editor
  use strict arg rows,cols
  editor~resize(rows,cols); editor~ensureCaretVisible
  self~event('Resize',rows||'x'||cols)
  return self
::method event
  expose trace
  use strict arg trigger, detail
  if trace<>.nil then trace~record(.CliUiSemanticEvent~new(trigger,'editor','document','detail',detail),'handled')
  return self
::requires 'CliUiSemantic.cls'
