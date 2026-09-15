call test_json_pointer
say "PASS test_json_pointer"
exit 0

test_json_pointer:
  root = .JSON~fromJSON('{"a/b":{"~key":"value"},"items":[{"id":7}],"present_null":null}')

  p = .CivicJsonPointer~evaluate(root, "/a~1b/~0key")
  call assertTrue p~present, "RFC6901 ~1 and ~0 escapes resolve"
  call assertEqual "value", p~value, "escaped object member value"

  a = .CivicJsonPointer~evaluate(root, "/items/0/id")
  call assertTrue a~present, "zero-based JSON array index resolves"
  call assertEqual 7, a~value, "array member value retained"

  n = .CivicJsonPointer~evaluate(root, "/present_null")
  call assertTrue n~present, "present JSON null distinguished from missing pointer"
  call assertTrue n~value == .nil, "JSON null remains .nil"

  m = .CivicJsonPointer~evaluate(root, "/missing")
  call assertTrue \m~present, "missing member does not become guessed null"
  call assertEqual "POINTER_MISSING", m~errorCode, "missing pointer reports explicit reason"

  e = .CivicJsonPointer~evaluate(root, "/bad~2escape")
  call assertTrue \e~present, "invalid pointer escape is rejected"
  call assertEqual "POINTER_ESCAPE", e~errorCode, "invalid pointer escape has explicit reason"
  return

::requires "TestSupport.cls"
::requires "CivicJson.cls"
