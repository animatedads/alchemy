::class CliUiAnsiRenderer public
::method init
  expose handle rows cols
  use strict arg inputFd=0,outputFd=1,rows=24,cols=80
  handle=CliUiAnsiOpen(inputFd,outputFd)
  if handle=.nil then raise syntax 93.900 array ('ANSI renderer could not be opened')
  self~resize(rows,cols)
::method close
  expose handle
  if handle<>.nil then call CliUiAnsiClose handle
  handle=.nil
  return self
::method uninit; self~close
::method resize
  expose handle rows cols
  use strict arg newRows,newCols
  rows=newRows; cols=newCols
  call CliUiAnsiResize handle,rows,cols
  return .CliUiSemanticEvent~new('Resize','terminal','','rowsxcols',rows||'x'||cols)
::method beginFrame; expose handle; call CliUiAnsiBeginFrame handle; return self
::method drawText
  expose handle
  use strict arg row,col,text,style='default'
  call CliUiAnsiDrawText handle,row,col,text,self~styleNumber(style)
  return self
::method setCursor
  expose handle
  use strict arg row,col,visible=.true
  call CliUiAnsiSetCursor handle,row,col,visible
  return self
::method endFrame; expose handle; call CliUiAnsiEndFrame handle; return self
::method pollKey
  expose handle
  use strict arg timeoutMs=0
  return CliUiAnsiPollKey(handle,timeoutMs)
::method styleNumber
  use strict arg style
  select
    when style='keyword' then return 1
    when style='string' then return 2
    when style='comment' then return 3
    when style='number' then return 4
    when style='type' then return 5
    when style='symbol' then return 6
    when style='error' then return 7
    when style='selection' then return 8
    when style='status' then return 9
    otherwise return 0
  end

::requires 'CliUiSemantic.cls'
::requires 'cliui_oorexx' LIBRARY
