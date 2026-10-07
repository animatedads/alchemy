#!/usr/bin/env rexx
numeric digits 50
rect=.VisionSamplingLattice~new("RECT",1,0,0,1)
hex=.VisionSamplingLattice~new("HEX",1,0,.5,.86602540378443864676)
call assert rect~neighbourOffsets~items=4,"RECT exposes four edge neighbours"
call assert hex~neighbourOffsets~items=6,"HEX exposes six equidistant logical neighbours"
call assert rect~forwardNeighbourOffsets~items=2,"RECT scans each undirected edge once"
call assert hex~forwardNeighbourOffsets~items=3,"HEX scans each undirected edge once"
model=.VisionValueModel~new(2)
s=.VisionSurface~new(3,3,1,2,model)
s~put(1,1,1)
r=.VisionBoundaryExtractor~new~extract(s,1,rect)
h=.VisionBoundaryExtractor~new~extract(s,1,hex)
call assert r~items=4,"isolated RECT centre has four boundary relationships"
call assert h~items=6,"isolated HEX centre has six boundary relationships"
say "PASS vision/0.1 lattice-aware boundary topology"
exit 0
assert: procedure
 use arg c,m
 if \c then do; say "FAIL:" m; exit 1; end
 return
::requires "../src/Vision.cls"
