/*
 * CivicPort v0.3 JSON decode + explicit mapping support.
 *
 * JSON is decoded only when the response media type declares JSON.
 * Mapping uses explicit JSON Pointer paths; there is no schema inference,
 * recursive flattening, reflection, or repair of malformed payloads.
 */

::class CivicJsonDecodeResult subclass CivicAlchemyObject public
::attribute parsed get
::attribute status get
::attribute message get

::method init
  expose parsed status message
  use arg parsedArg, statusArg, messageArg = ""
  ignore = self~initCivicAlchemy
  parsed = parsedArg
  status = statusArg~string~translate
  message = messageArg~string


::class CivicJsonDecoder subclass CivicAlchemyObject public
::method decode
  use arg headerMap, bodyBytes
  contentType = headerMap~first("Content-Type")
  if contentType == .nil then return .CivicJsonDecodeResult~new(.nil, "UNSUPPORTED", "Content-Type does not declare JSON")
  mediaType = contentType~string
  semi = mediaType~pos(";")
  if semi > 0 then mediaType = mediaType~left(semi - 1)
  mediaType = mediaType~strip~lower
  if mediaType \= "application/json" & mediaType~right(5) \= "+json" then -
    return .CivicJsonDecodeResult~new(.nil, "UNSUPPORTED", "Content-Type does not declare JSON")

  signal on syntax name jsonError
  tree = .JSON~fromJSON(bodyBytes)
  signal off syntax
  return .CivicJsonDecodeResult~new(tree, "OK", "")

jsonError:
  info = condition("O")
  signal off syntax
  detail = "JSON parse failed"
  if info \== .nil then do
    messageText = info~at("MESSAGE")
    if messageText \== .nil then do
      if messageText~string \= "" then detail = messageText~string
    end
  end
  return .CivicJsonDecodeResult~new(.nil, "INVALID", detail)


::class CivicJsonPointerResult subclass CivicAlchemyObject public
::attribute present get
::attribute value get
::attribute errorCode get
::attribute message get

::method found class
  use arg value
  return .CivicJsonPointerResult~new(.true, value, "", "")

::method missing class
  use arg code, message
  return .CivicJsonPointerResult~new(.false, .nil, code, message)

::method init
  expose present value errorCode message
  use arg presentArg, valueArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  present = presentArg
  value = valueArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicJsonPointer subclass CivicAlchemyObject public
::method evaluate class
  use arg root, pointer
  path = pointer~string
  if path = "" then return .CivicJsonPointerResult~found(root)
  if path~left(1) \= "/" then return .CivicJsonPointerResult~missing("POINTER_INVALID", "JSON Pointer must be empty or start with /")

  current = root
  remainder = path~substr(2)
  do forever
    slash = remainder~pos("/")
    if slash = 0 then do
      rawToken = remainder
      remainder = .nil
    end
    else do
      rawToken = remainder~left(slash - 1)
      remainder = remainder~substr(slash + 1)
    end

    tokenResult = self~decodeToken(rawToken)
    if \tokenResult~present then return tokenResult
    token = tokenResult~value

    if current~isA(.Directory) then do
      if \current~hasIndex(token) then return .CivicJsonPointerResult~missing("POINTER_MISSING", "Object member missing at " || path)
      current = current[token]
    end
    else if current~isA(.Array) then do
      if token = "" | \datatype(token, "W") then return .CivicJsonPointerResult~missing("POINTER_TYPE", "Array token must be a non-negative integer")
      zeroIndex = token + 0
      if zeroIndex < 0 then return .CivicJsonPointerResult~missing("POINTER_RANGE", "Array index is negative")
      oneIndex = zeroIndex + 1
      if oneIndex > current~items then return .CivicJsonPointerResult~missing("POINTER_MISSING", "Array index is outside the document")
      current = current[oneIndex]
    end
    else return .CivicJsonPointerResult~missing("POINTER_TYPE", "JSON Pointer attempted to traverse a scalar value")

    if remainder == .nil then leave
  end
  return .CivicJsonPointerResult~found(current)

