call assert .WireUIAlchemy~PACKAGE_VERSION="0.17","Alchemy package version"
call assert .WireUIProtocol~VERSION="WIRE-UI/0.1","wire protocol unchanged"
say "PASS server package identity 0.17 / WIRE-UI/0.1"
exit 0
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIAll.cls"
