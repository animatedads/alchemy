q=.PhysicsQuantity~new(2,.SI~centimetre)
if \q~isA(.UnitQuantity) then do; say 'FAIL PhysicsQuantity is not backed by Units UnitQuantity'; exit 1; end
if q~sourceUnit~symbol<>'cm' then do; say 'FAIL source-unit identity not retained' q~sourceUnit~symbol; exit 1; end
room=.UnitQuantity~new(21,.Units~celsius,.Units~fahrenheit)
if abs(room~in(.Units~fahrenheit)-'69.8')>'0.000001' then do; say 'FAIL shared Units affine conversion'; exit 1; end
if .SI~newton~dimension~canonical<>.Units~newton~dimension~canonical then do; say 'FAIL SI facade diverges from Units authority'; exit 1; end
say 'PHYSICS SHARED UNITS AUTHORITY: OK'
::requires 'PhysicsWorld.cls'
