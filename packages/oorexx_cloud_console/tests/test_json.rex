call assertEq .CloudJsonParser~new('{"a":[1,"x",true,null],"b":{"c":"d"}}')~parse["b"]["c"], "d", "nested json"
p=.CloudJsonParser~new('[{"id":"x","n":2}]'); a=p~parse
call assertEq p~error, "", "parser error empty"
call assertEq a[1]["id"], "x", "array object"
out=.CloudJson~encode(a)
p2=.CloudJsonParser~new(out); b=p2~parse
call assertEq p2~error, "", "encoded json reparses"
call assertEq b[1]["n"], "2", "number preserved"
say "PASS JSON"
exit 0
assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected=<"expected"> actual=<"actual">"
    exit 1
  end
  return
::requires "../src/CloudConsole.cls"