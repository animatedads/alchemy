::routine assertTrue public
  use arg condition, message
  if \condition then do
    say "FAIL:" message
    raise syntax 93.900 additional(message)
  end
  return .true

::routine assertEqual public
  use arg expected, actual, message
  if expected \== actual then do
    say "FAIL:" message
    say "  expected:" expected
    say "  actual:  " actual
    raise syntax 93.900 additional(message)
  end
  return .true

::routine readBinary public
  use arg path
  s = .Stream~new(path)
  opened = s~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot open fixture: " || path)
  n = s~chars
  if n > 0 then data = s~charin(1, n)
  else data = ""
  ignore = s~close
  return data
