::class CliUiChoice public
::method init
  expose identity label
  use strict arg identity,label
::attribute identity get
::attribute label get

::class CliUiField public
::method init
  expose identity label value editable
  use strict arg identity,label,value='',editable=.true
::attribute identity get
::attribute label get
::attribute value get
::attribute value set
::attribute editable get
::method kind; return 'field'

::class CliUiSelectionField subclass CliUiField public
::method init
  expose choices selectedIdentity
  use strict arg identity,label,value='',choices=.nil,selectedIdentity=.nil
  self~init:super(identity,label,value,.true)
  if choices=.nil then choices=.array~new
::attribute choices get
::attribute selectedIdentity get
::method kind; return 'selection'
::method selectIdentity
  expose choices selectedIdentity
  use strict arg identity
  choice=self~choiceByIdentity(identity)
  if choice=.nil then return .false
  selectedIdentity=choice~identity
  self~value=choice~label
  return .true
::method choiceByIdentity
  expose choices
  use strict arg identity
  return self~choiceAt(choices,identity,1)
::method choiceAt
  use strict arg choices,identity,index
  if index>choices~items then return .nil
  candidate=choices[index]
  if candidate~identity=identity then return candidate
  return self~choiceAt(choices,identity,index+1)
::method moveChoice
  expose choices selectedIdentity
  use strict arg delta
  if choices~items=0 then return .nil
  index=self~selectedIndex(choices,selectedIdentity,1)
  if index=0 then index=1
  else index=index+delta
  if index<1 then index=1
  if index>choices~items then index=choices~items
  choice=choices[index]
  selectedIdentity=choice~identity
  self~value=choice~label
  return selectedIdentity
::method selectedIndex
  use strict arg choices,identity,index
  if index>choices~items then return 0
  if choices[index]~identity=identity then return index
  return self~selectedIndex(choices,identity,index+1)

::class CliUiFormModel public
::method init
  expose title fields focusIndex
  use strict arg title=''
  fields=.array~new
  focusIndex=0
::attribute title get
::method addField
  expose fields focusIndex
  use strict arg field
  fields~append(field)
  if focusIndex=0 then do
    if field~editable then focusIndex=fields~items
  end
  return self
::method fields; expose fields; return fields
::method count; expose fields; return fields~items
::method field; expose fields; use strict arg index; return fields[index]
::method focusIndex; expose focusIndex; return focusIndex
::method focusedField
  expose fields focusIndex
  if focusIndex=0 then return .nil
  return fields[focusIndex]
::method focus
  expose fields focusIndex
  use strict arg index
  if index<1 then return .false
  if index>fields~items then return .false
  if \fields[index]~editable then return .false
  focusIndex=index
  return .true
::method moveFocus
  expose fields focusIndex
  use strict arg delta
  if fields~items=0 then return 0
  target=focusIndex
  if target=0 then target=1
  else target=target+delta
  return self~seekEditable(fields,target,delta)
::method seekEditable
  expose focusIndex
  use strict arg fields,index,delta
  if index<1 then return focusIndex
  if index>fields~items then return focusIndex
  if fields[index]~editable then do
    focusIndex=index
    return focusIndex
  end
  return self~seekEditable(fields,index+delta,delta)
