/* argument_semantics.rex */
call probe
call probe .nil
call probe ""
call probe "value"
say "ARGUMENT SEMANTICS BASELINE PASS"
exit

probe: procedure
  present = arg(1, "E")
  if \present then do
    say "arg-case:OMITTED"
    return
  end
  value = arg(1)
  if value == .nil then say "arg-case:NIL"
  else if value == "" then say "arg-case:EMPTY"
  else say "arg-case:VALUE:"value
  return
