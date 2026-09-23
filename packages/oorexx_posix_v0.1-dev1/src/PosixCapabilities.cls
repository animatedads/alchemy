/* ooRexx POSIX Foundation v0.1-dev1 - capability set. */

::class PosixCapabilities public

::method init
  expose capMap capOrder
  capMap = .directory~new
  capOrder = .array~new
  use strict arg initial = .nil
  if initial \== .nil then do name over initial
    self~add(name)
  end

::method add
  expose capMap capOrder
  use strict arg name
  name = name~string
  if name == '' then raise syntax 88.900 array('capability name must not be empty')
  if capMap[name] == .nil then do
    capMap[name] = .true
    capOrder~append(name)
  end
  return self

::method has
  expose capMap
  use strict arg name
  return capMap[name~string] \== .nil

::method names
  expose capOrder
  a = .array~new
  do name over capOrder
    a~append(name)
  end
  return a

::method items
  expose capOrder
  return capOrder~items

::method string
  expose capOrder
  s = ''
  do name over capOrder
    if s \== '' then s ||= ', '
    s ||= name
  end
  return s
