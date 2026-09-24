/* ooRexx Physics World v0.1-dev8
   Reciprocal electromechanical actuation over authoritative rigid-body mechanics.

   Physics remains mechanical authority; Rexx-tronics (or another electrical peer)
   remains electrical authority.  The public drive boundary is typed UnitQuantity
   evidence, not anonymous amps/volts.

   Ideal reciprocal linear transducer:
       F = K i
       e = K v_rel
       P_conversion = F v_rel = e i

   Ideal reciprocal rotary transducer:
       tau = K i
       e   = K omega_rel
       P_conversion = tau omega_rel = e i

   Winding resistance, inductance, switching, commutation and electrical-source
   behaviour belong to the electrical authority.  Mechanical losses belong to the
   mechanical model.  This module does not hide either behind an efficiency factor.
*/

::class ElectromechanicalUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if \value~isA(.UnitQuantity) then raise syntax 93.900 array(label 'must be a UnitQuantity')
  if \value~dimension~compatible(expectedDimension) then raise syntax 93.900 array(label 'has incompatible physical dimension')
  return value~canonicalValue+0
::method optionalScalar class
  use strict arg value,expectedDimension,label
  if value==.nil then return .nil
  return self~scalar(value,expectedDimension,label)
::method time class
  use strict arg value,label='electromechanical observation time'
  v=self~scalar(value,.UnitDimension~time,label)
  if v<0 then raise syntax 88.900 array('non-negative electromechanical time',v)
  return v
::method forceConstantUnit class; return .Units~newton/.Units~ampere
::method torqueConstantUnit class; return .Units~newton*.Units~metre/.Units~ampere

::class ElectricalDriveObservation public
::method init
  expose _time _current _voltage _cause _source _evidence
  use strict arg timeQuantity,currentQuantity,voltageQuantity=.nil,cause='',source=.nil,evidence=.nil
  _time=.ElectromechanicalUnitBoundary~time(timeQuantity)
  _current=.ElectromechanicalUnitBoundary~scalar(currentQuantity,.Units~ampere~dimension,'electrical drive current')
  _voltage=.ElectromechanicalUnitBoundary~optionalScalar(voltageQuantity,.Units~volt~dimension,'electrical drive voltage')
  _cause=cause; _source=source; _evidence=evidence
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method current; expose _current; return _current
::method currentQuantity; return .Units~q(self~current,.Units~ampere)
::method voltage; expose _voltage; return _voltage
::method voltageQuantity
  if self~voltage==.nil then return .nil
  return .Units~q(self~voltage,.Units~volt)
::method hasVoltage; return self~voltage<>.nil
::method terminalPower
  if \self~hasVoltage then return .nil
  return self~voltage*self~current
::method terminalPowerQuantity
  if \self~hasVoltage then return .nil
  return .Units~q(self~terminalPower,.Units~watt)
::method cause; expose _cause; return _cause
::method source; expose _source; return _source
::method evidence; expose _evidence; return _evidence

::class LinearElectromechanicalActuationEvent public
::method init
  expose _transducer _drive _point _axis _force _relativeVelocity _backEmf _mechanicalPower _reactionApplied
  use strict arg transducer,driveObservation,worldPoint,worldAxis,forceVector,relativeVelocity,backEmfVolts,mechanicalPowerWatts,reactionApplied
  _transducer=transducer; _drive=driveObservation; _point=worldPoint; _axis=worldAxis~normalized
  _force=forceVector; _relativeVelocity=relativeVelocity; _backEmf=backEmfVolts
  _mechanicalPower=mechanicalPowerWatts; _reactionApplied=reactionApplied
::method transducer; expose _transducer; return _transducer
::method driveObservation; expose _drive; return _drive
::method time; return self~driveObservation~time
::method timeQuantity; return self~driveObservation~timeQuantity
::method point; expose _point; return _point
::method axis; expose _axis; return _axis
::method force; expose _force; return _force
::method forceQuantity; return .Units~q(self~force,.Units~newton)
::method forceMagnitude; return self~force~dot(self~axis)
::method forceMagnitudeQuantity; return .Units~q(self~forceMagnitude,.Units~newton)
::method relativeVelocity; expose _relativeVelocity; return _relativeVelocity
::method relativeVelocityQuantity; return .Units~q(self~relativeVelocity,.Units~metrePerSecond)
::method backEmf; expose _backEmf; return _backEmf
::method backEmfQuantity; return .Units~q(self~backEmf,.Units~volt)
::method mechanicalPower; expose _mechanicalPower; return _mechanicalPower
::method mechanicalPowerQuantity; return .Units~q(self~mechanicalPower,.Units~watt)
::method conversionElectricalPower; return self~backEmf*self~driveObservation~current
::method conversionElectricalPowerQuantity; return .Units~q(self~conversionElectricalPower,.Units~watt)
::method powerClosureError; return self~mechanicalPower-self~conversionElectricalPower
::method terminalElectricalPower; return self~driveObservation~terminalPower
::method terminalElectricalPowerQuantity; return self~driveObservation~terminalPowerQuantity
::method unassignedTerminalPower
  if \self~driveObservation~hasVoltage then return .nil
  return self~terminalElectricalPower-self~conversionElectricalPower
