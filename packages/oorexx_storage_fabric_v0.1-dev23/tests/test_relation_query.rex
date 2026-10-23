fields=.directory~new
fields["name"]="Arthur Dent"; fields["country"]="GB"; fields["balance"]="42.37"; fields["active"]="true"
r1=.StorageRelationRow~new("10001",fields,"v1")
fields=.directory~new
fields["name"]="Ford Prefect"; fields["country"]="GB"; fields["balance"]="1200"; fields["active"]="true"
r2=.StorageRelationRow~new("10002",fields,"v7")
fields=.directory~new
fields["name"]="Zaphod Beeblebrox"; fields["country"]="ZZ"; fields["balance"]="9999"
r3=.StorageRelationRow~new("10003",fields,"v2")

p=.StorageObjectRelationProvider~new("objects")
p~addRow("customers",r1)~addRow("customers",r2)~addRow("customers",r3)
r=.StorageRelationRegistry~new
r~mount("/customers",p,"customers","READ_ONLY")
core=.StorageRelationFuseReadOnlyCore~new(r)

x=core~readdir("/customers:?country=GB&balance>=1000")
call assert x~ok,"query readdir"
call assertEq 1,x~value~items,"one result"
call assertEq "10002",x~value[1],"matching row"
call assert pos("snapshot=REL:objects:",x~detail)>0,"snapshot token surfaced"

x=core~readdir("/customers:?country=GB/10001")
call assert x~ok,"row is directory"
call assert contains(x~value,"name"),"row fields projected"

x=core~getattr("/customers:?country=GB/10001/name")
call assert x~ok,"field getattr"
call assertEq .StorageFuseNodeKind~FILE,x~value~kind,"field is file"

x=core~open("/customers:?country=GB/10001/name","READ")
call assert x~ok,"field open"
h=x~value
call assertEq "Arthur Dent",core~read(h,0,100)~value,"field bytes"
call assert core~release(h)~ok,"release"

x=core~open("/customers:?country=GB/10001","READ")
call assert x~ok,"row canonical open"
data=core~read(x~value,0,4096)~value
call assert pos("id"||"09"x||"10001",data)>0,"canonical id"
call assert pos("name"||"09"x||"Arthur Dent",data)>0,"canonical field"
call assert core~release(x~value)~ok,"row release"

x=core~open("/customers:?country=GB/10001/name","WRITE")
call assertEq .StorageFuseErrno~EROFS,x~errno,"dev14 relation writes fail closed"

/* Query membership is snapshot-bound: mutate source after first traversal and
 * the same query path retains its original membership in this core. */
fields=.directory~new; fields["name"]="Trillian"; fields["country"]="GB"; fields["balance"]="5000"
p~addRow("customers",.StorageRelationRow~new("10004",fields,"v1"))
x=core~readdir("/customers:?country=GB&balance>=1000")
call assertEq 1,x~value~items,"cached query snapshot membership stable"
call assertEq "10002",x~value[1],"same member after source change"

q=.StorageRelationQueryParser~parse("name~Dent&active?")
call assert q~matches(r1),"contains/exists parser"
call assert \q~matches(r3),"contains/exists rejection"

say "PASS relation query projection read-only and snapshot-bound"
exit 0

contains: procedure
  use arg a,wanted
  do x over a; if x=wanted then return .true; end
  return .false
assert: procedure
  use arg truth,label
  if \truth then do; say "FAIL:" label; exit 1; end
  return
assertEq: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  return

::requires "src/StorageRelation.cls"
