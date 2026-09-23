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
  if arguments~items <> 0 then
    raise syntax 93.900 array ("v0.4 UNKNOWN POC only forwards zero-argument messages")
  return PYCALL(foreignHandle, messageName)

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
