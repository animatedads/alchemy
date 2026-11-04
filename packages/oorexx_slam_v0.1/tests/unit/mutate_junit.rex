/* Mutants of each Java or NetRexx method SLAM wrote JUnit tests for: one token changed, in a copy of
 * the method's source file (the same operators as mutate.rex).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: summary from write_junit.rex | mutants directory | jobs file
 * Job lines (tab-separated): mutant id, mutant source file, package, SLAM test class, random test class,
 * change. Each mutant is in a directory of its own, under its file's own name (a class's file name
 * is its name).
 */
signal on syntax name onSyntax
parse arg summary '|' mutDir '|' jobsFile
call SysMkDir mutDir
call SysFileDelete jobsFile
swap = .directory~new
swap['=']  = '\='; swap['\='] = '='; swap['=='] = '\=='; swap['\=='] = '=='
swap['<']  = '<='; swap['<='] = '<'; swap['>']  = '>=';  swap['>='] = '>'; swap['<>'] = '='
swap['+']  = '-';  swap['-']  = '+'; swap['*']  = '/';   swap['/']  = '*'
swap['//'] = '%';  swap['%']  = '//'; swap['&'] = '|';   swap['|']  = '&'
swap['!='] = '=='; swap['&&'] = '||'; swap['||J'] = '&&'
units = 0; mutants = 0; k = 0
do while lines(summary) > 0
  ln = linein(summary)
  parse var ln tag lang fqn sel arity file line . . . . . slamTest randTest .
  if tag \== 'UNIT' then iterate
  units += 1
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  lines = text~makeArray('0a'x)
  if lang == 'NRX' then us = .SlamNrxSplitter~new~split(text)
  else us = .SlamJavaSplitter~new~split(text)
  unit = .nil
  do u over us
    if u~kind == 'METHOD' then if u~selector~upper == sel~upper then if u~line = line then unit = u
  end
  if unit == .nil then iterate
  pkg = fqn~left(max(fqn~lastPos('.') - 1, 0))
  base = file~substr(file~lastPos('/') + 1)
  prev = .nil
  prev2 = .nil
  do t over unit~tokens
    p1 = prev
    p2 = prev2
    prev2 = prev
    prev = t
    /* an assignment (x = ...) or a loop's control variable (do i = ...) is not a comparison */
    /* x[i] = v and x~name = v are assignments too */
    if t~text == '=' then if p1 \== .nil then if p1~text == ']' then iterate
    if t~text == '=' then if p2 \== .nil then if p2~text == '~' | p2~text == '~~' then iterate
    if t~text == '=' then if p1 \== .nil then if p1~kind == 'IDENT' then do
      if p2 == .nil then iterate
      if p2~kind == 'SEP' then iterate
      if wordpos(p2~text~upper, 'DO LOOP THEN ELSE OTHERWISE') > 0 then iterate
    end
    if t~line \== t~endLine then iterate
    if t~line <= line then iterate
    op = t~text
    if lang == 'JAVA' then if op == '||' then op = '||J'
    new = ''
    if t~kind == 'OP' then if swap~hasIndex(op) then new = swap[op]
    if t~kind == 'NUMBER' then if datatype(t~text, 'W') then new = t~text + 1
    if new == '' then iterate
    if lang == 'JAVA' then if wordpos(t~text, '= \= \== <> // % & |') > 0 then iterate    /* assignment and bit operators: not the same mutation */
    if lang == 'NRX' then if t~text == '||' then iterate
    src = lines[t~line]
    was = src~substr(t~col, t~endCol - t~col)
    if was \== t~text then if was~upper \== t~text~upper then iterate
    k += 1
    mutants += 1
    id = 'M' || right(k, 4, '0')
    m = lines~copy
    m[t~line] = src~left(t~col - 1) || new || src~substr(t~endCol)
    call SysMkDir mutDir || '/' || id
    mf = mutDir || '/' || id || '/' || base
    call SysFileDelete mf
    call charout mf, m~makeString('L', '0a'x)
    call stream mf, 'C', 'CLOSE'
    call lineout jobsFile, id || '09'x || mf || '09'x || pkg || '09'x || slamTest || '09'x || randTest || '09'x || fqn || '.' || sel 'line' t~line || ':' t~text '->' new
  end
end
call stream jobsFile, 'C', 'CLOSE'
say 'units' units ' mutants' mutants
exit 0

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamNetRexx.cls'
::requires 'SlamJava.cls'
