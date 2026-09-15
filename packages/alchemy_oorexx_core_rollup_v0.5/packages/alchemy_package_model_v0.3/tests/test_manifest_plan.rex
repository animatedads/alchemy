base=SysTempFileName("/tmp/alchemy-model-??????"); call SysMkDir base
pkg=base || "/pkg"; repo=base || "/repo"; call SysMkDir pkg; call SysMkDir repo
manifest=pkg || "/integration.json"
text='{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"shannon_probe","version":"1","kind":"oorexx"},"dependencies":[{"name":"reputation_effect","version":"0.2","export":"REPUTATION_EFFECT_ROOT"},{"name":"runtime_registry","version":"0.12","export":"RUNTIME_REGISTRY_ROOT"}],"environment":{"rexx_path":{"mode":"prepend","entries":["${PACKAGE_ROOT}/src"]}},"tests":[{"name":"effect","argv":["rexx","effect.rex"],"environment":{"set":{"PROBE":"EFFECT"},"rexx_path":{"mode":"prepend","entries":["${PACKAGE_ROOT}/tests/effect"]}}},{"name":"registry","argv":["rexx","registry.rex"],"environment":{"set":{"PROBE":"REGISTRY"},"rexx_path":{"mode":"replace","entries":["${PACKAGE_ROOT}/tests/registry"]}}}],"publish":{"tree":{"source":".","path":"packages/shannon_probe_v1"}}}'
s=.stream~new(manifest)~~open("write replace"); s~charout(text); s~close
spec=.AlchemyIntegrationCodec~decodeFile(manifest)
floor=.AlchemyDependencyFloor~new
floor~add(.AlchemyDependencyFloorEntry~new(.AlchemyPackageId~new("reputation_effect","0.2"),repo || "/packages/reputation_effect_v0.2","REPUTATION_EFFECT_ROOT",.array~of("src")))
floor~add(.AlchemyDependencyFloorEntry~new(.AlchemyPackageId~new("runtime_registry","0.12"),repo || "/packages/runtime_registry_v0.12","RUNTIME_REGISTRY_ROOT",.array~of("src")))
policy=.AlchemyFakePathPolicy~new(.array~of(pkg,pkg || "/tests/effect",pkg || "/tests/registry",pkg || "/src",repo || "/packages/reputation_effect_v0.2",repo || "/packages/runtime_registry_v0.12"))
baseEnv=.table~new; baseEnv["PATH"]="/usr/bin"; baseEnv["REXX_PATH"]="/ambient"
plan=.AlchemyExecutionPlanner~new~plan(spec,floor,.AlchemyPlanningContext~new(pkg,repo,baseEnv,policy))
call ae 2, plan~tests~items, "test count"
e=plan~tests[1]~environment; r=plan~tests[2]~environment
call ae repo || "/packages/reputation_effect_v0.2", e["REPUTATION_EFFECT_ROOT"], "effect root"
call ae pkg || "/tests/effect:" || pkg || "/src:" || repo || "/packages/reputation_effect_v0.2/src:" || repo || "/packages/runtime_registry_v0.12/src:/ambient", e["REXX_PATH"], "effect REXX_PATH"
call ae pkg || "/tests/registry", r["REXX_PATH"], "registry replace REXX_PATH"
call ae "EFFECT", e["PROBE"], "test env effect"
call ae "REGISTRY", r["PROBE"], "test env registry"
address system "rm -rf -- '" || base || "'"
say "PASS test_manifest_plan"
exit 0
ae: procedure; use arg x,y,l; if x\==y then do; say "FAIL " || l || " expected=" || x || " actual=" || y; exit 1; end; return
::requires "AlchemyPackageModel.cls"
