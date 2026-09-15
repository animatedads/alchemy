repo=SysTempFileName("/tmp/alchemy-lease-object-repo-??????")
call SysMkDir repo
address system "git init -q " || .AlchemyRepositoryLeaseShell~quote(repo)
if rc<>0 then raise syntax 88.900 array("unable to initialize test repository")
lease=.AlchemyRepositoryLease~new(repo)
if \lease~isA(.AlchemyObject) then raise syntax 88.900 array("AlchemyRepositoryLease must inherit AlchemyObject")
if lease~alchemyObjectId="" then raise syntax 88.900 array("AlchemyRepositoryLease missing Alchemy identity")
d=lease~componentDescriptor
if d["name"]<>"AlchemyRepositoryLease" then raise syntax 88.900 array("unexpected component descriptor name")
if d["version"]<>"0.2" then raise syntax 88.900 array("unexpected component descriptor version")
address system "rm -rf -- " || .AlchemyRepositoryLeaseShell~quote(repo)
say "PASS test_alchemy_object_surface"
exit 0
::requires "AlchemyRepositoryLease.cls"
