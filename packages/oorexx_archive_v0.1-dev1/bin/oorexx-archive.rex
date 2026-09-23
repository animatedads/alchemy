#!/usr/bin/env rexx
signal on syntax name failed
parse arg command rest
command = translate(command)
select
  when command == 'LIST' then do
    parse var rest zipPath .
    if zipPath == '' then call usage
    a = .Archive~openZip(zipPath)
    do e over a~entries
      say e~method e~compressedSize e~uncompressedSize e~name
    end
  end
  when command == 'TEST' then do
    parse var rest zipPath .
    if zipPath == '' then call usage
    a = .Archive~openZip(zipPath)
    do e over a~entries
      if \e~isDirectory then discard = a~extractBytes(e)
    end
    say 'OK entries=' a~entries~items
  end
  when command == 'EXTRACT-FRESH' then do
    parse var rest zipPath root .
    if zipPath == '' | root == '' then call usage
    a = .Archive~openZip(zipPath)
    a~extractFresh(root)
    say 'OK extracted entries=' a~entries~items 'root=' root
  end
  otherwise call usage
end
exit 0

usage:
  say 'Usage: oorexx-archive.rex list ZIP'
  say '       oorexx-archive.rex test ZIP'
  say '       oorexx-archive.rex extract-fresh ZIP NEW_ROOT'
  exit 2

failed:
  c = condition('O')
  if c~hasIndex('DESCRIPTION') then say 'ERROR:' c['DESCRIPTION']
  else say 'ERROR: ooRexx condition'
  if c~hasIndex('ADDITIONAL') then do item over c['ADDITIONAL']; say '  ' item; end
  exit 3

::requires '../src/Archive.cls'
