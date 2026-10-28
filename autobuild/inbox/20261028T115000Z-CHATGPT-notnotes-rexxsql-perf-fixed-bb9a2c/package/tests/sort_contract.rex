a=.array~of(.Sample~new('TR-010'),.Sample~new('TR-002'),.Sample~new('TR-001'))
a~sortWith(.K~new)
if a[1]~DocKey \== 'TR-001' | a[2]~DocKey \== 'TR-002' | a[3]~DocKey \== 'TR-010' then do
  say 'FAIL comparator order'; exit 1
end
say 'PASS native comparator'
exit 0
::class Sample
::method init
 expose key
 use strict arg key
::method DocKey
 expose key
 return key
::class K subclass Comparator
::method compare
 use strict arg a,b
 return a~DocKey~compareTo(b~DocKey)
