numeric digits 30
water=.FluidMedium~water20C
breach=.RectangularBoundaryBreach2D~new('source','RIGHT',0,0,.1,.1,.6)
parcel=.EscapedFluidParcel~new(water,.001,.MathVector3~new(0,1,0),.MathVector3~new(1,0,0),0,breach)
world=.ExternalFluidParcelWorld~new
st=world~admit(parcel)
world~step(.1)
if abs(st~position~x-0.1)>.0000001 then do; say 'FAIL parcel horizontal motion'; exit 1; end
if st~position~y>=1 then do; say 'FAIL parcel did not fall'; exit 1; end
if abs(world~totalMass-water~density*.001)>.0000001 then do; say 'FAIL parcel mass changed'; exit 1; end
say 'PHYSICS ESCAPED FLUID BALLISTIC: OK'
exit 0
::requires 'ExternalFluidParcels.cls'
