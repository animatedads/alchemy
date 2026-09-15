/* Compact producer identity bound to generation-pinned Camera assessments. */
say 'CAMERA PRODUCTION IDENTITY SMOKE START'

camera=.CameraModel~new('CAMIDENT',640,360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200,1800))
do n=1 to 5
  ignored=camera~behaviour~observeMetric(43200+n,'TRACK_RATE',10+n)
end
g1=camera~publishGeneration(44000)

summary=.CameraClipSummary~new('CID1',43100,200)
summary~dayClass=.CameraConstant~DAY_WEEKDAY
summary~environmentCode=.CameraConstant~ENV_DAY_DIFFUSE
assessment=camera~assessSummaryAtGeneration(summary,'G1',3,2.5)

identity=assessment~productionIdentity
call assertTrue 'production identity attached',identity \== .nil
call assertEqual 'package version','0.45',identity~cameraPackageVersion
call assertEqual 'alchemy base version','0.8',identity~alchemyBaseVersion
call assertEqual 'method name','ASSESSSUMMARYATGENERATION',identity~methodName
call assertEqual 'contract id',.CameraConstant~ASSESSMENT_CONTRACT_ID,identity~contractId
call assertEqual 'contract revision',1,identity~contractRevision
call assertEqual 'construction entrypoint','INIT',identity~constructionEntrypoint
call assertTrue 'construction completed',identity~constructionCompleted
call assertEqual 'reserved surface clean',0,identity~reservedSurfaceDrift
call assertEqual 'compact token is 96 bits hex',24,identity~compactToken~length
call assertEqual 'full sha512 is 128 hex chars',128,identity~digestHex~length
call assertTrue 'identity matches current camera',identity~matchesCurrent(camera)

signature=assessment~conditionSignature
call assertEqual 'signature carries producer token',identity~compactToken,signature~productionToken
call assertTrue 'compact CAS carries producer field',signature~compactText~pos('|P=' || identity~compactToken || '|')>0
call assertTrue 'producer identity compact text stays small',identity~compactText~length < 100

camera2=.CameraModel~new('CAMIDENT2',640,360)
identity2=camera2~productionIdentity
call assertTrue 'different camera id changes digest',identity2~digestHex \= identity~digestHex
call assertTrue 'old identity does not match another camera',\identity~matchesCurrent(camera2)

adoption=.AlchemyAdoptionVerifier~verify(camera,'STANDARD')
call assertTrue 'Alchemy v0.8 STANDARD adoption',adoption~ok

say '  producer compact:' identity~compactText
say '  CAS bytes:' signature~compactText~length
say 'CAMERA PRODUCTION IDENTITY SMOKE: OK'
exit 0

assertEqual: procedure
 use arg label,expected,actual
 if expected==actual then return .true
 say 'ASSERT FAILED:' label
 say ' expected:' expected
 say ' actual:  ' actual
 exit 1

assertTrue: procedure
 use arg label,actual
 if actual then return .true
 say 'ASSERT FAILED:' label
 exit 1

::requires 'CameraCore.cls'
::requires 'AlchemyAdoption.cls'
