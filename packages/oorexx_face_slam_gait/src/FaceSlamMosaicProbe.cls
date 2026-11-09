/* Face SLAM dev3: provider-neutral RGB24 mosaic evidence probe.
 * Media Object Access supplies native decoded RGB24; Vision/Motion Control
 * supply a validated ROI. This measures block regularity, NOT reconstructs
 * pixels, identifies a person, or declares an engine failure.
 * An empty, occluded, tiny or invalid ROI must be rejected upstream.
 */
::options digits 30

::class FaceSlamMosaicSignature public
::attribute flatFraction get
::attribute gridLift get
::attribute xGridSize get
::attribute yGridSize get
::attribute xPhase get
::attribute yPhase get
::attribute sourceKind get
::method init
 expose flatFraction gridLift xGridSize yGridSize xPhase yPhase sourceKind
 use strict arg flatFraction,gridLift,xGridSize,yGridSize,xPhase,yPhase
 sourceKind='RGB24_ROI_BLOCK_REGULARITY'
::method assessment
 expose gridLift flatFraction
 if gridLift>4 & flatFraction>.52 then return 'MOSAIC_CANDIDATE'
 if gridLift<2 then return 'NO_PERIODIC_MOSAIC_EVIDENCE'
 return 'INDETERMINATE'

::class FaceSlamMosaicProbe public
::method inspectRgb24
 use strict arg pixels,frameWidth,frameHeight,roiX,roiY,roiWidth,roiHeight
 numeric digits 30
 if \datatype(frameWidth,'W') | \datatype(frameHeight,'W') | -
   frameWidth<16 | frameHeight<16 | -
   pixels~length<>frameWidth*frameHeight*3 then -
    raise syntax 88.900 array('invalid RGB24 frame')
 if \datatype(roiX,'W') | \datatype(roiY,'W') | -
   \datatype(roiWidth,'W') | \datatype(roiHeight,'W') | -
   roiX<0 | roiY<0 | roiWidth<32 | roiHeight<32 | -
   roiX+roiWidth>frameWidth | roiY+roiHeight>frameHeight then -
    raise syntax 88.900 array('ROI outside image or insufficient pixels')
 /* Two 1-D energy profiles count distributed gradients vs periodic grid lines.
    The probe does not read or mutate any media outside the supplied ROI. */
 horizontal=.array~new;vertical=.array~new
 do x=1 to roiWidth-1;horizontal[x]=0;end
 do y=1 to roiHeight-1;vertical[y]=0;end
 prevRow=.array~new
 flat=0;connections=0
 do y=1 to roiHeight
  row=.array~new
  do x=1 to roiWidth
   byteIndex=((roiY+y-1)*frameWidth+(roiX+x-1))*3+1
   r=c2d(substr(pixels,byteIndex,1));g=c2d(substr(pixels,byteIndex+1,1));b=c2d(substr(pixels,byteIndex+2,1))
   row[x]=trunc((77*r+150*g+29*b)/256)
   if x>1 then do
    e=abs(row[x]-row[x-1]); horizontal[x-1]=horizontal[x-1]+e
    if e<=2 then flat=flat+1
    connections=connections+1
   end
   if y>1 then do
    e=abs(row[x]-prevRow[x]);vertical[y-1]=vertical[y-1]+e
    if e<=2 then flat=flat+1
    connections=connections+1
   end
  end
  prevRow=row
 end
 hx=self~dominantLineSpacing(horizontal,roiHeight)
 hy=self~dominantLineSpacing(vertical,roiWidth)
 lift=hx[1]*hy[1]
 return .FaceSlamMosaicSignature~new(flat/connections,lift,hx[2],hy[2],hx[3],hy[3])
::method dominantLineSpacing
 use strict arg profile,countAcross
 n=profile~items
 total=0
 do v over profile;total=total+v;end
 best=.array~of(1,0,0)
 if total<1 then return best
 maxSpacing=24
 if n<maxSpacing*2 then maxSpacing=trunc(n/2)
 do spacing=7 to maxSpacing
  do phase=0 to spacing-1
   boundary=0;boundaryPositions=0
   do x=1 to n
    if (x//spacing)=phase then do
     boundary=boundary+profile[x]
     boundaryPositions=boundaryPositions+1
    end
   end
   if boundaryPositions=0 | boundaryPositions>=n then iterate
   inAverage=(boundary/(boundaryPositions*countAcross))
   outAverage=((total-boundary)/((n-boundaryPositions)*countAcross))
   ratio=(inAverage+1)/(outAverage+1)
   if ratio>best[1] then best=.array~of(ratio,spacing,phase)
  end
 end
 return best