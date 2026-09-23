call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root=directory()||'/tests/tmp-dev8'; address system '/bin/rm -rf '||root; address system '/bin/mkdir -p '||root||'/src/config '||root||'/src/cache'
call lineout root||'/src/config/a.txt','important'; call stream root||'/src/config/a.txt','c','close'
call lineout root||'/src/cache/junk','junk'; call stream root||'/src/cache/junk','c','close'
g=.EvacInventory~new~scan(root||'/src',8,.false)
p=.EvacOperationalPolicy~new; p~selection~exclude('cache'); p~bandwidthBytesPerSec=2500000; p~concurrency=3
r=.EvacDryRunReport~new~render(g,p)
if pos('selected=2',r)=0 | pos('excluded=2',r)=0 then do; say 'FAIL dryrun' r; exit 1; end
p~selection~apply(g)
s=.EvacSession~new('laptop-evac',root||'/src',root||'/dst',root||'/manifest',p)
line=s~renderStatus(g)
if pos('session=laptop-evac',line)=0 | pos('outstanding=2',line)=0 then do; say 'FAIL status' line; exit 2; end
planner=.EvacManifestPlanner~new; intents=planner~plan(g,67108864,512,1073741824)
if intents~items<>1 then do; say 'FAIL planner count' intents~items; exit 3; end
if intents[1]~paths~items<>1 | intents[1]~paths[1]<>'config/a.txt' then do; say 'FAIL planner selection'; exit 4; end
say 'PASS dev8 operational policy/session/planner'
exit 0
::requires 'src/StorageEvacuation.cls'
::requires 'src/StorageEvacuationQueueRexx.cls'