::method decodeToken class private
  use arg raw
  output = ""
  i = 1
  do while i <= raw~length
    ch = raw~substr(i, 1)
    if ch \= "~" then do
      output = output || ch
      i = i + 1
      iterate
    end
    if i = raw~length then return .CivicJsonPointerResult~missing("POINTER_ESCAPE", "JSON Pointer token ends with bare ~")
    esc = raw~substr(i + 1, 1)
    if esc = "0" then output = output || "~"
    else if esc = "1" then output = output || "/"
    else return .CivicJsonPointerResult~missing("POINTER_ESCAPE", "JSON Pointer contains unsupported ~ escape")
    i = i + 2
  end
  return .CivicJsonPointerResult~found(output)


::class CivicJsonType subclass CivicAlchemyObject public
::method matches class
  use arg value, expectedType
  kind = expectedType~string~translate
  select
    when kind = "ANY" then return .true
    when kind = "NULL" then return value == .nil
    when kind = "OBJECT" then return value \== .nil & value~isA(.Directory)
    when kind = "ARRAY" then return value \== .nil & value~isA(.Array)
    when kind = "BOOLEAN" then return value \== .nil & value~isA(.JsonBoolean)
    when kind = "STRING" then return value \== .nil & value~isA(.JsonString)
    when kind = "NUMBER" then do
      if value == .nil then return .false
      if value~isA(.JsonString) | value~isA(.JsonBoolean) then return .false
      if value~isA(.Directory) | value~isA(.Array) then return .false
      return datatype(value~string, "N")
    end
    otherwise return .false
  end


::class CivicJsonField subclass CivicAlchemyObject public
::attribute name get
::attribute pointer get
::attribute required get
::attribute expectedType get
::attribute nullable get

::method init
  expose name pointer required expectedType nullable
  use arg nameArg, pointerArg, requiredArg = .false, expectedTypeArg = "ANY", nullableArg = .false
  ignore = self~initCivicAlchemy
  name = nameArg~string
  pointer = pointerArg~string
  required = requiredArg
  expectedType = expectedTypeArg~string~translate
  nullable = nullableArg
  if name = "" then raise syntax 93.900 additional("CivicJsonField requires a projection name")
  if pointer \= "" & pointer~left(1) \= "/" then raise syntax 93.900 additional("CivicJsonField pointer must be empty or start with /")


::class CivicJsonMappingResult subclass CivicAlchemyObject public
::attribute ok get
::attribute status get
::attribute row get
::attribute errorCode get
::attribute message get
::attribute document get
::attribute mappingId get
::attribute sourcePointer get

::method success class
  use arg document, mappingId, row, sourcePointer = ""
  return .CivicJsonMappingResult~new(.true, "OK", row, "", "", document, mappingId, sourcePointer)

::method invalid class
  use arg document, mappingId, code, message, sourcePointer = ""
  return .CivicJsonMappingResult~new(.false, "INVALID", .nil, code, message, document, mappingId, sourcePointer)

::method init
  expose ok status row errorCode message document mappingId sourcePointer
  use arg okArg, statusArg, rowArg, codeArg, messageArg, documentArg, mappingIdArg, sourcePointerArg = ""
  ignore = self~initCivicAlchemy
  ok = okArg
  status = statusArg~string~translate
  row = rowArg
  errorCode = codeArg~string
  message = messageArg~string
  document = documentArg
  mappingId = mappingIdArg~string
  sourcePointer = sourcePointerArg~string
  if sourcePointer \= "" & sourcePointer~left(1) \= "/" then raise syntax 93.900 additional("CivicJsonMappingResult source pointer must be empty or start with /")


::class CivicJsonCollectionMappingResult subclass CivicAlchemyObject public
::attribute ok get
::attribute status get
::attribute errorCode get
::attribute message get
::attribute document get
::attribute mappingId get

::method success class
  use arg document, mappingId, items
  return .CivicJsonCollectionMappingResult~new(.true, "OK", items, "", "", document, mappingId)

::method invalid class
  use arg document, mappingId, code, message
  return .CivicJsonCollectionMappingResult~new(.false, "INVALID", .array~new, code, message, document, mappingId)

