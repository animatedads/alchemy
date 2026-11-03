/* Invoke a negative case. Success means the codec incorrectly accepted it. */
parse arg caseName path
signal on syntax name rejected
codec = .Compress~new
select
  when translate(caseName) = 'GUNZIP' then discard = codec~gunzip(readFile(path))
  when translate(caseName) = 'INFLATE' then discard = codec~inflate(readFile(path))
  when translate(caseName) = 'UNZSTD' then discard = codec~unzstd(readFile(path))
  otherwise do; say 'bad test case'; exit 2; end
end
say 'FAIL: invalid input was accepted'
exit 1

rejected:
  c = condition('O')
  say 'PASS rejected:' caseName
  if c~hasIndex('ADDITIONAL') then do item over c['ADDITIONAL']; if item \== '' then say '  ' item; end
  exit 0

readFile: procedure
  use strict arg path
  call stream path, 'c', 'open read'
  data = charin(path, , chars(path))
  call stream path, 'c', 'close'
  return data

::requires '../src/Compress.cls'
