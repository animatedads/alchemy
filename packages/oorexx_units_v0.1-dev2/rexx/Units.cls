/* ooRexx Units v0.1-dev2
   Shared dimensional quantity / conversion objects for Maths, Physics and Rexx-tronics.
   Canonical storage is SI. Source-unit identity and display-unit identity are retained.
*/

::class UnitDimension public
::method init
  expose e
  use strict arg length=0,mass=0,time=0,current=0,temperature=0,amount=0,luminous=0
  numeric digits 50
  e=.array~of(length+0,mass+0,time+0,current+0,temperature+0,amount+0,luminous+0)

::method exponent
  expose e
  use strict arg index
  if index < 1 | index > 7 then raise syntax 93.900 array('dimension exponent index must be 1..7')
  return e[index]

::method '*'
  use strict arg other
  numeric digits 50
  self~requireDimension(other)
  return .UnitDimension~new(self~exponent(1)+other~exponent(1), -
                            self~exponent(2)+other~exponent(2), -
                            self~exponent(3)+other~exponent(3), -
                            self~exponent(4)+other~exponent(4), -
                            self~exponent(5)+other~exponent(5), -
                            self~exponent(6)+other~exponent(6), -
                            self~exponent(7)+other~exponent(7))

::method '/'
  use strict arg other
  numeric digits 50
  self~requireDimension(other)
  return .UnitDimension~new(self~exponent(1)-other~exponent(1), -
                            self~exponent(2)-other~exponent(2), -
                            self~exponent(3)-other~exponent(3), -
                            self~exponent(4)-other~exponent(4), -
                            self~exponent(5)-other~exponent(5), -
                            self~exponent(6)-other~exponent(6), -
                            self~exponent(7)-other~exponent(7))

::method power
  use strict arg n
  numeric digits 50
  n=n+0
  return .UnitDimension~new(self~exponent(1)*n,self~exponent(2)*n,self~exponent(3)*n, -
                            self~exponent(4)*n,self~exponent(5)*n,self~exponent(6)*n,self~exponent(7)*n)

::method '='
  use strict arg other
  if \other~isA(.UnitDimension) then return .false
  do i=1 to 7
    if self~exponent(i) <> other~exponent(i) then return .false
  end
  return .true

::method '\='
  use strict arg other
  return \(self = other)

::method compatible
  use strict arg other
  if \other~isA(.UnitDimension) then return .false
  return self~canonical == other~canonical

::method isDimensionless
  return self~canonical == 'dim[0,0,0,0,0,0,0]'

::method canonical
  return 'dim['self~exponent(1)','self~exponent(2)','self~exponent(3)','self~exponent(4)','self~exponent(5)','self~exponent(6)','self~exponent(7)']'

::method string
  return self~canonical

::method requireDimension private
  use strict arg other
  if \other~isA(.UnitDimension) then raise syntax 93.900 array('UnitDimension operand required')

::method dimensionless class; return self~new
::method length class; return self~new(1)
::method mass class; return self~new(0,1)
::method time class; return self~new(0,0,1)
::method current class; return self~new(0,0,0,1)
::method temperature class; return self~new(0,0,0,0,1)
::method amount class; return self~new(0,0,0,0,0,1)
::method luminousIntensity class; return self~new(0,0,0,0,0,0,1)


::class UnitDefinition public
::method init
  expose _name _symbol _scale _offset _dimension _family _aliases _kind
  use strict arg name,symbol,scale,dimension,offset=0,family='',aliases=.nil,kind='LINEAR'
  numeric digits 50
  if \dimension~isA(.UnitDimension) then raise syntax 93.900 array('unit dimension must be UnitDimension')
  if scale = 0 then raise syntax 93.900 array('unit scale must be non-zero')
  _name=name~string
  _symbol=symbol~string
  _scale=scale+0
  _offset=offset+0
  _dimension=dimension
  _family=family~string~upper
  _kind=kind~string~upper
  if _kind <> 'LINEAR' & _kind <> 'ABSOLUTE' & _kind <> 'DELTA' then raise syntax 93.900 array('unit kind must be LINEAR, ABSOLUTE, or DELTA')
  if aliases==.nil then _aliases=.array~new
  else _aliases=aliases

::method name; expose _name; return _name
::method symbol; expose _symbol; return _symbol
::method scale; expose _scale; return _scale
::method offset; expose _offset; return _offset
::method dimension; expose _dimension; return _dimension
::method family; expose _family; return _family
::method aliases; expose _aliases; return _aliases
::method kind; expose _kind; return _kind
::method isAffine; expose _offset; return _offset <> 0
::method isAbsolute; expose _kind; return _kind == 'ABSOLUTE'
::method isDelta; expose _kind; return _kind == 'DELTA'
::method isLinear; expose _kind; return _kind == 'LINEAR' | _kind == 'DELTA'

