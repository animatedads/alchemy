/* v0.18 quantify the vertical bridge correction at fixed, unqualified camera poses.
 * All results are sensitivity diagnostics, NOT camera calibration.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
f=.HarbourOtherCameraFit~new
scene=f~model~scene
r=.HarbourBridgeRoofPins~frame(scene)
call check r['STATUS']=='ROOF_PIN_LAYOUT_CONSISTENT_NOT_SURVEYED','pylon pin frame'
pts=.array~of('NW_DECK_PROXY','NE_DECK_PROXY','SW_DECK_PROXY','SE_DECK_PROXY')

/* The old scene shows roof-pin deck projections at 50 m, and a deck slab
   whose top is 52 m. The corrected slab surface/point proxy is at 49 m. */
levelBefore=scene~features['NW_DECK_PROXY'][3]
call check levelBefore=50,'old proxy z50'

/* All camera poses are exploratory, not the actual lens optical centres. */
do key over .array~of('NORTH_SHORE','BLUES_TOWER','CAFE_DIAGNOSTIC')
  select
    when key=='NORTH_SHORE' then do
      xy=scene~local(-33.8487411,151.214266)
      camera=.array~of(xy[1],xy[2],79,206.175,1.75,740)
      height=709
    end
    when key=='BLUES_TOWER' then do
      xy=scene~local(-33.8488623,151.203338)
      camera=.array~of(xy[1],xy[2],66.8125,150.3,-1.7875,440)
      height=709
    end
    otherwise do
      /* Prior invalid fit, solely to expose numerical sensitivity. */
      xy=scene~local(-33.862128338141,151.21083913743)
      camera=.array~of(xy[1],xy[2],25,5.5,0,2700)
      height=862
    end
  end
  say 'CAMERA' key 'unqualified fixed pose z='camera[3] 'focal='camera[6]
  do id over pts
    loc=scene~features[id]
    before=f~project(loc,camera,1536,height)
    afterPt=.array~of(loc[1],loc[2],49)
    after=f~project(afterPt,camera,1536,height)
    if before==.nil | after==.nil then do
      say 'SKIP' id 'behind camera'
      iterate
    end
    delta=after[2]-before[2]
    say 'PHOTO_PROXY' id 'z50->49 pixel_y_change' format(delta,5,2) 'old_y' format(before[2],7,2) 'new_y' format(after[2],7,2)
    call check delta>0,'lower object must project lower in image'
  end
  do side over .array~of('S','N')
    base=scene~features[side]
    topOld=.array~of(base[1],base[2],52)
    topNew=.array~of(base[1],base[2],49)
    q0=f~project(topOld,camera,1536,height)
    q1=f~project(topNew,camera,1536,height)
    if q0==.nil | q1==.nil then do
      say 'SKIP' side 'deck behind camera'
      iterate
    end
    say 'DECK_SURFACE' side 'z52->49 pixel_y_change' format(q1[2]-q0[2],7,2)
    call check q1[2]>q0[2],'lowered road surface projects lower'
  end
end
beforeBoxes=scene~boxes~items
result=.HarbourBridgeVertical~apply(scene)
call check result['STATUS']=='CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED','vertical continuity explicit'
call check scene~features['NW_DECK_PROXY'][3]=49,'all proxies lowered'
call check scene~boxes~items=beforeBoxes+2,'added two abutments'
call check scene~features['ARCH_CROWN'][3]=134,'arch crown unchanged'
call check scene~features['NW_ROOF_PIN'][3]=89,'pylon top unchanged'
say 'REPROJECTION SENSITIVITY PASS' checks 'checks; camera positions remain unqualified'
exit 0
check:
  use arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 3
  end
  checks+=1
  return
::requires 'SlamHarbourOtherCameraFit.cls'
::requires 'SlamHarbourBridgeVertical.cls'