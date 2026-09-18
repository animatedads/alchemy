/* Storage Fabric FUSE local RPC protocol.
 *
 * The kernel-facing libfuse3 shim deliberately owns no Storage semantics.  It
 * sends one bounded request to the resident ooRexx daemon and maps the reply
 * to errno / struct stat / byte buffers.  Strings and data are hex encoded so
 * path names, colons, tabs, newlines and arbitrary file bytes remain unambiguous.
 *
 * Wire format (one line per connection):
 *   SF1<TAB>OP<TAB>field...
 *   SF1<TAB>errno<TAB>field...
 */

::class StorageFuseRpcBuild public
::constant VERSION "0.1-dev14"
::constant API "storage.fabric.fuse.rpc/0.1"
::constant PROTOCOL "SF1"

::class StorageFuseRpcCodec public
::method encode class
  use arg valueArg=""
  return c2x(valueArg~string)
::method decode class
  use arg hexArg=""
  h=hexArg~string~strip
  if h="" then return ""
  if h~length//2<>0 then raise syntax 88.900 array("odd RPC hex field")
  return x2c(h)
::method split class
  use arg lineArg
  line=lineArg~string
  a=.array~new
  tab="09"x
  do forever
    p=pos(tab,line)
    if p=0 then do
      a~append(line)
      leave
    end
    a~append(left(line,p-1))
    line=substr(line,p+1)
  end
  return a
::method join class
  use arg fieldsArg
  tab="09"x
  out=""
  first=.true
  do item over fieldsArg
    if \first then out=out||tab
    out=out||item~string
    first=.false
  end
  return out

::class StorageFuseRpcDispatcher public
::attribute core get
::method init
  expose core
  use arg coreArg=.nil
  if coreArg==.nil then core=.StorageFuseOperationCore~new
  else core=coreArg
::method dispatchLine
  use arg lineArg
  line=lineArg~string
  do while line~length>0 & (right(line,1)="0a"x | right(line,1)="0d"x)
    line=left(line,line~length-1)
  end
  fields=.StorageFuseRpcCodec~split(line)
  if fields~items<2 then return self~errorLine(.StorageFuseErrno~EINVAL,"short RPC request")
  if fields[1]<>.StorageFuseRpcBuild~PROTOCOL then return self~errorLine(.StorageFuseErrno~EINVAL,"unsupported RPC protocol")
  op=fields[2]~upper
  signal on syntax name badRequest
  select
    when op="PING" then return self~reply(0,.array~of(.StorageFuseRpcCodec~encode("PONG")))
    when op="GETATTR" then return self~doGetattr(fields)
    when op="READDIR" then return self~doReaddir(fields)
    when op="OPEN" then return self~doOpen(fields,.false)
    when op="CREATE" then return self~doOpen(fields,.true)
    when op="MKDIR" then return self~doMkdir(fields)
    when op="READ" then return self~doRead(fields)
    when op="WRITE" then return self~doWrite(fields)
    when op="TRUNCATEH" then return self~doTruncateHandle(fields)
    when op="TRUNCATE" then return self~doTruncatePath(fields)
    when op="RELEASE" then return self~doRelease(fields)
    when op="UNLINK" then return self~doUnlink(fields)
    when op="RENAME" then return self~doRename(fields)
    when op="RMDIR" then return self~doRmdir(fields)
    when op="VREAD" then return self~doVirtualRead(fields)
    otherwise return self~errorLine(.StorageFuseErrno~ENOTSUP,"unknown RPC operation "||op)
  end
badRequest:
  return self~errorLine(.StorageFuseErrno~EINVAL,"malformed RPC request")
