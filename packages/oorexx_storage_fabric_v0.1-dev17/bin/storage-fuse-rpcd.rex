#!/usr/bin/env rexx
/* Resident ooRexx authority for the native FUSE3 shim.
 * Requires ooRexx Unix Socket v0.6 + Foreign Runtime v0.22.6 on REXX_PATH.
 */
numeric digits 50
parse arg socketPath
if socketPath=="" then socketPath="/tmp/oorexx-storage-fuse.sock"

ignore=.UnixSocket~unlinkPath(socketPath)
server=.UnixSocket~new("SOCK_STREAM")
if server~bind(.UnixAddress~pathname(socketPath))<>0 then call fail server,"bind"
/* Socket path is owner-only: octal 0600 = decimal 384. */
if .UnixSocket~chmodSocketPath(socketPath,"0600")<>0 then call fail server,"chmod"
if server~listen(32)<>0 then call fail server,"listen"

dispatch=.StorageFuseRpcDispatcher~new
say "storage-fuse-rpcd listening" socketPath
say "protocol" .StorageFuseRpcBuild~PROTOCOL "version" .StorageFuseRpcBuild~VERSION

do forever
  peer=server~accept
  if peer==.nil then iterate
  request=""
  tooLarge=.false
  do while pos("0a"x,request)=0
    chunk=peer~recv(65536)
    if chunk==.nil then leave
    if chunk="" then leave
    request=request||chunk
    if length(request)>4194304 then do; tooLarge=.true; leave; end
  end
  if tooLarge then reply="SF1"||"09"x||.StorageFuseErrno~EINVAL||"09"x||c2x("request exceeds 4 MiB RPC limit")||"0a"x
  else if request="" then reply="SF1"||"09"x||.StorageFuseErrno~EINVAL||"09"x||c2x("empty request")||"0a"x
  else reply=dispatch~dispatchLine(request)
  ignore=peer~sendAll(reply)
  peer~close
end

server~close
ignore=.UnixSocket~unlinkSocketPath(socketPath)
exit 0

fail:
  use arg s,where
  say "FAIL storage-fuse-rpcd" where "errno="s~errno s~errorText
  s~close
  ignore=.UnixSocket~unlinkPath(socketPath)
  exit 1

::requires "src/StorageFuseRpc.cls"
::requires "unixsocket.cls"