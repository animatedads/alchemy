/* Power SLAM v0.7: true pinhole perspective and bounded photographic pose fit.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 * Actual image controls provided by independent measurements, NOT inferred by
 * the 360-degree bearing renderer. Rooftop XY, bridge deck location and road
 * roof elevation are provisional. Model and camera unknowns must be audited.
 * Requires rxmath MathLoadFuncs in the invoking program.
 */
::requires 'SlamHarbourQuayInfrastructure.cls'


/* A candidate camera may be anywhere in a caller-supplied 2D polygon.
   The built-in bounding polygon is deliberately oversized and PROVISIONAL;
   it is a search envelope, not a surveyed building outline or a proof that
   every enclosed point is an accessible roof or a valid sightline. */
::class HarbourCameraPolygon public
::attribute vertices
::attribute provenance
::method init
  expose vertices provenance
  use strict arg vertices, provenance='USER_SUPPLIED_UNQUALIFIED'
  if vertices~items<3 then raise syntax 88.900 array('camera polygon needs >=3 vertices')
  do p over vertices
    if p~items<2 | \datatype(p[1],'N') | \datatype(p[2],'N') then raise syntax 88.900 array('camera polygon vertex must be XY')
  end
  self~vertices=vertices
  self~provenance=provenance
::method bounds
  expose vertices
  x0=1e20;x1=-1e20;y0=1e20;y1=-1e20
  do p over vertices
    x0=min(x0,p[1]);x1=max(x1,p[1]);y0=min(y0,p[2]);y1=max(y1,p[2])
  end
  return .array~of(x0,x1,y0,y1)
::method contains
  expose vertices
  use strict arg x,y
  inside=.false
  j=vertices~items
  do i=1 to vertices~items
    a=vertices[i];b=vertices[j]
    dx=b[1]-a[1];dy=b[2]-a[2]
    /* On polygon boundary counts as an admissible provisional sample. */
    cross=(x-a[1])*dy-(y-a[2])*dx
    if abs(cross)<0.00000001 then if x>=min(a[1],b[1])-0.000001 & x<=max(a[1],b[1])+0.000001 & y>=min(a[2],b[2])-0.000001 & y<=max(a[2],b[2])+0.000001 then return .true
    if (a[2]>y) \= (b[2]>y) then do
      cut=a[1]+(b[1]-a[1])*(y-a[2])/(b[2]-a[2])
      if x<cut then inside=\inside
    end
    j=i
  end
  return inside

::class HarbourPerspectiveFit public
::attribute model
::attribute cameraPolygon
::method init
  expose model cameraPolygon
  model = .HarbourQuayInfrastructurePanorama~new
  c=model~siteCamera('CAFE_SYDNEY')
  /* 80m EW x 64m NS provisional SEARCH ENVELOPE around the indexed centre.
     Replace with a georeferenced roof polygon once independently measured.
     Building address != rooftop lens location. */
  x=c[1];y=c[2]
  vertices=.array~of(.array~of(x-40,y-32),.array~of(x+40,y-32),.array~of(x+40,y+32),.array~of(x-40,y+32))
  cameraPolygon=.HarbourCameraPolygon~new(vertices, 'OVERSIZED_BUILDING_AREA_HYPOTHESIS_NOT_SURVEYED')
::method world
  expose model
  use strict arg id
  scene = model~scene
  if id=='S_TOP' | id=='N_TOP' | id=='S_DECK' | id=='N_DECK' then do
    side=id~left(1)
    p=scene~features[side]
    if id~right(3)=='TOP' then z=89
    else z=54
    return .array~of(p[1],p[2],z)
  end
  if id=='ARCH_CROWN' then do
    a=scene~features['S'];b=scene~features['N']
    return .array~of((a[1]+b[1])/2,(a[2]+b[2])/2,134)
  end
  if id=='DECK_MID' then do
    a=scene~features['S'];b=scene~features['N']
    return .array~of((a[1]+b[1])/2,(a[2]+b[2])/2,54)
  end
  if scene~features~hasIndex(id) then return scene~features[id]
  raise syntax 88.900 array('unknown image landmark' id)
::method initialCamera
  expose model
  c=model~siteCamera('CAFE_SYDNEY')
  /* camera: east/north/height/yaw(deg clockwise from north)/pitch(deg up)/focal_px */
  return .array~of(c[1],c[2],25,4,0,2500)
