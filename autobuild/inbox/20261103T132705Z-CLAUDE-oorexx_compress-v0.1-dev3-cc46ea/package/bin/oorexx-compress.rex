#!/usr/bin/env rexx
signal on syntax name failed
parse arg mode inPath outPath extra
mode = translate(mode)
if mode = '' | mode = '-H' | mode = '--HELP' | mode = 'HELP' then do
  call usage
  exit 0
end
if inPath = '' | outPath = '' | extra \== '' then do
  call usage
  exit 2
end

codec = .Compress~new
input = readFile(inPath)
select
  when mode = 'GZIP' | mode = 'GZIP-FIXED' | mode = 'FIXED' then output = codec~gzip(input, 'FIXED')
  when mode = 'GZIP-STORED' | mode = 'STORED' then output = codec~gzip(input, 'STORED')
  when mode = 'GUNZIP' then output = codec~gunzip(input)
  when mode = 'ZSTD' | mode = 'ZSTD-AUTO' then output = codec~zstd(input, 'AUTO', .true)
  when mode = 'ZSTD-RAW' then output = codec~zstd(input, 'RAW', .true)
  when mode = 'ZSTD-RLE' then output = codec~zstd(input, 'RLE', .true)
  when mode = 'ZSTD-NOCHECKSUM' then output = codec~zstd(input, 'AUTO', .false)
  when mode = 'UNZSTD' then output = codec~unzstd(input)
  otherwise do
    say 'ERROR: unknown mode:' mode
    call usage
    exit 2
  end
end
call writeFile outPath, output
say 'OK' mode ':' inPath '->' outPath
exit 0

usage:
  say 'oorexx-compress.rex - pure ooRexx bootstrap compression codec'
  say 'Usage: rexx oorexx-compress.rex MODE INPUT OUTPUT'
  say 'Modes: gzip gzip-stored gunzip zstd zstd-raw zstd-rle zstd-nochecksum unzstd'
  return

readFile: procedure
  use strict arg path
  state = stream(path, 'c', 'open read')
  if left(translate(state), 5) \== 'READY' then raise syntax 88.900 array('Cannot open input: ' || path || ' (' || state || ')')
  data = ''
  do while chars(path) > 0
    count = chars(path)
    if count > 1048576 then count = 1048576
    data ||= charin(path, , count)
  end
  call stream path, 'c', 'close'
  return data

writeFile: procedure
  use strict arg path, data
  state = stream(path, 'c', 'open write replace')
  if left(translate(state), 5) \== 'READY' then raise syntax 88.900 array('Cannot open output: ' || path || ' (' || state || ')')
  unwritten = charout(path, data)
  call stream path, 'c', 'close'
  if unwritten \== 0 then raise syntax 88.900 array('Short write to output: ' || path)
  return

failed:
  c = condition('O')
  if c~hasIndex('DESCRIPTION') then say 'ERROR:' c['DESCRIPTION']
  else say 'ERROR: ooRexx condition'
  if c~hasIndex('ADDITIONAL') then do item over c['ADDITIONAL']; say '  ' item; end
  exit 3

::requires '../src/Compress.cls'
