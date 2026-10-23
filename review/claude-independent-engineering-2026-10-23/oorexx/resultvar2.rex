o = .Q~new
o~run
exit
::class Q
::method run
  result = .directory~new
  say "start:                       " result~class
  self~priv
  say "after bare  self~priv:       " result~class
::method priv private
  return 1
