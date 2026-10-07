::class CliUiHeadlessRenderer public
::method init
  expose rows cols frames cells cursor
  use strict arg rows=24, cols=80
  frames=0; cells=.directory~new; cursor=.array~of(1,1)
::attribute rows
::attribute cols
::method resize
  expose rows cols
  use strict arg r,c
  rows=r; cols=c
  return .CliUiSemanticEvent~new("Resize","terminal","","rowsxcols",r||"x"||c)
::method beginFrame; expose cells; cells=.directory~new; return self
::method drawText
  expose cells
  use strict arg row,col,text,style="default"
  cells[row||":"||col]=style||":"||text; return self
::method setCursor
  expose cursor
  use strict arg row,col
  cursor=.array~of(row,col); return self
::method endFrame; expose frames; frames=frames+1; return frames
::method cell
  expose cells
  use strict arg row,col
  k=row||":"||col
  if cells~hasIndex(k) then return cells[k]
  return .nil

::requires "CliUiSemantic.cls"
