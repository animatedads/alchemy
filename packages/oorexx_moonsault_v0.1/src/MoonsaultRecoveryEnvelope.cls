/* Moonsault dead-reckoning recovery integrity: angular-error FEASIBLE REGION.
 * ooRexx owns all geometry. This is not a GPS validation or survey claim.
 * Astronomical bearing and terrain/landmark bearings remain different inputs.
 */
::options digits 30
::class MoonsaultRecoveryEnvelope public
::constant METRES_PER_DEGREE 111320
::constant ONE_NAUTICAL_MILE 1852
::method evaluate class
  use strict arg plate,julianDay,landmarks,fix,angularAllowanceDeg=2,searchRadiusMetres=2500,stepMetres=50
  if landmarks~items<3 then raise syntax 88.900 array('at least three independent landmarks')
  if angularAllowanceDeg<=0 | angularAllowanceDeg>15 then -
    raise syntax 88.900 array('angular allowance must be 0..15 deg')
  if searchRadiusMetres<100 | searchRadiusMetres>5000 then -
    raise syntax 88.900 array('search radius outside 100..5000 m')
  if stepMetres<10 | stepMetres>250 then -
    raise syntax 88.900 array('grid step outside 10..250 m')
  n=searchRadiusMetres%stepMetres
  if n>250 then raise syntax 88.900 array('grid too large')
  camera=.MoonsaultCameraFix
  o=.MoonsaultAngle;ignore=o~load
  lat0=fix['LATITUDE'];lon0=fix['LONGITUDE']
  accepted=0;seen=0;edge=0;far=0
  minE=999999;maxE=-999999;minN=999999;maxN=-999999
  worstError=0;closestError=999999
  /* Search in local tangent plane around the measured candidate. Strictly
   * use an explicit finite radius; never infer accuracy from the grid alone.
   * Recompute the celestial azimuth at each candidate observation location. */
  do i=-n to n
    east=i*stepMetres
    do j=-n to n
      north=j*stepMetres
      radial=o~sqrt(east*east+north*north)
      if radial>searchRadiusMetres then iterate
      seen=seen+1
      lat=lat0+north/self~METRES_PER_DEGREE
      lon=lon0+east/(self~METRES_PER_DEGREE*o~cos(lat))
      maxErr=0
      do lm over landmarks
        if lm~items<5 then raise syntax 88.900 array('incomplete landmark')
        chart=camera~landmarkBearing(lat,lon,lm[2],lm[3])
        predicted=camera~direction(plate,lm[4],lm[5],julianDay,lat,lon)['AZIMUTH_TRUE']
        err=abs(camera~angleError(chart,predicted))
        maxErr=max(maxErr,err)
        if err>angularAllowanceDeg then leave
      end
      if maxErr<closestError then closestError=maxErr
      if maxErr>angularAllowanceDeg then iterate
      accepted=accepted+1
      if radial>far then far=radial
      worstError=max(worstError,maxErr)
      minE=min(minE,east);maxE=max(maxE,east)
      minN=min(minN,north);maxN=max(maxN,north)
      if radial>=searchRadiusMetres-stepMetres then edge=edge+1
    end
  end
  output=.directory~new
  output['CANDIDATE_LATITUDE']=lat0
  output['CANDIDATE_LONGITUDE']=lon0
  output['ANGLE_ALLOWANCE_DEG']=angularAllowanceDeg
  output['GRID_STEP_METRES']=stepMetres
  output['SEARCH_RADIUS_METRES']=searchRadiusMetres
  output['POINTS_EXAMINED']=seen
  output['POINTS_FEASIBLE']=accepted
  output['BOUNDARY_TOUCH_COUNT']=edge
  output['BEST_GRID_RESIDUAL_DEG']=closestError
  output['WORST_FEASIBLE_RESIDUAL_DEG']=worstError
  output['RADIUS_LOWER_BOUND_METRES']=far
  /* Finite-grid conservative padding; not a calibrated probability interval.
   * Search coverage is invalid if any feasible cell touches its edge. */
  output['GRID_PADDED_RADIUS_METRES']=far+stepMetres*o~sqrt(2)
  output['EAST_LIMITS']=.array~of(minE,maxE)
  output['NORTH_LIMITS']=.array~of(minN,maxN)
  output['INDEPENDENT_GROUND_TRUTH']=.false
  output['SURVEY_5M_QUALIFIED']=.false
  output['ONE_NM_TARGET_METRES']=self~ONE_NAUTICAL_MILE
  output['MODEL_WITHIN_ONE_NM']=.false
  select
    when accepted=0 then output['STATUS']='NO_FEASIBLE_POSITION'
    when edge>0 then output['STATUS']='OPEN_AT_SEARCH_BOUNDARY'
    when far+stepMetres*o~sqrt(2)<=self~ONE_NAUTICAL_MILE then do
      output['STATUS']='BOUNDED_WITHIN_ONE_NM_MODEL_ONLY'
      output['MODEL_WITHIN_ONE_NM']=.true
    end
    otherwise output['STATUS']='MODEL_ENVELOPE_EXCEEDS_ONE_NM'
  end
  return output
