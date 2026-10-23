parse source . . here
base=filespec("L",here)
call value "REXX_PATH",base||"/../src:"||base||"/../fixtures:"||value("REXX_PATH",,"ENVIRONMENT"),"ENVIRONMENT"

recording=.AudioRecording~new("REC-INSTALL")
raw=recording~addRawFeed("RAW",1000,"","room recording")
parents=.array~of("RAW")
clean=recording~addDerived("CLEAN",1000,"","clean speech",parents,.directory~new,"STEP-CLEAN")
transcript=recording~createTranscriptView("TRANSCRIPT-1")
transcript~addBoundary(.AudioBoundary~new("B1",.array~of("CLEAN")))

binding=.AudioStorageBindingFixture~new("CLEAN",.AudioStorageIdentityFixture~new("storage:obj-clean:g=7"))
bindings=.directory~new
bindings["CLEAN"]=binding
context=.AudioIntentionContext~new(.nil,.nil,bindings,.directory~new,recording,.array~of(raw,clean))
provider=.AudioIntentionProvider~new
intentions=.ManagementIntentionDirectory~new
relationships=.ManagementRelationshipDirectory~new
storageSource=.StorageManagementSourceFixture~new

registration=.AudioManagementInstaller~install(intentions,relationships,provider,recording,context,storageSource)
call assertEq 1,intentions~sources~items,"installer registers one Audio intention source"
call assertEq 1,relationships~sources~items,"installer registers one Audio relationship source"
call assertSame intentions~sources[1],registration~intentionSource,"registration retains wrapped Audio source"
call assertSame relationships~sources[1],registration~relationshipSource,"registration retains relationship source"

resolution=intentions~resolve("show the clean transcript",context)
call assertTrue resolution~relevantCandidates~items>0,"installed Audio source resolves live request"
objects=resolution~preferredCandidate~assessment~evidence["objects"]
call assertContainsSame objects,clean,"installed source preserves clean AudioElement"
call assertContainsSame objects,transcript,"installed source preserves transcript AudioView"

exploration=registration~explorer~explore("where is the clean transcript stored",context,3)
call assertContainsSame exploration~relatedObjects,binding,"explorer reaches Audio Storage binding"
call assertContainsSame exploration~relatedObjects,binding~identity,"explorer reaches durable Storage identity"
call assertTrue exploration~relevantAdvertisedCandidates~items>0,"explorer asks separately supplied Storage source"
call assertSame storageSource,exploration~relevantAdvertisedCandidates[1]~source,"Storage source identity preserved"

transcript2=recording~createTranscriptView("TRANSCRIPT-2")
resolution2=intentions~resolve("show transcript 2",context)
call assertTrue resolution2~relevantCandidates~items>0,"installed source refreshes after Audio graph mutation"
objects2=resolution2~preferredCandidate~assessment~evidence["objects"]
call assertContainsSame objects2,transcript2,"new transcript exact object appears without re-installation"

say "AUDIO MANAGEMENT INSTALLATION DEV8: OK"
exit 0

assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

assertTrue: procedure
  use arg condition,label
  if condition then return
  say "FAIL" label
  exit 1

assertSame: procedure
  use arg expected,actual,label
  if expected==actual then return
  say "FAIL" label "object identity changed"
  exit 1

assertContainsSame: procedure
  use arg values,wanted,label
  do item over values
    if item==wanted then return
  end
  say "FAIL" label
  exit 1

::class AudioStorageIdentityFixture public
::attribute identityKey get
::method init
  expose identityKey
  use strict arg value
  identityKey=value

::class AudioStorageBindingFixture public
::attribute elementId get
::attribute identity get
::method init
  expose elementId identity
  use strict arg elementIdArg,identityArg
  elementId=elementIdArg
  identity=identityArg
::method identityKey
  expose identity
  return identity~identityKey

::class StorageManagementSourceFixture public
::method sourceId
  return "storage.fabric.intentions/0.1"
::method discover
  use strict arg context=.nil
  return .array~of("STORAGE_OBJECT","STORAGE_LOCATIONS")
::method assessRelevance
  use strict arg request,surface,context=.nil
  matched=pos("stor",request~string~lower)>0
  if matched then return .ManagementRelevanceAssessment~new(.true,85,"storage.fabric","DOMAIN_MATCH",surface)
  return .ManagementRelevanceAssessment~new(.false,0,"storage.fabric","NO_DOMAIN_MATCH",surface)

::requires "AudioCoreFixture.cls"
::requires "AudioManagementIntentions.cls"
