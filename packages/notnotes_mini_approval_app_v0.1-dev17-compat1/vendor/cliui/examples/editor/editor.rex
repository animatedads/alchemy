call main
exit 0

main:
  parse arg file
  if file="" then file="untitled.rex"
  text=""
  if sysFileExists(file) then text=charin(file,,chars(file))
  ext=file~right(4)~lower
  lang="plain"
  if ext=".rex" then lang="oorexx"
  if ext="json" then lang="json"
  if ext=".py" then lang="python"
  doc=.CliUiDocument~new(text,lang)
  syntax=.CliUiSimpleSyntax~new
  completion=.CliUiCompletionService~new
  completion~register("oorexx",.CliUiWordCompletion~new("call do else end expose forward if method parse procedure raise return say select use when"~makeArray(' ')))
  completion~register("python",.CliUiWordCompletion~new("def class import from return if elif else for while try except finally with lambda yield"~makeArray(' ')))
  completion~register("json",.CliUiWordCompletion~new("true false null"~makeArray(' ')))
  spans=syntax~spans(lang,doc~text)
  vars=.directory~new
  items=completion~complete(lang,doc~text,doc~caret,vars)
  say "CLIUI editor fixture:" file "language="lang
  say "syntax spans="spans~items "completion candidates="items~items
  say "The interactive NewShell host binds the same document to ANSI/curses or Wire."
  return

::requires 'CliUiDocument.cls'
::requires 'CliUiSyntax.cls'
::requires 'CliUiCompletion.cls'
::requires 'CliUiApplication.cls'
