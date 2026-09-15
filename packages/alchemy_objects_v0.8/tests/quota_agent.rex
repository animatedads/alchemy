parse arg mode
if mode = "OBJECT" then do
  a1 = .QuotaVictim~new
  a2 = .QuotaVictim~new
  a1~metered(1)
  a1~metered(2)
  a2~metered(3)
  a2~metered(4)
  return a1~metered(5)
end
if mode = "CONTEXT" then do
  a1 = .QuotaVictim~new
  a2 = .QuotaVictim~new
  a1~metered(1)
  a2~metered(2)
  a1~metered(3)
  return a2~metered(4)
end
raise syntax 88.900 array("unknown quota agent mode")

::class QuotaVictim public
::method metered public protected
  use strict arg n
  return n * 10
