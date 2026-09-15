/* Install Alchemy ooRexx core v0.5 through a leased disposable accepted-main worktree. */
parse arg line
repo=""
do i=1 to words(line)
  token=word(line,i)
  if token~left(7)="--repo=" then repo=token~substr(8)
  else do; say "ERROR unknown argument:" token; exit 2; end
end
if repo="" then repo=value("HOME",,"ENVIRONMENT") || "/alchemy-autobuild/repo"
parse source . . here
bundleRoot=filespec("P",here); if bundleRoot~right(1)="/" then bundleRoot=bundleRoot~left(bundleRoot~length-1)
runner=.AlchemyCommandRunner~new
tx=.AlchemyGitMainTransaction~new(repo,runner)~begin
active=.true
signal on syntax name installSyntax
packages=.array~of("oorexx_crypto_v0.1","alchemy_objects_v0.4.3","alchemy_core_component_v0.1","alchemy_repository_lease_v0.2","alchemy_package_model_v0.3","alchemy_transport_v0.4","alchemy_dependency_floor_v0.5","alchemy_executor_v0.4","alchemy_publisher_v0.4","alchemy_orchestrator_v0.5","alchemy_submission_v0.4","alchemy_inbox_v0.3","alchemy_autobuild_evidence_v0.3","alchemy_autobuild_service_v0.4","alchemy_oorexx_core_v0.5")
installed=0; preserved=0
runner~require(.array~of("mkdir","-p",tx~root || "/packages",tx~root || "/tools"),"","core install directories")
do name over packages
  src=bundleRoot || "/packages/" || name; dst=tx~root || "/packages/" || name
  if \.AlchemyTransportFs~isDirectory(src) then raise syntax 88.900 array("rollup package missing: " || name)
  if .AlchemyTransportFs~isDirectory(dst) then do
    cmp=runner~run(.array~of("diff","-qr","--",src,dst),"")
    if cmp~rc=0 then preserved+=1
    else if cmp~rc=1 then raise syntax 88.900 array("core install collision: packages/" || name)
    else raise syntax 88.900 array("core install compare failed rc=" || cmp~rc)
  end
  else do; runner~require(.array~of("cp","-a","--",src,dst),"","core package copy"); installed+=1; end
end
do tool over .array~of("alchemy-submit","alchemy-seed-dependency-floor","alchemy-autobuild","alchemy-install-autobuild-service")
  runner~require(.array~of("cp","-a","--",bundleRoot || "/tools/" || tool,tx~root || "/tools/" || tool),"","core tool install")
end
runner~require(.array~of("cp","-a","--",bundleRoot || "/GIT_SUBMISSION.md",tx~root || "/GIT_SUBMISSION.md"),"","submission documentation install")
runner~run(.array~of("git","rm","-f","--ignore-unmatch","tools/alchemy_submit.py","tools/seed_dependency_floor.py"),tx~root)
commit=tx~commitAndPush(.array~of("packages","tools","GIT_SUBMISSION.md"),"alchemy: install resident ooRexx core v0.5")
tx~close; active=.false; signal off syntax
say "INSTALLED=" || installed
say "EXISTING_PRESERVED=" || preserved
say "COMMIT=" || commit
say "PASS ALCHEMY_OOREXX_CORE_V05_INSTALLED"
exit 0
installSyntax:
  signal off syntax
  if active then tx~close
  raise propagate
::requires "packages/alchemy_transport_v0.4/src/AlchemyTransport.cls"
