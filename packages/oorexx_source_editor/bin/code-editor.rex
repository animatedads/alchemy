/* Small command-line driver for the ooRexx Source Editor API. */
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
    mode='text'; caseMode='sensitive'
    if args~items>=4 then mode=args[4]
    if args~items>=5 then caseMode=args[5]
    matches=doc~find(args[3],mode,caseMode)
    do m over matches; say m~asString; end
    say 'MATCHES' matches~items
  end
  when cmd='grep' then do
    if args~items<3 then do; call usage; exit 2; end
    mode='text'; caseMode='sensitive'
    if args~items>=4 then mode=args[4]
    if args~items>=5 then caseMode=args[5]
    matches=doc~grep(args[3],mode,caseMode)
    do m over matches; say m~asString; end
    say 'MATCHES' matches~items
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
  say 'code-editor find FILE NEEDLE [text|code [sensitive|insensitive]]'
  say 'code-editor grep FILE REGEX [text|code [sensitive|insensitive]]'
  say 'code-editor validate FILE'
return

::requires "SourceEditor.cls"
