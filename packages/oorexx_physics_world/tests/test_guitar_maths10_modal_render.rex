numeric digits 30
ctx=.MathContext~decimal(30,'PURE')
string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,6)
renderer=.GuitarMathsModalRenderer~new(string,ctx)
sr=48000;n=64
v=renderer~renderDisplacement(0,.82,sr,n,0,.18,.0008,'PICK',0)
if v~size<>n then exit 1
do i=1 to n
 t=(i-1)/sr
 expected=string~displacement(0,t,.82,.18,.0008,'PICK',0)
 if abs(v[i]-expected)>1E-7 then do
   say 'FAIL modal render sample' i v[i] expected
   exit 1
 end
end
/* Chunk addressing must preserve physical simulation time. */
a=renderer~renderDisplacement(0,.82,sr,32,0)
b=renderer~renderDisplacement(0,.82,sr,32,32)
do i=1 to 32
 if abs(a[i]-v[i])>1E-7 | abs(b[i]-v[i+32])>1E-7 then exit 1
end
say 'PHYSICS GUITAR MATHS10 MODAL RENDER: OK provider=' v~evidence~primaryProvider
::requires 'GuitarMathsAcceleration.cls'
