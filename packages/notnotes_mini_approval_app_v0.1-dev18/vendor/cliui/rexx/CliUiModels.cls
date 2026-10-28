::class CliUiDetailModel public
::method init
  expose title fields sections actions
  use strict arg title=""
  fields=.array~new; sections=.array~new; actions=.array~new
::attribute title get
::method addField; expose fields; use strict arg label,value; fields~append(.array~of(label,value)); return self
::method addSection; expose sections; use strict arg heading,body; sections~append(.array~of(heading,body)); return self
::method addAction; expose actions; use strict arg command,label; actions~append(.array~of(command,label)); return self
::method fields; expose fields; return fields
::method sections; expose sections; return sections
::method actions; expose actions; return actions

::class CliUiPromptModel public
::method init
  expose prompt buffer caret history candidates
  use strict arg prompt="Command: "
  buffer=""; caret=1; history=.array~new; candidates=.array~new
::attribute prompt get
::attribute buffer get
::attribute caret get
::method insert
  expose buffer caret
  use strict arg text
  buffer=buffer~substr(1,caret-1)||text||buffer~substr(caret)
  caret=caret+text~length
  return self
::method backspace
  expose buffer caret
  if caret>1 then do
    buffer=buffer~substr(1,caret-2)||buffer~substr(caret)
    caret=caret-1
  end
  return self
::method submit
  expose buffer caret history
  submitted=buffer
  if submitted<>"" then history~append(submitted)
  buffer=""; caret=1
  return submitted
::method cancel; expose buffer caret; buffer=""; caret=1; return self
::method history; expose history; return history
::method candidates; expose candidates; return candidates
::method setCandidates
  expose candidates
  use strict arg value
  candidates=value
  return self

::class CliUiActionMap public
::method init; expose bindings; bindings=.directory~new
::method bind; expose bindings; use strict arg key,command; bindings[key~upper]=command; return self
::method resolve
  expose bindings
  use strict arg key
  normalized=key~upper
  if bindings~hasIndex(normalized) then return bindings[normalized]
  return .nil
