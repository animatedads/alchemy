/* Run SLAM's cases for one routine, in a process of its own, and print each outcome as it comes:
 * @@SLAM i VALUE hex.  |  @@SLAM i NIL  |  @@SLAM i ERROR code message-hex.  |  @@SLAM i OTHER class
 * @@SLAM i CONDITION hex. (another condition the unit raises: its name, description and additional)
 * An argument written - is left out.
 * The caller runs this under a time limit: a case that does not finish (an input that sends a loop on
 * for ever) prints nothing, and the caller marks it and starts again after it.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: file | routine name, or CLASS~METHOD | cases file (lines: n hex. hex. ... ; one line per case) | first case
 */
parse arg file '|' name '|' casesFile '|' start
owner = ''
if name~pos('~') > 0 then parse var name owner '~' name    /* CLASS~METHOD: a method lifted alone */
r = slamLiftFile(file, name, owner)
i = 0
do while lines(casesFile) > 0
  ln = linein(casesFile)
  i += 1
  if i < start then iterate
  parse var ln n rest
  args = .array~new
  do k = 1 to n
    parse var rest a rest
    if a == '-' then iterate                 /* an argument left out: nothing at that place */
    args[k] = a~strip('T', '.')~x2c
  end
  call charout , '@@SLAM' i outcome(r, args) || '0a'x
end
exit 0

outcome: procedure
  use arg r, args
  signal on syntax name failed
  signal on any name other            /* a condition the unit raises (USER, NOTREADY ...) is its outcome */
  v = r~callWith(args)
  if v == .nil then return 'NIL'
  if \v~isA(.String) then return 'OTHER' v~class~id
  return 'VALUE' v~c2x || '.'
failed:
  c = condition('O')
  return 'ERROR' c['CODE'] c['MESSAGE']~c2x || '.'
other:
  c = condition('O')
  t = ''
  add = c['ADDITIONAL']
  if add \== .nil then do x over add; t = t || ',' || x~string; end
  return 'CONDITION' (c['CONDITION'] c['DESCRIPTION'] '[' || t~substr(2) || ']')~c2x || '.'

::requires 'SlamLift.cls'
