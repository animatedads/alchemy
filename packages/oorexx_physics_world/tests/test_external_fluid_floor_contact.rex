numeric digits 30
water=.FluidMedium~water20C
breach=.RectangularBoundaryBreach2D~new('source','RIGHT',0,0,.1,.1,.6)
parcel=.EscapedFluidParcel~new(water,.001,.MathVector3~new(0,.02,0),.MathVector3~new(0,-1,0),0,breach)
world=.ExternalFluidParcelWorld~new(.MathVector3~new(0,0,0))
world~addPlane(.ExternalFluidPlane~new(.MathVector3~new(0,0,0),.MathVector3~new(0,1,0),0,'floor'))
st=world~admit(parcel)
world~step(.05)
if world~contactEvents~items<>1 then do; say 'FAIL expected parcel-floor contact'; exit 1; end
if abs(st~velocity~y)>.0000001 then do; say 'FAIL zero restitution parcel retained normal velocity'; exit 1; end
if st~position~y<-.0000001 then do; say 'FAIL parcel crossed floor'; exit 1; end
say 'PHYSICS ESCAPED FLUID FLOOR CONTACT: OK'
exit 0
::requires 'ExternalFluidParcels.cls'
