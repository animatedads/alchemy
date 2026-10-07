/* Physics World dev28: compose static lateral payload equilibrium with a
   contained-fluid load report. The fluid mass is represented once in the
   static model (normally centred); this class adds only the fluid solver's
   resolved dynamic roll torque, never a second copy of fluid weight. */
::class AircraftFluidLateralLoadModel public
::method init
 expose _track
 use strict arg trackWidth
 if trackWidth<=0 then raise syntax 88.900 array('positive track width required')
 _track=trackWidth+0

::method resolve
 expose _track
 use strict arg staticObservation,fluidLoadReport
 return self~resolveMoment(staticObservation,fluidLoadReport~localTorque~z)

::method resolveMoment
 expose _track
 use strict arg staticObservation,dynamicFluidRollMoment
 total=staticObservation~portLoad+staticObservation~starboardLoad
 moment=staticObservation~rollMoment+dynamicFluidRollMoment
 port=total/2+moment/_track
 starboard=total-port
 if port<0 | starboard<0 then raise syntax 88.900 array('negative gear reaction; combined static/fluid two-sided contact invalid')
 return .AircraftFluidLateralLoadObservation~new(total,staticObservation~rollMoment,dynamicFluidRollMoment,moment,port,starboard)

::class AircraftFluidLateralLoadObservation public
::method init
 expose _total _static _fluid _combined _port _starboard
 use strict arg totalLoad,staticRollMoment,fluidRollMoment,combinedRollMoment,portLoad,starboardLoad
 _total=totalLoad;_static=staticRollMoment;_fluid=fluidRollMoment;_combined=combinedRollMoment;_port=portLoad;_starboard=starboardLoad
::method totalLoad; expose _total; return _total
::method staticRollMoment; expose _static; return _static
::method fluidRollMoment; expose _fluid; return _fluid
::method combinedRollMoment; expose _combined; return _combined
::method portLoad; expose _port; return _port
::method starboardLoad; expose _starboard; return _starboard

::requires 'AircraftStaticLateralLoads.cls'