::method unassignedTerminalPowerQuantity
  p=self~unassignedTerminalPower
  if p==.nil then return .nil
  return .Units~q(p,.Units~watt)
::method reactionApplied; expose _reactionApplied; return _reactionApplied

::class LinearElectromechanicalTransducer public
::method init
  expose _name _movingState _movingLocalPoint _statorFrame _axisLocal _forceConstant _reactionState _reactionLocalPoint
  use strict arg name,movingState,movingLocalPoint,statorFrame,axisLocal,forceConstant,reactionState=.nil,reactionLocalPoint=.nil
  _name=name; _movingState=movingState; _movingLocalPoint=movingLocalPoint; _statorFrame=statorFrame; _axisLocal=axisLocal~normalized
  _forceConstant=.ElectromechanicalUnitBoundary~scalar(forceConstant,.ElectromechanicalUnitBoundary~forceConstantUnit~dimension,'linear electromechanical force constant')
  if _forceConstant=0 then raise syntax 88.900 array('non-zero linear electromechanical force constant',_forceConstant)
  _reactionState=reactionState
  if reactionLocalPoint==.nil then reactionLocalPoint=.MathVector3~new(0,0,0,movingState~body~pose~context)
  _reactionLocalPoint=reactionLocalPoint
::method name; expose _name; return _name
::method movingState; expose _movingState; return _movingState
::method movingLocalPoint; expose _movingLocalPoint; return _movingLocalPoint
::method statorFrame; expose _statorFrame; return _statorFrame
::method axisLocal; expose _axisLocal; return _axisLocal
::method forceConstant; expose _forceConstant; return _forceConstant
::method forceConstantQuantity; return .Units~q(self~forceConstant,.ElectromechanicalUnitBoundary~forceConstantUnit)
::method reactionState; expose _reactionState; return _reactionState
::method reactionLocalPoint; expose _reactionLocalPoint; return _reactionLocalPoint
::method axis; return self~statorFrame~directionToWorld(self~axisLocal)
::method movingPoint; return self~movingState~body~pose~pointToWorld(self~movingLocalPoint)
::method reactionPoint
  if self~reactionState==.nil then return .nil
  return self~reactionState~body~pose~pointToWorld(self~reactionLocalPoint)
::method pointVelocity private
  use strict arg state,worldPoint
  r=worldPoint-state~position
  return state~velocity+state~angularVelocity~cross(r)
::method movingPointVelocity
  p=self~movingPoint
  return self~pointVelocity(self~movingState,p)
::method reactionPointVelocity
  if self~reactionState==.nil then return .MathVector3~new(0,0,0,self~movingState~body~pose~context)
  p=self~reactionPoint
  return self~pointVelocity(self~reactionState,p)
::method relativeVelocity
  return (self~movingPointVelocity-self~reactionPointVelocity)~dot(self~axis)
::method relativeVelocityQuantity; return .Units~q(self~relativeVelocity,.Units~metrePerSecond)
::method backEmf; return self~forceConstant*self~relativeVelocity
::method backEmfQuantity; return .Units~q(self~backEmf,.Units~volt)
::method forceForCurrent
  use strict arg currentQuantity
  current=.ElectromechanicalUnitBoundary~scalar(currentQuantity,.Units~ampere~dimension,'linear electromechanical current')
  return self~axis*(self~forceConstant*current)
::method applyDrive
  use strict arg driveObservation
  if \driveObservation~isA(.ElectricalDriveObservation) then raise syntax 93.900 array('ElectricalDriveObservation required')
  axis=self~axis; point=self~movingPoint; relV=self~relativeVelocity
  force=axis*(self~forceConstant*driveObservation~current)
  self~movingState~applyForce(force,point)
  reacted=.false
  if self~reactionState<>.nil then do
    self~reactionState~applyForce(force*(-1),self~reactionPoint)
    reacted=.true
  end
  emf=self~forceConstant*relV
  mechPower=force~dot(axis)*relV
  return .LinearElectromechanicalActuationEvent~new(self,driveObservation,point,axis,force,relV,emf,mechPower,reacted)

::class RotaryElectromechanicalActuationEvent public
::method init
  expose _transducer _drive _axis _torque _relativeOmega _backEmf _mechanicalPower _reactionApplied
  use strict arg transducer,driveObservation,worldAxis,torqueVector,relativeAngularVelocity,backEmfVolts,mechanicalPowerWatts,reactionApplied
  _transducer=transducer; _drive=driveObservation; _axis=worldAxis~normalized; _torque=torqueVector
  _relativeOmega=relativeAngularVelocity; _backEmf=backEmfVolts; _mechanicalPower=mechanicalPowerWatts; _reactionApplied=reactionApplied
