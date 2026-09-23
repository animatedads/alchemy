/* Compact synthetic Vision surface: value 1 is wall, value 4 is floor.
 * The floor penetrates upward in the middle like an open doorway. */
model=.VisionValueModel~new(5)
s=.VisionSurface~new(12,10,3,5,model)
do y=0 to 9; do x=0 to 11; s~put(x,y,1); end; end
do y=6 to 9
  do x=0 to 11; s~put(x,y,4); end
end
do y=2 to 5
  do x=5 to 7; s~put(x,y,4); end
end
f=.VisionSupportFrontierExtractor~new~extract(s,'cop-C',13,'f390',0,2,4,'synthetic')
if f~points~items<>12 then do; say 'FAIL coverage' f~points~items; exit 1; end
/* centre column must reach farther than edge columns */
if f~points[6][2]>=f~points[1][2] then do; say 'FAIL penetration'; exit 1; end
say 'PASS support frontier'
::requires 'Vision3DStructure.cls'
