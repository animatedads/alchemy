numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
surface=.MathVector3~new(0,0,0,ctx)
gravity=.MathVector3~new(0,'-9.80665',0,ctx)
field=.HydrostaticFluidField~new(water,surface,.Units~q(101325,.Units~pascal),gravity)
point=.MathVector3~new(0,-2,0,ctx)
expected='120902.99606'
call near field~pressureAt(point),expected,'pressure 2 m below reference','0.000001'
state=field~stateAt(point)
call near state~pressureQuantity~in(.Units~kilopascal),'120.90299606','typed pressure','0.0000001'
call near state~velocity~norm,0,'hydrostatic velocity'
call near water~kinematicViscosityQuantity~in(.FluidUnitBoundary~kinematicViscosityUnit), -
  water~dynamicViscosity/water~density,'kinematic viscosity','0.000000000001'
say 'PHYSICS FLUID HYDROSTATICS: OK pressure='state~pressure
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
