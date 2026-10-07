/* Physical Manufacturing dev4: growing manufactured workpiece dynamics.
   A print is a physical assembly, not a scalar payload.  Each deposited section
   is an independent rigid body connected laterally to the plate or previous
   section.  Growth therefore changes mass distribution, centre of mass,
   inertia and structural response without a PRINT_QUALITY rule.  SI units. */

::class ManufacturedSection public
::method init
  expose _id _body _mass _width _height _depth _materialRef _attachment _parent
  use strict arg sectionId,bodyState,mass,width,height,depth,materialRef=.nil,parent=.nil,attachment=.nil
  if mass<=0 | width<=0 | height<=0 | depth<=0 then raise syntax 88.900 array('positive section physical parameters')
  _id=sectionId~string; _body=bodyState; _mass=mass; _width=width; _height=height; _depth=depth
  _materialRef=materialRef; _parent=parent; _attachment=attachment
::method id; expose _id; return _id
::method body; expose _body; return _body
::method mass; expose _mass; return _mass
::method width; expose _width; return _width
::method height; expose _height; return _height
::method depth; expose _depth; return _depth
::method materialRef; expose _materialRef; return _materialRef
::method parent; expose _parent; return _parent
::method attachment; expose _attachment; return _attachment
::method position; expose _body; return _body~position

::class GrowingWorkpiece public
::method init
  expose _solver _plate _axis _sections _attachments _ctx
  use strict arg mechanicsSolver,plateBody,axis
  _solver=mechanicsSolver; _plate=plateBody; _axis=axis~normalized; _sections=.array~new; _attachments=.array~new; _ctx=.Maths~defaultContext
::method sections; expose _sections; return _sections~copy
::method sectionCount; expose _sections; return _sections~items
::method totalMass
  expose _sections
  total=0; do s over _sections; total=total+s~mass; end; return total
::method centreOfMass
  expose _sections _ctx
  if _sections~items=0 then return .MathVector3~new(0,0,0,_ctx)
  total=self~totalMass; sum=.MathVector3~new(0,0,0,_ctx)
  do s over _sections; sum=sum+s~position*s~mass; end
  return sum*(1/total)
::method lateralInertiaAboutCentre
  /* Izz-like evidence for lateral X motion about the assembly COM.  Each box
     contributes its own centroidal inertia plus parallel-axis mass distance. */
  expose _sections
  if _sections~items=0 then return 0
  c=self~centreOfMass; total=0
  do s over _sections
    local=s~mass*(s~width*s~width+s~height*s~height)/12
    dx=s~position~x-c~x; dy=s~position~y-c~y
    total=total+local+s~mass*(dx*dx+dy*dy)
  end
  return total
::method topSection
  expose _sections
  if _sections~items=0 then return .nil
  return _sections[_sections~items]
::method topPosition
  s=self~topSection; if s==.nil then return .nil; return s~position
::method addSection
  expose _solver _plate _axis _sections _attachments _ctx
  use strict arg sectionId,mass,width,height,depth,stiffness,damping=0,lateralOffset=0,materialRef=.nil
  if stiffness<=0 | damping<0 then raise syntax 88.900 array('valid section attachment parameters')
  parent=_plate
  if _sections~items=0 then baseY=height/2
  else do
    previous=_sections[_sections~items]
    parent=previous~body
    baseY=previous~position~y+previous~height/2+height/2
  end
  x=parent~position~x+lateralOffset
  shape=.BoxShape~new(width,height,depth,_ctx)
  physical=.OpticalBody~new('manufactured-section-'||sectionId,shape,.nil,.PhysicalPose~new(.MathVector3~new(x,baseY,0,_ctx),.nil,_ctx))
  body=.RigidBodyState~new(physical,.MechanicsMassProperties~solidBox(mass,width,height,depth))
  _solver~addBody(body)
  attachment=.LateralAttachment~new(parent,body,_axis,stiffness,damping)
  section=.ManufacturedSection~new(sectionId,body,mass,width,height,depth,materialRef,parent,attachment)
  _sections~append(section); _attachments~append(attachment)
  return section
