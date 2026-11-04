/* Diagnostic regridding of unregistered cyan-class segmentation screenshot.
 * Input is 80x45 RGB24 decoded with FFmpeg area filter from submitted PNG.
 * Output is a binary class mask IN ITS OWN screenshot frame, not a V5V
 * camera motion mask and not a surveyed map or shoreline polygon.
 */
numeric digits 18
parse arg rgbFile outFile sourceSha
if rgbFile=='' | outFile=='' | sourceSha=='' then do
 say 'Usage: mask_screenshot80.rex 80x45.rgb mask.psv SHA256'
 exit 2
end
if length(sourceSha)<>64 | verify(sourceSha,'0123456789abcdef')<>0 then call bad 'source SHA invalid'
if rgbFile==outFile then call bad 'input/output collision'
if stream(rgbFile,'c','query exists')=='' then call bad 'RGB24 source missing'
call stream rgbFile,'c','open read'
data=charin(rgbFile,1,10801)
call stream rgbFile,'c','close'
if length(data)<>10800 then call bad 'wrong 80x45 RGB24 byte count'
rows=.array~new
count=0
minX=80;minY=45;maxX=-1;maxY=-1
 do y=0 to 44
  bits=''
  do x=0 to 79
   off=(y*80+x)*3+1
   r=c2d(substr(data,off,1));g=c2d(substr(data,off+1,1));b=c2d(substr(data,off+2,1))
   /* Reproduces the cyan class of the input illustration only. */
   selected = (g>160 & g>r+25 & b>g+5 & r<215)
   if selected then do
    bits=bits||'1';count=count+1
    minX=min(x,minX);minY=min(y,minY)
    maxX=max(x,maxX);maxY=max(y,maxY)
   end
   else bits=bits||'0'
  end
  rows~append(y||'|'||bits||'|sha256:'||sourceSha||'|SCREEN_RASTER_UNREGISTERED|CLASS_SEMANTICS_UNVERIFIED')
 end
call stream outFile,'c','open write replace'
call lineout outFile,'row|cyan_class_bits|source_ref|coordinate_system|evidence_state'
do row over rows
 call lineout outFile,row
end
call stream outFile,'c','close'
say 'CROSS_SAMMY_SCREEN_MASK_PASS cells='count '/3600' 'extent='minX','minY,'through' maxX','maxY
say 'CAMERA_MASK_ADMISSION=BLOCKED_NO_REGISTRATION'
exit 0
bad: procedure
 use arg msg
 say 'CROSS_SAMMY_SCREEN_MASK_REJECT:'msg
 exit 3