/* Deterministic robustness exercise, NOT a probability bound.
 * Vary each image landmark pick by up to pixelBudget, or each charted
 * landmark by chartBudgetMetres. Exercise 3^3 combinations for each.
 * These paired ± perturbations do not exhaust the continuous input box.
 */
::method stress class
  use strict arg plate,julianDay,landmarks,fix,pixelBudget=20,chartBudgetMetres=25
  if landmarks~items<>3 then raise syntax 88.900 array('stress currently requires three landmarks')
  if pixelBudget<0 | pixelBudget>100 | chartBudgetMetres<0 | chartBudgetMetres>200 then -
    raise syntax 88.900 array('stress input outside bounded policy range')
  camera=.MoonsaultCameraFix
  o=.MoonsaultAngle;ignore=o~load
  baseLat=fix['LATITUDE'];baseLon=fix['LONGITUDE']
  widest=0;worstError=0;runCount=0
  do mode=1 to 2
    do caseNo=0 to 26
      digits=caseNo
      adjusted=.array~new
      do lm over landmarks
        k=digits//3-1;digits=digits%3
        newLat=lm[2];newLon=lm[3]
        newX=lm[4];newY=lm[5]
        if mode=1 then do
          newX=newX+k*pixelBudget
          newY=newY-k*pixelBudget/2
        end
        else do
          newLat=newLat+k*chartBudgetMetres/self~METRES_PER_DEGREE
          newLon=newLon-k*chartBudgetMetres/(self~METRES_PER_DEGREE*o~cos(newLat))
        end
        adjusted~append(.array~of(lm[1],newLat,newLon,newX,newY))
      end
      f=camera~locate(plate,julianDay,adjusted,baseLat,baseLon)
      e=(f['LONGITUDE']-baseLon)*self~METRES_PER_DEGREE*o~cos(baseLat)
      n=(f['LATITUDE']-baseLat)*self~METRES_PER_DEGREE
      d=o~sqrt(e*e+n*n)
      widest=max(widest,d)
      worstError=max(worstError,f['MAX_LANDMARK_ANGULAR_RESIDUAL'])
      runCount=runCount+1
    end
  end
  output=.directory~new
  output['RUNS']=runCount
  output['MAX_LOCATION_CHANGE_METRES']=widest
  output['MAX_LANDMARK_ANGULAR_RESIDUAL']=worstError
  output['PIXEL_PERTURBATION']=pixelBudget
  output['CHART_PERTURBATION_METRES']=chartBudgetMetres
  output['STATUS']='FINITE_STRESS_SAMPLES_NOT_CONFIDENCE_INTERVAL'
  output['ONE_NM_QUALIFIED']=.false
  return output
::requires 'MoonsaultCameraFix.cls'