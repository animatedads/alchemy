/* StructuredObjectGraph.cls
   Open JSON -> ooRexx object graph projection.

   JSON object keys become callable properties through UNKNOWN.  The loader does
   not prescribe project-specific fields, which allows specifications and rule
   packages to grow without changing this projection layer.
*/

::class DFStructuredNode public
::method init
  expose values path
  use strict arg valuesArg, pathArg="$"
  values = valuesArg
  path = pathArg
::attribute path
::method keys
  expose values
  return values~allIndexes
::method at
  expose values path
  use strict arg name
  key = self~findKey(name)
  if key == .nil then return .nil
  return self~wrap(values[key], path || "." || key)
::method has
  use strict arg name
  return self~findKey(name) <> .nil
::method unknown
  use strict arg name, args
  if args~items <> 0 then raise syntax 93.900 array("Structured property calls take no arguments", name)
  value = self~at(name)
  if value == .nil then raise syntax 97.1 array(name)
  return value
::method findKey private
  expose values
  use strict arg name
  wanted = translate(name~string)
  do key over values
    if translate(key~string) = wanted then return key
  end
  return .nil
::method wrap private
  use strict arg value, childPath
  if value == .nil then return .nil
  if value~isA(.Directory) then return .DFStructuredNode~new(value, childPath)
  if value~isA(.Array) then do
    answer = .Array~new
    do i = 1 to value~items
      item = value[i]
      if item == .nil then answer~append(.nil)
      else if item~isA(.Directory) then answer~append(.DFStructuredNode~new(item, childPath || "[" || i || "]"))
      else if item~isA(.Array) then answer~append(self~wrap(item, childPath || "[" || i || "]"))
      else answer~append(item)
    end
    return answer
  end
  return value

::class DFStructuredGraphLoader public
::method fromJsonFile class
  use strict arg path
  if stream(path, "c", "query exists") == "" then raise syntax 93.900 array("JSON graph file does not exist", path)
  f = .stream~new(path)
  f~open("READ")
  text = f~charIn(, f~chars)
  f~close
  raw = .json~fromJson(text)
  if \raw~isA(.Directory) then raise syntax 93.900 array("Structured graph root must be a JSON object")
  return .DFStructuredNode~new(raw)

::requires "json.cls"
