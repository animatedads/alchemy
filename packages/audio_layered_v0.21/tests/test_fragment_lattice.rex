call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs
a=.AudioRecording~new('ANNIE-GLASGOW-SHORT',11634)
a~addRawFeed('RAW',11634,'Audio from op Hardcastle','adult speech reference',.directory~new)

fA=a~createFragmentation('WIN-A','OVERLAP_WINDOW','3.2s windows with 0.4s overlap')
fA~addFragment(.AudioFragment~new('A1',0,3200,0,400,.array~of('RAW')))
fA~addFragment(.AudioFragment~new('A2',2800,6200,400,400,.array~of('RAW')))
fA~addFragment(.AudioFragment~new('A3',5800,9200,400,400,.array~of('RAW')))
fA~addFragment(.AudioFragment~new('A4',8800,11634,400,0,.array~of('RAW')))

fB=a~createFragmentation('WIN-B','OFFSET_WINDOW','offset windows crossing A boundaries')
fB~addFragment(.AudioFragment~new('B1',1200,4500,0,500,.array~of('RAW')))
fB~addFragment(.AudioFragment~new('B2',4000,7600,500,500,.array~of('RAW')))
fB~addFragment(.AudioFragment~new('B3',7100,10400,500,500,.array~of('RAW')))
fB~addFragment(.AudioFragment~new('B4',9900,11634,500,0,.array~of('RAW')))

c=a~compareFragmentations('WIN-A','WIN-B',200)
if c~items < 7 then do
  say 'FAIL expected >=7 cross-window overlaps, got' c~items
  exit 1
end
found=.false
do x over c
  if x~fragmentIdA='A2' & x~fragmentIdB='B1' then do
    if x~startMs=2800 & x~endMs=4500 then found=.true
  end
end
if \found then do
  say 'FAIL A2/B1 overlap not preserved'
  exit 1
end
say 'FRAGMENT LATTICE: OK overlaps='c~items
exit 0

::requires '../AudioCore.cls'
