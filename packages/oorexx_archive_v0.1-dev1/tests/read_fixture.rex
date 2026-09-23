parse arg zipPath expectedPath
if zipPath == '' | expectedPath == '' then exit 2
a = .Archive~openZip(zipPath)
expected = readFile(expectedPath)
actual = a~extractBytes('reference.txt')
if actual \== expected then do; say 'FAIL reference ZIP content mismatch'; exit 1; end
say 'PASS reference ZIP decoded method=' a~entry('reference.txt')~method 'bytes=' length(actual)
exit 0
readFile: procedure
  use strict arg path
  state=stream(path,'c','open read')
  if left(translate(state),5) \== 'READY' then raise syntax 88.900 array('open failed')
  data=''
  do while chars(path)>0
    n=chars(path); if n>1048576 then n=1048576
    data ||= charin(path,,n)
  end
  call stream path,'c','close'
  return data
::requires '../src/Archive.cls'
