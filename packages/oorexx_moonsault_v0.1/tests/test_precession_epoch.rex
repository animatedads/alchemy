/* J2000 remains unchanged at epoch; 2026 coordinates precess. */
numeric digits 17
p=.MoonsaultSkyPlate
star=.directory~new;star['RA']=0;star['DEC']=0
one=p~precessJ2000(star,2451545)
if abs(one[1])>0.00000001 | abs(one[2])>0.00000001 then do
 say 'FAIL J2000 identity' one[1] one[2];exit 1
end
jd=2440587.5+p~utcToUnix('2026-11-09T09:17:25Z')/86400
two=p~precessJ2000(star,jd)
say 'J2000_PRECESSION_2026' 'RA='two[1] 'Dec='two[2]
if two[1]<0.32 | two[1]>0.36 | two[2]<0.13 | two[2]>0.17 then do
 say 'FAIL precession 2026 sanity';exit 2
end
three=p~precessJ2000(star,jd)
if two[1]<>three[1] | two[2]<>three[2] then exit 3
say 'PASS: J2000 identity, 2026 IAU1976 precession, day cache'
::requires '../src/MoonsaultSkyPlate.cls'