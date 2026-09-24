d=.CommonParts~laserDiodeRed
if d~family<>'LASER_DIODE' then call fail 'diode family'
roles=.array~of('SEMICONDUCTOR','LEADS','WINDOW')
do role over roles
 if .CommonMaterials~byId(d~material(role))=.nil then call fail 'diode material' role
end
c=.CommonParts~laserCollimator
if c~parameter('FOCAL_LENGTH')<>'8 mm' then call fail 'collimator focal length'
m=.CommonParts~laserModuleRed
if m~family<>'LASER_MODULE' then call fail 'module family'
a=.CommonAssemblies~redLaserModule
if a~members~items<>3 then call fail 'assembly members'
if a~connections~items<>1 then call fail 'assembly optical-axis connection'
if .CommonParts~rugbyLeagueBall~family<>'SPORTS_BALL' then call fail 'rugby regression'
say 'PASS laser component/material/assembly model'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'PartAssemblies.cls'
