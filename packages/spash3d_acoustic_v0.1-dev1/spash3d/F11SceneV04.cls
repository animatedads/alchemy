/* F11SceneV04.cls -- Physics World F11/F12 acoustic scene from geometry v0.4.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Scene construction is the estate's own, as in oorexx_physics_world tests/f11_vehicle_experiment.rex:
 * proportion-traced room rectangles (breeze block), three corrected solid-wood doors (no A_to_stairs door),
 * F11RearExteriorGeometry (terrain step, stairwell shaft, 1 m x 2 m rear aperture).
 * Authority: geometry/f11_f12_proportion_geometry_v0.4.json
 *   sha256 3ed2eecd8bdcb00bce93c1fa4018dea3baeeb99a0e07d5f698e015f1dd552cde
 * Metric: FC-FD baseline 9.43 m; 0.017025100232155435 m/px; plan origin (75,145) px; X right, Y down (rear Y=0), Z up.
 * Not modelled (stated, not invented): floor/ceiling reflection materials, furniture, open/closed state of doors other
 * than the three corrected ones, front-facade openings (front_E/F/B doors are treated as part of the facade walls).
 */
::options numeric inherit

::class F11SceneV04 public
::constant SCALE '0.017025100232155435'
::constant X0 75
::constant Y0 145
::constant WALL_BOTTOM 3.0
::constant CEILING 5.2
::method init
  expose solver ctx freq receivers world
  use strict arg freqList
  numeric digits 20
  ctx=.Maths~defaultContext
  freq=freqList
  wood=.AcousticBuildingMaterialFactory~solidWoodDoor(freq)
  block=.AcousticBuildingMaterialFactory~breezeBlockWall(freq)
  world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
  solver=.AcousticImpulseResponseSolver~new(world)
  self~panelPx('A-top',142,161,383,161,block); self~panelPx('A-left',142,161,142,370,block)
  self~panelPx('A-right',383,161,383,370,block); self~panelPx('A-bottom',142,370,383,370,block)
  do r over .array~of('E 76 371 280 699','F 294 371 495 699','B 510 176 725 699','C 744 161 960 371', -
                      'D 976 161 1230 371','G 744 458 921 699','H 1078 382 1217 517','I 1001 516 1250 766', -
                      'Stairs 398 145 486 371')
    parse var r n x1 y1 x2 y2
    self~panelPx(n'-top',x1,y1,x2,y1,block); self~panelPx(n'-right',x2,y1,x2,y2,block)
    self~panelPx(n'-bottom',x2,y2,x1,y2,block); self~panelPx(n'-left',x1,y2,x1,y1,block)
  end
  rear=.F11RearExteriorGeometry~addToSolver(solver,block,freq,ctx)
  self~panelPx('door-A_to_F',383,327,383,366,wood)
  self~panelPx('door-E_to_F',280,503,294,538,wood)
  self~panelPx('door-FD_to_stairwell',398,328,461,371,wood)
  receivers=.directory~new
  receivers['FC']=.MathVector3~new('14.267033994546255','9.448930628846266','4.8',ctx)
  receivers['FD']=.MathVector3~new('7.014341295648039','3.4220451466632427','4.8',ctx)
::method panelPx private
  expose solver ctx
  use strict arg name,px1,py1,px2,py2,material
  s=self~SCALE; zmin=self~WALL_BOTTOM; zmax=self~CEILING
  a=.MathVector3~new((px1-self~X0)*s,(py1-self~Y0)*s,zmin,ctx)
  b=.MathVector3~new((px2-self~X0)*s,(py2-self~Y0)*s,zmin,ctx)
  solver~addSurface(.AcousticSpectralSurface~new(name,.AcousticVerticalPanel~new(a,b,zmin,zmax),material))
::method solver; expose solver; return solver
::method context; expose ctx; return ctx
::method receivers; expose receivers; return receivers
::method frequencies; expose freq; return freq
::method point
  expose ctx
  use strict arg x,y,z
  return .MathVector3~new(x,y,z,ctx)
/* plan pixel -> metres */
::method pxToM class
  use strict arg px,py
  return ((px-75)*'0.017025100232155435') ((py-145)*'0.017025100232155435')
/* room containing plan point (metres), or '' */
::method roomAt class
  use strict arg x,y
  px=x/'0.017025100232155435'+75; py=y/'0.017025100232155435'+145
  do r over .array~of('A 142 161 383 370','E 76 371 280 699','F 294 371 495 699','B 510 176 725 699','C 744 161 960 371', -
                      'D 976 161 1230 371','G 744 458 921 699','H 1078 382 1217 517','I 1001 516 1250 766','Stairs 398 145 486 371', -
                      'Corridor 725 382 1078 458','Corridor 921 458 1001 699')
    parse var r n x1 y1 x2 y2
    if px>=x1 & px<=x2 & py>=y1 & py<=y2 then return n
  end
  if py>746 then return 'STREET'
  if py<145 then return 'REAR'
  return 'WALL/OTHER'

::requires 'AcousticImpulseResponse.cls'
::requires 'F11RearExterior.cls'

