/* Optional Physics World adapter for ooRexx Materials v0.1-dev1.
 * Kept outside the catalogue core so Physics World is not a hard dependency.
 */
::class PhysicsMaterialProjection public
::method fluid class
  use strict arg material
  return .FluidMedium~new(material~id,material~quantity('DENSITY'),material~quantity('DYNAMIC_VISCOSITY'))
::method thermal class
  use strict arg material,emissivity=.nil
  return .ThermalMaterialProperties~new(material~id,material~quantity('SPECIFIC_HEAT'),material~quantity('THERMAL_CONDUCTIVITY'),emissivity)
::method mechanical class
  use strict arg material,yieldStrain='0.002',fractureStrain='0.15',damping=0,plasticFlow=1
  return .MechanicalMaterial~new(material~id,material~quantity('DENSITY'),material~quantity('YOUNG_MODULUS'),yieldStrain,fractureStrain,damping,plasticFlow)
::method optical class
  use strict arg material
  n=material~value('REFRACTIVE_INDEX')
  medium=.OpticalMedium~new(material~id,.ConstantIndexModel~new(n))
  return .OpticalMaterial~dielectric(material~id,medium)

::requires 'MaterialsCatalog.cls'
::requires 'PhysicsWorld.cls'
::requires 'Fluids.cls'
::requires 'Thermal.cls'
::requires 'Deformable.cls'
