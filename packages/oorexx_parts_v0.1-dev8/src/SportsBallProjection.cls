/* Projection of a Parts sports ball into data suitable for a Physics aerodynamic body.
 * No aerodynamic coefficients are invented here: Physics must supply/fit the force model.
 */
::class SportsBallProjection public
::method rugbyLeague class
  use strict arg definition
  if definition~family<>'SPORTS_BALL' then raise syntax 93.900 array('sports-ball definition required')
  d=.directory~new
  d['PART_DEFINITION_ID']=definition~id
  d['MASS']=definition~parameter('MASS')
  d['LENGTH']=definition~parameter('LENGTH')
  d['MAX_CIRCUMFERENCE']=definition~parameter('MAX_CIRCUMFERENCE')
  d['SHAPE']=definition~parameter('SHAPE')
  d['INFLATION_PRESSURE']=definition~parameter('INFLATION_PRESSURE')
  d['INFLATION_GAS_MATERIAL_ID']=definition~parameter('INFLATION_GAS_MATERIAL_ID')
  d['DRAG_MODEL_REQUIRED']=.true
  d['LIFT_MODEL_REQUIRED']=.true
  d['ORIENTATION_MODEL_REQUIRED']=.true
  d['SPIN_MODEL_REQUIRED']=.true
  return d
::requires 'PartsCatalog.cls'
