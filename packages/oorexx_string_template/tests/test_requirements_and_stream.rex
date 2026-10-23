ctx = .Directory~new
ctx["name"] = "Fred"
ctx["count"] = 7

t = .StringTemplate~new("${name|upper}:${count}:${name|trim}")
vars = t~variables
formats = t~formatterNames
call assertEq vars~items, 2, "variable requirement count"
call assertEq vars[1], "name", "variable requirement first"
call assertEq vars[2], "count", "variable requirement second"
call assertEq formats~items, 3, "formatter requirement count"
call assertEq formats[1], "upper", "formatter requirement first"
call assertEq formats[2], "identity", "formatter requirement second"
call assertEq formats[3], "trim", "formatter requirement third"

requirements = t~requirements
reqVars = requirements~variables
reqFormats = requirements~formatters
call assertEq reqVars[1], "name", "requirements variable"
call assertEq reqFormats[1], "upper", "requirements formatter"

sink = .BufferSink~new
written = t~renderTo(sink, ctx)
expected = "FRED:7:Fred"
call assertEq sink~text, expected, "streamed rendering"
call assertEq written, expected~length, "streamed character count"
call assertEq t~render(ctx), expected, "render and renderTo agree"

say "PASS test_requirements_and_stream"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::class BufferSink public
::method init
  expose _text
  _text = ""
::method charOut
  expose _text
  use strict arg chunk
  _text ||= chunk
  return 0
::method text
  expose _text
  return _text

::requires "StringTemplate.cls"
