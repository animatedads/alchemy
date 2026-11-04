/* Pure ooRexx temporal gate and bounded spatial forecast.
   This qualifies *motion search*, not vessel identity. V5V controls source data.
   All thresholds explicit; timestamp units seconds; 80x45 native lattice. */
::class V5VTripwireFollow public
::method threshold class
  use strict arg first,last,maxGap=0.45,minSpeed=1.5,maxSpeed=22,minTranslation=0.65
  state=.directory~new
  state['admit']=0;state['reason']='INVALID'
  if first==.nil | last==.nil then return state
  dt=last[2]-first[2]
  if dt<=0 then do;state['reason']='NONCAUSAL_TIME';return state;end
  if dt>maxGap then do;state['reason']='TIME_GAP';return state;end
  dx=last[3]-first[3];dy=last[4]-first[4]
  distance=self~sqrt(dx*dx+dy*dy)
  if distance<minTranslation then do;state['reason']='NO_TRANSLATION';return state;end
  speed=distance/dt
  if speed<minSpeed then do;state['reason']='BELOW_SPEED';return state;end
  if speed>maxSpeed then do;state['reason']='SPEED_LIMIT';return state;end
  state['admit']=1;state['reason']='THRESHOLDS_PASS';return state
::method predict class
  use strict arg first,last,targetTime,nRange=2,maxGap=0.45,maxArea=289
  projection=.directory~new
  projection['admit']=0;projection['reason']='BLOCKED';projection['left']=0;projection['top']=0;projection['right']=0;projection['bottom']=0;projection['area']=0
  dt=last[2]-first[2];future=targetTime-last[2]
  if dt<=0 | future<0 then do;projection['reason']='NONCAUSAL_TIME';return projection;end
  if future>maxGap then do;projection['reason']='TIME_GAP';return projection;end
  vx=(last[3]-first[3])/dt;vy=(last[4]-first[4])/dt
  px=last[3]+vx*future;py=last[4]+vy*future
  if px<0 | px>=80 | py<0 | py>=45 then do;projection['reason']='OUTSIDE_FRAME';return projection;end
  radius=nRange+0.4*(last[5]+last[6])/2+0.15*(abs(vx)+abs(vy))*future
  if radius>7 then do;projection['reason']='UNCERTAINTY_LIMIT';return projection;end
  left=max(0,trunc(px-radius));right=min(79,trunc(px+radius+0.9999))
  top=max(0,trunc(py-radius));bottom=min(44,trunc(py+radius+0.9999))
  area=(right-left+1)*(bottom-top+1)
  if area>maxArea then do;projection['reason']='AREA_LIMIT';return projection;end
  projection['admit']=1;projection['reason']='SEARCH_REQUESTED';projection['left']=left;projection['top']=top;projection['right']=right;projection['bottom']=bottom;projection['area']=area
  return projection
::method sqrt class private
  use strict arg number
  if number=0 then return 0
  previous=max(1,number)
  do forever
    next=(previous+number/previous)/2
    if next=previous then leave
    previous=next
  end
  return next
