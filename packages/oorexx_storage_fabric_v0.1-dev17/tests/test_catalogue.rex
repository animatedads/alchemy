cat=.StorageCatalogue~new
r=.StorageRef~new("sha256:abc","sha256:abc")
o=.StorageObject~new(r,"bodycam-001.mov",12345,"video/quicktime")
o~setEA(.StorageEA~new("evidence","case","CASE-9","STRING","scanner:bodycam","test-authority","2026-09-05T17:00:00+01:00"))
o~addLocation(.StorageLocation~new("tom-space","/srv/space/bodycam/DCIM/VIDEO/bodycam-001.mov","posixfs:/dev/nvme0n1p3",.StorageLocationState~AVAILABLE,"",.false,""))
cat~put(o)
r2=.StorageRef~new("drive:file:xyz")
o2=.StorageObject~new(r2,"interview.wav",9988,"audio/wav")
o2~addLocation(.StorageLocation~new("google-drive","drive:xyz","gdrive:default",.StorageLocationState~AVAILABLE,"",.true,"drive-checksum:xyz"))
cat~put(o2)

call assertEq 1,cat~search("bodycam")~items,"name search"
call assertEq 1,cat~search("/srv/space")~items,"locator search"
call assertEq 1,cat~search("google-drive")~items,"provider search"
call assertEq 1,cat~search("CASE-9")~items,"EA value search"
call assertEq 1,cat~search("evidence.case")~items,"EA key search"

path="/tmp/storage-catalogue-test.tsv"
cat~save(path)
cat2=.StorageCatalogue~new
cat2~load(path)
call SysFileDelete path
call assertEq 2,cat2~count,"persistent catalogue count"
call assertEq 1,cat2~search("interview")~items,"search after reload"
call assertEq "CASE-9",cat2~get("sha256:abc")~eaValue("evidence.case"),"EA persists with catalogue"
say "PASS catalogue search/persistence"
exit 0

::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"