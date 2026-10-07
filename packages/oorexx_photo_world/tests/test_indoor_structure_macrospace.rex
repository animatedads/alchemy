parse arg sourceRef
if sourceRef='' then sourceRef=value('PHOTO_WORLD_TEST_IMAGE',,'ENVIRONMENT')
if sourceRef='' then raise syntax 88.900 array('one image path', 'missing')
cls=.AlchemyPythonClass~loadCls('photo_world_structure_provider','PhotoWorldStructureProvider')
foreign=cls~new('OpenCV LSD structure','0.1','120')
provider=.SurveyPythonStructureProvider~new(foreign)
evidence=provider~analyze(sourceRef,'sha256:qualification-image')
if evidence~kind<>'STRUCTURE_RAW' then raise syntax 93.900 array('wrong evidence kind',evidence~kind)
if evidence~coordinateConvention<>'IMAGE_2D_DERIVED' then raise syntax 93.900 array('wrong coordinate convention',evidence~coordinateConvention)
payload=evidence~payload
if payload~pos('STRUCTURE:v1:1536x1152:')<>1 then raise syntax 93.900 array('unexpected structure payload',payload)
if foreign~callCount<>1 then raise syntax 93.900 array('resident structure provider call count failed',foreign~callCount)
say payload
say 'PASS Macrospace structural-image evidence provider'
return 'INDOOR-STRUCTURE-MACROSPACE-PASS'
::requires '../rexx/SurveyForeignProviders.cls'
::requires 'animals.cls'
