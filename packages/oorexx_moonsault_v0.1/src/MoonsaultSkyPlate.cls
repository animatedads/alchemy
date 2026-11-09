/* Moonsault native ooRexx catalogue-hypothesis stage, 2026-11-09.
 * No star identities or navigation fixes without independently calibrated
 * intrinsics and held-out star evidence. No Python or external image solver.
 * Catalogue is a J2000 RA/Dec table; proper motion, precession, nutation,
 * aberration, atmospheric refraction NOT included in this first gate.
 */
::options digits 17

::class MoonsaultSkyPlate public
::method loadCatalog class
  use strict arg path,maximumMagnitude=5.5
  if stream(path,'C','QUERY EXISTS')='' then -
    raise syntax 88.900 array('Yale catalogue file not found',path)
  items=.array~new
  do while lines(path)>0
    line=linein(path)
    if line='' | left(strip(line),1)='#' then iterate
    parse var line a ',' b ',' c ',' d ',' e ',' f ',' g ',' h ',' i
    if datatype(a,'N') then do
      ra=a;dec=b;mag=c;name=strip(i)
      if name='' then name='HD'||f
    end
    else do
      name=strip(a);ra=b;dec=c;mag=d
    end
    if \datatype(ra,'N') | \datatype(dec,'N') | \datatype(mag,'N') then iterate
    if mag>maximumMagnitude then iterate
    if ra<0 | ra>=360 | dec< -90 | dec>90 then iterate
    item=.directory~new
    item['NAME']=name;item['RA']=ra;item['DEC']=dec;item['MAG']=mag
    items~append(item)
    if items~items>12000 then raise syntax 88.900 array('Yale catalogue row limit exceeded')
  end
  ignore=stream(path,'C','CLOSE')
  return items

::method utcToUnix class
  use strict arg iso
  if iso~length<>20 | substr(iso,5,1)<>'-' | substr(iso,8,1)<>'-' | -
     substr(iso,11,1)<>'T' | substr(iso,20,1)<>'Z' then -
    raise syntax 88.900 array('UTC YYYY-MM-DDTHH:MM:SSZ required',iso)
  dateRaw=substr(iso,1,4)||substr(iso,6,2)||substr(iso,9,2)
  return (date('B',dateRaw,'S')-date('B','19700101','S'))*86400 + -
         substr(iso,12,2)*3600 + substr(iso,15,2)*60 + substr(iso,18,2)

/* Equinox J2000 -> mean equator/equinox of date using IAU1976/Meeus.
 * Expected error below pixel centroids over a 20-minute test, but proper
 * motion, aberration and atmospheric refraction remain OUT OF SCOPE.
 * Epoch-day memo avoids five repeated trig transformations per star. */
::method precessJ2000 class
  use strict arg star,jd
  day=trunc(jd)
  if star~hasIndex('PRECESS_DAY') then do
    if star['PRECESS_DAY']=day then return star['PRECESS_COORD']
  end
  o=.MoonsaultAngle
  ignore=o~load
  century=(jd-2451545)/36525
  zeta=(2306.2181*century+0.30188*century**2+0.017998*century**3)/3600
  zee=(2306.2181*century+1.09468*century**2+0.018203*century**3)/3600
  theta=(2004.3109*century-0.42665*century**2-0.041833*century**3)/3600
  alpha=star['RA']+zeta
  declination=star['DEC']
  sinD=o~sin(declination);cosD=o~cos(declination)
  aa=cosD*o~sin(alpha)
  bb=o~cos(theta)*cosD*o~cos(alpha)-o~sin(theta)*sinD
  cc=o~sin(theta)*cosD*o~cos(alpha)+o~cos(theta)*sinD
  ra=o~norm(o~atan2(aa,bb)+zee)
  dec=o~atan2(cc,o~sqrt(aa*aa+bb*bb))
  equatorial=.array~of(ra,dec)
  star['PRECESS_DAY']=day
  star['PRECESS_COORD']=equatorial
  return equatorial

::method project class
  use strict arg star,unix,latitude,longitude,centerAz=145,centerAlt=25
  o=.MoonsaultAngle
  ignore=o~load
  jd=2440587.5+unix/86400
  lst=o~norm(280.46061837+360.98564736629*(jd-2451545)+longitude)
  eq=self~precessJ2000(star,jd)
  ha=lst-eq[1]; dec=eq[2]
  sinDec=o~sin(dec);cosDec=o~cos(dec)
  east=-cosDec*o~sin(ha)
  north=o~cos(latitude)*sinDec-o~sin(latitude)*cosDec*o~cos(ha)
  up=o~sin(latitude)*sinDec+o~cos(latitude)*cosDec*o~cos(ha)
  cw=o~cos(centerAz);sw=o~sin(centerAz)
  cp=o~cos(centerAlt);sp=o~sin(centerAlt)
  depth=cp*sw*east+cp*cw*north+sp*up
  if depth<0.4 | up<=0 then return .nil
  right=cw*east-sw*north
  high=-sp*sw*east-sp*cw*north+cp*up
  return .array~of(right/depth,-high/depth)

