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

::method describe
  expose foreignHandle
  return PYCALL(foreignHandle, "describe")

::method speak
  expose foreignHandle
  return PYCALL(foreignHandle, "speak")

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
