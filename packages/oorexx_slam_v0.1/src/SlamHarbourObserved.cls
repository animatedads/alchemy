/* Power SLAM: measured-horizontal-landmark qualifier v0.2.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 * Additive to SlamHarbourPose.cls. Measurements ARE NOT solved camera positions.
 * Camera yaw is calculated per candidate; focal length is EXPLICITLY scanned.
 * Vertical height/pitch cannot be inferred from horizontal landmarks: not claimed.
 * Only eligible LAND candidates are projected. Unknown/water never admitted.
 */
::requires 'SlamHarbourPose.cls'
::class HarbourPhotoPose public
::attribute scene
::method init
  expose scene
  use strict arg scene
::method validate
  expose scene
  use strict arg obs, width
  if width<=0 then raise syntax 88.900 array('invalid image width')
  seen=.directory~new
  do a over obs
    if a~items<>2 then raise syntax 88.900 array('horizontal observation must be [landmark,pixelX]')
    id=a[1]
    if \scene~features~hasIndex(id) then raise syntax 88.900 array('unknown landmark' id)
    if seen~hasIndex(id) then raise syntax 88.900 array('duplicate landmark' id)
    if \datatype(a[2],'N') then raise syntax 88.900 array('non-numeric image measurement')
    if a[2]<0 | a[2]>=width then raise syntax 88.900 array('pixel outside frame')
    seen[id]=.true
  end
/* Count every candidate meeting ABSOLUTE error threshold, keep top matches.
 * Many camera positions/focals often give same projection; these are not probability
 * estimates. If fewer than 3 landmarks, we refuse inverse site estimation.
 * For photo1/2: uncalibrated lens, uncertain landmark selection -> EXPLORATORY.
 */
::method fitHorizontal
  expose scene
  use strict arg mask,obs,focals,width,step=25,maxResults=12,maxRms=20
  self~validate(obs,width)
  out=.directory~new
  out['STATUS']='INSUFFICIENT_LANDMARKS'
  out['BEST']=.array~new
  out['ADMITTED']=0
  out['LAND_TESTED']=0
  out['WATER_REJECTED']=0
  out['FOCAL_TRIALS']=focals~items
  out['MASK_CLASS']='UNQUALIFIED_MASK'
  if obs~items<3 then return out
  if focals~items<1 | step<=0 | maxRms<=0 | maxResults<1 then raise syntax 88.900 array('invalid search parameters')
  bounds=mask~bounds
  /* Scan each land sample once, then each explicitly supplied focal. */
  first=scene~features[obs[1][1]]
  do y=bounds[3] to bounds[4] by step
    do x=bounds[1] to bounds[2] by step
      if \mask~contains(x,y) then do
        out['WATER_REJECTED']+=1
        iterate
      end
      out['LAND_TESTED']+=1
      do focal over focals
        if \datatype(focal,'N') | focal<=0 then raise syntax 88.900 array('invalid focal sample')
        aim=scene~aim(first,x,y,obs[1][2],focal,width)
        if aim==.nil then iterate
        score=0;valid=.true
        do a over obs
          p=scene~project(scene~features[a[1]],x,y,0,aim[1],aim[2],focal,width,1)
          if p==.nil then do;valid=.false;leave;end
          score+=(p[1]-a[2])**2
        end
        if \valid then iterate
        if score<=obs~items*maxRms*maxRms then out['ADMITTED']+=1
        fit=.array~of(score,x,y,focal,aim[1],aim[2])
        best=out['BEST'];insertAt=best~items+1
        do i=1 to best~items
          if score<best[i][1] then do;insertAt=i;leave;end
        end
        if insertAt<=maxResults then do
          ranked=.array~new
          do j=1 to best~items+1
            if j==insertAt then ranked~append(fit)
            if j<=best~items then ranked~append(best[j])
          end
          if ranked~items>maxResults then ranked~remove(maxResults+1)
          out['BEST']=ranked
        end
      end
    end
  end
  out['STATUS']='NO_HORIZONTAL_FIT'
  if out['ADMITTED']>0 then out['STATUS']='HYPOTHESES_NOT_LAND_QUALIFIED'
  return out
/* A control camera's known geographical XY supplies an additional constraint.
 * It can calibrate the lens from TWO visible landmarks without solving a site.
 * Focal is bounded by explicit samples; all passing samples are returned.
 */
::method calibrateAt
  expose scene
  use strict arg camera,obs,focals,width,maxRms=15
  self~validate(obs,width)
  out=.directory~new
  out['STATUS']='INSUFFICIENT_LANDMARKS'
  out['PASSING_FOCALS']=.array~new
  out['BEST']=.nil
  if obs~items<2 then return out
  if maxRms<=0 then raise syntax 88.900 array('invalid pixel tolerance')
  first=scene~features[obs[1][1]]
  do focal over focals
    if \datatype(focal,'N') | focal<=0 then raise syntax 88.900 array('invalid focal sample')
    aim=scene~aim(first,camera[1],camera[2],obs[1][2],focal,width)
    if aim==.nil then iterate
    score=0;ok=.true
    do a over obs
      p=scene~project(scene~features[a[1]],camera[1],camera[2],0,aim[1],aim[2],focal,width,1)
      if p==.nil then do;ok=.false;leave;end
      score+=(p[1]-a[2])**2
    end
    if \ok then iterate
    if score<=obs~items*maxRms*maxRms then out['PASSING_FOCALS']~append(focal)
    if out['BEST']==.nil then out['BEST']=.array~of(score,focal)
    else if score<out['BEST'][1] then out['BEST']=.array~of(score,focal)
  end
  out['STATUS']='NO_CALIBRATION_FIT'
  if out['PASSING_FOCALS']~items>0 then out['STATUS']='FOCAL_INTERVAL_NOT_UNIQUE'
  return out