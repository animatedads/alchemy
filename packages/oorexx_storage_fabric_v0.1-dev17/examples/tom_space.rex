/* Example: discover /srv/space as a real pool, index it, and reserve work.
 * Run from the package root. This does not copy or delete any file.
 */

GB=1024*1024*1024
probe=.StoragePosixDfProbe~new
obs=probe~sample("/srv/space")
if obs==.nil then do; say "Could not inspect /srv/space"; exit 2; end

pool=.StoragePool~new("tom-space","local","/srv/space",obs~capacityDomainId,.StoragePoolMode~BOTH,5*GB)
manager=.StorageManager~new
manager~registerPool(pool)~observeCapacity(obs)
provider=.LocalFilesystemProvider~new("local",pool)
manager~registerProvider("local",provider)

say "capacity domain:" obs~capacityDomainId
say "physical free:" format(obs~freeBytes/GB,,2) "GiB"
say "allocatable after safety floor:" format(manager~workspace~availableForPool("tom-space")/GB,,2) "GiB"
say ""
say "Catalogue scan is intentionally explicit because the first scan can be large."
say "Call provider~scan(manager~catalogue) when ready, then catalogue~save(...)."
::requires "src/StorageFabric.cls"