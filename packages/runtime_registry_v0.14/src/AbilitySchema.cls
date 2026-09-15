/* Ability Schema v0.1
 *
 * Immutable, enforceable JSON Schema fragments for AbilityDescriptor.
 *
 * This deliberately implements a bounded subset rather than accepting schema
 * keywords that the runtime does not enforce.  Supported validation keywords:
 *
 *   type
 *   properties
 *   required
 *   additionalProperties
 *   items
 *   enum
 *   const
 *   minimum / maximum
 *   minLength / maxLength
 *   minItems / maxItems
 *
 * Annotation-only keywords:
 *   title / description
 *
 * Schemas are copied on ingress and egress.  The canonical text is stable
 * across Directory insertion order and participates in profile identity.
 */

::class AbilitySchemaBuild public
::constant PRODUCT "ooRexx Ability Schema"
::constant RELEASE "0.1"
::constant DIALECT "ability.schema/0.1"

::class AbilityJsonSchema public

::method init
  expose schema canonicalText
  use arg source = .nil
  if source == .nil then source = .directory~new
  definitionCheck = .AbilitySchemaSupport~validateDefinition(source, "$")
  if \definitionCheck~ok then raise syntax 88.900 array(definitionCheck~code || ": " || definitionCheck~detail)
  schema = .AbilitySchemaSupport~deepCopy(source)
  canonicalText = .AbilitySchemaSupport~canonicalJson(schema)

::method document
  expose schema
  return .AbilitySchemaSupport~deepCopy(schema)

::method canonicalText
  expose canonicalText
  return canonicalText

::method isAny
  expose canonicalText
  return canonicalText = "{}"

::method validate
  expose schema
  use arg value
  return .AbilitySchemaSupport~validateValue(schema, value, "$")

::method genericObject class
  schema = .directory~new
  schema["type"] = "object"
  schema["additionalProperties"] = .JSONBoolean~true
  return self~new(schema)

::method any class
  return self~new(.directory~new)

::method fromJson class
  use arg text
  signal on syntax name schemaJsonError
  value = .JSON~fromJSON(text)
  signal off syntax
  if \value~isa(.Directory) then return .RuntimeResult~failure("ABILITY_SCHEMA_ROOT_INVALID", "schema root must be a JSON object")
  signal on syntax name schemaDefinitionError
  schema = self~new(value)
  signal off syntax
  return .RuntimeResult~success(schema, "ability schema parsed")

schemaJsonError:
  info = condition("O")
  signal off syntax
  detail = "schema JSON parse failed"
  if info \== .nil then do
    message = info~at("MESSAGE")
    if message \== .nil then do
      if message <> "" then detail = message
    end
  end
  return .RuntimeResult~failure("ABILITY_SCHEMA_JSON_INVALID", detail)

schemaDefinitionError:
  info = condition("O")
  signal off syntax
  detail = "schema definition invalid"
  if info \== .nil then do
    message = info~at("MESSAGE")
    if message \== .nil then message = info~description
    if message \== .nil then do
      if message <> "" then detail = message
    end
  end
  return .RuntimeResult~failure("ABILITY_SCHEMA_DEFINITION_INVALID", detail)


::class AbilitySchemaSupport private

