/* dev5 UK domestic prior catalogue */

c=.VisionUKDomesticPriorCatalog~new
say assertNear(c~byId('UK.WALL_SOCKET.DOUBLE')~dimension('WIDTH')~nominal,0.15,1E-12,'socket width')
say assertNear(c~byId('UK.LIGHT_SWITCH.SQUARE')~dimension('WIDTH')~nominal,0.10,1E-12,'switch width')
say assertNear(c~byId('UK.INTERNAL_DOOR.MODERN')~dimension('WIDTH')~minimum,0.76,1E-12,'door width min')
say assertNear(c~byId('UK.INTERNAL_DOOR.MODERN')~dimension('HEIGHT')~minimum,1.97,1E-12,'door height min')
say assertNear(c~byId('UK.INTERNAL_DOOR.MODERN')~dimension('THICKNESS')~minimum,0.04,1E-12,'door thickness min')
say assertNear(c~byId('UK.INTERNAL_DOOR.MODERN')~dimension('THICKNESS')~maximum,0.05,1E-12,'door thickness max')
say assertNear(c~byId('UK.HALL.ORDINARY')~dimension('WIDTH')~minimum,0.80,1E-12,'hall width min')
say assertNear(c~byId('LIGHT.BARE_BULB.TYPICAL')~dimension('DIAMETER')~nominal,0.07,1E-12,'bulb diameter')
say assertNear(c~byId('UK.RADIATOR.ORDINARY')~dimension('WALL_STANDOFF')~minimum,0.025,1E-12,'radiator stand-off')
say assertNear(c~byId('UK.RADIATOR.ORDINARY')~dimension('DEPTH')~maximum,0.12,1E-12,'radiator depth max')
say 'PASS semantic prior catalog'
exit 0

::routine assertNear
use arg actual,expected,tolerance,label
if abs(actual-expected)>tolerance then do
  say 'FAIL' label actual expected
  exit 1
end
return 'PASS' label
::requires 'Vision3DSemanticPriors.cls'
