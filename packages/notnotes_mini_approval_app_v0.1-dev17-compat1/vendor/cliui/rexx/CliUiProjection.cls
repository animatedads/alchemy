::class CliUiTableProjection public
::method init; expose renderer; use strict arg renderer
::method render
  expose renderer
  use strict arg model,startRow=1,maxRows=10
  renderer~drawText(startRow,1,self~join(model~columns,"  "),"status")
  return self~renderRows(model,model~viewportTop,startRow+1,maxRows)
::method renderRows
  expose renderer
  use strict arg model,index,screenRow,remaining
  if remaining<=0 then return self
  if index>model~count then return self
  row=model~row(index); prefix="  "
  if index=model~selected then prefix="> "
  renderer~drawText(screenRow,1,prefix||self~join(row[2],"  "),"default")
  return self~renderRows(model,index+1,screenRow+1,remaining-1)
::method join
  use strict arg items,separator
  if items~items=0 then return ""
  return self~joinFrom(items,separator,1,"")
::method joinFrom
  use strict arg items,separator,index,accumulator
  if index>items~items then return accumulator
  next=items[index]
  if accumulator<>"" then next=separator||next
  return self~joinFrom(items,separator,index+1,accumulator||next)

::class CliUiDetailProjection public
::method init; expose renderer; use strict arg renderer
::method render
  expose renderer
  use strict arg model,startRow=1
  renderer~drawText(startRow,1,model~title,"status")
  nextRow=self~renderFields(model~fields,1,startRow+1)
  return self~renderSections(model~sections,1,nextRow)
::method renderFields
  expose renderer
  use strict arg fields,index,row
  if index>fields~items then return row+1
  item=fields[index]
  renderer~drawText(row,1,item[1]||" : "||item[2],"default")
  return self~renderFields(fields,index+1,row+1)
::method renderSections
  expose renderer
  use strict arg sections,index,row
  if index>sections~items then return self
  item=sections[index]
  renderer~drawText(row,1,item[1],"status")
  renderer~drawText(row+1,1,item[2],"default")
  return self~renderSections(sections,index+1,row+3)

::class CliUiPromptProjection public
::method init; expose renderer; use strict arg renderer
::method render
  expose renderer
  use strict arg model,row
  renderer~drawText(row,1,model~prompt||model~buffer,"default")
  renderer~setCursor(row,model~prompt~length+model~caret)
  return self
