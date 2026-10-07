numeric digits 20
ctx=.Maths~defaultContext
freq=.array~of(125,250,500,1000,2000,4000)
wood=.AcousticBuildingMaterialFactory~solidWoodDoor(freq)
block=.AcousticBuildingMaterialFactory~breezeBlockWall(freq)

world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)

/* Approximate topology from the user's amended plan.
   Coordinates are deliberately scale-relative, with FC-FD exactly 9 m.
   The three corrected doors are explicit solid-wood panels:
     A->F, E->F, FD->stairwell.
   There is deliberately NO A->stairwell door. */
fc=.MathVector3~new(9.0,1.0,4.2,ctx)
fd=.MathVector3~new(3.0,7.7082039325,4.2,ctx)

/* helper calls use vertical wall segments, split around door spans */
call addPanel solver,'outer-left',0,0,0,10,block,ctx
call addPanel solver,'outer-top',0,10,15,10,block,ctx
call addPanel solver,'outer-right',15,10,15,0,block,ctx
call addPanel solver,'outer-front',0,0,15,0,block,ctx

/* A/F partition: breeze block + closed solid wood door */
call addPanel solver,'wall-AF-1',4,0,4,3.0,block,ctx
call addPanel solver,'door-AF',4,3.0,4,4.0,wood,ctx
call addPanel solver,'wall-AF-2',4,4.0,4,7.0,block,ctx

/* E/F partition: breeze block + closed solid wood door */
call addPanel solver,'wall-EF-1',7,0,7,3.0,block,ctx
call addPanel solver,'door-EF',7,3.0,7,4.0,wood,ctx
call addPanel solver,'wall-EF-2',7,4.0,7,7.0,block,ctx

/* Rear corridor / stair boundary. No A->stairs opening. */
call addPanel solver,'rear-A-solid',0,7,2.5,7,block,ctx
call addPanel solver,'door-FD-stair',2.5,7,3.5,7,wood,ctx
call addPanel solver,'rear-F-solid',3.5,7,11,7,block,ctx
call addPanel solver,'rear-right-solid',11,7,15,7,block,ctx

/* Additional F12 partitions, approximate topology only. */
call addPanel solver,'f12-v1',11,0,11,7,block,ctx
call addPanel solver,'f12-v2',13,0,13,7,block,ctx

e=.AcousticEmissionSpectrum~new
do f over freq;e~addBand(.AcousticEmissionBand~new(f,0.001));end
receivers=.directory~new;receivers['FC']=fc;receivers['FD']=fd

say 'x,y,fc_ms,fd_ms,fd_minus_fc_ms,fc_kind,fd_kind,fd_fc_energy_ratio'
do y=0 to 7
  do x=0 to 10
    s=.MathVector3~new(x,y,4.2,ctx)
    r=solver~solve(s,e,receivers,0.150)
    afc=r~receiver('FC')~firstArrival
    afd=r~receiver('FD')~firstArrival
    if afc==.nil then fcms='NA'; else fcms=afc~delay*1000
    if afd==.nil then fdms='NA'; else fdms=afd~delay*1000
    if afc==.nil | afd==.nil then delta='NA'; else delta=(afd~delay-afc~delay)*1000
    if afc==.nil then fck='NONE'; else fck=afc~kind
    if afd==.nil then fdk='NONE'; else fdk=afd~kind
    efc=r~receiver('FC')~energyProxy; efd=r~receiver('FD')~energyProxy
    if efc=0 then ratio='NA'; else ratio=efd/efc
    say x','y','fcms','fdms','delta','fck','fdk','ratio
  end
end
exit 0

addPanel:
  use arg solver,name,x1,y1,x2,y2,material,ctx
  a=.MathVector3~new(x1,y1,0,ctx);b=.MathVector3~new(x2,y2,0,ctx)
  panel=.AcousticVerticalPanel~new(a,b,0,8)
  solver~addSurface(.AcousticSpectralSurface~new(name,panel,material))
  return

::requires 'AcousticImpulseResponse.cls'