::method doGetattr private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"GETATTR arity")
  r=core~getattr(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  n=r~value
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(n~kind), n~size, n~generation, .StorageFuseRpcCodec~encode(n~state), .StorageFuseRpcCodec~encode(r~detail)))
::method doReaddir private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"READDIR arity")
  r=core~readdir(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  out=.array~new
  out~append(r~value~items)
  do n over r~value; out~append(.StorageFuseRpcCodec~encode(n)); end
  out~append(.StorageFuseRpcCodec~encode(r~detail))
  return self~reply(0,out)
::method doOpen private
  expose core
  use arg f,isCreate
  if f~items<3 | f~items>4 then return self~errorLine(.StorageFuseErrno~EINVAL,"OPEN/CREATE arity")
  path=.StorageFuseRpcCodec~decode(f[3])
  mode="READ"
  if f~items=4 then mode=.StorageFuseRpcCodec~decode(f[4])
  if isCreate then r=core~create(path,mode)
  else r=core~open(path,mode)
  if \r~ok then return self~resultError(r)
  h=r~value
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(h~handleId), .StorageFuseRpcCodec~encode(r~detail)))
::method doMkdir private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"MKDIR arity")
  r=core~mkdir(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doRead private
  expose core
  use arg f
  if f~items<>5 then return self~errorLine(.StorageFuseErrno~EINVAL,"READ arity")
  h=.StorageFuseRpcCodec~decode(f[3]); off=f[4]+0; count=f[5]+0
  r=core~read(h,off,count)
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~value), .StorageFuseRpcCodec~encode(r~detail)))
::method doWrite private
  expose core
  use arg f
  if f~items<>5 then return self~errorLine(.StorageFuseErrno~EINVAL,"WRITE arity")
  h=.StorageFuseRpcCodec~decode(f[3]); off=f[4]+0; data=.StorageFuseRpcCodec~decode(f[5])
  r=core~write(h,off,data)
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(r~value, .StorageFuseRpcCodec~encode(r~detail)))
::method doTruncateHandle private
  expose core
  use arg f
  if f~items<>5 & f~items<>4 then return self~errorLine(.StorageFuseErrno~EINVAL,"TRUNCATEH arity")
  h=.StorageFuseRpcCodec~decode(f[3]); size=f[4]+0
  r=core~truncate(h,size)
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doTruncatePath private
  expose core
  use arg f
  if f~items<>4 then return self~errorLine(.StorageFuseErrno~EINVAL,"TRUNCATE arity")
  r=core~truncatePath(.StorageFuseRpcCodec~decode(f[3]),f[4]+0)
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doRelease private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"RELEASE arity")
  r=core~release(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doUnlink private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"UNLINK arity")
  r=core~unlink(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doRename private
  expose core
  use arg f
  if f~items<>4 then return self~errorLine(.StorageFuseErrno~EINVAL,"RENAME arity")
  r=core~rename(.StorageFuseRpcCodec~decode(f[3]),.StorageFuseRpcCodec~decode(f[4]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doRmdir private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"RMDIR arity")
  r=core~rmdir(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~detail)))
::method doVirtualRead private
  expose core
  use arg f
  if f~items<>3 then return self~errorLine(.StorageFuseErrno~EINVAL,"VREAD arity")
  r=core~readVirtual(.StorageFuseRpcCodec~decode(f[3]))
  if \r~ok then return self~resultError(r)
  return self~reply(0,.array~of(.StorageFuseRpcCodec~encode(r~value), .StorageFuseRpcCodec~encode(r~detail)))
::method resultError private
  use arg r
  return self~errorLine(r~errno,r~detail)
::method errorLine private
  use arg errnoArg,detailArg=""
  return self~reply(errnoArg,.array~of(.StorageFuseRpcCodec~encode(detailArg)))
::method reply private
  use arg errnoArg,tailArg=.nil
  f=.array~of(.StorageFuseRpcBuild~PROTOCOL,errnoArg+0)
  if tailArg<>.nil then do x over tailArg; f~append(x); end
  return .StorageFuseRpcCodec~join(f)||"0a"x

::requires "src/StorageFuse.cls"