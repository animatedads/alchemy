use arg path
if path='' then do
  say 'usage: rexx scan_file.rex FILE'
  exit 2
end
numeric digits 20
f=.LazyReadFile~new(path,8388608)
bytes=0
blocks=0
do while \f~eof
  block=f~nextBlock
  /* Do work on BLOCK here.  Do not accumulate blocks unless you intend to. */
  bytes+=block~length
  blocks+=1
end
f~release
f~close
say 'scanned' bytes 'bytes in' blocks 'blocks'

::requires '../src/LazyReadFile.cls'
