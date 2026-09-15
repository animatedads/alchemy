doc=.JSON~fromJSON('{"schema":"alchemy.autobuild.integration/0.2","package":{"name":"legacy","version":"0.2","kind":"oorexx"},"tests":[{"name":"t","argv":["rexx","t.rex"]}],"publish":{"artifact_only":true}}')
spec=.AlchemyIntegrationCodec~decode(doc)
if spec~packageId~key \= "legacy@0.2" then do; say "FAIL legacy id"; exit 1; end
if spec~dependencies~items \= 0 then do; say "FAIL legacy dependencies"; exit 1; end
if \spec~publish~artifactOnly then do; say "FAIL artifact only"; exit 1; end
say "PASS test_schema_compat"; exit 0
::requires "AlchemyPackageModel.cls"
