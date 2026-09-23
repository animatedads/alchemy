f=.directory~new; f["name"]="Arthur Dent"; f["country"]="GB"
p=.StorageObjectRelationProvider~new("objects")
p~addRow("customers",.StorageRelationRow~new("10001",f,"v1"))
reg=.StorageRelationRegistry~new; reg~mount("/customers",p,"customers")
rel=.StorageRelationFuseReadOnlyCore~new(reg)
ordinary=.StorageFuseOperationCore~new
core=.StorageFuseCompositeCore~new(ordinary,rel)
d=.StorageFuseRpcDispatcher~new(core)

path=.StorageFuseRpcCodec~encode("/customers:?country=GB")
line="SF1"||"09"x||"READDIR"||"09"x||path
reply=d~dispatchLine(line)
call assert left(reply,5)="SF1"||"09"x||"0"||"09"x,"RPC readdir succeeds"
call assert pos(c2x("10001"),reply)>0,"RPC contains row id"

field=.StorageFuseRpcCodec~encode("/customers:?country=GB/10001/name")
mode=.StorageFuseRpcCodec~encode("READ")
reply=d~dispatchLine("SF1"||"09"x||"OPEN"||"09"x||field||"09"x||mode)
parts=.StorageFuseRpcCodec~split(strip(reply,"T","0a"x))
call assertEq "0",parts[2],"RPC open success"
h=.StorageFuseRpcCodec~decode(parts[3])
call assert left(h,2)="rq","relation handle routed"
reply=d~dispatchLine("SF1"||"09"x||"READ"||"09"x||.StorageFuseRpcCodec~encode(h)||"09"x||"0"||"09"x||"100")
parts=.StorageFuseRpcCodec~split(strip(reply,"T","0a"x))
call assertEq "0",parts[2],"RPC read success"
call assertEq "Arthur Dent",.StorageFuseRpcCodec~decode(parts[3]),"RPC field bytes"

wmode=.StorageFuseRpcCodec~encode("WRITE")
reply=d~dispatchLine("SF1"||"09"x||"OPEN"||"09"x||field||"09"x||wmode)
parts=.StorageFuseRpcCodec~split(strip(reply,"T","0a"x))
call assertEq .StorageFuseErrno~EROFS,parts[2],"RPC relation write fail closed"

say "PASS relation query through FUSE RPC composite core"
exit 0
assert: procedure
  use arg truth,label
  if \truth then do; say "FAIL:" label; exit 1; end
  return
assertEq: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  return
::requires "src/StorageRelation.cls"
::requires "src/StorageFuseRpc.cls"