::method validateDefinition class
  use arg schema, path = "$"
  if \schema~isa(.Directory) then return .RuntimeResult~failure("ABILITY_SCHEMA_OBJECT_REQUIRED", path)

  allowed = .table~new
  allowed["type"] = .true
  allowed["properties"] = .true
  allowed["required"] = .true
  allowed["additionalProperties"] = .true
  allowed["items"] = .true
  allowed["enum"] = .true
  allowed["const"] = .true
  allowed["minimum"] = .true
  allowed["maximum"] = .true
  allowed["minLength"] = .true
  allowed["maxLength"] = .true
  allowed["minItems"] = .true
  allowed["maxItems"] = .true
  allowed["title"] = .true
  allowed["description"] = .true

  supplier = schema~supplier
  do while supplier~available
    key = supplier~index~string
    if allowed~at(key) == .nil then return .RuntimeResult~failure("ABILITY_SCHEMA_KEYWORD_UNSUPPORTED", path || ":" || key)
    supplier~next
  end

  typeName = schema~at("type")
  if typeName \== .nil then do
    if \self~isStringValue(typeName) then return .RuntimeResult~failure("ABILITY_SCHEMA_TYPE_INVALID", path)
    typeText = typeName~string
    if \self~supportedType(typeText) then return .RuntimeResult~failure("ABILITY_SCHEMA_TYPE_UNSUPPORTED", path || ":" || typeText)
  end

  title = schema~at("title")
  if title \== .nil then do
    if \self~isStringValue(title) then return .RuntimeResult~failure("ABILITY_SCHEMA_ANNOTATION_INVALID", path || ":title")
  end
  description = schema~at("description")
  if description \== .nil then do
    if \self~isStringValue(description) then return .RuntimeResult~failure("ABILITY_SCHEMA_ANNOTATION_INVALID", path || ":description")
  end

  properties = schema~at("properties")
  if properties \== .nil then do
    if \properties~isa(.Directory) then return .RuntimeResult~failure("ABILITY_SCHEMA_PROPERTIES_INVALID", path)
    propSupplier = properties~supplier
    do while propSupplier~available
      propName = propSupplier~index~string
      child = propSupplier~item
      childCheck = self~validateDefinition(child, path || ".properties." || propName)
      if \childCheck~ok then return childCheck
      propSupplier~next
    end
  end

  required = schema~at("required")
  if required \== .nil then do
    if \required~isa(.Array) then return .RuntimeResult~failure("ABILITY_SCHEMA_REQUIRED_INVALID", path)
    seenRequired = .table~new
    do i = 1 to required~items
      name = required~at(i)
      if \self~isStringValue(name) then return .RuntimeResult~failure("ABILITY_SCHEMA_REQUIRED_INVALID", path || "[" || i || "]")
      nameText = name~string
      if seenRequired~at(nameText) \== .nil then return .RuntimeResult~failure("ABILITY_SCHEMA_REQUIRED_DUPLICATE", path || ":" || nameText)
      seenRequired[nameText] = .true
    end
  end

  additional = schema~at("additionalProperties")
  if additional \== .nil then do
    if \additional~isa(.JSONBoolean) then do
      if \additional~isa(.Directory) then return .RuntimeResult~failure("ABILITY_SCHEMA_ADDITIONAL_PROPERTIES_INVALID", path)
      childCheck = self~validateDefinition(additional, path || ".additionalProperties")
      if \childCheck~ok then return childCheck
    end
  end

  items = schema~at("items")
  if items \== .nil then do
    childCheck = self~validateDefinition(items, path || ".items")
    if \childCheck~ok then return childCheck
  end

  enumValues = schema~at("enum")
  if enumValues \== .nil then do
    if \enumValues~isa(.Array) then return .RuntimeResult~failure("ABILITY_SCHEMA_ENUM_INVALID", path)
    if enumValues~items = 0 then return .RuntimeResult~failure("ABILITY_SCHEMA_ENUM_EMPTY", path)
  end

  minimum = schema~at("minimum")
  if minimum \== .nil then do
    if \self~isJsonNumber(minimum) then return .RuntimeResult~failure("ABILITY_SCHEMA_NUMERIC_BOUND_INVALID", path || ":minimum")
  end
  maximum = schema~at("maximum")
  if maximum \== .nil then do
    if \self~isJsonNumber(maximum) then return .RuntimeResult~failure("ABILITY_SCHEMA_NUMERIC_BOUND_INVALID", path || ":maximum")
  end
  if minimum \== .nil then do
    if maximum \== .nil then do
      if minimum > maximum then return .RuntimeResult~failure("ABILITY_SCHEMA_NUMERIC_BOUND_ORDER", path)
    end
  end

  numericKeywords = .array~of("minLength", "maxLength", "minItems", "maxItems")
  do i = 1 to numericKeywords~items
    key = numericKeywords~at(i)
    bound = schema~at(key)
    if bound == .nil then iterate
    if \self~isJsonInteger(bound) then return .RuntimeResult~failure("ABILITY_SCHEMA_SIZE_BOUND_INVALID", path || ":" || key)
    if bound < 0 then return .RuntimeResult~failure("ABILITY_SCHEMA_SIZE_BOUND_INVALID", path || ":" || key)
  end

  minLength = schema~at("minLength")
  maxLength = schema~at("maxLength")
  if minLength \== .nil then do
    if maxLength \== .nil then do
      if minLength > maxLength then return .RuntimeResult~failure("ABILITY_SCHEMA_SIZE_BOUND_ORDER", path || ":length")
    end
  end
  minItems = schema~at("minItems")
  maxItems = schema~at("maxItems")
  if minItems \== .nil then do
    if maxItems \== .nil then do
      if minItems > maxItems then return .RuntimeResult~failure("ABILITY_SCHEMA_SIZE_BOUND_ORDER", path || ":items")
    end
  end

  return .RuntimeResult~success(schema, "schema definition valid")

