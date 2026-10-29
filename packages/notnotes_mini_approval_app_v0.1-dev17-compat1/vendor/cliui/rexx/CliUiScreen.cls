::class CliUiFormProjection public
::method init
  expose renderer
  use strict arg renderer
::method render
  expose renderer
  use strict arg model,startRow=1,width=80
  labelWidth=self~labelWidth(model~fields,1,0)
  if labelWidth>20 then labelWidth=20
  if labelWidth>width%2 then labelWidth=width%2
  renderer~drawText(startRow,1,self~clip(model~title,width),'status')
  return self~renderFields(model,1,startRow+1,labelWidth,width)
::method renderFields
  expose renderer
  use strict arg model,index,row,labelWidth,width
  if index>model~count then return row
  field=model~field(index)
  label=self~pad(self~clip(field~label,labelWidth),labelWidth)||' : '
  valueWidth=width-label~length
  if valueWidth<1 then valueWidth=1
  marker=''
  if field~kind='selection' then marker=' v'
  value=self~clip(field~value||marker,valueWidth)
  style='default'
  if index=model~focusIndex then style='selection'
  renderer~drawText(row,1,self~clip(label||value,width),style)
  return self~renderFields(model,index+1,row+1,labelWidth,width)
::method labelWidth
  use strict arg fields,index,current
  if index>fields~items then return current
  size=fields[index]~label~length
  if size>current then current=size
  return self~labelWidth(fields,index+1,current)
::method clip
  use strict arg text,width
  if width<=0 then return ''
  if text~length<=width then return text
  if width=1 then return text~left(1)
  return text~left(width-1)||'>'
::method pad
  use strict arg text,width
  if text~length>=width then return text
  return text||(' '~copies(width-text~length))

::class CliUiScreenModel public
::method init
  expose title navigation table detail form prompt status focus
  use strict arg title=''
  navigation=.array~new; table=.nil; detail=.nil; form=.nil; prompt=.nil; status=''; focus='content'
::attribute title
::attribute navigation
::attribute table
::attribute detail
::attribute form
::attribute prompt
::attribute status
::attribute focus

::class CliUiScreenProjection public
::method init
  expose renderer
  use strict arg renderer
::method render
  expose renderer
  use strict arg model,rows=24,cols=80
  renderer~beginFrame
  renderer~drawText(1,1,self~clip(model~title,cols),'status')
  nav=self~join(model~navigation,' | ')
  if nav<>'' then renderer~drawText(2,1,self~clip(nav,cols),'default')
  contentTop=4
  footerRows=2
  contentRows=rows-contentTop-footerRows+1
  if contentRows<1 then contentRows=1
  if model~table<>.nil then do
    model~table~viewport(model~table~viewportTop,contentRows-1)
    .CliUiTableProjection~new(renderer)~render(model~table,contentTop,contentRows-1)
  end
  if model~detail<>.nil then .CliUiDetailProjection~new(renderer)~render(model~detail,contentTop)
  if model~form<>.nil then .CliUiFormProjection~new(renderer)~render(model~form,contentTop,cols)
  statusRow=rows-1
  if statusRow<1 then statusRow=1
  renderer~drawText(statusRow,1,self~clip(model~status,cols),'status')
  if model~prompt<>.nil then .CliUiPromptProjection~new(renderer)~render(model~prompt,rows)
  renderer~endFrame
  return self
::method clip
  use strict arg text,width
  if width<=0 then return ''
  if text~length<=width then return text
  if width=1 then return text~left(1)
  return text~left(width-1)||'>'
::method join
  use strict arg items,separator
  return self~joinAt(items,separator,1,'')
::method joinAt
  use strict arg items,separator,index,result
  if index>items~items then return result
  next=items[index]
  if result<>'' then next=separator||next
  return self~joinAt(items,separator,index+1,result||next)

::requires 'CliUiProjection.cls'
