/* Small command-line driver for the ooRexx Source Editor API. v0.1-dev8 */
parse arg commandLine
if commandLine='' then do; call usage; exit 2; end
args=.array~new
rest=commandLine
/* intentionally simple quoted-token parser suitable for the development CLI */
do while rest~strip<>''
  rest=rest~strip
  if rest~left(1)='"' then do
    p=rest~pos('"',2)
    if p=0 then do; say 'ERROR: unmatched quote'; exit 2; end
    args~append(rest~substr(2,p-2)); rest=rest~substr(p+1)
  end
  else do
    p=rest~pos(' ')
    if p=0 then do; args~append(rest); rest=''; end
    else do; args~append(rest~left(p-1)); rest=rest~substr(p+1); end
  end
end
if args~items<2 then do; call usage; exit 2; end
cmd=args[1]~lower; file=args[2]
signal on syntax name failed

if cmd='find-file' then do
  if args~items<3 then do; call usage; exit 2; end
  language=''
  if args~items>=4 then language=args[4]
  finder=.SourceTreeFinder~new(file)
  found=finder~files(args[3],language)
  do f over found; say f~asString; end
  say 'FILES' found~items
  exit 0
end
if cmd='grep-tree' then do
  if args~items<3 then do; call usage; exit 2; end
  filespec='*'; mode='code'; caseMode='sensitive'; language=''
  if args~items>=4 then filespec=args[4]
  if args~items>=5 then mode=args[5]
  if args~items>=6 then caseMode=args[6]
  if args~items>=7 then language=args[7]
  finder=.SourceTreeFinder~new(file)
  matches=finder~grep(args[3],filespec,mode,caseMode,language)
  do m over matches; say m~asString; end
  say 'MATCHES' matches~items
  exit 0
end
if cmd='references-tree' then do
  if args~items<3 then do; call usage; exit 2; end
  filespec='*'; language=''; caseMode='sensitive'
  if args~items>=4 then filespec=args[4]
  if args~items>=5 then language=args[5]
  if args~items>=6 then caseMode=args[6]
  finder=.SourceTreeFinder~new(file)
  matches=finder~references(args[3],filespec,caseMode,language)
  do m over matches; say m~asString; end
  say 'REFERENCES' matches~items
  exit 0
end
if cmd='complete-tree' then do
  prefix=''; filespec='*'; language=''
  if args~items>=3 then prefix=args[3]
  if args~items>=4 then filespec=args[4]
  if args~items>=5 then language=args[5]
  provider=.SourceCompletionProvider~new
  candidates=provider~completeTree(file,prefix,filespec,language)
  do c over candidates; say c~asString; end
  say 'CANDIDATES' candidates~items
  exit 0
end
doc=.SourceDocument~new(file)
select
  when cmd='symbols' then do
    do s over doc~symbols; say s~asString; end
  end
  when cmd='show' then do
    first=1; last=doc~lineCount
    if args~items>=3 then first=args[3]
    if args~items>=4 then last=args[4]
    do i=first to last; say right(i,5,'0')'|' doc~line(i); end
  end
  when cmd='replace-line' then do
    if args~items<4 then do; call usage; exit 2; end
    doc~replaceLine(args[3],args[4]); doc~save; say 'UPDATED' file
  end
  when cmd='delete' then do
    first=args[3]; last=first; if args~items>=4 then last=args[4]
    doc~deleteRange(first,last); doc~save; say 'UPDATED' file
  end
  when cmd='replace-symbol' then do
    if args~items<4 then do; call usage; exit 2; end
    doc~replaceSymbol(args[3],args[4]); doc~save; say 'UPDATED' file
  end
  when cmd='find' then do
    if args~items<3 then do; call usage; exit 2; end
    parsed=.SourceEditorCliSearchArgs~parse(args,3,'text','sensitive')
    matches=doc~find(parsed~expression,parsed~mode,parsed~caseMode)
    do m over matches; say m~asString; end
    say 'MATCHES' matches~items
  end
  when cmd='grep' then do
    if args~items<3 then do; call usage; exit 2; end
    parsed=.SourceEditorCliSearchArgs~parse(args,3,'text','sensitive')
    matches=doc~grep(parsed~expression,parsed~mode,parsed~caseMode)
    do m over matches; say m~asString; end
    say 'MATCHES' matches~items
  end
  when cmd='references' then do
    if args~items<3 then do; call usage; exit 2; end
    caseMode='sensitive'
    if args~items>=4 then caseMode=args[4]
    matches=doc~references(args[3],caseMode)
    do m over matches; say m~asString; end
    say 'REFERENCES' matches~items
  end
  when cmd='complete' then do
    prefix=''; kind=''
    if args~items>=3 then prefix=args[3]
    if args~items>=4 then kind=args[4]
    provider=.SourceCompletionProvider~new
    candidates=provider~completeDocument(doc,prefix,kind)
    do c over candidates; say c~asString; end
    say 'CANDIDATES' candidates~items
  end
  when cmd='validate' then do
    if doc~validate then say 'VALID' doc~language file
  end
  otherwise do; call usage; exit 2; end
end
exit 0
failed:
  say 'ERROR:' condition('D')
  exit 1

usage:
  say 'code-editor symbols FILE'
  say 'code-editor show FILE [FIRST [LAST]]'
  say 'code-editor replace-line FILE LINE "TEXT"'
  say 'code-editor delete FILE FIRST [LAST]'
  say 'code-editor replace-symbol FILE NAME "TEXT"'
  say 'code-editor find FILE WORDS... [--mode text|code] [--case sensitive|insensitive]'
  say 'code-editor grep FILE REGEX... [--mode text|code] [--case sensitive|insensitive]'
  say 'code-editor find-file ROOT FILESPEC [LANGUAGE]'
  say 'code-editor grep-tree ROOT REGEX [FILESPEC [text|code [sensitive|insensitive [LANGUAGE]]]]'
  say 'code-editor references FILE NAME [sensitive|insensitive]'
  say 'code-editor references-tree ROOT NAME [FILESPEC [LANGUAGE [sensitive|insensitive]]]'
  say 'code-editor complete FILE [PREFIX [KIND]]'
  say 'code-editor complete-tree ROOT [PREFIX [FILESPEC [LANGUAGE]]]'
  say 'code-editor validate FILE'
return

::requires "SourceEditor.cls"
