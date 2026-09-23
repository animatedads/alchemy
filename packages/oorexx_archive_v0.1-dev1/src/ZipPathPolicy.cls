/*----------------------------------------------------------------------------*/
/* Cross-platform conservative ZIP path policy for package archives.          */
/*                                                                            */
/* It rejects names whose filesystem interpretation is ambiguous or unsafe on */
/* common POSIX/Windows targets.  It intentionally does not attempt Unicode   */
/* normalization in dev1; exact and ASCII-case-fold collisions are rejected.  */
/*----------------------------------------------------------------------------*/
::class ZipPathPolicy public

::method validate
  use strict arg name, isDirectory = .false
  if name == '' then self~reject('empty ZIP entry name')
  if pos('00'x, name) > 0 then self~reject('NUL byte in ZIP entry name')
  if left(name, 1) == '/' | left(name, 1) == '\\' then self~reject('absolute ZIP entry path: ' || name)
  if pos('\\', name) > 0 then self~reject('backslash is not permitted in portable package entry names: ' || name)
  if length(name) >= 2 then do
    first = translate(left(name, 1))
    if first >= 'A' & first <= 'Z' & substr(name, 2, 1) == ':' then self~reject('drive-qualified ZIP entry path: ' || name)
  end

  work = name
  if isDirectory & right(work, 1) == '/' then work = left(work, length(work) - 1)
  if work == '' then self~reject('root directory entry is not permitted')

  do while work \== ''
    parse var work segment '/' work
    if segment == '' then self~reject('empty path segment in ZIP entry: ' || name)
    if segment == '.' | segment == '..' then self~reject('dot traversal segment in ZIP entry: ' || name)
    if pos(':', segment) > 0 then self~reject('colon is not permitted in portable package entry names: ' || name)
    if right(segment, 1) == ' ' | right(segment, 1) == '.' then -
      self~reject('trailing dot/space is not permitted in portable package entry names: ' || name)
    do i = 1 to length(segment)
      b = c2d(substr(segment, i, 1))
      if b < 32 | b = 127 then self~reject('control byte in ZIP entry name: ' || name)
    end
    self~rejectWindowsDevice(segment, name)
  end
  return .true

::method collisionKey
  use strict arg name
  /* ZIP separator is '/', and translate() gives us an ASCII case-fold guard. */
  if right(name, 1) == '/' then name = left(name, length(name) - 1)
  return translate(name)

::method parentNames
  use strict arg name
  out = .array~new
  if right(name, 1) == '/' then name = left(name, length(name) - 1)
  current = ''
  rest = name
  do while pos('/', rest) > 0
    parse var rest segment '/' rest
    if current == '' then current = segment
    else current ||= '/' || segment
    out~append(current)
  end
  return out

::method rejectWindowsDevice private
  use strict arg segment, fullName
  upper = translate(segment)
  parse var upper base '.' .
  if base == 'CON' | base == 'PRN' | base == 'AUX' | base == 'NUL' then -
    self~reject('Windows device name is not permitted in portable package entry: ' || fullName)
  if length(base) == 4 then do
    prefix = left(base, 3)
    digit = right(base, 1)
    if (prefix == 'COM' | prefix == 'LPT') & digit >= '1' & digit <= '9' then -
      self~reject('Windows device name is not permitted in portable package entry: ' || fullName)
  end
  return

::method reject private
  use strict arg message
  raise syntax 88.900 array(message)
