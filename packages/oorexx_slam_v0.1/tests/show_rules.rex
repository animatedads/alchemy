/* The rules of one ooRexx unit, the Java unit whose rules are most like them (SLAM finds it), and
 * where the two agree and differ. Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
 * Args: ooRexx file | OWNER~SELECTOR | Java source directory
 */
signal on syntax name onSyntax
parse arg rexxFile '|' wanted '|' javaDir
rd = .SlamRuleReader~new
text = charin(rexxFile, 1, chars(rexxFile)); call stream rexxFile, 'C', 'CLOSE'
mine = .nil
do u over .SlamUnitSplitter~new~split(text)
  if (u~owner || '~' || u~selector)~upper == wanted~upper then mine = u
end
if mine == .nil then do; say 'no unit' wanted; exit 1; end
rRules = rd~rexxUnit(mine, rexxFile)
say '== ooRexx' mine~owner || '~' || mine~selector '(' || rRules~items 'rules)'
do r over rRules; call showRule r; end

/* every Java unit in the directory, with its rules */
call SysFileTree javaDir || '/*.java', 'f.', 'FSO'
all = .array~new
do i = 1 to f.0
  text = charin(f.i, 1, chars(f.i)); call stream f.i, 'C', 'CLOSE'
  units = .SlamJavaSplitter~new~split(text)
  rd~findReaders(units)
  do u over units
    jr = rd~javaUnit(u, f.i)
    if jr~items > 0 then all~append(.array~of(u, jr, .SlamRuleReader~similarity(rRules, jr)))
  end
end
say
say '== Java units ranked by shared rules (' || all~items 'units have rules)'
best = .nil; bestScore = -1; seconds = .array~new
ranked = .array~new
do e over all; ranked~append(e); end
do 5
  top = 0; topScore = -1
  do k = 1 to ranked~items
    if ranked[k] == .nil then iterate
    if ranked[k][3] > topScore then do; top = k; topScore = ranked[k][3]; end
  end
  if top == 0 then leave
  e = ranked[top]; ranked[top] = .nil
  say '  ' format(e[3], 1, 3) e[1]~owner || '.' || e[1]~selector '(' || e[2]~items 'rules)'
  if best == .nil then best = e
  if seconds~items < 2 then seconds~append(e)
end
do pick over seconds
  call sideBySide rRules, pick, all, mine
end
exit 0

sideBySide: procedure
  use arg rRules, best, all, mine
jRules = best[2]
say '== side by side:' mine~selector '(ooRexx) and' best[1]~selector '(Java)'
jKeys = .directory~new
do r over jRules; jKeys[r~key] = r; end
rKeys = .directory~new
do r over rRules; rKeys[r~key] = r; end
say '-- both'
do r over rRules
  if \jKeys~hasIndex(r~key) then iterate
  j = jKeys[r~key]
  say '  ' r~must
  say '      ooRexx line' r~line r~stop '[' || r~names || ']' r~flags '   Java line' j~line j~stop '[' || j~names || ']' j~flags
end
say '-- only in ooRexx' mine~selector '(and where the same rule is in the Java)'
do r over rRules
  if jKeys~hasIndex(r~key) then iterate
  where = ''
  do e over all
    do j over e[2]
      if j~key == r~key then where = where e[1]~selector || ':' || j~line
    end
  end
  if where == '' then where = 'nowhere in the Java'
  say '  ' r~show '  line' r~line '->' where~strip
end
say '-- only in Java' best[1]~selector
do j over jRules
  if rKeys~hasIndex(j~key) then iterate
  say '  ' j~show '  line' j~line j~stop
end
  return

showRule: procedure
  use arg r
  w = ''
  if r~when \== '' then w = '   when' r~when
  say '  ' left(r~line, 4) left(r~stop, 6) r~show || w
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamRules.cls'
