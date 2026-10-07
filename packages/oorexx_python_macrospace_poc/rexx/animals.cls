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
::class AlchemyPythonObject public subclass AlchemyForeignObject
::method foreignRuntime
  return 'python'

::attribute foreignHandle get

::method init
  expose foreignHandle foreignReleased
  use strict arg foreignHandle
  foreignReleased = .false
  self~init:super

::method uninit
  expose foreignHandle foreignReleased
  if foreignReleased == .false then do
    foreignReleased = .true
    call PYRELEASE foreignHandle
  end

::method call
  expose foreignHandle
  use strict arg methodName
  return PYCALL(foreignHandle, methodName)

::method explicitPythonFoo
  expose foreignHandle
  return PYCALL(foreignHandle, "foo")

::method installRexxFooR1
  self~setMethod("FOO", 'return "R1"', "OBJECT")
  return self

::method installRexxFooR2
  self~setMethod("FOO", 'return "R2"', "OBJECT")
  return self

::method removeRexxFoo
  self~setMethod("FOO")
  return self

::method pythonClass
  expose foreignHandle
  encoded = PYTYPEQUERY(foreignHandle, "CLASS")
  if encoded~left(9) \== "@PYCLASS:" then raise syntax 93.900 array ("Python class query failed")
  return .AlchemyPythonClass~new(encoded~substr(10))

::method isInstanceOfPython
  expose foreignHandle
  use strict arg foreignClass
  if \ foreignClass~isInstanceOf(.AlchemyPythonClass) then raise syntax 93.900 array ("expected PythonClassProxy")
  return PYTYPERELATION(foreignHandle, foreignClass~foreignHandle, "INSTANCE") == "1"

/* Deliberately no describe/speak/etc methods.  Any message not implemented by
 * this Rexx proxy lands here.  UNKNOWN receives the original message name and
 * argument array; v0.4 proves the zero-argument case and forwards the name to
 * the retained Python object. */
::method unknown
  expose foreignHandle
  use strict arg messageName, arguments

  packet = self~encodePythonArguments(arguments)
  result = PYCALL(foreignHandle, messageName, packet)

  /* A non-scalar Python return is represented by an identity-preserving
   * foreign handle and immediately becomes another ordinary Rexx proxy. */
  if result~left(9) == "@PYCLASS:" then
    return .AlchemyPythonClass~new(result~substr(10))
  if result~left(7) == "@PYOBJ:" then
    return .AlchemyPythonObject~new(result~substr(8))
  return result

::method retainRexxArgument private external "LIBRARY rexxpython_poc RETAIN_REXX_ARGUMENT"

::method encodePythonArguments private
  use strict arg arguments
  packet = "@ARGS:"
  do i = 1 to arguments~items
    value = arguments[i]
    if value~isInstanceOf(.AlchemyPythonClass) then encoded = "C:" || value~foreignHandle
    else if value~isInstanceOf(.AlchemyPythonObject) then encoded = "P:" || value~foreignHandle
    else if value~isInstanceOf(.String) then do
      if value~datatype("W") then encoded = "I:" || value
      else encoded = "S:" || value~string
    end
    else encoded = "R:" || self~retainRexxArgument(value)
    packet ||= encoded~length || ":" || encoded
  end
  return packet

::class AlchemyPythonClass public subclass AlchemyForeignObject
::method foreignRuntime
  return 'python'

::attribute foreignHandle get
::method init
  expose foreignHandle foreignReleased
  use strict arg foreignHandle
  foreignReleased = .false
  self~init:super

::method uninit
  expose foreignHandle foreignReleased
  if foreignReleased == .false then do
    foreignReleased = .true
    call PYRELEASE foreignHandle
  end

/* Family-facing class loader.  The result is an ordinary Rexx object that is
 * operated with Rexx messages, while Python remains authoritative for class
 * identity, inheritance, descriptors and construction. */
::method loadCls class
  use strict arg moduleName, qualifiedName, pathText = ""
  encoded = PYCLASSLOAD(moduleName, qualifiedName, pathText)
  if encoded~left(9) \== "@PYCLASS:" then
    raise syntax 93.900 array ("Python class load failed", moduleName, qualifiedName, encoded)
  cls = self~new(encoded~substr(10))
  if pathText \== "" then cls~addClsPath(pathText)
  return cls

::method resolveCls class
  use strict arg moduleName, qualifiedName, pathText = ""
  return self~loadCls(moduleName, qualifiedName, pathText)

