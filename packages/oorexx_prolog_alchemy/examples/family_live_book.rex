/* Live-state host fixture for dev9.  This file documents the executable object
 * contract used by family_live_relations.pl; native qualification requires the
 * ooRexx + SWI host build. */
::requires 'AlchemyProlog.cls'

::class FamilyBook public
::method init
  expose runtime parents sexes
  use strict arg runtime
  parents = .directory~new
  sexes = .directory~new

::method addParent
  expose parents
  use strict arg child, parent
  key = child~name
  if parents[key] == .nil then parents[key] = .array~new
  parents[key]~append(parent)
  return self

::method setSex
  expose sexes
  use strict arg person, sex
  sexes[person~name] = sex
  return self

::method parentsOf
  expose parents
  use strict arg child
  values = parents[child~name]
  if values == .nil then values = .array~new
  return .AlchemyPrologSolutionSource~new(values~supplier)

::method isFemale
  expose runtime sexes
  use strict arg person
  if sexes[person~name] == 'F' then return runtime~callbackAtom('true')
  return runtime~callbackAtom('false')

::method isMale
  expose runtime sexes
  use strict arg person
  if sexes[person~name] == 'M' then return runtime~callbackAtom('true')
  return runtime~callbackAtom('false')

::class Person public
::method init
  expose name
  use strict arg name
::method name
  expose name
  return name
