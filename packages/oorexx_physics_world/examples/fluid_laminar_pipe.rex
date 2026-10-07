numeric digits 30
water=.FluidMedium~water20C
flow=.LaminarCircularPipeFlow~new( -
  water, -
  .Units~q(5,.Units~millimetre), -
  .Units~q(1,.Units~metre), -
  .Units~q(10,.Units~pascal))
flow~requireLaminar
say 'Q:' flow~volumeFlowRateQuantity~in(.FluidUnitBoundary~volumetricFlowUnit) 'm3/s'
say 'mean velocity:' flow~meanVelocityQuantity~in(.Units~metrePerSecond) 'm/s'
say 'Re:' flow~reynoldsNumber
say 'wall shear:' flow~wallShearStressQuantity~in(.Units~pascal) 'Pa'
exit 0
::requires 'Fluids.cls'
