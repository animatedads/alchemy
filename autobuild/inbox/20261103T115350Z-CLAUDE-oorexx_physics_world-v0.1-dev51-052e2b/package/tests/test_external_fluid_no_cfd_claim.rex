water=.FluidMedium~water20C
breach=.RectangularBoundaryBreach2D~new('source','RIGHT',0,0,.1,.1,.6)
parcel=.EscapedFluidParcel~new(water,.001,.MathVector3~new(0,1,0),.MathVector3~new(0,0,0),0,breach)
world=.ExternalFluidParcelWorld~new
st=world~admit(parcel)
if st~parcel<>parcel then do; say 'FAIL parcel provenance lost'; exit 1; end
if world~states~items<>1 then do; say 'FAIL external parcel state'; exit 1; end
say 'PHYSICS EXTERNAL FLUID PARCEL BOUNDARY: OK'
exit 0
::requires 'ExternalFluidParcels.cls'
