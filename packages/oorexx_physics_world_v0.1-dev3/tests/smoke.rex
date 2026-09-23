q=.PhysicsQuantity~new(2,.SI~centimetre)
say q~in(.SI~metre)
world=.PhysicalWorld~new(.OpticalMedium~water)
say world~ambient~name
p=.TriangularPrismShape~new(0.03,0.03,0.05)
say p~class~id
say .Photometry~isotropicRectangleFlux(20,0.01,0.01,0.02)
::requires 'PhysicsWorld.cls'
