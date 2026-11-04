#!/usr/bin/env rexx
parse arg port stateRoot evidenceFile
if port='' then port=37075
if stateRoot='' then stateRoot='/tmp/mas-live-gateway'
if evidenceFile='' then evidenceFile=stateRoot||'/gateway-log.txt'
call SysMkDir stateRoot
say 'MAS LIVE GATEWAY port='port 'state='stateRoot 'evidence='evidenceFile
server=.MasLiveGateway~new(port,stateRoot,evidenceFile)
rc=server~serveOnce
say 'MAS LIVE GATEWAY EXIT rc='rc
exit rc
::requires 'MasLiveGateway.cls'
