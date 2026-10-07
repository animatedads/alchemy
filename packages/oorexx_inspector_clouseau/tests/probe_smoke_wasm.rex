obj=.ProbeDemo~new('alpha',42)
i=.InspectorClouseau~new
i~enableProbes(.true)
i~dontFollowPackage('REXX')
i~reportVariable('*')
i~addPackage(.context~package)
i~addRoot('demo',obj)
s=i~snapshot
d=s~asDirectory
pc=0
slots=0
do rec over d~at('objects')
  if rec~at('class')='PROBEDEMO' then do
    if rec~hasIndex('probe') then do
      pc=pc+1
      p=rec~at('probe')
      if p~hasIndex('slots') then slots=p~at('slots')~items
    end
  end
end
say 'CLOUSEAU probe objects='pc 'slots='slots
if pc < 1 then do
  say 'FAIL cooperative probe was not installed'
  exit 21
end
say 'PASS Inspector Clouseau cooperative probe-mode WASM smoke'
exit 0

::class InspectorCooperative MIXINCLASS Object
::method __INSPECTOR_CLOUSEAU_INSTALL
  use strict arg probeName, source, scope='OBJECT'
  self~setMethod(probeName,source,scope)
  return .true
::method __INSPECTOR_CLOUSEAU_UNINSTALL
  use strict arg probeName
  self~unsetMethod(probeName)
  return .true

::class ProbeDemo public inherit InspectorCooperative
::attribute name
::attribute value
::method init
  expose name value
  use strict arg name,value

::requires 'InspectorClouseau.cls'
