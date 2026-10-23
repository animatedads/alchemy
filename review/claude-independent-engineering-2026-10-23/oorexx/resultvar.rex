o = .P~new
o~a
o~b
exit
::class P
::method a
  result = .directory~new
  x = self~helper
  say "after self~helper (message term):        " result~class
::method b
  result = .directory~new
  do i over .array~of(1)
    if .directory~new~hasIndex(i) then nop
  end
  say "after DO OVER + IF:                      " result~class
  s = "x" || self~helper
  say "after message inside concatenation:      " result~class
::method helper
  return 1
