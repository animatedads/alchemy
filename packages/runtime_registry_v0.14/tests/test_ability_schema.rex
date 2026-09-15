parse arg root
if root = "" then root = "."
say "ABILITY SCHEMA V0.1 START"

schemaParse = .AbilityJsonSchema~fromJson('{"type":"object","required":["count","name"],"properties":{"count":{"type":"integer","minimum":1,"maximum":5},"name":{"type":"string","minLength":2,"maxLength":8}},"additionalProperties":false}')
call mustOk schemaParse, "parse strict object schema"
schema = schemaParse~value
call assertEq '{"additionalProperties":false,"properties":{"count":{"maximum":5,"minimum":1,"type":"integer"},"name":{"maxLength":8,"minLength":2,"type":"string"}},"required":["count","name"],"type":"object"}', schema~canonicalText, "canonical schema text"

validValue = .JSON~fromJSON('{"name":"Ada","count":2}')
call mustOk schema~validate(validValue), "valid value"
quotedNumber = schema~validate(.JSON~fromJSON('{"name":"Ada","count":"2"}'))
call assertFalse quotedNumber~ok, "quoted numeric string is not integer"
call assertEq "ABILITY_SCHEMA_TYPE_MISMATCH", quotedNumber~code, "quoted number mismatch code"
extraValue = schema~validate(.JSON~fromJSON('{"name":"Ada","count":2,"extra":true}'))
call assertFalse extraValue~ok, "additional property rejected"
call assertEq "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", extraValue~code, "additional property code"
missingValue = schema~validate(.JSON~fromJSON('{"count":2}'))
call assertFalse missingValue~ok, "required property rejected"
smallValue = schema~validate(.JSON~fromJSON('{"name":"A","count":2}'))
call assertFalse smallValue~ok, "min length enforced"
highValue = schema~validate(.JSON~fromJSON('{"name":"Ada","count":6}'))
call assertFalse highValue~ok, "maximum enforced"

arrayParse = .AbilityJsonSchema~fromJson('{"type":"array","minItems":1,"maxItems":2,"items":{"type":"string","enum":["A","B"]}}')
call mustOk arrayParse, "parse array schema"
call mustOk arrayParse~value~validate(.JSON~fromJSON('["A","B"]')), "array valid"
arrayBad = arrayParse~value~validate(.JSON~fromJSON('["A","C"]'))
call assertFalse arrayBad~ok, "enum enforced"

unsupported = .AbilityJsonSchema~fromJson('{"type":"string","pattern":"^[A-Z]+$"}')
call assertFalse unsupported~ok, "unsupported keyword rejected"

copyDoc = schema~document
copyDoc["type"] = "array"
call assertEq "object", schema~document~at("type"), "schema document is immutable by copy"

schemaSame = .AbilityJsonSchema~fromJson('{"required":["count","name"],"additionalProperties":false,"type":"object","properties":{"name":{"maxLength":8,"type":"string","minLength":2},"count":{"maximum":5,"type":"integer","minimum":1}}}')
call mustOk schemaSame, "parse reordered schema"
call assertEq schema~canonicalText, schemaSame~value~canonicalText, "canonical identity independent of object key order"

say "  canonical_bytes=" || schema~canonicalText~length
say "  numeric_string_distinction=OK"
say "  immutable_copy=OK"
say "ABILITY SCHEMA V0.1: OK"
exit 0

mustOk:
  procedure
  use arg operation, label
  if \operation~ok then do; say "FAILED:" label operation~code operation~detail; exit 90; end
  return
assertFalse:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 91; end
  return
assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do; say "FAILED:" label; say " expected=" expected; say " actual=" actual; exit 92; end
  return

::requires "AbilitySchema.cls"
::requires "json.cls"
