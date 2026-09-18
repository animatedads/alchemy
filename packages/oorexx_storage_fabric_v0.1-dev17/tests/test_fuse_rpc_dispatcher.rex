numeric digits 50

d=.StorageFuseRpcDispatcher~new
call assertEq rpcField(d~dispatchLine("SF1"||"09"x||"PING"),2),0,"PING errno"
call assertEq decodeField(d~dispatchLine("SF1"||"09"x||"PING"),3),"PONG","PING response"

call rpcOk d,"MKDIR",enc("/work")
r=rpc(d,"CREATE",enc("/work/a.txt"),enc("RW"))
call assertEq rpcField(r,2),0,"CREATE errno"
h=decodeField(r,3)
call assertTrue h<>"","CREATE handle"

r=rpc(d,"WRITE",enc(h),0,enc("alpha"||"00"x||"beta"))
call assertEq rpcField(r,2),0,"WRITE errno"
call assertEq rpcField(r,3),10,"WRITE count"
call rpcOk d,"RELEASE",enc(h)

/* Application named stream can be created through the same FUSE CREATE path. */
r=rpc(d,"CREATE",enc("/work/a.txt:thumb"),enc("RW")); sh=decodeField(r,3)
call assertEq rpcField(r,2),0,"named stream CREATE"
r=rpc(d,"WRITE",enc(sh),0,enc("side")); call assertEq rpcField(r,2),0,"named stream WRITE"
call rpcOk d,"RELEASE",enc(sh)
r=rpc(d,"OPEN",enc("/work/a.txt:thumb"),enc("READ")); srh=decodeField(r,3)
r=rpc(d,"READ",enc(srh),0,64); call assertEq decodeField(r,3),"side","named stream content"
call rpcOk d,"RELEASE",enc(srh)

r=rpc(d,"OPEN",enc("/work/a.txt"),enc("READ"))
call assertEq rpcField(r,2),0,"OPEN errno"
rh=decodeField(r,3)
r=rpc(d,"READ",enc(rh),0,64)
call assertEq decodeField(r,3),"alpha"||"00"x||"beta","binary READ roundtrip"
call rpcOk d,"RELEASE",enc(rh)

r=rpc(d,"GETATTR",enc("/work/a.txt"))
call assertEq rpcField(r,2),0,"GETATTR errno"
call assertEq decodeField(r,3),"FILE","GETATTR kind"
call assertEq rpcField(r,4),10,"GETATTR size"

r=rpc(d,"READDIR",enc("/work"))
call assertEq rpcField(r,2),0,"READDIR errno"
call assertEq rpcField(r,3),1,"READDIR count"
call assertEq decodeField(r,4),"a.txt","READDIR name"

/* :frozen auto-acquires a complete generation when no old writer drains. */
r=rpc(d,"READDIR",enc("/work:frozen"))
call assertEq rpcField(r,2),0,"frozen READDIR errno"
call assertEq rpcField(r,3),1,"frozen count"
call assertEq decodeField(r,4),"a.txt","frozen member"
r=rpc(d,"GETATTR",enc("/work:frozen/a.txt"))
call assertEq rpcField(r,2),0,"frozen GETATTR"
g=rpcField(r,5)
call assertTrue g>0,"frozen generation"

/* mutate live; exact frozen generation remains immutable */
r=rpc(d,"OPEN",enc("/work/a.txt"),enc("RW")); wh=decodeField(r,3)
r=rpc(d,"WRITE",enc(wh),0,enc("NEW")); call assertEq rpcField(r,2),0,"live rewrite"
call rpcOk d,"RELEASE",enc(wh)
r=rpc(d,"OPEN",enc("/work:g"||g||"/a.txt"),enc("READ")); gh=decodeField(r,3)
r=rpc(d,"READ",enc(gh),0,64)
call assertEq decodeField(r,3),"alpha"||"00"x||"beta","generation immutability"
call rpcOk d,"RELEASE",enc(gh)

say "PASS FUSE RPC dispatcher"
exit 0

rpc:
  procedure
  use arg d,op,a=.nil,b=.nil,c=.nil
  line="SF1"||"09"x||op
  if a<>.nil then line=line||"09"x||a
  if b<>.nil then line=line||"09"x||b
  if c<>.nil then line=line||"09"x||c
  return d~dispatchLine(line)

rpcOk:
  procedure
  use arg d,op,a=.nil,b=.nil,c=.nil
  r=rpc(d,op,a,b,c)
  if rpcField(r,2)<>0 then do
    say "FAIL RPC" op "errno" rpcField(r,2) "detail" decodeField(r,3)
    exit 1
  end
  return

rpcField:
  procedure
  use arg line,index
  do while line~length>0 & (right(line,1)="0a"x | right(line,1)="0d"x)
    line=left(line,line~length-1)
  end
  a=.StorageFuseRpcCodec~split(line)
  if index>a~items then return ""
  return a[index]

enc:
  procedure
  use arg s
  return .StorageFuseRpcCodec~encode(s)

decodeField:
  procedure
  use arg line,index
  return .StorageFuseRpcCodec~decode(rpcField(line,index))

assertEq:
  procedure
  use arg actual,expected,label
  if actual<>expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertTrue:
  procedure
  use arg value,label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return

::requires "src/StorageFuseRpc.cls"