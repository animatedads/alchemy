::class Animal public
::constant KINGDOM "Animalia"
::attribute name
::attribute species
::attribute sound

::method init
  expose name species sound
  use strict arg name, species, sound

::method describe
  expose name species
  return name || " is a " || species

::method speak
  expose name sound
  return name || " says " || sound

::class AnimalCollection public
::method init
  expose animals
  animals = .array~new

::method add
  expose animals
  use strict arg animal
  animals~append(animal)
  return animals~items

::method count
  expose animals
  return animals~items

::method at
  expose animals
  use strict arg index
  return animals[index]

::method descriptions
  expose animals
  out = .array~new
  do animal over animals
    out~append(animal~describe)
  end
  return out

::method descriptionText
  expose animals
  text = ""
  do animal over animals
    if text <> "" then text ||= " | "
    text ||= animal~describe
  end
  return text

/* Exercise ooRexx ~~ itself.  The second member in the POC is the Python
 * proxy.  MIDNIGHT_SNACK returns a Python string, but ~~ must return the
 * original receiver; the following ~DESCRIBE therefore targets that same
 * proxy and crosses UNKNOWN a second time. */
::method doubleTildeProbe
  expose animals
  object = animals[2]
  returned = object~~midnight_snack
  same = (returned == object)
  return same || "|" || returned~describe

::class Alarm public
::attribute message

::method init
  expose message
  use strict arg message

::method ring
  expose message
  /* PYALARM is intentionally resolved through ooRexx Macrospace. */
  return PYALARM(message)

/* A deliberately tiny foreign-object holder.  The Python object remains owned
 * by Python; ooRexx stores this proxy object in an ordinary Rexx collection. */
::class PythonObjectProxy public
::attribute foreignHandle get

::method init
  expose foreignHandle
  use strict arg foreignHandle

::method call
  expose foreignHandle
  use strict arg methodName
  return PYCALL(foreignHandle, methodName)

/* Deliberately no describe/speak/etc methods.  Any message not implemented by
 * this Rexx proxy lands here.  UNKNOWN receives the original message name and
 * argument array; v0.4 proves the zero-argument case and forwards the name to
 * the retained Python object. */
::method unknown
  expose foreignHandle
  use strict arg messageName, arguments

  /* Deliberately bounded POC marshalling: zero, one or two scalar arguments.
   * Integer-looking Rexx values are tagged I:, everything else S:. */
  select
    when arguments~items == 0 then result = PYCALL(foreignHandle, messageName)
    when arguments~items == 1 then do
      a1 = arguments[1]
      if a1~datatype("W") then a1 = "I:" || a1
      else a1 = "S:" || a1~string
      result = PYCALL(foreignHandle, messageName, a1)
    end
    when arguments~items == 2 then do
      a1 = arguments[1]
      a2 = arguments[2]
      if a1~datatype("W") then a1 = "I:" || a1
      else a1 = "S:" || a1~string
      if a2~datatype("W") then a2 = "I:" || a2
      else a2 = "S:" || a2~string
      result = PYCALL(foreignHandle, messageName, a1, a2)
    end
    otherwise raise syntax 93.900 array ("v0.8 POC forwards at most two scalar arguments")
  end

  /* A non-scalar Python return is represented by an identity-preserving
   * foreign handle and immediately becomes another ordinary Rexx proxy. */
  if result~left(7) == "@PYOBJ:" then
    return .PythonObjectProxy~new(result~substr(8))
  return result

::class ObjectCollection public
::method init
  expose objects
  objects = .array~new

::method add
  expose objects
  use strict arg object
  objects~append(object)
  return objects~items

::method count
  expose objects
  return objects~items

::method at
  expose objects
  use strict arg index
  return objects[index]

::method callAt
  expose objects
  use strict arg index, methodName
  return objects[index]~call(methodName)


/* v0.10: deliberately small ooRexx concurrency/guard experiment.
 * INIT starts a Rexx-side asynchronous loop.  GUARDEDVALUE waits on an
 * object-variable guard.  Python calls GUARDEDVALUE synchronously through
 * the existing retained-object bridge; the Rexx START'ed activity opens the
 * gate later.  No Python thread is used to make the guard become true. */
::class GuardedAnimal public
::attribute name get

::method init
  expose name gate ticks
  use strict arg name
  gate = .false
  ticks = 0
  self~start("GATELOOP")

::method gateLoop unguarded
  expose gate ticks
  do 4
    call SysSleep .10
    ticks += 1
  end
  gate = .true
  return ticks

::method guardedValue guarded
  expose gate ticks name
  guard on when gate
  return name || " released after " || ticks || " ticks"

::method gateState unguarded
  expose gate ticks
  return gate || ":" || ticks
