::class CliUiEditorProjection public
::method init
  expose editor renderer
  use strict arg editor, renderer
::method render
  expose editor renderer
  doc=editor~document; vp=editor~viewport
  renderer~beginFrame
  lines=doc~text~makeArray("0a"x)
  bodyRows=vp~rows-1
  if bodyRows<1 then bodyRows=1
  self~renderRows(lines,vp,1,bodyRows)
  status=editor~status
  lc=doc~lineColumn
  status=status||"  "||lc[1]||":"||lc[2]
  renderer~drawText(vp~rows,1,status~left(vp~cols),"status")
  row=lc[1]-vp~top+1; col=lc[2]-vp~left+1
  if row<1 then row=1
  if row>bodyRows then row=bodyRows
  if col<1 then col=1
  if col>vp~cols then col=vp~cols
  renderer~setCursor(row,col)
  renderer~endFrame
  return self
::method renderRows
  expose renderer
  use strict arg lines,vp,screenRow,bodyRows
  if screenRow>bodyRows then return self
  sourceRow=vp~top+screenRow-1
  if sourceRow<=lines~items then do
    sourceLine=lines[sourceRow]
    shown=""
    if vp~left<=sourceLine~length then shown=sourceLine~substr(vp~left,vp~cols)
    renderer~drawText(screenRow,1,shown,"default")
  end
  return self~renderRows(lines,vp,screenRow+1,bodyRows)
