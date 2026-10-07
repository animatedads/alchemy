/* General-purpose Inspector Clouseau example. */
obj = .DemoObject~new('alpha', 42)

clouseau = .InspectorClouseau~new
clouseau~enableProbes(.true)
clouseau~dontFollowPackage('REXX')
clouseau~reportVariable('*')
clouseau~reportInheritanceMap(.true)
clouseau~addPackage(.context~package)
clouseau~addRoot('demo', obj)

snapshot = clouseau~snapshot
say snapshot~asText

::class DemoObject public
::attribute name
::attribute value
::method init
  expose name value
  use strict arg name, value

::requires 'InspectorClouseau.cls'
