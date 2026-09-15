s=.ServiceTestSupport
root=s~tempDir("service-unit")
home=root || "/home"; s~sh("mkdir -p " || .AlchemyShell~quote(home))
repo="/home/hc3/alchemy-autobuild/repo"
launcher="/home/hc3/alchemy-autobuild/runtime/alchemy_oorexx_core_v0.5/tools/alchemy-autobuild"
unit=.AlchemyAutobuildServiceUnit~new
text=unit~render(repo,7,launcher)
s~assertTrue(text~pos('ExecStart="' || launcher || '"')>0,"runtime launcher rendered")
s~assertTrue(text~pos("--poll=7")>0,"poll rendered")
path=unit~install(home,repo,7,.false,.false,launcher)
s~assertTrue(.AlchemyTransportFs~isFile(path),"unit installed")
s~assertEq(text,.AlchemyTransportFs~readFile(path),"unit content")
say "PASS test_service_unit"
exit 0
::requires "ServiceTestSupport.cls"
::requires "AlchemyAutobuildServiceUnit.cls"
