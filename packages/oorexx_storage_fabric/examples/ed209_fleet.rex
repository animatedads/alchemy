/* Current ED209 test-fleet topology.  This example records only supplied or
 * observed facts; it does not SSH to nodes and does not invent capacity. */
inv=.StorageNodeInventory~new
unknown=.StorageServiceLifecycle~new(.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE)
az=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"","temporary trial service; workspace only")

inv~putNode(.StorageNodeDescriptor~new("ed209a","oracle","192.0.2.10","",unknown))
inv~putNode(.StorageNodeDescriptor~new("ed209b","oracle","192.0.2.11","",unknown))
inv~putNode(.StorageNodeDescriptor~new("ed209c","microsoft","192.0.2.12","US-EAST",az))
inv~putNode(.StorageNodeDescriptor~new("ed209d","aws","192.0.2.13","EU-NORTH-1",unknown))

do n over inv~allNodes
  say n~canonical
end

say "Azure trial counts as durable safety:" inv~node("ed209c")~lifecycle~countsAsDurable
say "NOTE: endpoints are routing observations; Job-to-Node retains liveness/hard eligibility authority."
exit 0

::requires "src/StorageFabric.cls"
