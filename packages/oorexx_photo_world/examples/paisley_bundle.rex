/* Provisional geometry bundle from the supplied pedestrian-street photographs.
   Measurements are hypotheses to be refined by reprojection, not surveyed truth. */
numeric digits 20
parse source . . here
root=filespec('location',here)'..'
call directory root
::requires '../rexx/SurveyBundle.cls'
::requires '../rexx/SurveySvg.cls'

ctx=.Maths~defaultContext
w=.SurveyWorld~new(ctx)
g=.SurveyGroundPatch~new('STREET',.MathVector3~new(0,0,0,ctx),120,30,0,0,ctx); w~addGround(g)
/* X is along the pedestrian street. Right-hand photographed frontage is Y=-10. */
call addBuilding w,'B03_LIBRARY',18,15,15,12,-17
call addBuilding w,'B04_SUBWAY_TECH',13,14,14,30,-17
call addBuilding w,'B05_NAPIER_RED',16,14,14,44.5,-17
call addBuilding w,'B06_TGJ_SPORTS',22,15,13,63.5,-17
call addBuilding w,'B07_HISTORIC',18,16,15,83.5,-17.5
/* repeated near-ground anchors */
call addFurniture w,'F_POLE',0.35,0.35,5.5,50,-2.2
call addFurniture w,'F_BLOCK1',4.2,0.65,0.65,43,2.2
call addFurniture w,'F_BLOCK2',4.2,0.65,0.65,36,2.1
call addFurniture w,'F_PLANTER1',2.2,1.0,0.8,53,-8.0
call addFurniture w,'F_PLANTER2',2.2,1.0,0.8,62,-8.1

spec=.XCoverCameraSpecifications~byId('XCOVERPRO')
/* Initial camera stations: deliberately provisional. Each retains 1.60 m prior. */
call addCamera w,spec,'P01',55,5.8,185,-2.0
call addCamera w,spec,'P02',51,6.2,178,-1.0
call addCamera w,spec,'P03',47,5.5,170,-1.5
call addCamera w,spec,'P04',42,5.0,162,-1.0
call addCamera w,spec,'P05',35,4.8,151,-1.5
call addCamera w,spec,'P06',29,4.5,145,-1.0
call addCamera w,spec,'P07',23,4.0,137,-0.5
call addCamera w,spec,'P08',16,3.8,128,-1.0
call addCamera w,spec,'P09',8,3.5,116,-0.5

.SurveySvg~topDown(w,'output/paisley_top_down.svg','Provisional multi-photo geometry - NOT a panorama')
say 'PASS provisional world built; top-down=output/paisley_top_down.svg'
exit 0

addBuilding: procedure
  use arg w,id,width,depth,height,x,y
  o=.SurveyBlock~new(id,width,depth,height); o~moveTo(x,y,height/2); w~addObject(o); return
addFurniture: procedure
  use arg w,id,width,depth,height,x,y
  o=.SurveyBlock~new(id,width,depth,height,.nil,'0.35','survey anchor'); o~moveTo(x,y,height/2); w~addObject(o); return
addCamera: procedure
  use arg w,spec,id,x,y,yaw,pitch
  c=.SurveyCamera~new(id,.nil,1.60,60,3000,4000,spec,'MAIN')
  c~moveTo(x,y,1.60); c~setAngles(yaw,pitch,0); w~addCamera(c); return
