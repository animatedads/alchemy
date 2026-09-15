parse arg args
repo=""; bundle=""; dry=.false
do while args<>""
  parse var args token args
  select
    when token~left(7)="--repo=" then repo=token~substr(8)
    when token~left(9)="--bundle=" then bundle=token~substr(10)
    when token="--repo" then parse var args repo args
    when token="--bundle" then parse var args bundle args
    when token="--dry-run" then dry=.true
    otherwise do; say "ERROR unknown argument:" token; exit 2; end
  end
end
if repo="" then repo=directory()
if bundle="" then do
  stem="ALCHEMY_BUNDLES."
  call SysFileTree value("HOME",,"ENVIRONMENT") || "/Downloads/oorexx-libs*crypto-consolidated*.zip", stem, "FO"
  if value(stem || "0")<>1 then do
    say "ERROR specify --bundle; matching consolidated bundles=" || value(stem || "0")
    exit 2
  end
  bundle=value(stem || "1")
end
seedResult=.AlchemyDependencyFloorSeeder~new~seed(repo,bundle,dry)
say "SEED_ID=" || seedResult~seedId
say "BUNDLE_SHA256=" || seedResult~bundleSha256
say "SEEDED=" || seedResult~seeded~items
do p over seedResult~seeded; say "  + " || p; end
say "EXISTING_PRESERVED=" || seedResult~preserved~items
do p over seedResult~preserved; say "  = " || p; end
if dry then say "PASS DEPENDENCY_FLOOR_DRY_RUN"
else do
  say "LEDGER=" || seedResult~ledgerPath
  say "COMMIT=" || seedResult~commit
  say "PASS DEPENDENCY_FLOOR_SEEDED"
end
exit 0
::requires "AlchemyDependencyFloor.cls"
