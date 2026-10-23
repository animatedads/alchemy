/* Alchemy facade; requires upstream ooRexx/Python, Apache-2.0. */
::requires "python.cls"
::class AlchemyPythonAdapter public
::method import class
  use strict arg name
  return .py~import(name)
::method evaluate class
  use strict arg expression
  return .py~eval(expression)
::method execute class
  use strict arg source
  return .py~exec(source)
::method keyword class
  forward to (.py) message "KW" arguments (arg(1, "A"))
::method box class
  forward to (.py) message "BOX" arguments (arg(1, "A"))
::method pythonType class
  use strict arg value
  return .py~type(value)