::method applyAttachments
  expose _attachments
  do a over _attachments; a~apply; end
::method lateralTipDeflection
  expose _sections
  if _sections~items=0 then return 0
  top=_sections[_sections~items]
  parent=top~parent
  return (top~body~position-parent~position)~dot(.MathVector3~new(1,0,0,.Maths~defaultContext))

::class GrowingPrinterDynamics public
/* Printer rig whose workpiece may grow during the same simulation.  Head and
   plate remain finite-force physical bodies.  Deposition coordinate is actual
   head position minus actual top-section position (or plate if empty). */
::method create class
  use strict arg headMass,plateMass,headMaxForce=80,plateMaxForce=120
  if headMass<=0 | plateMass<=0 then raise syntax 88.900 array('positive machine masses')
  ctx=.Maths~defaultContext; world=.PhysicalWorld~new
  head=.OpticalBody~new('printer-head',.BoxShape~new('0.05','0.05','0.05',ctx),.nil,.PhysicalPose~identity(ctx))
  plate=.OpticalBody~new('printer-plate',.BoxShape~new('0.20','0.02','0.20',ctx),.nil,.PhysicalPose~identity(ctx))
  hr=.RigidBodyState~new(head,.MechanicsMassProperties~solidBox(headMass,'0.05','0.05','0.05'))
  pr=.RigidBodyState~new(plate,.MechanicsMassProperties~solidBox(plateMass,'0.20','0.02','0.20'))
  solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx)); solver~addBody(hr); solver~addBody(pr)
  axis=.MathVector3~new(1,0,0,ctx)
  hs=.AxisServo~new(hr,axis,900,50,headMaxForce); ps=.AxisServo~new(pr,axis,900,50,plateMaxForce)
  growth=.GrowingWorkpiece~new(solver,pr,axis)
  return self~new(solver,hs,ps,pr,growth)
::method init
  expose _solver _headServo _plateServo _plate _growth _samples _history
  use strict arg solver,headServo,plateServo,plateBody,growingWorkpiece
  _solver=solver; _headServo=headServo; _plateServo=plateServo; _plate=plateBody; _growth=growingWorkpiece
  _samples=.array~new; _history=.SampledScalarHistory~new
::method workpiece; expose _growth; return _growth
::method commandHead; expose _headServo; use strict arg p,v=0; _headServo~targetPosition=p; _headServo~targetVelocity=v
::method commandPlate; expose _plateServo; use strict arg p,v=0; _plateServo~targetPosition=p; _plateServo~targetVelocity=v
::method addSection; expose _growth; use strict arg id,mass,width,height,depth,stiffness,damping=0,lateralOffset=0,materialRef=.nil; return _growth~addSection(id,mass,width,height,depth,stiffness,damping,lateralOffset,materialRef)
::method depositionPosition
  expose _headServo _plate _growth
  top=_growth~topSection
  if top==.nil then target=_plate~position~x
  else target=top~body~position~x
  return _headServo~position-target
::method step
  expose _solver _headServo _plateServo _growth _samples _history
  use strict arg dt
  if dt<=0 then raise syntax 88.900 array('positive timestep')
  _headServo~apply; _plateServo~apply; _growth~applyAttachments; _solver~step(dt)
  value=self~depositionPosition; _history~append(_solver~time,value); _samples~append(value); return value
::method runFor
  use strict arg duration,dt
  if duration<=0 | dt<=0 then raise syntax 88.900 array('positive duration and timestep')
  elapsed=0; do while elapsed<duration; h=dt; if elapsed+h>duration then h=duration-elapsed; self~step(h); elapsed=elapsed+h; end
::method relativeHistory; expose _history; return _history
::method samples; expose _samples; return _samples~copy

::requires 'MachineDynamics.cls'