::method project
  use strict arg pt,cam,w=1536,h=862
  if cam[6]<=0 then raise syntax 88.900 array('invalid focal length')
  east=pt[1]-cam[1]; north=pt[2]-cam[2]; up=pt[3]-cam[3]
  forwardHorizontal=east*RxCalcSin(cam[4])+north*RxCalcCos(cam[4])
  right=east*RxCalcCos(cam[4])-north*RxCalcSin(cam[4])
  forward=forwardHorizontal*RxCalcCos(cam[5])+up*RxCalcSin(cam[5])
  vertical=up*RxCalcCos(cam[5])-forwardHorizontal*RxCalcSin(cam[5])
  if forward<=0.001 then return .nil
  return .array~of(w/2+cam[6]*right/forward,h/2-cam[6]*vertical/forward,forward)
/* Project a straight fixed-elevation section of the station-length Cahill
   cuboid and interpolate its expected vertical image coordinate at x.
   It may only be used as a PROVISIONAL observation: neither the geometry
   nor the foreground edge correspondence is surveyed. */
::method cahillAtX
  use strict arg cam,x,w=1536,h=862
  a=self~project(self~world('CAHILL_W'),cam,w,h)
  b=self~project(self~world('CAHILL_E'),cam,w,h)
  if a==.nil | b==.nil then return .nil
  if abs(a[1]-b[1])<0.001 then return .nil
  return a[2]+(b[2]-a[2])*(x-a[1])/(b[1]-a[1])
::method score
  use strict arg cam,observations,w=1536,h=862
  if cam[3]<12 | cam[3]>60 | cam[6]<500 | cam[6]>10000 then return 1e20
  value=0
  do item over observations
    id=item[1]
    if id=='PROVISIONAL_CAHILL_EDGE' then do
      predicted=self~cahillAtX(cam,item[2],w,h)
      if predicted==.nil then return 1e20
      err=predicted-item[3]
      value+=err*err/(item[4]*item[4])
    end
    else do
      predicted=self~project(self~world(id),cam,w,h)
      if predicted==.nil then return 1e20
      errx=predicted[1]-item[2]
      erry=predicted[2]-item[3]
      value+=(errx*errx+erry*erry)/(item[4]*item[4])
    end
  end
  return value
/* Search the ENTIRE candidate roof polygon in XY (both east-west and
   north-south), and solve z,yaw,pitch,f simultaneously. Multiple seeds stop
   a bad centre or Gemini XY guess defining the search. The opt-in polygon
   parameter lets an authoritative surveyed footprint replace the initial
   oversized uncertainty envelope without changing the fit algorithm. */