::method transducer; expose _transducer; return _transducer
::method driveObservation; expose _drive; return _drive
::method time; return self~driveObservation~time
::method timeQuantity; return self~driveObservation~timeQuantity
::method axis; expose _axis; return _axis
::method torque; expose _torque; return _torque
::method torqueQuantity; return .Units~q(self~torque,.Units~newton*.Units~metre)
::method torqueMagnitude; return self~torque~dot(self~axis)
::method torqueMagnitudeQuantity; return .Units~q(self~torqueMagnitude,.Units~newton*.Units~metre)
::method relativeAngularVelocity; expose _relativeOmega; return _relativeOmega
::method relativeAngularVelocityQuantity; return .Units~q(self~relativeAngularVelocity,.Units~radian/.Units~second)
::method backEmf; expose _backEmf; return _backEmf
::method backEmfQuantity; return .Units~q(self~backEmf,.Units~volt)
::method mechanicalPower; expose _mechanicalPower; return _mechanicalPower
::method mechanicalPowerQuantity; return .Units~q(self~mechanicalPower,.Units~watt)
::method conversionElectricalPower; return self~backEmf*self~driveObservation~current
::method conversionElectricalPowerQuantity; return .Units~q(self~conversionElectricalPower,.Units~watt)
::method powerClosureError; return self~mechanicalPower-self~conversionElectricalPower
::method terminalElectricalPower; return self~driveObservation~terminalPower
::method terminalElectricalPowerQuantity; return self~driveObservation~terminalPowerQuantity
::method unassignedTerminalPower
  if \self~driveObservation~hasVoltage then return .nil
  return self~terminalElectricalPower-self~conversionElectricalPower
::method unassignedTerminalPowerQuantity
  p=self~unassignedTerminalPower
  if p==.nil then return .nil
  return .Units~q(p,.Units~watt)
::method reactionApplied; expose _reactionApplied; return _reactionApplied

::class RotaryElectromechanicalTransducer public
::method init
  expose _name _rotorState _statorFrame _axisLocal _torqueConstant _reactionState
  use strict arg name,rotorState,statorFrame,axisLocal,torqueConstant,reactionState=.nil
  _name=name; _rotorState=rotorState; _statorFrame=statorFrame; _axisLocal=axisLocal~normalized
  _torqueConstant=.ElectromechanicalUnitBoundary~scalar(torqueConstant,.ElectromechanicalUnitBoundary~torqueConstantUnit~dimension,'rotary electromechanical torque constant')
  if _torqueConstant=0 then raise syntax 88.900 array('non-zero rotary electromechanical torque constant',_torqueConstant)
  _reactionState=reactionState
::method name; expose _name; return _name
::method rotorState; expose _rotorState; return _rotorState
::method statorFrame; expose _statorFrame; return _statorFrame
::method axisLocal; expose _axisLocal; return _axisLocal
::method torqueConstant; expose _torqueConstant; return _torqueConstant
::method torqueConstantQuantity; return .Units~q(self~torqueConstant,.ElectromechanicalUnitBoundary~torqueConstantUnit)
::method reactionState; expose _reactionState; return _reactionState
::method axis; return self~statorFrame~directionToWorld(self~axisLocal)
::method relativeAngularVelocity
  statorOmega=.MathVector3~new(0,0,0,self~rotorState~body~pose~context)
  if self~reactionState<>.nil then statorOmega=self~reactionState~angularVelocity
  return (self~rotorState~angularVelocity-statorOmega)~dot(self~axis)
::method relativeAngularVelocityQuantity; return .Units~q(self~relativeAngularVelocity,.Units~radian/.Units~second)
::method backEmf; return self~torqueConstant*self~relativeAngularVelocity
::method backEmfQuantity; return .Units~q(self~backEmf,.Units~volt)
::method torqueForCurrent
  use strict arg currentQuantity
  current=.ElectromechanicalUnitBoundary~scalar(currentQuantity,.Units~ampere~dimension,'rotary electromechanical current')
  return self~axis*(self~torqueConstant*current)
::method applyDrive
  use strict arg driveObservation
  if \driveObservation~isA(.ElectricalDriveObservation) then raise syntax 93.900 array('ElectricalDriveObservation required')
  axis=self~axis; relOmega=self~relativeAngularVelocity
  torque=axis*(self~torqueConstant*driveObservation~current)
  self~rotorState~applyTorque(torque)
  reacted=.false
  if self~reactionState<>.nil then do
    self~reactionState~applyTorque(torque*(-1))
    reacted=.true
  end
  emf=self~torqueConstant*relOmega
  mechPower=torque~dot(axis)*relOmega
  return .RotaryElectromechanicalActuationEvent~new(self,driveObservation,axis,torque,relOmega,emf,mechPower,reacted)

::requires 'Coupling.cls'
::requires 'Mechanics.cls'
