call addPackagePath
registry=.MediaReferenceVideoProviderRegistry~new("providers")
call assert registry~profiles~items=5, "five reference profiles"
ids=.Array~of("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL","VIDEO.RECON.FLOW_WARP_ACCUMULATE","VIDEO.RECON.MOVING_STRIP_MOSAIC","VIDEO.RECON.LATENT_MULTI_FRAME")
do id over ids
  call assert registry~supports(id), "registry supports" id
  p=registry~profile(id)
  call assert p<>.nil, "profile exists" id
  call assert p~runtime="OOREXX_FOREIGN_PYTHON", "resident Foreign Runtime is execution authority" id
  abilities=p~requiredAbilities
  foreignAllowed=.false
  do ability over abilities
    if ability="OOREXX.FOREIGN.PYTHON" then foreignAllowed=.true
  end
  call assert foreignAllowed, "Foreign Python ability required" id
  call assert p~recoveryClass="RECONSTRUCTABLE", "reconstructable" id
end
say "PASS reference video provider registry"
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do
    say "FAIL" msg
    exit 1
  end
return

addPackagePath: procedure
  parse source . . me
  root=filespec("L",me)||".."
return

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaReferenceVideoProviders.cls"
