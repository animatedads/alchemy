ctx = .Directory~new
ctx["name"] = "  Fred Smith  "
ctx["code"] = "abc"
call assertEq .StringTemplate~new("${name|trim}")~render(ctx), "Fred Smith", "trim"
call assertEq .StringTemplate~new("${code|upper}")~render(ctx), "ABC", "upper"
call assertEq .StringTemplate~new("${code|prefix:ID-}")~render(ctx), "ID-abc", "prefix arg"
call assertEq .StringTemplate~new("${code|suffix:-END}")~render(ctx), "abc-END", "suffix arg"

registry = .TemplateFormatterRegistry~default
registry~register("bracket", .BracketFormatter~new)
t = .StringTemplate~new("${code|bracket}", registry)
call assertEq t~render(ctx), "[abc]", "registered formatter"

say "PASS test_formatters"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::class BracketFormatter subclass TemplateFormatter public
::method format
  use strict arg value, argument=""
  return "[" || value || "]"

::requires "StringTemplate.cls"
