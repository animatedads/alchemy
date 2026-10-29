/* Rexx-tronics experiment comparison preflight, dev29 review source.
 * Does not compute numerical differences. Maths/Units retain that authority.
 * A result is comparable only when every declared experimental coordinate
 * agrees. Unknown/missing coordinates fail closed.
 */
::class RexxTronicsComparisonSample public
::attribute value get
::attribute dimension get
::attribute method get
::attribute excitation get
::attribute window get
::attribute solver get
::attribute instrument get
::method init
  expose value dimension method excitation window solver instrument
  use strict arg valueArg,dimensionArg,methodArg,excitationArg,windowArg,solverArg,instrumentArg
  if valueArg==.nil then raise syntax 93.900 array('comparison requires a measured value')
  if dimensionArg=='' | methodArg=='' | excitationArg=='' | windowArg=='' | solverArg=='' | instrumentArg=='' then -
    raise syntax 93.900 array('comparison requires all provenance coordinates')
  value=valueArg
  dimension=dimensionArg~string
  method=methodArg~string
  excitation=excitationArg~string
  window=windowArg~string
  solver=solverArg~string
  instrument=instrumentArg~string

::class RexxTronicsComparisonGate public
::method compatible
  use strict arg a,b
  if a==.nil | b==.nil then return .false
  if a~dimension \== b~dimension then return .false
  if a~method \== b~method then return .false
  if a~excitation \== b~excitation then return .false
  if a~window \== b~window then return .false
  if a~solver \== b~solver then return .false
  if a~instrument \== b~instrument then return .false
  return .true
::method requireCompatible
  use strict arg a,b
  if \self~compatible(a,b) then raise syntax 93.900 array('incompatible experimental measurements')
  return .true
