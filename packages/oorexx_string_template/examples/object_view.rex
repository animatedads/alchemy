customer = .Customer~new("Alice Morgan", 282)
properties = .Directory~new
properties["name"] = "displayName"
properties["balance"] = "balance"
context = .TemplateContext~new~putObject("customer", customer, properties)
template = .StringTemplate~new("Customer ${customer.name} owes GBP ${customer.balance}.")
say template~render(context)

::class Customer public
::method init
  expose _name _balance
  use strict arg name, balance
  _name = name
  _balance = balance
::method displayName
  expose _name
  return _name
::method balance
  expose _balance
  return _balance

::requires "StringTemplate.cls"
