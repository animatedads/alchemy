call test
say "PASS test_package_identity"
exit 0

test:
  call assert .WireUIDesignAlchemy~PACKAGE_VERSION="0.11","Alchemy package version exact"
  call assert .WireUIDesignAlchemy~SCHEMA="WIRE-UI-DESIGN/0.7","authoring schema exact"
  m=.WireUIDesignAlchemy~metadata("identity test")
  call assert m["package"]="wire_ui_builder","package name exact"
  call assert m["package_version"]="0.11","metadata package version exact"
  found=.false; do s over m["standards"]; if s="WIRE-UI-DESIGN/0.7" then found=.true; end
  call assert found,"metadata carries v0.7 authoring schema"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
