parse arg zipPath
if zipPath == '' then do; say 'usage: rexx read_zip.rex archive.zip'; exit 2; end
a = .Archive~openZip(zipPath)
do e over a~entries
  say e~method e~compressedSize e~uncompressedSize e~name
end
::requires '../src/Archive.cls'
