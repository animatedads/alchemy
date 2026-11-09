/* Moonsault-owned sky point candidate detector for grayscale 8-bit planes.
 * The native provider supplies pixels only. These are NOT identified stars.
 * Outer masks exclude playback UI, skyline and bridge, and output is bounded.
 */
::options digits 30
::class MoonsaultStillPointScan public
::method scan class
  use strict arg plane,width,height,leftX=55,rightX=1855,topY=68,bottomY=315, -
                 minContrast=15,maxCandidates=20000
  if plane~length<>width*height then -
    raise syntax 88.900 array('sky plane does not match pixel dimensions')
  if leftX<10 | topY<10 | rightX>width-11 | bottomY>height-11 | -
     minContrast<1 | maxCandidates<1 then -
    raise syntax 88.900 array('sky scan bounds invalid')
  candidates=.array~new
  /* Pixel locations zero-based; ooRexx strings one-based. */
  do y=topY to bottomY
    row=y*width+1
    do x=leftX to rightX
      off=row+x
      center=c2d(substr(plane,off,1))
      if center<25 then iterate
      /* strict compact local maximum suppresses cloud gradients/edges */
      nearLeft=c2d(substr(plane,off-1,1))
      if nearLeft>=center then iterate
      nearRight=c2d(substr(plane,off+1,1))
      if nearRight>=center then iterate
      nearUp=c2d(substr(plane,off-width,1))
      if nearUp>=center then iterate
      nearDown=c2d(substr(plane,off+width,1))
      if nearDown>=center then iterate
      d=7
      bg=(c2d(substr(plane,off-d,1))+c2d(substr(plane,off+d,1))+ -
        c2d(substr(plane,off-width*d,1))+c2d(substr(plane,off+width*d,1))+ -
        c2d(substr(plane,off-width*d-d,1))+c2d(substr(plane,off-width*d+d,1))+ -
        c2d(substr(plane,off+width*d-d,1))+c2d(substr(plane,off+width*d+d,1)))/8
      contrast=center-bg
      if contrast<minContrast then iterate
      /* reject flat/large features; a compact point must have a sharper peak */
      nearMean=(nearLeft+nearRight+nearUp+nearDown)/4
      if center-nearMean<2 then iterate
      item=.directory~new
      item['X']=x;item['Y']=y;item['CONTRAST']=contrast;item['PEAK']=center
      candidates~append(item)
      if candidates~items>=maxCandidates then -
        raise syntax 88.900 array("sky candidate capacity exceeded",maxCandidates)
    end
  end
  return candidates
::method register class
  use strict arg refGray,gray,width,height,maxShift=5
  if refGray~length<>width*height | gray~length<>width*height then -
    raise syntax 88.900 array('registration image size mismatch')
  best=9999999999;bx=0;by=0
  /* Fixed downtown facade patches; avoid sky/traffic/water/bridge beacon. */
  do dy=-maxShift to maxShift
    do dx=-maxShift to maxShift
      score=0;n=0
      do y=435 to 510 by 13
        do x=425 to 900 by 19
          a=c2d(substr(refGray,y*width+x+1,1))
          b=c2d(substr(gray,(y+dy)*width+x+dx+1,1))
          score=score+abs(a-b)
          n=n+1
        end
      end
      score=score/n
      if score<best then do
        best=score;bx=dx;by=dy
      end
    end
  end
  return .array~of(bx,by,best)
::method shortMatches class
  use strict arg one,two,dx=0,dy=0,radius=3
  pairs=.array~new
  do first over one
    x=first['X'];y=first['Y'];best=radius*radius;match=.nil
    do second over two
      ex=second['X']-dx-x;ey=second['Y']-dy-y
      d2=ex*ex+ey*ey
      if d2<best then do
        best=d2;match=second
      end
    end
    if match<>.nil then pairs~append(.array~of(first,match,best))
  end
  return pairs

/* Track source candidates across long-separated stills in a fixed camera.
 * Endpoints propose a linear motion; all intermediate frames must match.
 * No YBC star names or camera calibration are assumed here.
 * Time is seconds on a monotonic observed clock. */
::method trackFive class
  use strict arg positions,times,alignment,maxResidual=2.5,minSpeed=0.006,maxSpeed=0.12
  if positions~items<>5 | times~items<>5 | alignment~items<>5 then -
    raise syntax 88.900 array('five-frame track needs exactly five frames')
  span=times[5]-times[1]
  if span<1 then raise syntax 88.900 array('invalid sky track duration')
  tracks=.array~new
  do first over positions[1]
    a=alignment[1];x0=first['X']-a[1];y0=first['Y']-a[2]
    do last over positions[5]
      b=alignment[5];x5=last['X']-b[1];y5=last['Y']-b[2]
      vx=(x5-x0)/span;vy=(y5-y0)/span
      speed2=vx*vx+vy*vy
      /* Existing webcam footage: plausible apparent stellar motion. */
      if speed2<minSpeed*minSpeed | speed2>maxSpeed*maxSpeed then iterate
      error2=0;ok=.true;matches=.array~new
      matches~append(first)
      do k=2 to 4
        t=times[k]-times[1]
        expectedX=x0+vx*t;expectedY=y0+vy*t
        align=alignment[k]
        best=maxResidual*maxResidual;winner=.nil
        do point over positions[k]
          dx=(point['X']-align[1])-expectedX
          dy=(point['Y']-align[2])-expectedY
          e=dx*dx+dy*dy
          if e<best then do
            best=e;winner=point
          end
        end
        if winner==.nil then do
          ok=.false
          leave
        end
        error2=error2+best;matches~append(winner)
      end
      if \ok then iterate
      matches~append(last)
      track=.directory~new
      track['START_X']=x0;track['START_Y']=y0
      track['END_X']=x5;track['END_Y']=y5
      track['VX']=vx;track['VY']=vy;track['RMS']=self~sqrt(error2/3)
      track['POINTS']=matches
      tracks~append(track)
    end
  end
  return tracks

/* Groups neighbouring peaks into streak-like clusters within one frame.
 * A cluster is only a transient candidate until time comparisons confirm it. */
::method elongatedClusters class
  use strict arg points,radius=9,minMembers=3
  clusters=.array~new
  do p over points
    minx=p['X'];maxx=minx;miny=p['Y'];maxy=miny
    members=.array~new
    do q over points
      if abs(q['X']-p['X'])<=radius & abs(q['Y']-p['Y'])<=radius then do
        members~append(q)
        minx=min(minx,q['X']);maxx=max(maxx,q['X'])
        miny=min(miny,q['Y']);maxy=max(maxy,q['Y'])
      end
    end
    if members~items>=minMembers & (maxx-minx>=3 | maxy-miny>=3) then do
      /* emit each local cluster once at the top-left member */
      if p['X']<>minx | p['Y']<>miny then iterate
      record=.directory~new
      record['LEFT']=minx;record['RIGHT']=maxx
      record['TOP']=miny;record['BOTTOM']=maxy
      record['MEMBERS']=members~items
      clusters~append(record)
    end
  end
  return clusters
::method sqrt class
  use strict arg n
  if n<0 then raise syntax 88.900 array('negative root')
  if n=0 then return 0
  guess=max(n,1)
  do 24
    guess=(guess+n/guess)/2
  end
  return guess