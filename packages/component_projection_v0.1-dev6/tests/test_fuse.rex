#!/usr/bin/env rexx
src=.ComponentProjectionDirectorySource~new
src~values["depth"]=42
src~values["inject"]=""
src~values["duplex"]="ready"
r=.ComponentProjectionRegistry~new
r~registerReport("QueueFabric","/queuefabric/q/main/depth",src,"depth")
r~registerControl("QueueFabric","/queuefabric/q/main/inject",src,"inject","text/plain","write-only injection",.false,8)
r~registerControl("QueueFabric","/queuefabric/q/main/duplex",src,"duplex","text/plain","read/write control",.true,32)
core=.StorageComponentProjectionFuseCore~new(r,.StorageFuseOperationCore~new,"/components")
g=core~getattr("/components/queuefabric/q/main/depth")
if \g~ok | g~value~kind<>.StorageFuseNodeKind~FILE then call fail "getattr"
o=core~open("/components/queuefabric/q/main/depth","READ")
if \o~ok then call fail "open report"
rd=core~read(o~value~handleId,0,20)
if \rd~ok | rd~value<>"42"||d2c(10) then call fail "read snapshot"
ignore=core~release(o~value~handleId)
bad=core~open("/components/queuefabric/q/main/depth","RW")
if bad~ok then call fail "report accepted write"
wo=core~open("/components/queuefabric/q/main/inject","READ")
if wo~ok then call fail "write-only control accepted read"
w=core~open("/components/queuefabric/q/main/inject","WRITE")
if \w~ok then call fail "open write-only control"
wr=core~write(w~value~handleId,0,"hel")
if \wr~ok then call fail "first fragment"
wr=core~write(w~value~handleId,3,"lo"||d2c(10))
if \wr~ok then call fail "second fragment"
if src~values["inject"]<>"" then call fail "control committed before release"
cl=core~release(w~value~handleId)
if \cl~ok | src~values["inject"]<>"hello" then call fail "release commit"
w2=core~open("/components/queuefabric/q/main/inject","WRITE")
if \w2~ok then call fail "reopen control"
tooBig=core~write(w2~value~handleId,0,"123456789")
if tooBig~ok | tooBig~errno<>27 then call fail "write limit"
ignore=core~release(w2~value~handleId)
duplex=core~open("/components/queuefabric/q/main/duplex","RW")
if \duplex~ok then call fail "read/write control open"
drd=core~read(duplex~value~handleId,0,20)
if \drd~ok | drd~value<>"ready"||d2c(10) then call fail "read/write control read"
ignore=core~release(duplex~value~handleId)
if \core~truncatePath("/components/queuefabric/q/main/inject",0)~ok then call fail "control truncate zero"
dirOpen=core~open("/components/queuefabric/q/main","READ")
if dirOpen~ok | dirOpen~errno<>.StorageFuseErrno~EISDIR then call fail "directory open errno"
say "PASS component projection FUSE"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1
::requires "../src/ComponentProjectionFuse.cls"
