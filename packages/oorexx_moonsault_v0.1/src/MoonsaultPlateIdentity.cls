/* Native ooRexx celestial identity/plate qualification.
 * Source authority: Yale BSC J2000 RA/DEC; measured source-video pixels.
 * Camera solution is projective 3x3 (unknown intrinsics), fitted to first
 * observation ONLY. Time extrapolation uses Earth's sidereal rotation.
 * Never confound 0.7 pixel tracking RMS with a catalogue identity test.
 * No Python, subprocess media decoder, OpenCV or external plate solver.
 */
::options digits 30
::class MoonsaultPlateIdentity public
::constant SIDEREAL_SECONDS 86164.0905
::method candidate class
  use strict arg name,ra,dec,mag=0
  s=.directory~new
  s['NAME']=name; s['RA']=ra; s['DEC']=dec; s['MAG']=mag
  return s
::method loadCatalogue class
  use strict arg path,maxMagnitude=5.5
  if stream(path,'C','QUERY EXISTS')='' then -
    raise syntax 88.900 array('Yale catalogue missing',path)
  stars=.array~new
  do while lines(path)>0
    line=strip(linein(path))
    if line='' | left(line,1)='#' then iterate
    parse var line a ',' b ',' c ',' d ',' e ',' f ',' g ',' h ',' i
    if datatype(a,'N') then do
      ra=a;dec=b;mag=c;name=strip(i)
      if name='' then name='HD'||f
    end
    else do
      name=strip(a);ra=b;dec=c;mag=d
    end
    if \datatype(ra,'N') | \datatype(dec,'N') | \datatype(mag,'N') then iterate
    if ra<0 | ra>=360 | dec< -90 | dec>90 | mag>maxMagnitude then iterate
    stars~append(self~candidate(name,ra,dec,mag))
    if stars~items>12000 then raise syntax 88.900 array('BSC row limit')
  end
  ignored=stream(path,'C','CLOSE')
  return stars
::method vector class
  use strict arg star,elapsed=0
  o=.MoonsaultAngle
  ignore=o~load
  ra=star['RA']-elapsed*360/self~SIDEREAL_SECONDS
  dec=star['DEC']
  cd=o~cos(dec)
  return .array~of(cd*o~cos(ra),cd*o~sin(ra),o~sin(dec))
::method dot class
  use strict arg a,b
  return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
::method norm3 class
  use strict arg a
  o=.MoonsaultAngle; ignore=o~load
  n=o~sqrt(self~dot(a,a))
  if n=0 then raise syntax 88.900 array('zero 3-vector')
  return .array~of(a[1]/n,a[2]/n,a[3]/n)
::method cross class
  use strict arg a,b
  return .array~of(a[2]*b[3]-a[3]*b[2], -
                   a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1])
::method solveLinear class
  use strict arg a,b
  n=b~items
  matrix=.array~new
  do i=1 to n
    row=.array~new
    do j=1 to n
      row[j]=a[i][j]
    end
    row[n+1]=b[i];matrix[i]=row
  end
  do i=1 to n
    best=i
    do j=i+1 to n
      if abs(matrix[j][i])>abs(matrix[best][i]) then best=j
    end
    if abs(matrix[best][i])<0.00000000001 then -
      raise syntax 88.900 array('degenerate camera/rotation geometry',i)
    if best<>i then do
      temp=matrix[i];matrix[i]=matrix[best];matrix[best]=temp
    end
    pivot=matrix[i][i]
    do k=i to n+1
      matrix[i][k]=matrix[i][k]/pivot
    end
    do j=1 to n
      if j=i then iterate
      z=matrix[j][i]
      do k=i to n+1
        matrix[j][k]=matrix[j][k]-z*matrix[i][k]
      end
    end
  end
  sol=.array~new
  do i=1 to n
    sol[i]=matrix[i][n+1]
  end
  return sol
