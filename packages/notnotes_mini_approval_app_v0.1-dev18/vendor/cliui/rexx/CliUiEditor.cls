::class CliUiEditor public
::method init
  expose document syntax completion viewport path status completionItems completionIndex
  use strict arg document, syntax, completion, viewport
  path=""; status="Ready"; completionItems=.array~new; completionIndex=0
::attribute document get
::attribute viewport get
::attribute status get
::attribute path get
::method open
  expose document path status
  use strict arg file, language=""
  s=.stream~new(file); s~open('read'); text=s~charin(,s~chars); s~close
  if language="" then language=self~languageFor(file)
  document=.CliUiDocument~new(text,language); path=file; status="Opened "||file; return self
::method save
  expose document path status
  use strict arg file=""
  if file="" then file=path
  if file="" then raise syntax 88.900 array('No editor path')
  s=.stream~new(file); s~open('write replace'); s~charout(document~text); s~close
  document~markClean; path=file; status="Saved "||file; return self
::method languageFor
  use strict arg file
  p=file~lastPos('.'); if p=0 then return 'plain'; e=file~substr(p+1)~lower
  if e='rex' | e='cls' then return 'oorexx'
  if e='py' then return 'python'
  if e='json' then return 'json'
  return 'plain'
::method spans; expose document syntax; return syntax~spans(document~language,document~text)
::method requestCompletion
  expose document completion completionItems completionIndex status
  completionItems=completion~complete(document~language,document~text,document~caret,.directory~new)
  if completionItems~items>0 then completionIndex=1; else completionIndex=0
  status=completionItems~items||' completions'; return completionItems
::method completionNext
  expose completionItems completionIndex
  if completionItems~items=0 then return .nil
  completionIndex=(completionIndex//completionItems~items)+1; return completionItems[completionIndex]
::method acceptCompletion
  expose document completionItems completionIndex status
  if completionIndex=0 then return .false
  item=completionItems[completionIndex]
  n=item~prefixLength
  if n>0 then do i=1 to n; document~backspace; end
  document~insert(item~insertText)
  completionItems=.array~new; completionIndex=0; status='Completed '||item~label; return .true
::method resize
  expose viewport
  use strict arg rows,cols
  viewport~rows=rows; viewport~cols=cols; return self
::method ensureCaretVisible
  expose document viewport
  lc=document~lineColumn
  line=lc[1]; col=lc[2]
  if line<viewport~top then viewport~top=line
  if line>=viewport~top+viewport~rows-1 then viewport~top=line-viewport~rows+2
  if col<viewport~left then viewport~left=col
  if col>=viewport~left+viewport~cols then viewport~left=col-viewport~cols+1
  if viewport~top<1 then viewport~top=1
  if viewport~left<1 then viewport~left=1
  return self
