/* Synthetic frontier with a local upward penetration through an opening. */
pts=.array~new
do x=0 to 19
  y=20
  if x>=8 & x<=12 then y=12
  pts~append(.array~of(x,y))
end
f=.VisionSupportFrontier~new('cop-C',13,'f390',20,30,pts,1,3,'ev')
o=.VisionSupportOpeningDetector~new~detect(f,3,4)
if o~items<1 then do; say 'FAIL no opening'; exit 1; end
if o[1]~width<4 then do; say 'FAIL width'; exit 1; end
say 'PASS opening detector'
::requires 'Vision3DStructure.cls'
