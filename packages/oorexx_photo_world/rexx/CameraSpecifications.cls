/* ooRexx Photo Survey World camera specifications
   Calibration priors for Samsung Galaxy XCover photographs.
   FOV values are diagonal degrees unless axis says otherwise.
   Ranges are priors, not EXIF evidence.
*/

::class SurveyLensSpecification public
::method init
  expose _id _role _megapixels _aperture _equivMM _fovMin _fovMax _axis _focus _notes _estimated
  use strict arg id,role,megapixels=.nil,aperture='',equivMM=.nil,fovMin=.nil,fovMax=.nil,axis='DIAGONAL',focus='',notes='',estimated=.false
  _id=id; _role=role~upper; _megapixels=megapixels; _aperture=aperture; _equivMM=equivMM
  _fovMin=fovMin; _fovMax=fovMax; _axis=axis~upper; _focus=focus; _notes=notes; _estimated=estimated
::method id; expose _id; return _id
::method role; expose _role; return _role
::method megapixels; expose _megapixels; return _megapixels
::method aperture; expose _aperture; return _aperture
::method equivalentFocalLengthMM; expose _equivMM; return _equivMM
::method fovMin; expose _fovMin; return _fovMin
::method fovMax; expose _fovMax; return _fovMax
::method fovAxis; expose _axis; return _axis
::method focus; expose _focus; return _focus
::method notes; expose _notes; return _notes
::method estimated; expose _estimated; return _estimated
::method hasFov; expose _fovMin _fovMax; return _fovMin<>.nil & _fovMax<>.nil
::method nominalFov
  if \self~hasFov then return .nil
  return (self~fovMin+self~fovMax)/2
::method verticalFov
  use strict arg imageWidth,imageHeight,context=.nil
  if \self~hasFov then return .nil
  if self~fovAxis<>'DIAGONAL' then raise syntax 88.900 array('DIAGONAL FOV required for aspect conversion',self~fovAxis)
  if imageWidth<=0 | imageHeight<=0 then raise syntax 88.900 array('positive image dimensions',imageWidth'/'imageHeight)
  if context==.nil then context=.Maths~defaultContext
  d=.MathAngle~degrees(self~nominalFov,context)
  td=.Maths~tan(d~radiansValue/2,context)
  denom=.Maths~sqrt(imageWidth*imageWidth+imageHeight*imageHeight,context)
  tv=td*imageHeight/denom
  return 2*.Maths~atan(tv,context)~degreesValue
::method horizontalFov
  use strict arg imageWidth,imageHeight,context=.nil
  if \self~hasFov then return .nil
  if context==.nil then context=.Maths~defaultContext
  d=.MathAngle~degrees(self~nominalFov,context)
  td=.Maths~tan(d~radiansValue/2,context)
  denom=.Maths~sqrt(imageWidth*imageWidth+imageHeight*imageHeight,context)
  th=td*imageWidth/denom
  return 2*.Maths~atan(th,context)~degreesValue

::class SurveyCameraSpecification public
::method init
  expose _id _manufacturer _model _release _lenses _lensOrder _notes
  use strict arg id,manufacturer,model,release,notes=''
  _id=id; _manufacturer=manufacturer; _model=model; _release=release; _notes=notes
  _lenses=.directory~new; _lensOrder=.array~new
::method id; expose _id; return _id
::method manufacturer; expose _manufacturer; return _manufacturer
::method model; expose _model; return _model
::method release; expose _release; return _release
::method notes; expose _notes; return _notes
::method addLens
  expose _lenses _lensOrder
  use strict arg lens
  if _lenses~hasIndex(lens~id) then raise syntax 88.900 array('unique lens id',lens~id)
  _lenses[lens~id]=lens; _lensOrder~append(lens~id); return lens
::method lens; expose _lenses; use strict arg id; return _lenses[id]
::method lensIds; expose _lensOrder; return _lensOrder~copy
::method mainLens; return self~lens('MAIN')

::class XCoverCameraSpecifications public
::method all class
  expose _catalog
  if var('CATALOG')=0 then self~buildCatalog
  return _catalog~copy
::method byId class
  expose _byId
  use strict arg id
  if var('BYID')=0 then self~buildCatalog
  return _byId[id~upper]
/* Synchronous class-internal helper. Do not send as a Message activity. */
::method buildCatalog class private
  expose _catalog _byId
  _catalog=.array~new; _byId=.directory~new

  c=.SurveyCameraSpecification~new('XCOVER7','Samsung','Galaxy XCover7',2024)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',50,'f/1.8',26,79,81,'DIAGONAL','PDAF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',5,'f/2.0',.nil,77,77,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER6PRO','Samsung','Galaxy XCover6 Pro',2022)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',50,'f/1.8',26,79,81,'DIAGONAL','PDAF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('ULTRAWIDE','ULTRA-WIDE',8,'f/2.2',.nil,123,123,'DIAGONAL','','',.false))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',13,'f/2.2',.nil,80,80,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER5','Samsung','Galaxy XCover 5',2021)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',16,'f/1.8',26,78,80,'DIAGONAL','PDAF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',5,'f/2.2',.nil,76,76,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVERFIELDPRO','Samsung','Galaxy XCover FieldPro',2019,'dual-aperture main camera')
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',12,'f/1.5-2.4',26,77,77,'DIAGONAL','','dual aperture',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',8,'f/1.7',.nil,80,80,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVERPRO','Samsung','Galaxy XCover Pro',2020)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',25,'f/1.7',26,79,81,'DIAGONAL','','wide',.true))
  c~addLens(.SurveyLensSpecification~new('ULTRAWIDE','ULTRA-WIDE',8,'f/2.2',.nil,123,123,'DIAGONAL','','',.false))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',13,'f/2.0',.nil,80,80,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER4S','Samsung','Galaxy XCover 4s',2019)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',16,'f/1.7',26,78,80,'DIAGONAL','PDAF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',5,'f/2.2',.nil,76,76,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER4','Samsung','Galaxy XCover 4',2017)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',13,'f/1.9',26,78,80,'DIAGONAL','AF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',5,'f/2.2',.nil,76,76,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER3','Samsung','Galaxy XCover 3',2015)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',5,'f/2.2',28,73,75,'DIAGONAL','AF','wide',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',2,'',.nil,70,70,'DIAGONAL','','',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER2','Samsung','Galaxy XCover 2',2013)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',5,'f/2.8',.nil,68,72,'DIAGONAL','AF','',.true))
  c~addLens(.SurveyLensSpecification~new('FRONT','FRONT',0.3,'',.nil,.nil,.nil,'DIAGONAL','','VGA; FOV not supplied',.true)); self~put(c)

  c=.SurveyCameraSpecification~new('XCOVER-S5690','Samsung','Galaxy XCover (S5690)',2011)
  c~addLens(.SurveyLensSpecification~new('MAIN','MAIN',3.15,'',.nil,65,70,'DIAGONAL','AF','',.true)); self~put(c)
  return
/* Synchronous class-internal helper. Do not send as a Message activity. */
::method put class private
  expose _catalog _byId
  use strict arg camera
  _catalog~append(camera); _byId[camera~id]=camera

::requires 'MathsBootstrap.cls'
