/* Power SLAM Harbour v0.15: fixed-landmark frame stability on REAL MPEG-TS video.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6.
 * Input is raw grayscale bytes generated using FFmpeg as a source adapter.
 * No OpenCV or external image recognition. Source images are not shipped.
 * Patch-template shift is an image registration diagnostic, NOT ferry detection
 * and NOT admission of camera world coordinates.
 */
::class HarbourStreamStability public
::method imagePoint
  use strict arg oldX,oldY
  /* Older screenshot 1536x709 includes 138px black bars on both sides;
   * 1280x720 stream is the active 1260x709 image at full raster.
   * Project to the native 320x180 sampled pixel grid. */
  x=(oldX-138)*320/1260
  y=oldY*180/709
  return .array~of(x~round,y~round)
::method anchors
  use strict arg feed
  a=.array~new
  select
   when feed==1 then do
     p=self~imagePoint(674,324);a~append(.array~of('BRIDGE_S_ROOF',p[1],p[2]))
     p=self~imagePoint(419,273);a~append(.array~of('BRIDGE_CROWN',p[1],p[2]))
     p=self~imagePoint(1007,255);a~append(.array~of('CBD_TOWER',p[1],p[2]))
   end
   when feed==2 then do
     p=self~imagePoint(1175,350);a~append(.array~of('BRIDGE_NE_ROOF',p[1],p[2]))
     p=self~imagePoint(1005,283);a~append(.array~of('BRIDGE_CROWN',p[1],p[2]))
     p=self~imagePoint(280,416);a~append(.array~of('OPERA',p[1],p[2]))
     p=self~imagePoint(651,258);a~append(.array~of('CBD_TOWER',p[1],p[2]))
   end
   when feed==3 then do
     a~append(.array~of('BRIDGE_CROWN',94,41))
     a~append(.array~of('BRIDGE_S_PYLON',27,72))
     a~append(.array~of('BRIDGE_N_PYLON',162,75))
     a~append(.array~of('SHORE_BUILDING',238,73))
   end
   otherwise raise syntax 88.900 array('unknown feed')
  end
  return a
::method patchError
  use strict arg bytes,w,h,frame,x,y,deltaX,deltaY,radius=4,step=2
  if frame<1 then return -1
  if x-radius+deltaX<0 | x+radius+deltaX>=w then return -1
  if x-radius<0 | x+radius>=w then return -1
  if y-radius+deltaY<0 | y+radius+deltaY>=h then return -1
  if y-radius<0 | y+radius>=h then return -1
  diff=0;count=0
  do dy=0-radius to radius by step
    do dx=0-radius to radius by step
      i0=(y+dy)*w+x+dx+1
      i1=(frame-1)*w*h+(y+dy+deltaY)*w+x+dx+deltaX+1
      v0=c2d(substr(bytes,i0,1));v1=c2d(substr(bytes,i1,1))
      diff+=abs(v0-v1);count+=1
    end
  end
  return diff/count
::method patchRange
  use strict arg bytes,w,h,x,y,radius=4,step=2
  low=255;high=0
  do dy=0-radius to radius by step
    do dx=0-radius to radius by step
      idx=(y+dy)*w+x+dx+1
      v=c2d(substr(bytes,idx,1))
      if v<low then low=v
      if v>high then high=v
    end
  end
  return high-low
::method fitPatch
  use strict arg bytes,w,h,frame,x,y,search=3,radius=4
  ans=.directory~new
  ans['STATUS']='REJECTED_LOW_TEXTURE'
  ans['DX']=0;ans['DY']=0;ans['MAD']=1e10
  if frame<2 | frame*w*h>length(bytes) then return ans
  if x-radius-search<0 | x+radius+search>=w | y-radius-search<0 | y+radius+search>=h then return ans
  if self~patchRange(bytes,w,h,x,y,radius)<12 then return ans
  best=1e10;bestX=0;bestY=0
  do dy=0-search to search
    do dx=0-search to search
      err=self~patchError(bytes,w,h,frame,x,y,dx,dy,radius)
      if err>=0 & err<best then do
        best=err;bestX=dx;bestY=dy
      end
    end
  end
  ans['DX']=bestX;ans['DY']=bestY;ans['MAD']=best
  ans['STATUS']='MEASURED_UNQUALIFIED_CAMERA_SITE'
  if best>=35 then ans['STATUS']='REJECTED_PATCH_CHANGED'
  if abs(bestX)==search | abs(bestY)==search then ans['STATUS']='REJECTED_SEARCH_BOUNDARY'
  return ans
::method measure
  use strict arg rawPath,feed,width=320,height=180,frames=4
  expected=width*height*frames
  if expected<1 then raise syntax 88.900 array('invalid raster dimensions')
  if stream(rawPath,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('missing source raw')
  bytes=charin(rawPath,1,expected+1)
  call stream rawPath,'C','CLOSE'
  if length(bytes)\==expected then raise syntax 88.900 array('partial or oversized raw frame input')
  rows=.array~new
  do anchor over self~anchors(feed)
    x=anchor[2];y=anchor[3]
    do frame=2 to frames
      fit=self~fitPatch(bytes,width,height,frame,x,y)
      rows~append(.array~of(feed,anchor[1],frame,fit['DX'],fit['DY'],fit['MAD'],fit['STATUS']))
    end
  end
  return rows
::method admission
  use strict arg rows
  /* Stationary relative frame does not qualify geographical camera position.
   * Return only a temporal image stability status. */
  rejected=0;valid=0
  do row over rows
    if row[7]=='MEASURED_UNQUALIFIED_CAMERA_SITE' then valid+=1
    else rejected+=1
  end
  if rejected>0 then return 'FRAME_STABILITY_INCOMPLETE'
  if valid<3 then return 'FRAME_STABILITY_UNDERSAMPLED'
  return 'FRAME_STABLE_POSE_UNQUALIFIED'