::method fit
  expose cameraPolygon
  use strict arg obs,ref,firstHeight=25,iterations=26,footprint=.nil
  if footprint==.nil then footprint=cameraPolygon
  bounds=footprint~bounds
  lower=.array~of(bounds[1],bounds[3],15,-15,-10,900)
  upper=.array~of(bounds[2],bounds[4],55,15,10,7000)
  bestScore=1e30;best=.nil;count=0;seeds=0;accepted=0
  ranked=.array~new
  heights=.array~of(firstHeight,43)
  do fy over .array~of(0.12,0.5,0.88)
    do fx over .array~of(0.12,0.5,0.88)
      initX=bounds[1]+fx*(bounds[2]-bounds[1])
      initY=bounds[3]+fy*(bounds[4]-bounds[3])
      if \footprint~contains(initX,initY) then iterate
      do initHeight over heights
        p=ref~copy
        p[1]=initX;p[2]=initY;p[3]=initHeight
        step=.array~of(9,9,5,1.5,0.8,350)
        val=self~score(p,obs)
        seeds+=1
        do cycle=1 to iterations
          improved=.false
          do axis=1 to 6
            localBest=p[axis];localScore=val
            do side over .array~of(-1,1)
              next=p[axis]+side*step[axis]
              if next<lower[axis] | next>upper[axis] then iterate
              q=p~copy;q[axis]=next
              if \footprint~contains(q[1],q[2]) then iterate
              score=self~score(q,obs)
              count+=1
              if score<localScore-0.0000000001 then do
                localScore=score;localBest=next
              end
            end
            if localScore<val then do
              p[axis]=localBest;val=localScore;improved=.true
            end
          end
          if \improved then do
            maxStep=0
            do axis=1 to 6
              step[axis]=step[axis]/2
              maxStep=max(maxStep,step[axis])
            end
            if maxStep<0.01 then leave
          end
        end
        if val<bestScore then do
          bestScore=val;best=p~copy
        end
        /* Keep regionally distinct optima as evidence of non-identifiability,
           not just multiple seeds that converged to the same point. */
        if val<1e19 then do
          accepted+=1
          different=.true
          do i=1 to ranked~items
            cand=ranked[i][2]
            if abs(cand[1]-p[1])<2 & abs(cand[2]-p[2])<2 & abs(cand[3]-p[3])<2 then do
              different=.false
              if val<ranked[i][1] then ranked[i]=.array~of(val,p~copy)
              leave
            end
          end
          if different then ranked~append(.array~of(val,p~copy))
        end
      end
    end
  end
  /* Refine the best distinct coarse-start poses locally after the broad XY
     search. This avoids sacrificing precision to affordable multi-starts. */
  used=.array~new
  do polishIndex=1 to 5
    index=0;minChi=1e30
    do i=1 to ranked~items
      skip=.false
      do prev over used
        if i=prev then skip=.true
      end
      if skip then iterate
      if ranked[i][1]<minChi then do
        index=i;minChi=ranked[i][1]
      end
    end
    if index=0 then leave
    used~append(index)
    updated=self~polish(obs,ranked[index][2],lower,upper,footprint,55)
    count+=updated[3]
    if updated[1]<bestScore then do
      bestScore=updated[1];best=updated[2]~copy
    end
  end
  answer=.directory~new
  answer['POSE']=best
  answer['CHI2']=bestScore
  answer['EVALUATIONS']=count
  answer['SEEDS']=seeds
  answer['OBSERVATIONS']=obs~items
  answer['FOOTPRINT_PROVENANCE']=footprint~provenance
  answer['CANDIDATES']=ranked
  answer['STATUS']='PROVISIONAL_FOOTPRINT_UNSURVEYED'
  if best==.nil then answer['STATUS']='NO_GEOMETRIC_SOLUTION'
  else do
    if best[3]>54.9 | best[3]<15.1 then answer['STATUS']='HEIGHT_BOUNDARY_NOT_IDENTIFIED'
  end
  return answer
::method polish
  use strict arg obs,start,lower,upper,footprint,iterations=55
  p=start~copy;val=self~score(p,obs);n=0
  step=.array~of(3,3,2,0.6,0.4,120)
  do cycle=1 to iterations
    improved=.false
    do axis=1 to 6
      localBest=p[axis];localScore=val
      do sign over .array~of(-1,1)
        next=p[axis]+sign*step[axis]
        if next<lower[axis] | next>upper[axis] then iterate
        q=p~copy;q[axis]=next
        if \footprint~contains(q[1],q[2]) then iterate
        sc=self~score(q,obs);n+=1
        if sc<localScore-0.0000000001 then do
          localScore=sc;localBest=next
        end
      end
      if localScore<val then do
        p[axis]=localBest;val=localScore;improved=.true
      end
    end
    if \improved then do
      largest=0
      do axis=1 to 6
        step[axis]=step[axis]/2
        largest=max(largest,step[axis])
      end
      if largest<0.005 then leave
    end
  end
  return .array~of(val,p,n)
::method horizontalFov
  use strict arg focal,width=1536
  if focal<=0 then raise syntax 88.900 array('invalid focal length')
  return 2*RxCalcArcTan(width/(2*focal))
::method report
  use strict arg title,fit,observations
  pose=fit['POSE']
  say 'MODEL PHOTO FIT:' title
  say 'STATUS:' fit['STATUS']
  say 'site XY east,north' format(pose[1],8,4) format(pose[2],8,4)
  c=self~initialCamera
  say 'offset from indexed Customs House centre, east/north m:' format(pose[1]-c[1],5,2) format(pose[2]-c[2],5,2)
  say 'camera height (ASL, m):' format(pose[3],3,3)
  say 'yaw pitch (deg):' format(pose[4],3,3) format(pose[5],3,3)
  say 'focal (px):' format(pose[6],5,2) 'horizontal FOV:' format(self~horizontalFov(pose[6]),2,2)
  say 'roof polygon:' fit['FOOTPRINT_PROVENANCE'] 'multi-starts:' fit['SEEDS']
  say 'weighted chi2:' format(fit['CHI2'],4,3) 'evaluations' fit['EVALUATIONS']
  do item over observations
    if item[1]=='PROVISIONAL_CAHILL_EDGE' then do
      pred=self~cahillAtX(pose,item[2]); say item[1] 'obsX='item[2] 'obsY='item[3] 'projectedY='format(pred,5,1) 'residualY='format(pred-item[3],4,2)
    end
    else do
      p=self~project(self~world(item[1]),pose)
      say item[1] 'observed' item[2] item[3] 'projected' format(p[1],5,1) format(p[2],5,1) 'delta' format(p[1]-item[2],4,1) format(p[2]-item[3],4,1)
    end
  end
  return .true

