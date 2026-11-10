/* each line below is a trap rexx_pitfalls.rex must find (4 in all) */
phrase = '"'('the' x)'"'
call out '  UNREAD  'x
uNp = 1; unP = 2
f: procedure
  use arg en, ids
  do en over ids
  end
  return
