call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root='/tmp/storage-hercules-paper-tape-'||random(100000,999999)
call SysMkDir root

/* Hercules printer output -> canonical PAPER_LISTING.
 * Hercules has already stripped trailing blanks and interpreted carriage
 * control; preserve exactly the observable line/page structure. */
printer='TITLE'||'0A'x||'LINE 1'||'0A'x||'0A'x||'0C'x||'PAGE TWO'||'0D0A'x||'LAST'
listing=.StorageHerculesPrinterBridge~importPrinterBytes('PRINT-1',printer)
call assertEq .StorageSequentialMediaFamily~PAPER_LISTING,listing~family,'printer becomes paper listing'
call assertEq 5,listing~dataRecordCount,'printer lines including blank line preserved'
call assertEq 1,listing~boundaryCount,'printer form feed preserved as page break'
call assertEq 'TITLE',listing~records[1]~data,'first printer line'
call assertEq '',listing~records[3]~data,'blank printer line'
call assertEq .StorageSequentialMediaRecordKind~PAGE_BREAK,listing~records[4]~kind,'page break record'
call assertEq 'PAGE TWO',listing~records[5]~data,'page two first line'

ppath=root||'/prt.txt'
x=.StorageHerculesPrinterBridge~exportListingFile(listing,ppath,.false)
round=.StorageHerculesPrinterBridge~importPrinterFile('PRINT-2',ppath)
call assertListingEq listing,round,'paper listing host projection round trip'
pcfg=.StorageHerculesPrinterBridge~printerConfig('000E',ppath,'1403',.false,.true)
call assertEq '000E 1403 '||ppath||' noclear',pcfg,'1403 config fragment'

/* Canonical tape -> AWSTAPE -> canonical tape. */
tape=.StorageTapeVolumeCodec~newVolume('AWS-IN','BINARY')
.StorageTapeVolumeCodec~addBlock(tape,'ABC')
.StorageTapeVolumeCodec~addBlock(tape,copies('X',70000))
.StorageTapeVolumeCodec~filemark(tape)
.StorageTapeVolumeCodec~addBlock(tape,'TAIL')
aws=.StorageHerculesAwsTapeCodec~toBytes(tape,32768)
call assertTrue aws~length>70000,'AWSTAPE bytes rendered'
awsround=.StorageHerculesAwsTapeCodec~fromBytes('AWS-OUT',aws)
call assertTapeEq tape,awsround,'AWSTAPE canonical round trip including segmented block and filemark'

apath=root||'/work.aws'
x=.StorageHerculesAwsTapeCodec~exportFile(tape,apath,4096)
fileRound=.StorageHerculesAwsTapeCodec~importFile('AWS-FILE',apath)
call assertTapeEq tape,fileRound,'AWSTAPE file round trip'
tcfg=.StorageHerculesAwsTapeCodec~tapeConfig('0180',apath,'3420')
call assertEq '0180 3420 '||apath,tcfg,'3420 AWSTAPE config fragment'

/* Corruption/truncation must fail closed. */
failed=.false
signal on syntax name BadPrev
bad=aws~substr(1,6+3)||'01'x||aws~substr(6+3+2) /* perturb next header previous-length byte */
/* The synthetic splice above may shift content; any malformed stream must fail. */
x=.StorageHerculesAwsTapeCodec~fromBytes('BADPREV',bad)
signal off syntax
signal ContinueBadPrev
BadPrev:
  failed=.true
  signal off syntax
ContinueBadPrev:
call assertTrue failed,'malformed AWSTAPE fails closed'

failed=.false
signal on syntax name EmptyBlock
emptyTape=.StorageTapeVolumeCodec~newVolume('EMPTY','BINARY')
.StorageTapeVolumeCodec~addBlock(emptyTape,'')
x=.StorageHerculesAwsTapeCodec~toBytes(emptyTape)
signal off syntax
signal ContinueEmpty
EmptyBlock:
  failed=.true
  signal off syntax
ContinueEmpty:
call assertTrue failed,'empty data block cannot alias AWSTAPE filemark'

call SysFileDelete ppath
call SysFileDelete apath
call SysRmDir root
say 'PASS Hercules printer/AWSTAPE Storage bridge'
exit 0

::routine assertListingEq
  use arg a,b,label
  call assertEq a~records~items,b~records~items,label 'record count'
  do i=1 to a~records~items
    call assertEq a~records[i]~kind,b~records[i]~kind,label 'kind' i
    call assertEq a~records[i]~data,b~records[i]~data,label 'data' i
  end
::routine assertTapeEq
  use arg a,b,label
  call assertEq a~records~items,b~records~items,label 'record count'
  do i=1 to a~records~items
    call assertEq a~records[i]~kind,b~records[i]~kind,label 'kind' i
    call assertEq a~records[i]~data,b~records[i]~data,label 'data' i
  end
::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageFabric.cls"
::requires "src/StorageSequentialMedia.cls"
::requires "src/StorageHerculesSequentialMedia.cls"