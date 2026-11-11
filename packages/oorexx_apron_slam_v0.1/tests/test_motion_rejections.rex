/* Negative contract tests — no source media, synthetic tokens only. */
numeric digits 30
passed=0
call bad '.ApronTransientObservation~new("S","T",-1,10,10,100,100)', 'negative pts'
call bad '.ApronTransientObservation~new("S","T",1.3,10,10,100,100)', 'fractional pts'
call bad '.ApronTransientObservation~new("S","T",1,110,10,100,100)', 'centroid bounds'
call bad '.ApronTransientObservation~new("S","T",1,10,10,100,100,0)', 'quality zero'
call bad '.ApronTransientTrack~new("S","T",120000,2)', 'limit too small'
call bad 'trk~fit', 'empty fit'
call bad 'trk~observe(.ApronTransientObservation~new("OTHER","T",1,10,10,100,100))', 'different source'
call bad 'trk~observe(.ApronTransientObservation~new("S","OTHER",1,10,10,100,100))', 'different track'
call bad 'trk~observe(.ApronTransientObservation~new("S","T",1,10,10,100,100))', 'repeated PTS'
call bad 'trk~observe(.ApronTransientObservation~new("S","T",0,10,10,100,100))', 'backwards PTS'
call bad 'trk~observe(.ApronTransientObservation~new("S","T",150001,10,10,100,100))', 'large gap'
call bad 'trk~observe(.ApronTransientObservation~new("S","T",40000,10,10,200,100))', 'resolution change'
call bad 'motion~displacement(0)', 'zero exposure'
call bad 'motion~displacement(1000001)', 'excessive exposure'
call bad 'trk~close~~observe(.ApronTransientObservation~new("S","T",2,10,10,100,100))', 'closed track'
say 'PASS' passed 'Apron SLAM rejection checks'
exit 0
bad: procedure expose passed
 use strict arg code,label
 trk=.ApronTransientTrack~new('S','T')
 trk~observe(.ApronTransientObservation~new('S','T',1,10,10,100,100))
 motion=.ApronImageMotion~new(10,0,3,80000)
 signal on syntax name rejected
 interpret code
 signal off syntax
 say 'FAIL should reject' label
 exit 1
 rejected:
 signal off syntax
 passed=passed+1
 return
::requires '../src/ApronTransientMotion.cls'