/* Exactly three observed tracks, each a 5-element array of pixel pairs.
 * Pair-fit similarity enforces uniform focal scale/roll: no arbitrary affine
 * distortion and no false claim of a calibrated projection.
 */
/* A complete Yale BSC catalogue may have 9,096 rows; never run an
 * unconstrained cubic pattern search across all of it. Downselect to a
 * nominal camera cone and visual magnitude BEFORE pair hypotheses.
 * This filter is only a search acceleration, not observation evidence. */
::method preselect class
  use strict arg catalogue,unix,latitude,longitude,centerAz,centerAlt, -
                 halfWidth=1.2,halfHeight=0.9,maximumCount=128
  if halfWidth<=0 | halfHeight<=0 | maximumCount<3 | maximumCount>128 then -
    raise syntax 88.900 array('invalid camera cone / subset bound')
  selected=.array~new
  do star over catalogue
    p=self~project(star,unix,latitude,longitude,centerAz,centerAlt)
    if p==.nil then iterate
    if abs(p[1])>halfWidth | abs(p[2])>halfHeight then iterate
    selected~append(star)
    if selected~items>maximumCount then -
      raise syntax 88.900 array('catalogue cone exceeds 128 candidates: narrow camera cone or magnitude')
  end
  return selected

::method matchThree class
  use strict arg catalogue,observed,times,latitude,longitude, -
         centerAz=145,centerAlt=25,maxFirstError=7,maxTemporalRms=4
  if observed~items<>3 | times~items<>5 then -
    raise syntax 88.900 array('Three five-frame observed tracks required')
  if catalogue~items>128 then -
    raise syntax 88.900 array('preselect <=128 visible stars before pattern matching')
  o=.MoonsaultAngle
  ignore=o~load
  ignore=o~load
  projected=.array~new
  do star over catalogue
    pp=.array~new
    valid=.true
    do t over times
      p=self~project(star,t,latitude,longitude,centerAz,centerAlt)
      if p==.nil then do
        valid=.false;leave
      end
      pp~append(p)
    end
    if valid then do
      item=.directory~new
      item['NAME']=star['NAME'];item['MAG']=star['MAG']
      item['PROJECTION']=pp
      projected~append(item)
    end
  end
  results=.array~new
  if projected~items<3 then return results
  /* Observed A,B form a baseline; C is independent validation in each epoch. */
  a=observed[1]; b=observed[2]; c=observed[3]
  dx=b[1][1]-a[1][1];dy=b[1][2]-a[1][2]
  do i=1 to projected~items
    s1=projected[i];p=s1['PROJECTION'][1]
    do j=1 to projected~items
      if i=j then iterate
      p=s1['PROJECTION'][1]
      s2=projected[j];q=s2['PROJECTION'][1]
      du=q[1]-p[1];dv=q[2]-p[2]
      d2=du*du+dv*dv
      if d2<0.003 then iterate
      aa=(dx*du+dy*dv)/d2
      bb=(dy*du-dx*dv)/d2
      scale=o~sqrt(aa*aa+bb*bb)
      if scale<350 | scale>2200 then iterate
      /* Large camera roll is unlikely for fixed upright city panorama. */
      roll=o~atan2(bb,aa)
      if abs(roll)>45 then iterate
      x0=a[1][1]-aa*p[1]+bb*p[2]
      y0=a[1][2]-bb*p[1]-aa*p[2]
      bestC=0;bestD=maxFirstError*maxFirstError
      do k=1 to projected~items
        if k=i | k=j then iterate
        third=projected[k]['PROJECTION'][1]
        px=x0+aa*third[1]-bb*third[2]
        py=y0+bb*third[1]+aa*third[2]
        ed=(px-c[1][1])**2+(py-c[1][2])**2
        if ed<bestD then do
          bestD=ed;bestC=k
        end
      end
      if bestC=0 then iterate
      s3=projected[bestC]
      rms2=0
      do t=1 to 5
        v1=s1['PROJECTION'][t];v2=s2['PROJECTION'][t];v3=s3['PROJECTION'][t]
        obs=a[t]
        ex=(x0+aa*v1[1]-bb*v1[2])-obs[1]
        ey=(y0+bb*v1[1]+aa*v1[2])-obs[2]
        rms2=rms2+ex*ex+ey*ey
        obs=b[t]
        ex=(x0+aa*v2[1]-bb*v2[2])-obs[1]
        ey=(y0+bb*v2[1]+aa*v2[2])-obs[2]
        rms2=rms2+ex*ex+ey*ey
        obs=c[t]
        ex=(x0+aa*v3[1]-bb*v3[2])-obs[1]
        ey=(y0+bb*v3[1]+aa*v3[2])-obs[2]
        rms2=rms2+ex*ex+ey*ey
      end
      rms=o~sqrt(rms2/15)
      if rms>maxTemporalRms then iterate
      record=.directory~new
      record['NAMES']=.array~of(s1['NAME'],s2['NAME'],s3['NAME'])
      record['RMS']=rms;record['FIRST_ERROR']=o~sqrt(bestD)
      record['PIXELS_PER_TANGENT']=scale;record['ROLL_DEG']=roll
      record['OFFSET_X']=x0;record['OFFSET_Y']=y0
      record['REAL_A']=aa;record['IMAG_A']=bb
      record['CATALOGUE_SCAN_COUNT']=projected~items
      record['STATUS']='HYPOTHESIS_ONLY'
      results~append(record)
    end
  end
  /* Selection sort by RMS for bounded output (typically few survivors). */
  ranked=.array~new
  used=.directory~new
  do rank=1 to min(50,results~items)
    best=0
    do i=1 to results~items
      if used~hasIndex(i) then iterate
      if best=0 then best=i
      else if results[i]['RMS']<results[best]['RMS'] then best=i
    end
    if best=0 then leave
    ranked~append(results[best]);used[best]=1
  end
  return ranked
