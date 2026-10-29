/* Mutants of each unit SLAM wrote tests for: one small change each, in a copy of the unit's file.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: alchemy repo root | summary from write_tests.rex | groups directory | mutants directory | jobs file
 * Job lines (tab-separated): group file, mutant file, unit, mutant id, SLAM|RAND, change
 * Operators (one token changed): = <-> \=, == <-> \==, < -> <=, <= -> <, > -> >=, >= -> >, <> -> =,
 * + <-> -, * <-> /, // <-> %, & <-> |, a whole number n -> n + 1. A mutant whose routine does not compile
 * is stillborn and not used; a mutant whose text is the original's is impossible by construction.
 */
signal on syntax name onSyntax
parse arg repo '|' summary '|' groupDir '|' mutDir '|' jobsFile
call SysMkDir mutDir
call SysFileDelete jobsFile
swap = .directory~new
swap['=']  = '\='; swap['\='] = '='; swap['=='] = '\=='; swap['\=='] = '=='
swap['<']  = '<='; swap['<='] = '<'; swap['>']  = '>=';  swap['>='] = '>'; swap['<>'] = '='
swap['+']  = '-';  swap['-']  = '+'; swap['*']  = '/';   swap['/']  = '*'
swap['//'] = '%';  swap['%']  = '//'; swap['&'] = '|';   swap['|']  = '&'
units = 0; mutants = 0; stillborn = 0
do while lines(summary) > 0
  parse value linein(summary) with tag name path .
  if tag \== 'UNIT' then iterate
  units += 1
  file = repo || '/' || path
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  lines = text~makeArray('0a'x)
  unit = .nil
  do u over .SlamUnitSplitter~new~split(text)
    if u~kind == 'ROUTINE' then if u~selector == name~upper then unit = u
  end
  if unit == .nil then iterate
  k = 0
  prev = .nil
  prev2 = .nil
  do t over unit~tokens
    p1 = prev
    p2 = prev2
    prev2 = prev
    prev = t
    /* an assignment (x = ...) or a loop's control variable (do i = ...) is not a comparison */
    if t~text == '=' then if p1 \== .nil then if p1~kind == 'IDENT' then do
      if p2 == .nil then iterate
      if p2~kind == 'SEP' then iterate
      if wordpos(p2~text~upper, 'DO LOOP THEN ELSE OTHERWISE') > 0 then iterate
    end
    if t~line \== t~endLine then iterate
    if lines[t~line]~strip~left(2) == '::' then iterate
    new = ''
    if t~kind == 'OP' then if swap~hasIndex(t~text) then new = swap[t~text]
    if t~kind == 'NUMBER' then if datatype(t~text, 'W') then new = t~text + 1
    if new == '' then iterate
    ln = lines[t~line]
    was = ln~substr(t~col, t~endCol - t~col)
    if was \== t~text then if was~upper \== t~text~upper then iterate
    mutated = ln~left(t~col - 1) || new || ln~substr(t~endCol)
    m = lines~copy
    m[t~line] = mutated
    if \compiles(m, name) then do
      stillborn += 1
      iterate
    end
    k += 1
    mutants += 1
    id = name || '_' || right(k, 3, '0')
    mf = mutDir || '/' || id || '.rex'
    call SysFileDelete mf
    call charout mf, m~makeString('L', '0a'x)
    call stream mf, 'C', 'CLOSE'
    change = 'line' t~line || ':' t~text '->' new
    do kind over .array~of('SLAM', 'RAND')
      g = groupDir || '/' || kind || '_' || name~upper || '.testGroup'
      call lineout jobsFile, g || '09'x || mf || '09'x || name || '09'x || id || '09'x || kind || '09'x || change
    end
  end
end
call stream jobsFile, 'C', 'CLOSE'
say 'units' units ' mutants' mutants ' stillborn' stillborn
exit 0

/* Does the routine still compile in the changed file? (the lines after its directive, to the next) */
compiles: procedure
  use arg lines, name
  body = .array~new
  inside = .false
  do ln over lines
    s = ln~strip
    if s~left(2) == '::' then do
      if inside then leave
      parse upper value s with d nm .
      nm = nm~strip('B', ';')~strip('B', "'")~strip('B', '"')
      if d == '::ROUTINE' then if nm == name~upper then do
        inside = .true
        semi = s~pos(';')
        if semi > 0 then body~append(s~substr(semi + 1))
      end
      iterate
    end
    if inside then body~append(ln)
  end
  signal on syntax name noCompile
  r = .Routine~new(name, body)
  return .true
noCompile:
  return .false

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamSegmenter.cls'
