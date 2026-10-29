/* Run one suite of SLAM's cases (or the random ones) on one mutant, in one process, with ooTest's
 * comparisons: a value with == (assertSame), .nil (assertNull), a syntax error by its code (expectSyntax).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: cases file | unit | file to lift the routine from | SLAM|RAND
 * Prints KILLED (some case's outcome differs) or SURVIVED, and the first case that differed.
 * Hex fields end in '.', so an empty value is '.'.
 */
parse arg casesFile '|' name '|' file '|' suite
r = lift(file, name)
if r == .nil then do
  say 'KILLED does-not-compile'
  exit 0
end
n = 0
do while lines(casesFile) > 0
  ln = linein(casesFile)
  if ln~word(2) \== name then iterate
  if ln~word(3) \== suite then iterate
  n += 1
  parse var ln . . . kind expected nargs rest
  expected = expected~strip('T', '.')~x2c
  args = .array~new
  nargs = nargs~strip('T', '.')
  do i = 1 to nargs
    parse var rest a rest
    args~append(a~strip('T', '.')~x2c)
  end
  o = outcome(r, args)
  ok = .false
  select
    when kind == 'NIL' then ok = (o[1] == 'NIL')
    when kind == 'ERROR' then if o[1] == 'ERROR' then ok = (o[2] = expected)
    otherwise if o[1] == 'VALUE' then ok = (o[2] == expected)
  end
  if \ok then do
    say 'KILLED case' n
    exit 0
  end
end
say 'SURVIVED' n 'cases'
exit 0

outcome: procedure
  use arg r, args
  signal on syntax name failed
  v = r~callWith(args)
  if v == .nil then return .array~of('NIL', '')
  if \v~isA(.String) then return .array~of('OTHER', '')
  return .array~of('VALUE', v)
failed:
  return .array~of('ERROR', condition('O')['CODE'])

/* As the ooTest groups lift it: the lines after the routine's directive, up to the next directive. */
lift: procedure
  use arg file, name
  lines = .array~new
  do while lines(file) > 0; lines~append(linein(file)); end
  call stream file, 'C', 'CLOSE'
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
  return .Routine~new(name, body)
noCompile:
  return .nil