::method validateValue class
  use arg schema, value, path = "$"
  typeName = schema~at("type")
  if typeName \== .nil then do
    typeCheck = self~valueHasType(value, typeName~string)
    if \typeCheck then return .RuntimeResult~failure("ABILITY_SCHEMA_TYPE_MISMATCH", path || " expected " || typeName~string || " found " || self~valueType(value))
  end

  enumValues = schema~at("enum")
  if enumValues \== .nil then do
    matched = .false
    candidateText = self~canonicalJson(value)
    do i = 1 to enumValues~items
      if self~canonicalJson(enumValues~at(i)) = candidateText then do
        matched = .true
        leave
      end
    end
    if \matched then return .RuntimeResult~failure("ABILITY_SCHEMA_ENUM_MISMATCH", path)
  end

  if schema~hasIndex("const") then do
    if self~canonicalJson(schema~at("const")) \= self~canonicalJson(value) then return .RuntimeResult~failure("ABILITY_SCHEMA_CONST_MISMATCH", path)
  end

  if value~isa(.Directory) then do
    properties = schema~at("properties")
    required = schema~at("required")
    if required \== .nil then do i = 1 to required~items
      name = required~at(i)~string
      if \value~hasIndex(name) then return .RuntimeResult~failure("ABILITY_SCHEMA_REQUIRED_MISSING", path || "." || name)
    end

    if properties == .nil then properties = .directory~new
    additional = schema~at("additionalProperties")
    supplier = value~supplier
    do while supplier~available
      key = supplier~index~string
      childValue = supplier~item
      childSchema = properties~at(key)
      if childSchema \== .nil then do
        childCheck = self~validateValue(childSchema, childValue, path || "." || key)
        if \childCheck~ok then return childCheck
      end
      else if additional \== .nil then do
        if additional~isa(.JSONBoolean) then do
          if \additional~value then return .RuntimeResult~failure("ABILITY_SCHEMA_ADDITIONAL_PROPERTY", path || "." || key)
        end
        else do
          childCheck = self~validateValue(additional, childValue, path || "." || key)
          if \childCheck~ok then return childCheck
        end
      end
      supplier~next
    end
  end

  if value~isa(.Array) then do
    minItems = schema~at("minItems")
    if minItems \== .nil then do
      if value~items < minItems then return .RuntimeResult~failure("ABILITY_SCHEMA_MIN_ITEMS", path)
    end
    maxItems = schema~at("maxItems")
    if maxItems \== .nil then do
      if value~items > maxItems then return .RuntimeResult~failure("ABILITY_SCHEMA_MAX_ITEMS", path)
    end
    itemSchema = schema~at("items")
    if itemSchema \== .nil then do i = 1 to value~items
      childCheck = self~validateValue(itemSchema, value~at(i), path || "[" || i || "]")
      if \childCheck~ok then return childCheck
    end
  end

  if self~isStringValue(value) then do
    minLength = schema~at("minLength")
    if minLength \== .nil then do
      if value~string~length < minLength then return .RuntimeResult~failure("ABILITY_SCHEMA_MIN_LENGTH", path)
    end
    maxLength = schema~at("maxLength")
    if maxLength \== .nil then do
      if value~string~length > maxLength then return .RuntimeResult~failure("ABILITY_SCHEMA_MAX_LENGTH", path)
    end
  end

  if self~isJsonNumber(value) then do
    minimum = schema~at("minimum")
    if minimum \== .nil then do
      if value < minimum then return .RuntimeResult~failure("ABILITY_SCHEMA_MINIMUM", path)
    end
    maximum = schema~at("maximum")
    if maximum \== .nil then do
      if value > maximum then return .RuntimeResult~failure("ABILITY_SCHEMA_MAXIMUM", path)
    end
  end

  return .RuntimeResult~success(value, "value conforms to schema")

