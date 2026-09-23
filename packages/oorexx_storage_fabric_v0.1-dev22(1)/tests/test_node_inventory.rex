GB=1024*1024*1024
inv=.StorageNodeInventory~new

unknown=.StorageServiceLifecycle~new(.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE)
disposable=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"2026-10","temporary Azure trial")

inv~putNode(.StorageNodeDescriptor~new("ed209a","oracle","193.123.184.140","",unknown,"2026-09-06","user inventory"))
inv~putNode(.StorageNodeDescriptor~new("ed209b","oracle","193.123.190.35","",unknown,"2026-09-06","user inventory"))
inv~putNode(.StorageNodeDescriptor~new("ed209c","microsoft","52.146.17.8","US-EAST",disposable,"2026-09-06","user inventory"))
inv~putNode(.StorageNodeDescriptor~new("ed209d","aws","16.170.244.216","EU-NORTH-1",unknown,"2026-09-06","user inventory"))

call assertEq 4,inv~allNodes~items,"four ED209 nodes"
call assertEq 2,inv~byProvider("oracle")~items,"two Oracle nodes"
call assertEq "52.146.17.8",inv~node("ed209c")~endpoint,"Azure endpoint retained separately from identity"
call assertTrue inv~node("ed209c")~lifecycle~disposable,"Azure service lifecycle is disposable"
call assertFalse inv~node("ed209c")~lifecycle~countsAsDurable,"Azure trial cannot count as durable safety"

/* Presence is not admission.  The large Azure block devices are visible but
 * cannot become workspace merely because fdisk can see them. */
inv~observeDevice(.StorageDeviceObservation~new("ed209c","/dev/nvme0n1",30*GB,.StorageDeviceAdmission~WORKSPACE,"MSFT NVMe Accelerator v1.0","2026-09-05","fdisk"))
inv~observeDevice(.StorageDeviceObservation~new("ed209c","/dev/nvme0n2",1024*GB,.StorageDeviceAdmission~UNQUALIFIED,"MSFT NVMe Accelerator v1.0","2026-09-05","fdisk"))
inv~observeDevice(.StorageDeviceObservation~new("ed209c","/dev/nvme1n1",110*GB,.StorageDeviceAdmission~UNQUALIFIED,"Microsoft NVMe Direct Disk v2","2026-09-05","fdisk"))
call assertEq 3,inv~devicesForNode("ed209c")~items,"three observed Azure devices"
call assertEq 1,inv~admittedWorkspaceDevicesForNode("ed209c")~items,"only explicitly admitted device is workspace"

p="tests/.tmp-node-inventory.tsv"
inv~save(p)
inv2=.StorageNodeInventory~new~load(p)
call assertEq 4,inv2~allNodes~items,"node inventory survives restart"
call assertEq 3,inv2~devicesForNode("ed209c")~items,"device observations survive restart"
call assertEq 1,inv2~admittedWorkspaceDevicesForNode("ed209c")~items,"admission state survives restart"
call assertEq "16.170.244.216",inv2~node("ed209d")~endpoint,"AWS endpoint survives restart"
call SysFileDelete p

say "PASS node identity/provider/endpoint/device admission inventory"
exit 0

::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertFalse
  use arg v,l
  if v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