::method toCanonical
  expose _scale _offset
  use strict arg value
  numeric digits 50
  /* Maths vectors deliberately use vector * scalar, never vector / scalar. */
  if _offset <> 0 then do
    if \self~isScalarLike(value) then raise syntax 93.900 array('affine unit conversion requires a scalar value')
    return value * _scale + _offset
  end
  return value * _scale

::method fromCanonical
  expose _scale _offset
  use strict arg value
  numeric digits 50
  if _offset <> 0 then do
    if \self~isScalarLike(value) then raise syntax 93.900 array('affine unit conversion requires a scalar value')
    return (value - _offset) / _scale
  end
  /* Scale by reciprocal so MathVector3 follows the Maths v0.8 contract. */
  return value * (1 / _scale)

::method compatibleWith
  use strict arg other
  if \other~isA(.UnitDefinition) then return .false
  if \self~dimension~compatible(other~dimension) then return .false
  /* A non-empty family refines conversion safety for equal-dimension semantic units. */
  if self~family <> '' & other~family <> '' then do
    if self~family <> other~family then return .false
    if self~family == 'TEMPERATURE' then return self~kind == other~kind
  end
  return .true

::method '*'
  use strict arg other
  numeric digits 50
  self~requireComposable(other)
  d=self~dimension*other~dimension
  return .UnitDefinition~new(self~name 'times' other~name,self~compoundSymbol('*',other),self~scale*other~scale,d)

::method '/'
  use strict arg other
  numeric digits 50
  self~requireComposable(other)
  d=self~dimension/other~dimension
  return .UnitDefinition~new(self~name 'per' other~name,self~compoundSymbol('/',other),self~scale/other~scale,d)

::method power
  use strict arg n
  numeric digits 50
  if self~isAffine | self~isAbsolute then raise syntax 93.900 array('absolute/affine units cannot be exponentiated')
  n=n+0
  d=self~dimension~power(n)
  if n=1 then return self
  symbol=self~symbol
  if symbol <> '' then symbol=symbol || '^' || n
  return .UnitDefinition~new(self~name 'power' n,symbol,self~scale**n,d)

::method scaled
  use strict arg name,symbol,factor
  numeric digits 50
  if self~isAffine | self~isAbsolute then raise syntax 93.900 array('absolute/affine units cannot be prefixed by scaling')
  return .UnitDefinition~new(name,symbol,self~scale*factor,self~dimension,0,self~family,.nil,self~kind)

::method compoundSymbol private
  use strict arg op,other
  if self~symbol='' | other~symbol='' then return ''
  return self~symbol || op || other~symbol

::method requireComposable private
  use strict arg other
  if \other~isA(.UnitDefinition) then raise syntax 93.900 array('UnitDefinition operand required')
  if self~isAffine | other~isAffine | self~isAbsolute | other~isAbsolute then -
    raise syntax 93.900 array('absolute/affine units cannot form compound units; use canonical quantity values or delta units')

::method string
  expose _name _symbol
  if _symbol='' then return _name
  return _name '(' || _symbol || ')'

::method isScalarLike private
  use strict arg value
  /* Native Rexx numerics and Maths scalar values both accept + 0.  Vectors do not. */
  signal on syntax name notScalar
  dummy=value+0
  signal off syntax
  return .true
notScalar:
  signal off syntax
  return .false


::class UnitProof public
::method init
  expose _operation _fromUnit _toUnit _input _canonical _output _equation
  use strict arg operation,fromUnit,toUnit,input,canonical,output,equation
  _operation=operation
  _fromUnit=fromUnit
  _toUnit=toUnit
  _input=input
  _canonical=canonical
  _output=output
  _equation=equation
::method operation; expose _operation; return _operation
::method fromUnit; expose _fromUnit; return _fromUnit
::method toUnit; expose _toUnit; return _toUnit
::method input; expose _input; return _input
::method canonicalValue; expose _canonical; return _canonical
::method output; expose _output; return _output
::method equation; expose _equation; return _equation
::method verifies
  expose _fromUnit _toUnit _input _output
  numeric digits 50
  signal on syntax name bad
  expected=_toUnit~fromCanonical(_fromUnit~toCanonical(_input))
  signal off syntax
  return expected = _output
bad:
  signal off syntax
  return .false
::method string
  expose _equation
  return _equation


