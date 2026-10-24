call RxFuncAdd 'SysLoadFuncs','rexxutil','SysLoadFuncs'
call SysLoadFuncs
listPath=value('PHOTO_WORLD_IMAGE_LIST',,'ENVIRONMENT')
outDir=value('PHOTO_WORLD_OUTPUT_DIR',,'ENVIRONMENT')
if listPath='' then raise syntax 88.900 array('PHOTO_WORLD_IMAGE_LIST','missing')
if outDir='' then outDir='../output/indoor_vanishing'
call SysFileTree outDir, '_pw_dirs.', 'DO'
if _pw_dirs.0=0 then do
  mkdirRc=SysMkDir(outDir)
  if mkdirRc<>0 then raise syntax 93.900 array('create output directory',outDir)
end
cls=.AlchemyPythonClass~loadCls('photo_world_structure_provider','PhotoWorldStructureProvider')
foreign=cls~new('OpenCV LSD structure','0.2','120')
provider=.SurveyPythonSegmentStructureProvider~new(foreign)
summary=outDir'/summary.tsv'
call lineout summary
call lineout summary,'id'||'09'x||'segments'||'09'x||'families'||'09'x||'unresolved'||'09'x||'main80_ortho'||'09'x||'ultrawide123_ortho'||'09'x||'selected_fov'
do while lines(listPath)>0
  row=linein(listPath)
  if row='' then iterate
  parse var row imageId '09'x sourceRef
  evidence=provider~analyze(sourceRef,'source:'imageId)
  collection=evidence~payload
  solution=.SurveyVanishingPointSolver~solve(collection,3,'3.0',3)
  candidates=.array~of(80,123)
  selectedPair=.SurveyManhattanLensSelector~choose(collection~imageWidth,collection~imageHeight,solution,candidates,'0.20')
  selectedCheck=selectedPair[1]; checks=selectedPair[2]
  main=checks[1]; ultra=checks[2]
  mainScore='NA'; ultraScore='NA'; selected='UNRESOLVED'
  if main~valid then mainScore=main~orthogonalityRms
  if ultra~valid then ultraScore=ultra~orthogonalityRms
  if selectedCheck<>.nil then selected=selectedCheck~diagonalFovDegrees
  svgPath=outDir'/'imageId'.svg'
  .SurveySegmentSvg~render(collection,solution,svgPath,'image 'imageId' - Rexx/Maths vanishing families')
  call lineout summary,imageId||'09'x||collection~count||'09'x||solution~pointCount||'09'x||solution~unresolvedSegmentCount||'09'x||mainScore||'09'x||ultraScore||'09'x||selected
  say imageId 'segments='collection~count 'families='solution~pointCount 'fov='selected
end
call lineout listPath
call lineout summary
say 'wrote' summary
return 'INDOOR-VANISHING-BATCH-PASS'
::requires '../rexx/SurveyForeignProviders.cls'
::requires 'animals.cls'