/* A projected Python class is callable through the normal Rexx NEW spelling.
 * Keep the current bridge's bounded scalar codec; widening argument semantics
 * is independent of class projection. */
::method new
  expose foreignHandle
  arguments = .array~new
  do i = 1 to arg()
    arguments[i] = arg(i)
  end
  packet = self~encodePythonArguments(arguments)
  encoded = PYCLASSCONSTRUCT(foreignHandle, packet)
  if encoded~left(7) \== "@PYOBJ:" then raise syntax 93.900 array ("Python construction failed", encoded)
  object = .AlchemyPythonObject~new(encoded~substr(8))
  object~inheritClsPath(self)
  return object

::method retainRexxArgument private external "LIBRARY rexxpython_poc RETAIN_REXX_ARGUMENT"

::method encodePythonArguments private
  use strict arg arguments
  packet = "@ARGS:"
  do i = 1 to arguments~items
    value = arguments[i]
    if value~isInstanceOf(.AlchemyPythonClass) then encoded = "C:" || value~foreignHandle
    else if value~isInstanceOf(.AlchemyPythonObject) then encoded = "P:" || value~foreignHandle
    else if value~isInstanceOf(.String) then do
      if value~datatype("W") then encoded = "I:" || value
      else encoded = "S:" || value~string
    end
    else encoded = "R:" || self~retainRexxArgument(value)
    packet ||= encoded~length || ":" || encoded
  end
  return packet

::method isSubclassOf
  expose foreignHandle
  use strict arg other
  if \ other~isInstanceOf(.AlchemyPythonClass) then raise syntax 93.900 array ("expected AlchemyPythonClass")
  return PYTYPERELATION(foreignHandle, other~foreignHandle, "SUBCLASS") == "1"
::method qualifiedName
  expose foreignHandle
  return PYTYPEQUERY(foreignHandle, "INFO")
::method directBases
  expose foreignHandle
  return self~classList("BASES")
::method mro
  expose foreignHandle
  return self~classList("MRO")
::method classList private
  expose foreignHandle
  use strict arg operation
  raw = PYTYPEQUERY(foreignHandle, operation)
  out = .array~new
  if raw == "" then return out
  do token over raw~makeArray(",")
    cls = .AlchemyPythonClass~new(token)
    cls~inheritClsPath(self)
    out~append(cls)
  end
  return out

/* Class/static methods use the same live Python attribute lookup as instance
 * projection.  This intentionally does not snapshot the Python method table. */
::method unknown
  expose foreignHandle
  use strict arg messageName, arguments
  packet = self~encodePythonArguments(arguments)
  result = PYCALL(foreignHandle, messageName, packet)
  if result~left(9) == "@PYCLASS:" then do
    cls = .AlchemyPythonClass~new(result~substr(10))
    cls~inheritClsPath(self)
    return cls
  end
  if result~left(7) == "@PYOBJ:" then do
    object = .AlchemyPythonObject~new(result~substr(8))
    object~inheritClsPath(self)
    return object
  end
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
  do 8
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

::method concurrentPing unguarded
  expose gate ticks
  return "PING:" || gate || ":" || ticks


/* v0.16: prove that projection can coexist with a class that already owns
 * UNKNOWN.  The original Method object is preserved under an object-local,
 * generated private selector before the bridge UNKNOWN is installed. */
::class ExistingUnknownThing public subclass AlchemyForeignObject
::attribute foreignHandle
::attribute projectedNames
::method init
  self~init:super
::method foreignRuntime
  return 'python'

::method known
  return "REXX-KNOWN"

::method unknown
  use strict arg messageName, arguments
  return "ORIGINAL-UNKNOWN:" || messageName || ":" || arguments~items

/* This method is compiled normally with the package, so PYCALL has exactly
 * the same visibility as PythonObjectProxy~UNKNOWN.  INSTALLPYTHONPROJECTION
 * installs this existing Method object under the UNKNOWN selector. */
::method bridgeUnknown
  expose foreignHandle projectedNames
  use strict arg messageName, arguments
  if wordpos(messageName~upper, projectedNames) > 0 then do
    if arguments~items <> 0 then
      raise syntax 93.900 array ("projected collision test accepts zero arguments")
    return PYCALL(foreignHandle, messageName)
  end
  return self~foreignUnknownFallback(messageName, arguments)

::method installPythonProjection
  expose foreignHandle projectedNames
  use strict arg handle, names
  foreignHandle = handle
  projectedNames = names~upper
  return self~installForeignUnknownComposition("BRIDGEUNKNOWN")

::requires 'AlchemyForeignObject.cls'