::class UnitQuantity public
::method init
  expose _canonical _dimension _sourceUnit _displayUnit _family _proof
  use strict arg value,unit,displayUnit=.nil
  numeric digits 50
  if \unit~isA(.UnitDefinition) then raise syntax 93.900 array('UnitDefinition required')
  _canonical=unit~toCanonical(value)
  _dimension=unit~dimension
  _sourceUnit=unit
  if displayUnit==.nil then _displayUnit=unit
  else do
    if \unit~compatibleWith(displayUnit) then raise syntax 93.900 array('display unit is incompatible with source unit')
    _displayUnit=displayUnit
  end
  _family=unit~family
  shown=_displayUnit~fromCanonical(_canonical)
  eq=value unit~symbol '->' _canonical 'SI[' || _dimension~canonical || '] ->' shown _displayUnit~symbol
  _proof=.UnitProof~new('CONSTRUCT',unit,_displayUnit,value,_canonical,shown,eq)

::method fromCanonical class
  use strict arg value,dimension,displayUnit=.nil,sourceUnit=.nil,family=''
  numeric digits 50
  if sourceUnit==.nil then sourceUnit=.UnitDefinition~new('canonical','SI[' || dimension~canonical || ']',1,dimension,0,family)
  obj=self~new(sourceUnit~fromCanonical(value),sourceUnit,displayUnit)
  return obj

::method canonicalValue; expose _canonical; return _canonical
::method siValue; expose _canonical; return _canonical
::method dimension; expose _dimension; return _dimension
::method sourceUnit; expose _sourceUnit; return _sourceUnit
::method displayUnit; expose _displayUnit; return _displayUnit
::method family; expose _family; return _family
::method proof; expose _proof; return _proof
::method mathValue; expose _canonical; return _canonical
::method sourceValue
  numeric digits 50
  return self~sourceUnit~fromCanonical(self~canonicalValue)
::method displayValue
  numeric digits 50
  return self~displayUnit~fromCanonical(self~canonicalValue)
::method unitSymbol; return self~displayUnit~symbol
::method dimensionKey; return self~dimension~canonical

::method metadata
  d=.directory~new
  d['schema']='oorexx.units.quantity/0.1'
  d['unitsVersion']='0.1-dev2'
  d['dimension']=self~dimension~canonical
  d['family']=self~family
  d['sourceUnit']=self~sourceUnit~symbol
  d['sourceKind']=self~sourceUnit~kind
  d['displayUnit']=self~displayUnit~symbol
  d['displayKind']=self~displayUnit~kind
  d['sourceValue']=self~sourceValue
  d['displayValue']=self~displayValue
  d['canonicalValue']=self~canonicalValue
  return d

::method 'displayUnit='
  expose _displayUnit _sourceUnit
  use strict arg unit
  if \_sourceUnit~compatibleWith(unit) then raise syntax 93.900 array('compatible display unit required')
  _displayUnit=unit
  return unit

::method as
  use strict arg unit
  copy=.UnitQuantity~fromCanonical(self~canonicalValue,self~dimension,unit,self~sourceUnit,self~family)
  return copy

::method in
  use strict arg unit
  numeric digits 50
  self~requireCompatibleUnit(unit)
  return unit~fromCanonical(self~canonicalValue)

::method convert
  use strict arg unit
  numeric digits 50
  self~requireCompatibleUnit(unit)
  value=unit~fromCanonical(self~canonicalValue)
  eq=self~in(self~sourceUnit) self~sourceUnit~symbol '->' self~canonicalValue 'SI[' || self~dimension~canonical || '] ->' value unit~symbol
  return .UnitProof~new('CONVERT',self~sourceUnit,unit,self~in(self~sourceUnit),self~canonicalValue,value,eq)

