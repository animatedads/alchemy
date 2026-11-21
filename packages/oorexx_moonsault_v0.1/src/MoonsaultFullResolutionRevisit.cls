/* Moonsault-only second-pass inspector. A processing-resolution positive
 * difference mask proposes locations; native full-resolution luma verifies
 * local shape. No image-file decoding, catalogue identity, or calibration.
 * A point-like transient is NOT a star (insects and aircraft can pass).
 */
::options digits 30
::class MoonsaultFullResolutionRevisit public
::method examine class
  use strict arg fullImage,mask,maskWidth,maskHeight, -
      left,top,right,bottom,maxComponents=512,maxCoarseArea=20,minContrast=12
  if fullImage~width<16 | fullImage~height<16 | -
     maskWidth<8 | maskHeight<8 | maskWidth*maskHeight>2000000 | -
     mask~length<>maskWidth*maskHeight then -
    raise syntax 88.900 array('invalid full-resolution revisit dimensions')
  if left<1 | top<1 | right>=maskWidth-1 | bottom>=maskHeight-1 | -
     right<left | bottom<top | maxComponents<1 | maxComponents>4096 then -
    raise syntax 88.900 array('invalid full-resolution revisit sky region')
  source=.MediaRasterOps~asImage(fullImage)~luma
  width=fullImage~width;height=fullImage~height
  visited=.array~new(maskWidth*maskHeight)
  clusters=.array~new
  do y=top to bottom
    do x=left to right
      at=y*maskWidth+x+1
      if c2d(substr(mask,at,1))=0 | visited[at]<>.nil then iterate
      qx=.array~new;qy=.array~new
      qx~append(x);qy~append(y);visited[at]=1
      cursor=1;area=0;sx=0;sy=0
      do while cursor<=qx~items
        px=qx[cursor];py=qy[cursor];cursor+=1
        area+=1;sx+=px;sy+=py
        do ny=max(top,py-1) to min(bottom,py+1)
          do nx=max(left,px-1) to min(right,px+1)
            if nx=px & ny=py then iterate
            p=ny*maskWidth+nx+1
            if visited[p]<>.nil | c2d(substr(mask,p,1))=0 then iterate
            visited[p]=1
            qx~append(nx);qy~append(ny)
          end
        end
      end
      if clusters~items>=maxComponents then -
        raise syntax 88.900 array('sky candidate clusters exceed bounded maximum')
      candidate=.directory~new
      candidate['COARSE_AREA']=area
      candidate['PEAK']=-1
      candidate['LOCAL_BACKGROUND']=-1
      candidate['CONTRAST']=-1
      candidate['HALF_MAX_AREA']=0
      candidate['HALF_MAX_WIDTH']=0
      candidate['HALF_MAX_HEIGHT']=0
      candidate['COARSE_X']=sx/area;candidate['COARSE_Y']=sy/area
      x0=trunc(((sx/area)+0.5)*width/maskWidth)
      y0=trunc(((sy/area)+0.5)*height/maskHeight)
      candidate['FRAME_X']=x0;candidate['FRAME_Y']=y0
      if x0<7 | y0<7 | x0>=width-7 | y0>=height-7 then do
        candidate['STATUS']='EDGE_INVALID'
        clusters~append(candidate)
        iterate
      end
      if area>maxCoarseArea then do
        candidate['STATUS']='DIFFUSE_COARSE'
        clusters~append(candidate)
        iterate
      end
      /* Extract local 13x13 luma; border gives a local rather than global
       * sky baseline. Never use an interpolated 315x150 pixel as evidence. */
      boundary=0;nBoundary=0
      peak=-1;peakX=x0;peakY=y0
      do dy=-6 to 6
        do dx=-6 to 6
          value=c2d(substr(source,(y0+dy)*width+x0+dx+1,1))
          if abs(dx)>=4 | abs(dy)>=4 then do
            boundary+=value;nBoundary+=1
          end
          if abs(dx)<=3 & abs(dy)<=3 & value>peak then do
            peak=value;peakX=x0+dx;peakY=y0+dy
          end
        end
      end
      baseline=boundary/nBoundary
      contrast=peak-baseline
      candidate['PEAK']=peak
      candidate['LOCAL_BACKGROUND']=baseline
      candidate['CONTRAST']=contrast
      candidate['PEAK_X']=peakX;candidate['PEAK_Y']=peakY
      above=0;minX=999999;maxX=-1;minY=999999;maxY=-1
      do dy=-6 to 6
        do dx=-6 to 6
          value=c2d(substr(source,(y0+dy)*width+x0+dx+1,1))
          if contrast>0 & value>=baseline+contrast/2 then do
            above+=1
            minX=min(minX,x0+dx);maxX=max(maxX,x0+dx)
            minY=min(minY,y0+dy);maxY=max(maxY,y0+dy)
          end
        end
      end
      candidate['HALF_MAX_AREA']=above
      candidate['HALF_MAX_WIDTH']=maxX-minX+1
      candidate['HALF_MAX_HEIGHT']=maxY-minY+1
      candidate['STATUS']='DIFFUSE_OR_LOW_CONTRAST'
      if contrast>=minContrast & above>=1 & above<=24 & -
         maxX-minX+1<=7 & maxY-minY+1<=7 then -
         candidate['STATUS']='POINT_LIKE_UNIDENTIFIED'
      clusters~append(candidate)
    end
  end
  return clusters
/* Brightness/shape is NOT motion evidence. At the same registered
 * camera geometry, a genuine slow celestial point should have a compact
 * source near the same location on a seconds-long independent exposure. */
::method localPointEvidence class
  use strict arg frame,x0,y0,radius=6
  image=.MediaRasterOps~asImage(frame)
  w=image~width;h=image~height
  if radius<4 | radius>12 | x0<radius | y0<radius | -
     x0>=w-radius | y0>=h-radius then -
    raise syntax 88.900 array('short-baseline point window invalid')
  luma=image~luma
  ring=0;ringCount=0;peak=-1;peakX=x0;peakY=y0
  do dy=-radius to radius
    do dx=-radius to radius
      value=c2d(substr(luma,(y0+dy)*w+x0+dx+1,1))
      if abs(dx)>=radius-2 | abs(dy)>=radius-2 then do
        ring+=value;ringCount+=1
      end
      if value>peak then do
        peak=value;peakX=x0+dx;peakY=y0+dy
      end
    end
  end
  q=.directory~new
  q['X']=peakX;q['Y']=peakY
  q['PEAK']=peak
  q['BACKGROUND']=ring/ringCount
  q['CONTRAST']=peak-ring/ringCount
  return q
::method corroborateShortInterval class
  use strict arg beforeFrame,afterFrame,x,y,minContrast=12,maxDisplacement=2
  a=self~localPointEvidence(beforeFrame,x,y)
  b=self~localPointEvidence(afterFrame,x,y)
  dx=b['X']-a['X'];dy=b['Y']-a['Y']
  q=.directory~new
  q['BEFORE_CONTRAST']=a['CONTRAST']
  q['AFTER_CONTRAST']=b['CONTRAST']
  q['DISPLACEMENT_SQUARED']=dx*dx+dy*dy
  q['STATUS']='TRANSIENT_REJECTED'
  if a['CONTRAST']>=minContrast & b['CONTRAST']>=minContrast & -
     q['DISPLACEMENT_SQUARED']<=maxDisplacement*maxDisplacement then -
    q['STATUS']='PERSISTENT_POINT_UNIDENTIFIED'
  return q

::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaRasterOps.cls'