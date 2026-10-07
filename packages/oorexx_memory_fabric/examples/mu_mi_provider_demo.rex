numeric digits 20
GB=1024*1024*1024

registry=.MemoryFabricRegistry~new("memory:production")

/* Same physical site: MU-A directly provides memory; MU-B advertises an MI provider. */
registry~registerProvider(.MemoryFabricProvider~new("mem-mu-a","MU","MU-A","","europe-west2","host-a","local://memory",32*GB,0,"ACTIVE","ACCEPTING",4,7,"boot-a"))
registry~registerProvider(.MemoryFabricProvider~new("mem-mi-b","MI","MU-B","MI-MEM-B","europe-west2","host-b","queue://MI-MEM-B/memory",64*GB,0,"SPARE","RESERVED",8,3,"boot-b"))

registry~bindMU("MU-A","mem-mu-a","local://memory",12)
registry~bindMU("MU-B","mem-mi-b","queue://MI-MEM-B/memory",5)

say "MU-A Memory Fabric provider:" registry~discoverForMU("MU-A")["provider_id"]
say "MU-B Memory Fabric provider:" registry~discoverForMU("MU-B")["provider_id"]

candidate=registry~bestProvider("MU-C","host-c","europe-west2",48*GB,.true)
say "48 GiB candidate:" candidate~providerId "kind" candidate~kind "state" candidate~providerState
say "MI provider can be RTO-managed independently of the stable fabric identity."

::requires "../src/MemoryFabric.cls"
