numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
surface=.MathVector3~new(0,0,0,ctx)
field=.HydrostaticFluidField~new(water,surface,.Units~q(101325,.Units~pascal))
probe=.FluidProbe~new('two-metres-down',field,.PhysicalPose~new(.MathVector3~new(0,-2,0,ctx),.nil,ctx))
reading=probe~sample
say 'medium:' reading~medium~name
say 'pressure:' reading~pressureQuantity~in(.Units~kilopascal) 'kPa'
exit 0
::requires 'Fluids.cls'
