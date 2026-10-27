::class Consumer public
::method check
  mode = .Surface~MODE
  s = .Surface~new
  if s~value = 1 then return mode
  return ""
