s1=.VisionSurface~new(32,24,5,32)
s2=.VisionSurface~new(32,24,5,32)
s1~timestamp=0
s2~timestamp=1/30
/* high-contrast vertical band moves one pixel right */
do y=2 to 21
  s1~put(10,y,31); s1~put(11,y,31)
  s2~put(11,y,31); s2~put(12,y,31)
end
tracker=.VisionNativeLineTracker~new(.VisionNativeLineTrackerConfig~new(4,2.5,4,10))
a1=.LineAssessment~assess(s1,10,.nil,4)
g1=tracker~geometryFromAssessment(a1,s1~timestamp)
a2=.LineAssessment~assess(s2,10,.nil,4)
g2=tracker~geometryFromAssessment(a2,s2~timestamp)
if g1~lines~items=0 | g2~lines~items=0 then do; say 'FAIL no tracked lines'; exit 1; end
shared=0
do id over g2~lines
  if g1~lines~hasIndex(id) then shared=shared+1
end
if shared=0 then do; say 'FAIL no stable line identities'; exit 1; end
say 'PASS native line tracking shared=' shared
::requires 'Vision3DNativeMotion.cls'
::requires 'Vision.cls'
