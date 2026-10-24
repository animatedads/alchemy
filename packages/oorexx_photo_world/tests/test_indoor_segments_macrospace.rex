parse arg sourceRef
if sourceRef='' then sourceRef=value('PHOTO_WORLD_TEST_IMAGE',,'ENVIRONMENT')
if sourceRef='' then raise syntax 88.900 array('one image path','missing')
cls=.AlchemyPythonClass~loadCls('photo_world_structure_provider','PhotoWorldStructureProvider')
foreign=cls~new('OpenCV LSD structure','0.2','120')
provider=.SurveyPythonSegmentStructureProvider~new(foreign)
evidence=provider~analyze(sourceRef,'sha256:qualification-image')
if evidence~kind<>'STRUCTURE_SEGMENTS_RAW' then raise syntax 93.900 array('structured evidence kind',evidence~kind)
collection=evidence~payload
if collection~count<3 then raise syntax 93.900 array('at least three structural line observations',collection~count)
if collection~imageWidth<>1536 then raise syntax 93.900 array('image width retained',collection~imageWidth)
if collection~imageHeight<>1152 then raise syntax 93.900 array('image height retained',collection~imageHeight)
solution=.SurveyVanishingPointSolver~solve(collection,3,'3.0',3)
if solution~pointCount<1 then raise syntax 93.900 array('at least one vanishing family',solution~pointCount)
say 'segments='collection~count 'families='solution~pointCount
say 'PASS live Python detector -> Rexx segment objects -> Maths vanishing solve'
return 'INDOOR-SEGMENTS-MACROSPACE-PASS'
::requires '../rexx/SurveyForeignProviders.cls'
::requires 'animals.cls'
