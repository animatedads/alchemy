/* Install immutable local v0.5 runtime capsule and optionally enable service. */
parse arg line
repo=""; home=value("HOME",,"ENVIRONMENT"); poll=5; enableNow=.false; reload=.true
do i=1 to words(line)
  token=word(line,i)
  select
    when token~left(7)="--repo=" then repo=token~substr(8)
    when token~left(7)="--home=" then home=token~substr(8)
    when token~left(7)="--poll=" then poll=token~substr(8)+0
    when token="--enable-now" then enableNow=.true
    when token="--no-reload" then reload=.false
    otherwise do; say "ERROR unknown argument:" token; exit 2; end
  end
end
if repo="" then repo=home || "/alchemy-autobuild/repo"
parse source . . here
bundleRoot=filespec("P",here); if bundleRoot~right(1)="/" then bundleRoot=bundleRoot~left(bundleRoot~length-1)
runner=.AlchemyCommandRunner~new
runtimeParent=home || "/alchemy-autobuild/runtime"; runtimeRoot=runtimeParent || "/alchemy_oorexx_core_v0.5"
runner~require(.array~of("mkdir","-p",runtimeParent),"","runtime parent")
if .AlchemyTransportFs~isDirectory(runtimeRoot) then do
  cmp=runner~run(.array~of("diff","-qr","--",bundleRoot || "/packages",runtimeRoot || "/packages"),"")
  if cmp~rc<>0 then raise syntax 88.900 array("runtime capsule collision: " || runtimeRoot)
end
else do
  runner~require(.array~of("mkdir","-p",runtimeRoot),"","runtime root")
  runner~require(.array~of("cp","-a","--",bundleRoot || "/packages",runtimeRoot || "/packages"),"","runtime packages")
  runner~require(.array~of("cp","-a","--",bundleRoot || "/tools",runtimeRoot || "/tools"),"","runtime tools")
  runner~require(.array~of("cp","-a","--",bundleRoot || "/README.md",runtimeRoot || "/README.md"),"","runtime README")
end
launcher=runtimeRoot || "/tools/alchemy-autobuild"
unit=.AlchemyAutobuildServiceUnit~new(runner)~install(home,repo,poll,enableNow,reload,launcher)
say "RUNTIME=" || runtimeRoot
say "UNIT=" || unit
if enableNow then say "PASS ALCHEMY_OOREXX_RUNTIME_ENABLED"
else say "PASS ALCHEMY_OOREXX_RUNTIME_INSTALLED"
exit 0
::requires "packages/alchemy_transport_v0.4/src/AlchemyTransport.cls"
::requires "packages/alchemy_autobuild_service_v0.4/src/AlchemyAutobuildServiceUnit.cls"
