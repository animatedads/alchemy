call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root=directory()||'/tests/tmp-dev3'; address system '/bin/rm -rf '||root; address system '/bin/mkdir -p '||root||'/queue/pending '||root||'/queue/waiting '||root||'/queue/running '||root||'/queue/done '||root||'/queue/failed '||root||'/src '||root||'/dst '||root||'/cp'
/* QueueRexx submission binding */
d=.EvacQueueRexxDispatcher~new(root||'/queue')
c=.Array~of('/bin/true')
r=d~submit(.EvacQueueWorkUnit~new('evac-test',c,42,.EvacQueueJobClass~BULK))
if \r~ok then do; say 'FAIL queue submit' r~code r~detail; exit 1; end
/* governor is accepted by executor and transfer still verifies */
call charout root||'/src/a.bin',copies('abcdefgh',131072); call stream root||'/src/a.bin','c','close'
g=.EvacInventory~new~scan(root||'/src',1)
gov=.EvacBandwidthGovernor~new(100000000)
e=.EvacLocalReplicaExecutor~new(65536,gov)
entry=g~entries['a.bin']; rr=e~transfer(entry,root||'/src',root||'/dst',root||'/cp')
if rr==.nil | rr~state<>.EvacReplicaState~VERIFIED_CURRENT then do; say 'FAIL governed transfer'; exit 2; end
say 'PASS dev3 QueueRexx binding and bandwidth governor'
exit 0
::requires 'src/StorageEvacuation.cls'
::requires 'src/StorageEvacuationQueueRexx.cls'
