support=.FloorTestSupport
runner=.AlchemyCommandRunner~new
base=support~tempDir("floor-inventory")
make=base || "/make"
support~mkdir(make || "/wrapped_v1")
support~write(make || "/wrapped_v1/a.cls", "A")
runner~require(.array~of("zip", "-qr", base || "/wrapped_v1.zip", "wrapped_v1"), make)
support~mkdir(make || "/rootless")
support~write(make || "/rootless/README.md", "R")
runner~require(.array~of("zip", "-qj", base || "/runtime_registry_v9.9(1).zip", make || "/rootless/README.md"), make)
outer=base || "/outer"
support~mkdir(outer || "/current/testapps")
runner~require(.array~of("cp", base || "/wrapped_v1.zip", outer || "/current/"), base)
runner~require(.array~of("cp", base || "/runtime_registry_v9.9(1).zip", outer || "/current/"), base)
support~write(outer || "/current/testapps/ourladyair_shannon_ticket_groups_v1.md", "M")
support~write(outer || "/current/testapps/ourladyair_shannon_ticket_groups_v1.edi", "E")
bundle=base || "/bundle.zip"
runner~require(.array~of("zip", "-qr", bundle, "current"), outer)
work=base || "/work"; support~mkdir(work)
inv=.AlchemyBundleInspector~new(runner)~inspect(bundle, .AlchemyTransportContext~new(work, "", runner))
support~assertEq(2, inv~packages~items, "package count")
names=.array~new; do p over inv~packages; names~append(p~packageName); end; names~sort
support~assertEq("runtime_registry_v9.9", names[1], "rootless naming")
support~assertEq("wrapped_v1", names[2], "wrapped naming")
support~assertEq(2, inv~sidecars~items, "sidecars")
support~remove(base)
say "PASS test_bundle_inventory"
exit 0
::requires "AlchemyDependencyFloor.cls"
::requires "TestFloorSupport.cls"
