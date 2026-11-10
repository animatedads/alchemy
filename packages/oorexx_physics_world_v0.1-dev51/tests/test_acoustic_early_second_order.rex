numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
f=1000
surfaceMaterial=.AcousticSpectralMaterial~new('test-reflector')
surfaceMaterial~addBand(.AcousticBandTransfer~new(f,0.8,1.0,0))
panel=.AcousticVerticalPanel~new(.MathVector3~new(-5,3,0,ctx),.MathVector3~new(5,3,0,ctx),-1,3)
solver~addSurface(.AcousticSpectralSurface~new('ceiling-side-test',panel,surfaceMaterial))
edgeMaterial=.AcousticSpectralMaterial~new('edge')
edgeMaterial~addBand(.AcousticBandTransfer~new(f,0,1,0.5))
solver~addDiffractionPoint(.AcousticDiffractionPoint~new('corner-1',.MathVector3~new(2,0,1,ctx),edgeMaterial))
solver~addDiffractionPoint(.AcousticDiffractionPoint~new('corner-2',.MathVector3~new(4,0,1,ctx),edgeMaterial))
e=.AcousticEmissionSpectrum~new;e~addBand(.AcousticEmissionBand~new(f,0.001))
receivers=.directory~new;receivers['MIC']=.MathVector3~new(6,0,1,ctx)
r=solver~solveEarly(.MathVector3~new(0,0,1,ctx),e,receivers,0.150,2)
dd=0;rd=0;dr=0
do a over r~receiver('MIC')~arrivals
  select
    when a~kind='DIFFRACTION_DIFFRACTION' then do
      dd=dd+1
      if a~vertices~items<4 | a~interactionCount<>2 then exit 1
    end
    when a~kind='REFLECTION_DIFFRACTION' then rd=rd+1
    when a~kind='DIFFRACTION_REFLECTION' then dr=dr+1
    otherwise nop
  end
end
if dd<1 | rd<1 | dr<1 then do
  say 'FAIL second-order families dd='dd 'rd='rd 'dr='dr
  exit 1
end
if r~receiver('MIC')~arrivalsByKind('DIFFRACTION_DIFFRACTION')~items<>dd then exit 1
first=r~receiver('MIC')~firstArrival
if first==.nil then exit 1
say 'PHYSICS ACOUSTIC SECOND-ORDER EARLY PATHS: OK dd='dd 'rd='rd 'dr='dr 'arrivals='r~receiver('MIC')~arrivals~items
::requires 'AcousticImpulseResponse.cls'
