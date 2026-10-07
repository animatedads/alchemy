ctx = .Directory~new
ctx["name"] = "Fred"
ctx["count"] = 7
call assertEq .StringTemplate~new("Hello ${name}. You have ${count} messages.")~render(ctx), "Hello Fred. You have 7 messages.", "basic interpolation"

t = .StringTemplate~new("${name}/${count}/${name}")
v = t~variables
call assertEq v~items, 2, "variables unique"
call assertEq v[1], "name", "first variable"
call assertEq v[2], "count", "second variable"

say "PASS test_basic"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "StringTemplate.cls"
