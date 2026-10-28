/* Run each BIF case on the ooRexx interpreter.  Prints: ID ACCEPT value | ID REJECT rc.code
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.   Arg: cases file */
parse arg cases
do while lines(cases) > 0
  parse value linein(cases) with id '|' name '|' . '|' . '|' . '|' n '|' rest
  args = .array~new
  do k = 1 to n                     /* the count says how many, so one empty argument is not none */
    parse var rest a '|' rest
    args~append(a)
  end
  say id runOne(name, args)
end
exit 0

runOne: procedure
  use arg name, args
  signal on syntax name failed
  call = name || '('
  do k = 1 to args~items
    if k > 1 then call = call || ','
    call = call || "'" || args[k]~changeStr("'", "''") || "'"
  end
  call = call || ')'
  interpret 'v =' call
  return 'ACCEPT' c2x(v)
failed:
  return 'REJECT' condition('O')['CODE']
