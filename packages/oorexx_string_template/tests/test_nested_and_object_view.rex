customer = .Directory~new
customer["name"] = "Alice"
address = .Directory~new
address["city"] = "Rochdale"
customer["address"] = address
context = .TemplateContext~new~put("customer", customer)
t = .StringTemplate~new("${customer.name} lives in ${customer.address.city}.")
call assertEq t~render(context), "Alice lives in Rochdale.", "nested directory"

obj = .DemoCustomer~new("Bob", 42)
props = .Directory~new
props["name"] = "displayName"
props["balance"] = "accountBalance"
context2 = .TemplateContext~new~putObject("customer", obj, props)
t2 = .StringTemplate~new("${customer.name}:${customer.balance}")
call assertEq t2~render(context2), "Bob:42", "allowlisted object view"

say "PASS test_nested_and_object_view"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::class DemoCustomer public
::method init
  expose _name _balance
  use strict arg name, balance
  _name = name
  _balance = balance
::method displayName
  expose _name
  return _name
::method accountBalance
  expose _balance
  return _balance

::requires "StringTemplate.cls"