::method init
  expose ok status storedItems errorCode message document mappingId
  use arg okArg, statusArg, itemsArg, codeArg, messageArg, documentArg, mappingIdArg
  ignore = self~initCivicAlchemy
  ok = okArg
  status = statusArg~string~translate
  storedItems = .array~new
  if itemsArg \== .nil then do item over itemsArg
    storedItems~append(item)
  end
  errorCode = codeArg~string
  message = messageArg~string
  document = documentArg
  mappingId = mappingIdArg~string

::method items
  expose storedItems
  copied = .array~new
  do item over storedItems
    copied~append(item)
  end
  return copied


::class CivicJsonMapping subclass CivicAlchemyObject public
::attribute mappingId get

::method init
  expose mappingId fields
  use arg mappingIdArg
  ignore = self~initCivicAlchemy
  mappingId = mappingIdArg~string
  fields = .array~new
  if mappingId = "" then raise syntax 93.900 additional("CivicJsonMapping requires a mapping id")

::method addField
  expose fields
  use arg name, pointer, required = .false, expectedType = "ANY", nullable = .false
  field = .CivicJsonField~new(name, pointer, required, expectedType, nullable)
  fields~append(field)
  return field

::method fields
  expose fields
  copyFields = .array~new
  do field over fields
    copyFields~append(field)
  end
  return copyFields

::method map
  use arg document
  return self~mapAt(document, "")

::method mapAt
  expose mappingId
  use arg document, sourcePointer = ""
  if document == .nil then return .CivicJsonMappingResult~invalid(.nil, mappingId, "DOCUMENT_MISSING", "CivicDocument is required", sourcePointer)
  if document~parseStatus \= "OK" then return .CivicJsonMappingResult~invalid(document, mappingId, "DOCUMENT_NOT_VALID_JSON", "Document parse status is " || document~parseStatus, sourcePointer)

  tree = document~parsed
  if tree == .nil then return .CivicJsonMappingResult~invalid(document, mappingId, "DOCUMENT_TREE_MISSING", "Parsed JSON tree is absent", sourcePointer)
  if sourcePointer \= "" then do
    sourceResult = .CivicJsonPointer~evaluate(tree, sourcePointer)
    if \sourceResult~present then return .CivicJsonMappingResult~invalid(document, mappingId, "SOURCE_POINTER_MISSING", "Collection source missing at " || sourcePointer, sourcePointer)
    tree = sourceResult~value
  end
  return self~mapTree(document, tree, sourcePointer)

::method mapTree
  expose mappingId fields
  use arg document, tree, sourcePointer = ""
  if tree == .nil then return .CivicJsonMappingResult~invalid(document, mappingId, "SOURCE_TREE_MISSING", "Mapping source tree is absent", sourcePointer)
  row = .directory~new
  do field over fields
    pointerResult = .CivicJsonPointer~evaluate(tree, field~pointer)
    if \pointerResult~present then do
      if field~required then return .CivicJsonMappingResult~invalid(document, mappingId, "SCHEMA_REQUIRED_MISSING", field~name || " missing at " || self~fullPointer(sourcePointer, field~pointer), sourcePointer)
      row[field~name] = .nil
      iterate
    end
    value = pointerResult~value
    if value == .nil & field~nullable then do
      row[field~name] = .nil
      iterate
    end
    if \ .CivicJsonType~matches(value, field~expectedType) then -
      return .CivicJsonMappingResult~invalid(document, mappingId, "SCHEMA_TYPE_MISMATCH", field~name || " expected " || field~expectedType || " at " || self~fullPointer(sourcePointer, field~pointer), sourcePointer)
    row[field~name] = value
  end
  return self~validateMapped(document, row, sourcePointer)

::method fullPointer
  use arg sourcePointer, fieldPointer
  sourceText = sourcePointer~string
  fieldText = fieldPointer~string
  if sourceText = "" then return fieldText
  if fieldText = "" then return sourceText
  return sourceText || fieldText

::method validateMapped protected
  expose mappingId
  use arg document, row, sourcePointer = ""
  return .CivicJsonMappingResult~success(document, mappingId, row, sourcePointer)

::requires "json.cls"

::requires "CivicAlchemy.cls"
