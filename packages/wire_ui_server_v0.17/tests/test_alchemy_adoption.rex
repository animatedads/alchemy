b=.OurLadyAirFixture~build
manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,"admin")
transition=.WireUIJourneyTransition~new("SEARCH","FLIGHT_OFFERS","FLIGHT.SEARCH.SUBMIT","test",.table~new,1)
design=.WireUIServerBuilderFixture~build
compiled=.WireUICompiler~new~compile(design["workspace"],design["release"])~value
catalogue=.WireUICompiledCatalogue~new(compiled)
objects=.array~of(b["app"],b["app"]~view,b["app"]~projection,b["journey"],b["planner"],.WireUIRevision~new,.WireUIElementDefinition~new("X","1","TEXT"),.WireUISubscription~new("S","1","test"),transition,server,catalogue,catalogue~releaseBinding,.WireUIExperimentAssignment~new("E","A","X","SESSION","X@1","session-test",catalogue~releaseBinding~contentAddress),.WireUIObservationDefinition~new("OBS","1","TEST",.array~of("value")),.WireUIObservationRecord~new("APP","SUB","1","OBS","TEST","CLIENT_APPLICATION_ASSERTED",.table~new),.WireUIRenderProfilePolicy~new("generic"),.WireUIDefinitionManifest~new("SITE","generic",.array~new),.WireUITimingClock~new,.WireUIJourneyTimingRecord~new(1,"TEST","APP"),.WireUISemanticState~new("STATUS","OK","Operational","GOOD"),.WireUIIntentProjection~new("I","TEST"),.WireUICollectionWindow~new("COLLECTION",0,10,10),.WireUIEvidenceEntry~new("EV","TEST","2026-08-28T10:00:00Z"),.WireUIWorkspaceQueryState~new("POSITIONS"),.WireUIWorkspaceSelection~new("POSITIONS",0),.WireUIWorkspaceCommandContext~new("POSITIONS",0,0,0,0,.array~new),.WireUIWorkspaceResultState~new("POSITIONS"))
do o over objects
 r=.AlchemyAdoptionVerifier~verify(o,"STANDARD")
 if \r~ok then do
   say "FAIL adoption" o~class~id r~failures~items
   do f over r~failures; say f["code"] f["message"]; end
   exit 1
 end
end
say "PASS AlchemyObject STANDARD adoption" objects~items
exit 0
::requires "OurLadyAirFixture.cls"
::requires "WireUIServer.cls"
::requires "AlchemyAdoption.cls"
::requires "WireUIServerBuilderFixture.cls"
::requires "WireUICompiler.cls"
::requires "WireUIObservationDefinition.cls"
::requires "WireUIObservationRecord.cls"

::requires "WireUIRenderProfilePolicy.cls"
::requires "WireUIDefinitionManifest.cls"

::requires "WireUITimingClock.cls"
::requires "WireUIJourneyTimingRecord.cls"

::requires "WireUISemanticState.cls"
::requires "WireUIIntentProjection.cls"

::requires "WireUICollectionWindow.cls"
::requires "WireUIEvidenceEntry.cls"

::requires "WireUIWorkspaceQueryState.cls"
::requires "WireUIWorkspaceSelection.cls"
::requires "WireUIWorkspaceCommandContext.cls"

::requires "WireUIWorkspaceResultState.cls"
