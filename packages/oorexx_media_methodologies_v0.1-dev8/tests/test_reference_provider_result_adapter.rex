providerResult=.Directory~new
providerResult["status"]="CANDIDATE"
providerResult["provider_id"]="reference.opencv.video-reconstruction/0.1"
providerResult["source_evidence_ref"]="sha256:abc"
providerResult["methodology_id"]="VIDEO.RECON.LEADING_EDGE_BACKPROJECTION"
providerResult["implementation_id"]="reference.opencv.leading-edge/0.1"
providerResult["output_ref"]="candidate.png"
providerResult["support_map_ref"]="support.png"
providerResult["uncertainty_ref"]="uncertainty.png"
c=.MediaReferenceProviderResultAdapter~new~candidate(providerResult,"EXP1","LIN1","WORK1")
call assert c<>.nil,"candidate created"
call assert c~status="CANDIDATE","candidate status"
call assert c~methodologyId="VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","methodology retained"
call assert c~implementationId="reference.opencv.leading-edge/0.1","implementation retained"
call assert c~metadata["OBSERVATION_PROMOTION"]="FALSE","no observation promotion"
call assert c~provenanceRefs[1]="sha256:abc","source evidence retained"
providerResult["status"]="NOT_APPLICABLE"
call assert .MediaReferenceProviderResultAdapter~new~candidate(providerResult,"EXP1","LIN1")=.nil,"not applicable does not create candidate"
say "PASS reference provider result adapter"
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do
    say "FAIL" msg
    exit 1
  end
return

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaReferenceVideoProviders.cls"
