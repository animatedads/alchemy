/* Run one suite of SLAM's cases (or the random ones) on one mutant, in one process, with ooTest's
 * comparisons: a value with == (assertSame), .nil (assertNull), a syntax error by its code (expectSyntax).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: cases file | unit | file to lift the routine from | SLAM|RAND
 * Prints KILLED (some case's outcome differs) or SURVIVED, and the first case that differed.
 * Hex fields end in '.', so an empty value is '.'.
 * A fifth arg ALL (Leg Drop's kill matrix) runs every case: one line KILL n for each case that differs, then END n.
 */
parse arg casesFile '|' name '|' file '|' suite '|' mode
owner = ''
rname = name
if name~pos('~') > 0 then parse var name owner '~' rname    /* CLASS~METHOD */
r = slamLiftFile(file, rname, owner)
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
    if a == '-' then iterate                 /* an argument left out */
    args[i] = a~strip('T', '.')~x2c
  end
  o = outcome(r, args)
  ok = .false
  select
    when kind == 'NIL' then ok = (o[1] == 'NIL')
    when kind == 'CONDITION' then if o[1] == 'CONDITION' then ok = (o[2] == expected)
    when kind == 'ERROR' then if o[1] == 'ERROR' then do
      parse var expected code '0a'x msg      /* the code, and the message the test reads too */
      ok = (o[2] = code)
      if ok then ok = (o[3] == msg)
    end
    otherwise if o[1] == 'VALUE' then ok = (o[2] == expected)
  end
  if \ok then do
    if mode \== 'ALL' then do
      say 'KILLED case' n
      exit 0
    end
    say 'KILL' n                 /* ALL: every case is run, and each one that catches the mutant is named */
  end
end
if mode == 'ALL' then say 'END' n
else say 'SURVIVED' n 'cases'
exit 0

outcome: procedure
  use arg r, args
  signal on syntax name failed
  signal on any name other
  v = r~callWith(args)
  if v == .nil then return .array~of('NIL', '')
  if \v~isA(.String) then return .array~of('OTHER', '')
  return .array~of('VALUE', v)
failed:
  c = condition('O')
  return .array~of('ERROR', c['CODE'], c['MESSAGE'])
other:
  c = condition('O')
  t = ''
  add = c['ADDITIONAL']
  if add \== .nil then do x over add; t = t || ',' || x~string; end
  return .array~of('CONDITION', c['CONDITION'] c['DESCRIPTION'] '[' || t~substr(2) || ']')

::requires 'SlamLift.cls'