/* Independent withheld sky tracks: each four observations from frames 2..5.
 * A candidate fitted to three references may not claim star identification
 * without matching other independently detected points. A cached J2000
 * mean-equator precession is applied, but lens intrinsics, refraction,
 * proper motion and apparent-place corrections are NOT yet qualified.
 */
::method scoreHoldouts class
  use strict arg hypotheses,catalogue,heldouts,times,latitude,longitude, -
         centerAz=250,centerAlt=25,maxEachRms=5
  o=.MoonsaultAngle
  ignore=o~load
  projected=.array~new
  do star over catalogue
    pp=.array~new;valid=.true
    do index=2 to 5
      p=self~project(star,times[index],latitude,longitude,centerAz,centerAlt)
      if p==.nil then do
        valid=.false;leave
      end
      pp~append(p)
    end
    if valid then do
      d=.directory~new
      d['NAME']=star['NAME'];d['PROJECTION']=pp
      projected~append(d)
    end
  end
  ranked=.array~new
  do h over hypotheses
    refs=h['NAMES'];aa=h['REAL_A'];bb=h['IMAG_A']
    tx=h['OFFSET_X'];ty=h['OFFSET_Y']
    seen=.directory~new;matches=.array~new;sum=0
    do t over heldouts
      best=0;bestError=maxEachRms*maxEachRms
      do k=1 to projected~items
        star=projected[k]
        name=star['NAME']
        if name==refs[1] | name==refs[2] | name==refs[3] then iterate
        if seen~hasIndex(name) then iterate
        distance=0
        do j=1 to 4
          p=star['PROJECTION'][j];obs=t[j]
          x=tx+aa*p[1]-bb*p[2]
          y=ty+bb*p[1]+aa*p[2]
          distance=distance+(x-obs[1])**2+(y-obs[2])**2
        end
        distance=distance/4
        if distance<bestError then do
          bestError=distance;best=k
        end
      end
      if best>0 then do
        name=projected[best]['NAME']
        seen[name]=1
        m=.directory~new
        m['NAME']=name;m['RMS']=o~sqrt(bestError)
        matches~append(m)
        sum=sum+bestError
      end
    end
    h['HELDOUT_MATCHES']=matches~items
    h['HELDOUT']=matches
    if matches~items>0 then h['HELDOUT_RMS']=o~sqrt(sum/matches~items)
    else h['HELDOUT_RMS']=-1
    ranked~append(h)
  end
  /* Order by held-out independent matches, then total RMS. */
  ordered=.array~new;used=.directory~new
  do rank=1 to ranked~items
    best=0
    do k=1 to ranked~items
      if used~hasIndex(k) then iterate
      if best=0 then best=k
      else do
        left=ranked[k];right=ranked[best]
        if left['HELDOUT_MATCHES']>right['HELDOUT_MATCHES'] then best=k
        else if left['HELDOUT_MATCHES']=right['HELDOUT_MATCHES'] & -
          left['RMS']<right['RMS'] then best=k
      end
    end
    if best=0 then leave
    ordered~append(ranked[best]);used[best]=1
  end
  return ordered
::requires 'MoonsaultEphemeris.cls'