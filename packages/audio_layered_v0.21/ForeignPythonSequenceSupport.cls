/* ForeignPythonSequenceSupport.cls - Layered Audio v0.18
 *
 * Compatibility shim between ordinary ooRexx Arrays and resident Python
 * sequence proxies. Foreign Runtime v0.22.2 gives ForeignPythonObject Rexx-
 * native ITEMS / AT / [] semantics. Domain code should use those semantics
 * rather than forcing Python lists/tuples through eager Rexxification.
 */

::class ForeignPythonSequenceSupport public

::method isSequence class
  use strict arg value
  if value == .nil then return .false
  if value~isa(.Array) then return .true
  if value~isa(.ForeignPythonObject) then return .true
  return .false

::method size class
  use strict arg value
  if \self~isSequence(value) then return -1
  return value~items

::method at class
  use strict arg value, index
  if \self~isSequence(value) then raise syntax 88.900 array('value is not an ooRexx/Python sequence')
  return value[index]

::method toArray class
  use strict arg value
  if \self~isSequence(value) then raise syntax 88.900 array('value is not an ooRexx/Python sequence')
  if value~isa(.Array) then return value
  out=.Array~new
  do i=1 to value~items
    out~append(value[i])
  end
  return out

::method closeIfProxy class
  use strict arg value
  if value \== .nil then if value~isa(.ForeignPythonObject) then value~close
  return

::requires 'python_foreign.cls'
