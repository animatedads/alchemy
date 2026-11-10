numeric digits 30
m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
a=.RectangularTankSlosh2D~new(m,tank,24.5,0)
a~seedStandingMode(0.02,0.01)
a~step(a~maxStableTimeStep(9.80665)*0.5,0.4,-0.2,9.80665)
state=a~exportContinuationState
b=.RectangularTankSlosh2D~new(m,tank,24.5,0)
b~restoreContinuationState(state)
if a~time<>b~time then exit 1
do j=1 to tank~zCells
 do i=1 to tank~xCells
  if a~depthAtCell(i,j)<>b~depthAtCell(i,j) then exit 1
  if a~dischargeXAtCell(i,j)<>b~dischargeXAtCell(i,j) then exit 1
  if a~dischargeZAtCell(i,j)<>b~dischargeZAtCell(i,j) then exit 1
 end
end
dt=a~maxStableTimeStep(9.80665)*0.4
a~step(dt,0.1,0.05,9.80665); b~step(dt,0.1,0.05,9.80665)
do j=1 to tank~zCells
 do i=1 to tank~xCells
  if a~depthAtCell(i,j)<>b~depthAtCell(i,j) then exit 1
  if a~dischargeXAtCell(i,j)<>b~dischargeXAtCell(i,j) then exit 1
  if a~dischargeZAtCell(i,j)<>b~dischargeZAtCell(i,j) then exit 1
 end
end
say 'PHYSICS FREE SURFACE CHECKPOINT RELOAD: OK time='a~time
::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fluids.cls'