::method fit class
  use strict arg stars,tracks,training=.nil,trainLate=.false
  if stars~items<>tracks~items | stars~items<4 then -
    raise syntax 88.900 array('>=4 star/observation correspondences required')
  if training==.nil then do
    training=.array~new
    do i=1 to stars~items
      training~append(i)
    end
  end
  n=8
  A=.array~new;rhs=.array~new
  do i=1 to n
    row=.array~new
    do j=1 to n
      row[j]=0
    end
    A[i]=row;rhs[i]=0
  end
  do index over training
    if index<1 | index>stars~items then raise syntax 88.900 array('bad training track',index)
    do pass=1 to 2
      if pass=2 & \trainLate then leave
      elapsed=0
      if pass=2 then elapsed=330
      v=self~vector(stars[index],elapsed)
      point=tracks[index]
      x=point[1];y=point[2]
      if pass=2 then do
        x=point[3];y=point[4]
      end
      ax=.array~of(v[1],v[2],v[3],0,0,0,-x*v[1],-x*v[2])
      ay=.array~of(0,0,0,v[1],v[2],v[3],-y*v[1],-y*v[2])
      self~addEq(A,rhs,ax,x*v[3])
      self~addEq(A,rhs,ay,y*v[3])
    end
  end
  h=self~solveLinear(A,rhs)
  return .array~of(.array~of(h[1],h[2],h[3]), -
                   .array~of(h[4],h[5],h[6]), -
                   .array~of(h[7],h[8],1))
::method addEq class
  use strict arg A,rhs,row,target
  do i=1 to 8
    rhs[i]=rhs[i]+row[i]*target
    do j=1 to 8
      A[i][j]=A[i][j]+row[i]*row[j]
    end
  end
::method project class
  use strict arg camera,star,elapsed=0
  v=self~vector(star,elapsed)
  out=.array~new
  do i=1 to 3
    out[i]=self~dot(camera[i],v)
  end
  if abs(out[3])<0.00000001 then raise syntax 88.900 array('camera projection at infinity')
  return .array~of(out[1]/out[3],out[2]/out[3])
::method score class
  use strict arg camera,stars,tracks,only=.nil
  if stars~items<>tracks~items then raise syntax 88.900 array('star/track count mismatch')
  if only==.nil then do
    only=.array~new
    do i=1 to stars~items
      only~append(i)
    end
  end
  o=.MoonsaultAngle; ignore=o~load
  total=0;maximum=0;count=0;residuals=.array~new
  do index over only
    do pass=1 to 2
      time=0
      if pass=2 then time=330
      p=self~project(camera,stars[index],time)
      obs=tracks[index]
      if pass=1 then do
        dx=p[1]-obs[1];dy=p[2]-obs[2]
      end
      else do
        dx=p[1]-obs[3];dy=p[2]-obs[4]
      end
      err=o~sqrt(dx*dx+dy*dy)
      residuals~append(.array~of(index,time,err,p[1],p[2]))
      total=total+err*err;count=count+1
      maximum=max(maximum,err)
    end
  end
  return .array~of(o~sqrt(total/count),maximum,count,residuals)
/* Ideal-pinhole consistency check of projective 3x3 estimate.
 * If principal point, fx/fy and skew are plausible, one camera and a
 * single rigid lens can account for the celestial rotation.
 */
::method intrinsics class
  use strict arg camera
  o=.MoonsaultAngle;ignore=o~load
  a=camera[1];b=camera[2];c=camera[3]
  n=self~dot(c,c)
  centerX=self~dot(a,c)/n;centerY=self~dot(b,c)/n
  fx=o~sqrt(self~dot(a,a)/n-centerX*centerX)
  fy=o~sqrt(self~dot(b,b)/n-centerY*centerY)
  skew=(self~dot(a,b)/n-centerX*centerY)/fy
  return .array~of(centerX,centerY,fx,fy,skew)
::method heldout class
  use strict arg camera,stars,path
  if stream(path,'C','QUERY EXISTS')='' then raise syntax 88.900 array('heldout TSV unavailable',path)
  first=linein(path)
  o=.MoonsaultAngle;ignore=o~load
  n=0;sum=0;maximum=0
  do while lines(path)>0
    line=linein(path)
    parse var line clip '09'x second '09'x track '09'x ex '09'x ey '09'x measuredX '09'x measuredY '09'x previous
    if \datatype(track,'W') | \datatype(measuredX,'N') then iterate
    if track<1 | track>stars~items then raise syntax 88.900 array('heldout track number',track)
    time=second-5
    if clip=2 then time=275+second-5
    xy=self~project(camera,stars[track],time)
    dx=xy[1]-measuredX;dy=xy[2]-measuredY
    error=o~sqrt(dx*dx+dy*dy)
    sum=sum+error*error;n=n+1
    maximum=max(maximum,error)
  end
  ignored=stream(path,'C','CLOSE')
  if n=0 then raise syntax 88.900 array('no heldout observations')
  return .array~of(n,o~sqrt(sum/n),maximum)
::requires 'MoonsaultEphemeris.cls'