::method supportedType private class
  use arg typeName
  select
    when typeName = "object" then return .true
    when typeName = "array" then return .true
    when typeName = "string" then return .true
    when typeName = "integer" then return .true
    when typeName = "number" then return .true
    when typeName = "boolean" then return .true
    when typeName = "null" then return .true
    otherwise return .false
  end

::method valueHasType private class
  use arg value, typeName
  select
    when typeName = "object" then return value~isa(.Directory)
    when typeName = "array" then return value~isa(.Array)
    when typeName = "string" then return self~isStringValue(value)
    when typeName = "integer" then return self~isJsonInteger(value)
    when typeName = "number" then return self~isJsonNumber(value)
    when typeName = "boolean" then return value~isa(.JSONBoolean)
    when typeName = "null" then return value == .nil
    otherwise return .false
  end

::method valueType private class
  use arg value
  if value == .nil then return "null"
  if value~isa(.JSONBoolean) then return "boolean"
  if value~isa(.Directory) then return "object"
  if value~isa(.Array) then return "array"
  if self~isJsonInteger(value) then return "integer"
  if self~isJsonNumber(value) then return "number"
  if self~isStringValue(value) then return "string"
  return value~class~id

::method isStringValue private class
  use arg value
  if value == .nil then return .false
  if value~isa(.JSONString) then return .true
  if \value~isa(.String) then return .false
  if value~datatype("N") then return .false
  return .true

::method isJsonInteger private class
  use arg value
  if value == .nil then return .false
  if value~isa(.JSONString) then return .false
  if \value~isa(.String) then return .false
  return value~datatype("W")

::method isJsonNumber private class
  use arg value
  if value == .nil then return .false
  if value~isa(.JSONString) then return .false
  if \value~isa(.String) then return .false
  return value~datatype("N")

::method deepCopy class
  use arg value
  if value == .nil then return .nil
  if value~isa(.Directory) then do
    copy = .directory~new
    supplier = value~supplier
    do while supplier~available
      copy[supplier~index~string] = self~deepCopy(supplier~item)
      supplier~next
    end
    return copy
  end
  if value~isa(.Array) then do
    copy = .array~new
    do i = 1 to value~items
      copy~append(self~deepCopy(value~at(i)))
    end
    return copy
  end
  if value~isa(.JSONString) then return .JSON~fromJSON(.JSON~toJSON(value))
  if value~isa(.JSONBoolean) then do
    if value~value then return .JSONBoolean~true
    return .JSONBoolean~false
  end
  return value

::method canonicalJson class
  use arg value
  if value == .nil then return "null"
  if value~isa(.Directory) then do
    keys = .array~new
    supplier = value~supplier
    do while supplier~available
      keys~append(supplier~index~string)
      supplier~next
    end
    keys = .RuntimeCanonical~sortStrings(keys)
    text = "{"
    do i = 1 to keys~items
      if i > 1 then text = text || ","
      key = keys~at(i)
      keyJson = .JSON~toJSON(.JSONString~new(key))
      text = text || keyJson || ":" || self~canonicalJson(value~at(key))
    end
    return text || "}"
  end
  if value~isa(.Array) then do
    text = "["
    do i = 1 to value~items
      if i > 1 then text = text || ","
      text = text || self~canonicalJson(value~at(i))
    end
    return text || "]"
  end
  return .JSON~toJSON(value)

::requires "RuntimeRegistry.cls"
::requires "json.cls"
