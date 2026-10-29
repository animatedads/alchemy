/* Run SLAM's cases for one routine, in a process of its own, and print each outcome as it comes:
 * @@SLAM i VALUE hex.  |  @@SLAM i NIL  |  @@SLAM i ERROR code  |  @@SLAM i OTHER class
 * The caller runs this under a time limit: a case that does not finish (an input that sends a loop on
 * for ever) prints nothing, and the caller marks it and starts again after it.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: file | routine name | cases file (lines: n hex. hex. ... ; one line per case) | first case
 */
parse arg file '|' name '|' casesFile '|' start
r = lift(file, name)
i = 0
do while lines(casesFile) > 0
  ln = linein(casesFile)
  i += 1
  if i < start then iterate
  parse var ln n rest
  args = .array~new
  do k = 1 to n
    parse var rest a rest
    args~append(a~strip('T', '.')~x2c)
  end
  call charout , '@@SLAM' i outcome(r, args) || '0a'x
end
exit 0

outcome: procedure
  use arg r, args
  signal on syntax name failed
  v = r~callWith(args)
  if v == .nil then return 'NIL'
  if \v~isA(.String) then return 'OTHER' v~class~id
  return 'VALUE' v~c2x || '.'
failed:
  return 'ERROR' condition('O')['CODE']

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
  return .Routine~new(name, body)
