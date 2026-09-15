c = .AlchemyCoreComponent~new("probe", "0.1", "base component acceptance")
if c~alchemyObjectId = "" then raise syntax 88.900 array("missing Alchemy object id")
d = c~componentDescriptor
if d["name"] <> "probe" then raise syntax 88.900 array("component descriptor name")
if d["version"] <> "0.1" then raise syntax 88.900 array("component descriptor version")
m = c~alchemyMetrics
if m["use_count"] < 1 then raise syntax 88.900 array("lifecycle telemetry not inherited")
say "PASS test_base_component"
::requires "AlchemyCoreComponent.cls"