::method renderOverlay
  expose model
  use strict arg filename,cam,obs,title='Power SLAM true perspective',w=1536,h=862
  call SysFileDelete filename
  call lineout filename, '<svg xmlns="http://www.w3.org/2000/svg" width="' || w || '" height="' || h || '" viewBox="0 0 ' || w || ' ' || h || '">'
  /* Transparent, geometric overlay: no generated landscape. */
  edges=.array~of('1 2','2 4','4 3','3 1','5 6','6 8','8 7','7 5','1 5','2 6','3 7','4 8')
  do box over model~scene~boxes
    name=box[1]
    color='#64748b'
    if name=='PYLON' then color='#f59e0b'
    if name=='DECK' then color='#f97316'
    if name=='OPERA' then color='#eab308'
    if name=='SALESFORCE' then color='#38bdf8'
    if name=='CQ_STATION' then color='#22c55e'
    if name=='CAHILL' then color='#e11d48'
    if name~left(2)=='CQ' then color='#22c55e'
    if name~left(2)=='WB' then color='#a16207'
    v=box[2]
    do edge over edges
      p=self~project(v[edge~word(1)],cam,w,h)
      q=self~project(v[edge~word(2)],cam,w,h)
      if p==.nil | q==.nil then iterate
      line='<line x1="' || p[1] || '" y1="' || p[2] || '" x2="' || q[1] || '" y2="' || q[2] || '" stroke="' || color || '" stroke-width="2.2" stroke-opacity="0.65"/>'
      call lineout filename, line
    end
  end
  do item over obs
    if item[1]=='PROVISIONAL_CAHILL_EDGE' then do
      pred=self~cahillAtX(cam,item[2],w,h)
      if pred==.nil then iterate
      x=item[2];y=item[3]
      line='<line x1="' || x || '" y1="' || y || '" x2="' || x || '" y2="' || pred || '" stroke="#d946ef" stroke-width="3" stroke-dasharray="5,3"/>'
      call lineout filename, line
      line='<circle cx="' || x || '" cy="' || y || '" r="6" fill="#d946ef" stroke="white" stroke-width="1.5"/>'
      call lineout filename, line
      iterate
    end
    p=self~project(self~world(item[1]),cam,w,h)
    if p==.nil then iterate
    x=item[2];y=item[3]
    line='<line x1="' || x || '" y1="' || y || '" x2="' || p[1] || '" y2="' || p[2] || '" stroke="#ffffff" stroke-width="3" stroke-opacity="0.8"/>'
    call lineout filename, line
    line='<circle cx="' || x || '" cy="' || y || '" r="6" fill="#ef4444" stroke="#ffffff" stroke-width="1.8"/>'
    call lineout filename, line
    line='<circle cx="' || p[1] || '" cy="' || p[2] || '" r="5" fill="#1d4ed8" stroke="#ffffff" stroke-width="1.8"/>'
    call lineout filename, line
  end
  arch=self~project(self~world('ARCH_CROWN'),cam,w,h)
  if arch\==.nil then do
    line='<circle cx="' || arch[1] || '" cy="' || arch[2] || '" r="7" fill="none" stroke="#a855f7" stroke-width="3"/>'
    call lineout filename, line
    call lineout filename, '<circle cx="447" cy="190" r="7" fill="none" stroke="#ec4899" stroke-width="3"/>'
  end
  call lineout filename, '<rect x="12" y="11" width="745" height="74" fill="#0f172a" fill-opacity="0.83" rx="8"/>'
  call lineout filename, '<text x="25" y="38" font-size="20" fill="white" font-family="DejaVu Sans">' || title || '</text>'
  call lineout filename, '<text x="25" y="63" font-size="14" fill="white" font-family="DejaVu Sans">Red = image pixels; blue = model projection; purple = arch holdout</text>'
  call lineout filename, '</svg>'
  call stream filename,'C','CLOSE'
  return .true