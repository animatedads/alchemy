call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root='/tmp/storage-hercules-'||random(100000,999999)
call SysMkDir root

/* Storage -> Hercules ASCII reader file. */
deck=.StorageCardDeckCodec~newDeck('JOB-IN','ASCII',80)
x=.StorageCardDeckCodec~addTextCard(deck,'//HELLO JOB CLASS=A')
x=.StorageCardDeckCodec~addTextCard(deck,'//STEP1 EXEC PGM=IEFBR14')
x=.StorageCardDeckCodec~addTextCard(deck,'')
reader=root||'/reader.cards'
x=.StorageHerculesCardBridge~exportReaderFile(deck,reader,'ASCII_LINES')
raw=readAll(reader)
call assertTrue raw~pos('//HELLO JOB CLASS=A')=1,'ASCII reader deck rendered'
call assertEq 3,countLf(raw),'three card records emitted'

/* Simulate Hercules 3525 ASCII punch behaviour: trailing blanks disappear.
 * Re-import must restore canonical 80-column cards and preserve blank cards. */
punched='//HELLO JOB CLASS=A'||'0A'x||'//STEP1 EXEC PGM=IEFBR14'||'0A'x||'0A'x
punch=root||'/punch.cards'
call writeAll punch,punched
round=.StorageHerculesCardBridge~importPunchFile('JOB-OUT',punch,'ASCII_LINES')
call assertEq 3,round~dataRecordCount,'three punched cards imported'
call assertEq 80,round~records[1]~sizeBytes,'ASCII punch import restores card width'
call assertEq deck~records[1]~data,round~records[1]~data,'first canonical card round trip'
call assertEq deck~records[2]~data,round~records[2]~data,'second canonical card round trip'
call assertEq deck~records[3]~data,round~records[3]~data,'blank canonical card round trip'

/* CRLF is accepted on punch ingress. */
crlf='ONE'||'0D0A'x||'TWO'||'0D0A'x
crlfDeck=.StorageHerculesCardBridge~importPunchBytes('CRLF',crlf,'ASCII_LINES')
call assertEq 2,crlfDeck~dataRecordCount,'CRLF punch records imported'
call assertEq left('ONE',80),crlfDeck~records[1]~data,'CRLF first card padded'

/* Strictness: over-width punch records are never silently truncated. */
failed=.false
signal on syntax name WidePunchFailed
bad=.StorageHerculesCardBridge~importPunchBytes('BAD',copies('X',81)||'0A'x,'ASCII_LINES')
signal off syntax
signal ContinueWide
WidePunchFailed:
  failed=.true
  signal off syntax
ContinueWide:
call assertTrue failed,'over-width ASCII punch card fails closed'

/* Fixed EBCDIC images are byte exact and deliberately translation-free. */
eb=.StorageCardDeckCodec~newDeck('EBCDIC-IN','EBCDIC',80)
eb~addData(copies('C1'x,80))
eb~addData(copies('C2'x,80))
ebpath=root||'/reader.ebc'
x=.StorageHerculesCardBridge~exportReaderFile(eb,ebpath,'EBCDIC_FIXED_80')
ebround=.StorageHerculesCardBridge~importPunchFile('EBCDIC-OUT',ebpath,'EBCDIC_FIXED_80')
call assertEq .StorageCardDeckCodec~toFixedBytes(eb),.StorageCardDeckCodec~toFixedBytes(ebround),'EBCDIC fixed deck byte exact'

/* Configuration snippets remain an edge concern. */
rcfg=.StorageHerculesCardBridge~readerConfig('000C',reader,'ASCII_LINES','eof')
pcfg=.StorageHerculesCardBridge~punchConfig('000D',punch,'ASCII_LINES')
call assertEq '000C 3505 '||reader||' ascii eof',rcfg,'3505 config fragment'
call assertEq '000D 3525 '||punch||' ascii',pcfg,'3525 config fragment'

call SysFileDelete reader
call SysFileDelete punch
call SysFileDelete ebpath
call SysRmDir root
say 'PASS Hercules card reader/punch Storage bridge'
exit 0

::routine readAll
  use arg p
  call stream p,'c','open read'; n=stream(p,'c','query size')+0
  if n>0 then x=charin(p,1,n); else x=''
  call stream p,'c','close'; return x
::routine writeAll
  use arg p,x
  call stream p,'c','open write replace'; left=charout(p,x); call stream p,'c','close'
  if left<>0 then raise syntax 88.900 array('short test write')
  return 0
::routine countLf
  use arg x
  n=0; p=1
  do forever
    p=x~pos('0A'x,p); if p=0 then leave
    n+=1; p+=1
  end
  return n
::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageFabric.cls"
::requires "src/StorageSequentialMedia.cls"
::requires "src/StorageHerculesSequentialMedia.cls"