::method '+'
  use strict arg other
  numeric digits 50
  self~requireQuantity(other)
  if self~isAbsoluteTemperature then do
    if other~isAbsoluteTemperature then raise syntax 93.900 array('adding two absolute temperatures is undefined; add a temperature delta')
    if other~isTemperatureDelta then return self~absolutePlusDelta(other)
  end
  if self~isTemperatureDelta & other~isAbsoluteTemperature then return other~absolutePlusDelta(self)
  self~requireCompatibleQuantity(other)
  return .UnitQuantity~fromCanonical(self~canonicalValue+other~canonicalValue,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method '-'
  use strict arg other
  numeric digits 50
  self~requireQuantity(other)
  if self~isAbsoluteTemperature & other~isAbsoluteTemperature then do
    delta=self~canonicalValue-other~canonicalValue
    return .UnitQuantity~fromCanonical(delta,self~dimension,.Units~deltaKelvin,.Units~deltaKelvin,'TEMPERATURE')
  end
  if self~isAbsoluteTemperature & other~isTemperatureDelta then return self~absoluteMinusDelta(other)
  if self~isTemperatureDelta & other~isAbsoluteTemperature then raise syntax 93.900 array('temperature delta minus absolute temperature is undefined')
  self~requireCompatibleQuantity(other)
  return .UnitQuantity~fromCanonical(self~canonicalValue-other~canonicalValue,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method isAbsoluteTemperature
  return self~family == 'TEMPERATURE' & self~sourceUnit~isAbsolute

::method isTemperatureDelta
  return self~family == 'TEMPERATURE' & self~sourceUnit~isDelta

::method absolutePlusDelta private
  use strict arg delta
  numeric digits 50
  if \delta~isTemperatureDelta then raise syntax 93.900 array('temperature delta required')
  value=self~canonicalValue+delta~canonicalValue
  return .UnitQuantity~fromCanonical(value,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method absoluteMinusDelta private
  use strict arg delta
  numeric digits 50
  if \delta~isTemperatureDelta then raise syntax 93.900 array('temperature delta required')
  value=self~canonicalValue-delta~canonicalValue
  return .UnitQuantity~fromCanonical(value,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method '*'
  use strict arg other
  numeric digits 50
  if other~isA(.UnitQuantity) then do
    d=self~dimension*other~dimension
    product=self~multiplyPayload(self~canonicalValue,other~canonicalValue)
    return .UnitQuantity~fromCanonical(product,d)
  end
  product=self~multiplyPayload(self~canonicalValue,other)
  return .UnitQuantity~fromCanonical(product,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method '/'
  use strict arg other
  numeric digits 50
  if other~isA(.UnitQuantity) then do
    d=self~dimension/other~dimension
    quotient=self~divideByScalarPayload(self~canonicalValue,other~canonicalValue)
    return .UnitQuantity~fromCanonical(quotient,d)
  end
  quotient=self~divideByScalarPayload(self~canonicalValue,other)
  return .UnitQuantity~fromCanonical(quotient,self~dimension,self~displayUnit,self~sourceUnit,self~family)

::method multiplyPayload private
  use strict arg left,right
  numeric digits 50
  signal on syntax name reverseProduct
  product=left*right
  signal off syntax
  return product
reverseProduct:
  signal off syntax
  /* Scalar * MathVector3 can be rewritten as MathVector3 * scalar. */
  return right*left

::method divideByScalarPayload private
  use strict arg dividend,divisor
  numeric digits 50
  /* Authoritative Maths v0.8 has vector * scalar, not vector / scalar. */
  reciprocal=1/divisor
  return dividend*reciprocal

::method compareTo
  use strict arg other
  numeric digits 50
  self~requireQuantity(other)
  self~requireCompatibleQuantity(other)
  if self~canonicalValue < other~canonicalValue then return -1
  if self~canonicalValue > other~canonicalValue then return 1
  return 0

::method '='
  use strict arg other
  if \other~isA(.UnitQuantity) then return .false
  if \self~dimension~compatible(other~dimension) then return .false
  if self~family <> '' & other~family <> '' & self~family <> other~family then return .false
  if self~family == 'TEMPERATURE' & other~family == 'TEMPERATURE' then do
    if self~sourceUnit~kind <> other~sourceUnit~kind then return .false
  end
  return self~canonicalValue = other~canonicalValue

::method string
  expose _displayUnit
  return self~in(_displayUnit) _displayUnit~symbol

::method requireQuantity private
  use strict arg other
  if \other~isA(.UnitQuantity) then raise syntax 93.900 array('UnitQuantity operand required')

::method requireCompatibleQuantity private
  use strict arg other
  if \self~dimension~compatible(other~dimension) then raise syntax 93.900 array('same physical dimension required')
  if self~family <> '' & other~family <> '' & self~family <> other~family then -
    raise syntax 93.900 array('same unit family required')

::method requireCompatibleUnit private
  use strict arg unit
  if \unit~isA(.UnitDefinition) then raise syntax 93.900 array('UnitDefinition required')
  if \self~dimension~compatible(unit~dimension) then raise syntax 93.900 array('compatible physical dimension required')
  if self~family <> '' & unit~family <> '' & self~family <> unit~family then -
    raise syntax 93.900 array('compatible unit family required')


::class Units public
::method q class
  use strict arg value,unit,displayUnit=.nil
  return .UnitQuantity~new(value,unit,displayUnit)

::method convert class
  use strict arg value,fromUnit,toUnit
  return self~q(value,fromUnit)~in(toUnit)

::method proof class
  use strict arg value,fromUnit,toUnit
  return self~q(value,fromUnit)~convert(toUnit)

::method version class; return '0.1-dev2'

::method fromMetadata class
  use strict arg metadata
  if \metadata~isA(.Directory) then raise syntax 93.900 array('quantity metadata must be a Directory')
  if \metadata~hasIndex('sourceUnit') | \metadata~hasIndex('sourceValue') then -
    raise syntax 93.900 array('quantity metadata requires sourceUnit and sourceValue')
  source=self~parseUnit(metadata['sourceUnit'])
  if metadata~hasIndex('displayUnit') & metadata['displayUnit'] <> '' then display=self~parseUnit(metadata['displayUnit'])
  else display=source
  return self~q(metadata['sourceValue'],source,display)

/* Base / dimensionless */
::method one class; return .UnitDefinition~new('one','',1,.UnitDimension~dimensionless,0,'DIMENSIONLESS')
::method percent class; return .UnitDefinition~new('percent','%',0.01,.UnitDimension~dimensionless,0,'RATIO')
::method radian class; return .UnitDefinition~new('radian','rad',1,.UnitDimension~dimensionless,0,'ANGLE')
::method degree class; return .UnitDefinition~new('degree','deg','0.017453292519943295769236907684886127134428718885417',.UnitDimension~dimensionless,0,'ANGLE')

/* Length */
::method metre class; return .UnitDefinition~new('metre','m',1,.UnitDimension~length,0,'LENGTH')
::method kilometre class; return .UnitDefinition~new('kilometre','km',1000,.UnitDimension~length,0,'LENGTH')
::method centimetre class; return .UnitDefinition~new('centimetre','cm','0.01',.UnitDimension~length,0,'LENGTH')
::method millimetre class; return .UnitDefinition~new('millimetre','mm','0.001',.UnitDimension~length,0,'LENGTH')
::method micrometre class; return .UnitDefinition~new('micrometre','um','0.000001',.UnitDimension~length,0,'LENGTH')
::method nanometre class; return .UnitDefinition~new('nanometre','nm','0.000000001',.UnitDimension~length,0,'LENGTH')
::method inch class; return .UnitDefinition~new('inch','in','0.0254',.UnitDimension~length,0,'LENGTH')
::method foot class; return .UnitDefinition~new('foot','ft','0.3048',.UnitDimension~length,0,'LENGTH')
::method mile class; return .UnitDefinition~new('mile','mi','1609.344',.UnitDimension~length,0,'LENGTH')

/* Mass */
::method kilogram class; return .UnitDefinition~new('kilogram','kg',1,.UnitDimension~mass,0,'MASS')
::method gram class; return .UnitDefinition~new('gram','g','0.001',.UnitDimension~mass,0,'MASS')
::method milligram class; return .UnitDefinition~new('milligram','mg','0.000001',.UnitDimension~mass,0,'MASS')
::method pound class; return .UnitDefinition~new('pound','lb','0.45359237',.UnitDimension~mass,0,'MASS')

/* Time / frequency */
::method second class; return .UnitDefinition~new('second','s',1,.UnitDimension~time,0,'TIME')
::method millisecond class; return .UnitDefinition~new('millisecond','ms','0.001',.UnitDimension~time,0,'TIME')
::method microsecond class; return .UnitDefinition~new('microsecond','us','0.000001',.UnitDimension~time,0,'TIME')
::method nanosecond class; return .UnitDefinition~new('nanosecond','ns','0.000000001',.UnitDimension~time,0,'TIME')
::method picosecond class; return .UnitDefinition~new('picosecond','ps','0.000000000001',.UnitDimension~time,0,'TIME')
::method minute class; return .UnitDefinition~new('minute','min',60,.UnitDimension~time,0,'TIME')
::method hour class; return .UnitDefinition~new('hour','h',3600,.UnitDimension~time,0,'TIME')
::method hertz class; return .UnitDefinition~new('hertz','Hz',1,.UnitDimension~time~power(-1),0,'FREQUENCY')
::method kilohertz class; return .UnitDefinition~new('kilohertz','kHz',1000,.UnitDimension~time~power(-1),0,'FREQUENCY')
::method megahertz class; return .UnitDefinition~new('megahertz','MHz',1000000,.UnitDimension~time~power(-1),0,'FREQUENCY')

/* SI mechanics */
::method metrePerSecond class
  return .UnitDefinition~new('metre per second','m/s',1,.UnitDimension~length/.UnitDimension~time,0,'SPEED')
::method kilometrePerHour class
  return .UnitDefinition~new('kilometre per hour','km/h','0.27777777777777777777777777777777777777777777777778',.UnitDimension~length/.UnitDimension~time,0,'SPEED')
::method milePerHour class
  return .UnitDefinition~new('mile per hour','mph','0.44704',.UnitDimension~length/.UnitDimension~time,0,'SPEED')
::method metrePerSecondSquared class
  return .UnitDefinition~new('metre per second squared','m/s^2',1,.UnitDimension~length/.UnitDimension~time~power(2),0,'ACCELERATION')
::method newton class
  d=.UnitDimension~mass*.UnitDimension~length/.UnitDimension~time~power(2)
  return .UnitDefinition~new('newton','N',1,d,0,'FORCE')
::method newtonSecond class
  d=.UnitDimension~mass*.UnitDimension~length/.UnitDimension~time
  return .UnitDefinition~new('newton second','N*s',1,d,0,'IMPULSE')
::method joule class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(2)
  return .UnitDefinition~new('joule','J',1,d,0,'ENERGY')
::method watt class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)
  return .UnitDefinition~new('watt','W',1,d,0,'POWER')
::method kilowatt class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)
  return .UnitDefinition~new('kilowatt','kW',1000,d,0,'POWER')
::method pascal class
  d=.UnitDimension~mass/.UnitDimension~length/.UnitDimension~time~power(2)
  return .UnitDefinition~new('pascal','Pa',1,d,0,'PRESSURE')
::method kilopascal class
  d=.UnitDimension~mass/.UnitDimension~length/.UnitDimension~time~power(2)
  return .UnitDefinition~new('kilopascal','kPa',1000,d,0,'PRESSURE')

/* Temperature: canonical kelvin. */
::method kelvin class; return .UnitDefinition~new('kelvin','K',1,.UnitDimension~temperature,0,'TEMPERATURE',.nil,'ABSOLUTE')
::method celsius class; return .UnitDefinition~new('degree Celsius','degC',1,.UnitDimension~temperature,'273.15','TEMPERATURE',.nil,'ABSOLUTE')
::method fahrenheit class
  /* K = degF * 5/9 + 255.372222222... */
  return .UnitDefinition~new('degree Fahrenheit','degF','0.55555555555555555555555555555555555555555555555556',.UnitDimension~temperature,'255.37222222222222222222222222222222222222222222222','TEMPERATURE',.nil,'ABSOLUTE')
::method deltaKelvin class; return .UnitDefinition~new('kelvin difference','deltaK',1,.UnitDimension~temperature,0,'TEMPERATURE',.nil,'DELTA')
::method deltaCelsius class; return .UnitDefinition~new('Celsius difference','deltaC',1,.UnitDimension~temperature,0,'TEMPERATURE',.nil,'DELTA')
::method deltaFahrenheit class; return .UnitDefinition~new('Fahrenheit difference','deltaF','0.55555555555555555555555555555555555555555555555556',.UnitDimension~temperature,0,'TEMPERATURE',.nil,'DELTA')

/* Electrical SI derived dimensions. */
::method ampere class; return .UnitDefinition~new('ampere','A',1,.UnitDimension~current,0,'CURRENT')
::method milliampere class; return .UnitDefinition~new('milliampere','mA','0.001',.UnitDimension~current,0,'CURRENT')
::method coulomb class
  return .UnitDefinition~new('coulomb','C',1,.UnitDimension~current*.UnitDimension~time,0,'CHARGE')
::method volt class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current
  return .UnitDefinition~new('volt','V',1,d,0,'VOLTAGE')
::method millivolt class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current
  return .UnitDefinition~new('millivolt','mV','0.001',d,0,'VOLTAGE')
::method ohm class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current~power(2)
  return .UnitDefinition~new('ohm','ohm',1,d,0,'RESISTANCE')
::method kiloohm class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current~power(2)
  return .UnitDefinition~new('kiloohm','kohm',1000,d,0,'RESISTANCE')
::method megaohm class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current~power(2)
  return .UnitDefinition~new('megaohm','Mohm',1000000,d,0,'RESISTANCE')
::method siemens class
  d=(.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(3)/.UnitDimension~current~power(2))~power(-1)
  return .UnitDefinition~new('siemens','S',1,d,0,'CONDUCTANCE')
::method farad class
  d=.UnitDimension~mass~power(-1)*.UnitDimension~length~power(-2)*.UnitDimension~time~power(4)*.UnitDimension~current~power(2)
  return .UnitDefinition~new('farad','F',1,d,0,'CAPACITANCE')
::method microfarad class
  d=.UnitDimension~mass~power(-1)*.UnitDimension~length~power(-2)*.UnitDimension~time~power(4)*.UnitDimension~current~power(2)
  return .UnitDefinition~new('microfarad','uF','0.000001',d,0,'CAPACITANCE')
::method nanofarad class
  d=.UnitDimension~mass~power(-1)*.UnitDimension~length~power(-2)*.UnitDimension~time~power(4)*.UnitDimension~current~power(2)
  return .UnitDefinition~new('nanofarad','nF','0.000000001',d,0,'CAPACITANCE')
::method picofarad class
  d=.UnitDimension~mass~power(-1)*.UnitDimension~length~power(-2)*.UnitDimension~time~power(4)*.UnitDimension~current~power(2)
  return .UnitDefinition~new('picofarad','pF','0.000000000001',d,0,'CAPACITANCE')
::method henry class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(2)/.UnitDimension~current~power(2)
  return .UnitDefinition~new('henry','H',1,d,0,'INDUCTANCE')
::method millihenry class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(2)/.UnitDimension~current~power(2)
  return .UnitDefinition~new('millihenry','mH','0.001',d,0,'INDUCTANCE')

/* Additional shared Physics / electronics units. */
::method squareMetre class; return .Units~metre~power(2)
::method cubicMetre class; return .Units~metre~power(3)
::method litre class
  return .UnitDefinition~new('litre','L','0.001',.UnitDimension~length~power(3),0,'VOLUME')
::method millilitre class
  return .UnitDefinition~new('millilitre','mL','0.000001',.UnitDimension~length~power(3),0,'VOLUME')
::method gramPerCubicCentimetre class
  d=.UnitDimension~mass/.UnitDimension~length~power(3)
  return .UnitDefinition~new('gram per cubic centimetre','g/cm^3',1000,d,0,'DENSITY')
::method kilogramPerCubicMetre class
  d=.UnitDimension~mass/.UnitDimension~length~power(3)
  return .UnitDefinition~new('kilogram per cubic metre','kg/m^3',1,d,0,'DENSITY')
::method bar class
  return .UnitDefinition~new('bar','bar',100000,.Units~pascal~dimension,0,'PRESSURE')
::method electronvolt class
  return .UnitDefinition~new('electronvolt','eV','0.0000000000000000001602176634',.Units~joule~dimension,0,'ENERGY')
::method weber class
  d=.UnitDimension~mass*.UnitDimension~length~power(2)/.UnitDimension~time~power(2)/.UnitDimension~current
  return .UnitDefinition~new('weber','Wb',1,d,0,'MAGNETIC_FLUX')
::method tesla class
  d=.UnitDimension~mass/.UnitDimension~time~power(2)/.UnitDimension~current
  return .UnitDefinition~new('tesla','T',1,d,0,'MAGNETIC_FLUX_DENSITY')
::method voltAmpere class
  return .UnitDefinition~new('volt ampere','VA',1,.Units~watt~dimension,0,'APPARENT_POWER')
::method var class
  return .UnitDefinition~new('volt ampere reactive','var',1,.Units~watt~dimension,0,'REACTIVE_POWER')

::method prefixed class
  use strict arg unit,prefixName,prefixSymbol,factor
  if \unit~isA(.UnitDefinition) then raise syntax 93.900 array('UnitDefinition required')
  return unit~scaled(prefixName || unit~name,prefixSymbol || unit~symbol,factor)

::method parseUnit class
  use strict arg expression
  text=expression~string~strip
  if text='' then raise syntax 93.900 array('unit expression must not be empty')
  compact=text~changestr(' ','')
  /* Direct catalogue names/symbols win before expression parsing. */
  signal on syntax name compound
  direct=self~unit(compact)
  signal off syntax
  return direct
compound:
  signal off syntax
  /* Multiplication and division are evaluated left-to-right. Exponents bind to factors. */
  factors=.array~new
  ops=.array~new
  token=''
  do i=1 to compact~length
    ch=compact~substr(i,1)
    if ch='*' | ch='/' then do
      if token='' then raise syntax 93.900 array('invalid unit expression: ' || text)
      factors~append(token); ops~append(ch); token=''
    end
    else token=token || ch
  end
  if token='' then raise syntax 93.900 array('invalid unit expression: ' || text)
  factors~append(token)
  result=self~parseUnitFactor(factors[1])
  do i=2 to factors~items
    rhs=self~parseUnitFactor(factors[i])
    op=ops[i-1]
    if op='*' then result=result*rhs
    else result=result/rhs
  end
  return result

::method parseUnitFactor class private
  use strict arg token
  pos=token~lastPos('^')
  if pos=0 then return self~unit(token)
  base=token~left(pos-1)
  exponent=token~substr(pos+1)
  if base='' | exponent='' then raise syntax 93.900 array('invalid unit factor: ' || token)
  /* Require an integral exponent so dimension signatures stay exact. */
  signal on syntax name badExponent
  n=exponent+0
  if n\=n~trunc then signal badExponent
  signal off syntax
  return self~unit(base)~power(n)
badExponent:
  signal off syntax
  raise syntax 93.900 array('unit exponent must be an integer: ' || token)

::method unit class
  use strict arg token
  key=token~string~strip
  select
    when key == 'm' | key~caselessEquals('metre') | key~caselessEquals('meter') then return self~metre
    when key == 'km' | key~caselessEquals('kilometre') | key~caselessEquals('kilometer') then return self~kilometre
    when key == 'cm' then return self~centimetre
    when key == 'mm' then return self~millimetre
    when key == 'in' | key~caselessEquals('inch') then return self~inch
    when key == 'ft' | key~caselessEquals('foot') then return self~foot
    when key == 'mi' | key~caselessEquals('mile') then return self~mile
    when key == 'kg' then return self~kilogram
    when key == 'g' then return self~gram
    when key == 'lb' then return self~pound
    when key == 's' | key~caselessEquals('second') then return self~second
    when key == 'ms' then return self~millisecond
    when key == 'min' | key~caselessEquals('minute') then return self~minute
    when key == 'h' | key~caselessEquals('hour') then return self~hour
    when key == 'Hz' | key~caselessEquals('hertz') then return self~hertz
    when key == 'm/s' then return self~metrePerSecond
    when key == 'km/h' then return self~kilometrePerHour
    when key~caselessEquals('mph') then return self~milePerHour
    when key == 'm/s^2' then return self~metrePerSecondSquared
    when key == 'N' | key~caselessEquals('newton') then return self~newton
    when key == 'J' | key~caselessEquals('joule') then return self~joule
    when key == 'W' | key~caselessEquals('watt') then return self~watt
    when key == 'Pa' | key~caselessEquals('pascal') then return self~pascal
    when key == 'K' | key~caselessEquals('kelvin') then return self~kelvin
    when key~caselessEquals('degC') | key~caselessEquals('celsius') | key == '°C' then return self~celsius
    when key~caselessEquals('degF') | key~caselessEquals('fahrenheit') | key == '°F' then return self~fahrenheit
    when key~caselessEquals('deltaK') then return self~deltaKelvin
    when key~caselessEquals('deltaC') then return self~deltaCelsius
    when key~caselessEquals('deltaF') then return self~deltaFahrenheit
    when key == 'A' | key~caselessEquals('ampere') then return self~ampere
    when key == 'mA' then return self~milliampere
    when key == 'V' | key~caselessEquals('volt') then return self~volt
    when key == 'mV' then return self~millivolt
    when key~caselessEquals('ohm') | key == 'Ω' then return self~ohm
    when key~caselessEquals('kohm') | key == 'kΩ' then return self~kiloohm
    when key == 'Mohm' | key~caselessEquals('megaohm') | key == 'MΩ' then return self~megaohm
    when key == 'F' | key~caselessEquals('farad') then return self~farad
    when key == 'uF' then return self~microfarad
    when key == 'nF' then return self~nanofarad
    when key == 'pF' then return self~picofarad
    when key == 'H' | key~caselessEquals('henry') then return self~henry
    when key == 'mH' then return self~millihenry
    when key == 'L' | key~caselessEquals('litre') | key~caselessEquals('liter') then return self~litre
    when key == 'mL' then return self~millilitre
    when key~caselessEquals('bar') then return self~bar
    when key == 'eV' then return self~electronvolt
    when key == 'Wb' then return self~weber
    when key == 'T' then return self~tesla
    otherwise raise syntax 93.900 array('unknown unit: ' || key)
  end

::method parseQuantity class
  use strict arg text
  words=text~string~space
  split=words~pos(' ')
  if split=0 then raise syntax 93.900 array('quantity text must contain value and unit, for example 4.7 kohm')
  value=words~left(split-1)
  unitText=words~substr(split+1)~strip
  return self~q(value,self~parseUnit(unitText))

/* Photometric base/derived units used by Physics. */
::method candela class; return .UnitDefinition~new('candela','cd',1,.UnitDimension~luminousIntensity,0,'LUMINOUS_INTENSITY')
::method lumen class; return .UnitDefinition~new('lumen','lm',1,.UnitDimension~luminousIntensity,0,'LUMINOUS_FLUX')
::method lux class
  d=.UnitDimension~luminousIntensity/.UnitDimension~length~power(2)
  return .UnitDefinition~new('lux','lx',1,d,0,'ILLUMINANCE')
