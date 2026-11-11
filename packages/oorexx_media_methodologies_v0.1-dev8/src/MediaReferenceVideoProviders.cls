/* Reference video reconstruction provider identities and execution adapter.
 *
 * API: media.methodologies.reference-video-provider/0.1
 *
 * These provider profiles do not become methodology authority.  They describe
 * one executable implementation family which can be selected, A/B tested or
 * rejected independently of the methodology catalogue.
 */

::class MediaReferenceVideoProviderRegistry public
::method init
  expose providerRoot profiles
  use strict arg providerRootArg=""
  providerRoot=providerRootArg
  profiles=.Directory~new
  self~add("reference.opencv.leading-edge/0.1","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
  self~add("reference.opencv.blur-envelope/0.1","VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL")
  self~add("reference.opencv.flow-warp-accumulate/0.1","VIDEO.RECON.FLOW_WARP_ACCUMULATE")
  self~add("reference.opencv.moving-strip-mosaic/0.1","VIDEO.RECON.MOVING_STRIP_MOSAIC")
  self~add("reference.opencv.latent-multiframe/0.1","VIDEO.RECON.LATENT_MULTI_FRAME")

::method add
  expose profiles
  use strict arg implementationId, methodologyId
  /* OpenCV is the Python implementation dependency, not execution authority.
   * The application launches it IN PROCESS through Foreign Runtime. */
  abilities=.Array~of("MEDIA.VIDEO.DECODE","MEDIA.PYTHON.OPENCV","OOREXX.FOREIGN.PYTHON")
  tags=.Array~of("REFERENCE_PROVIDER","DERIVED_CANDIDATE_ONLY","NO_SUBPROCESS")
  profile=.MediaImplementationExecutionProfile~new(implementationId,methodologyId,"OOREXX_FOREIGN_PYTHON",abilities,tags,"",256,64,1,128,32,1,0,0,.true,"RECONSTRUCTABLE")
  profiles[translate(methodologyId)]=profile

::method profiles
  expose profiles
  answer=.Array~new
  do item over profiles~allItems
    answer~append(item)
  end
  return answer

::method profile
  expose profiles
  use strict arg methodologyIdArg
  return profiles[translate(strip(methodologyIdArg))]

::method supports
  expose profiles
  use strict arg methodologyIdArg
  return profiles~hasIndex(translate(strip(methodologyIdArg)))

/* Disallow the legacy runner from constructing shell commands.  Every ooRexx
 * execution must use MediaForeignVideoInvoker and a registered runtime. */
::method command
  use strict arg methodologyId, jobPath, resultPath
  raise syntax 93.900 array("SUBPROCESS_PROVIDER_FORBIDDEN","Use MediaForeignVideoInvoker")

::method providerRoot
  expose providerRoot
  return providerRoot

::class MediaReferenceProviderResultAdapter public
::method candidate
  use strict arg providerResult, experimentId, lineageId, workId=""
  if providerResult=.nil then raise syntax 93.900 array("Provider result is required")
  status=translate(strip(providerResult["status"]))
  if status<>"CANDIDATE" then return .nil
  metadata=.Directory~new
  metadata["PROVIDER_ID"]=providerResult["provider_id"]
  metadata["SOURCE_EVIDENCE_REF"]=providerResult["source_evidence_ref"]
  metadata["AUTHORITY_EFFECT"]="RECONSTRUCT_CANDIDATE"
  metadata["OBSERVATION_PROMOTION"]="FALSE"
  workIds=.Array~new
  if workId<>"" then workIds~append(workId)
  provenance=.Array~new
  if providerResult["source_evidence_ref"]<>.nil then provenance~append(providerResult["source_evidence_ref"])
  candidateId=strip(experimentId)||":"||strip(lineageId)||":"||translate(providerResult["methodology_id"])
  return .MediaExperimentCandidate~new(candidateId,experimentId,lineageId,providerResult["methodology_id"],providerResult["implementation_id"],"DERIVED_RECONSTRUCTION",workIds,providerResult["output_ref"],providerResult["support_map_ref"],providerResult["uncertainty_ref"],provenance,metadata)

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
