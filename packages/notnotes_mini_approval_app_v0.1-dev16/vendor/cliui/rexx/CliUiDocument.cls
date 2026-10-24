::class CliUiDocument public
::method init
  expose text caret anchor language modified
  use strict arg text = "", language = "plain"
  caret = text~length + 1
  anchor = caret
  modified = .false
::attribute text get
::attribute language get
::attribute modified get
::method markClean; expose modified; modified=.false; return self
::method lineColumn
  expose text caret
  before=text~substr(1,caret-1)
  return self~lineColumnFor(before,1,0)
::method lineColumnFor
  use strict arg remaining,line,last
  p=remaining~pos("0a"x)
  if p=0 then return .array~of(line,remaining~length+1)
  return self~lineColumnFor(remaining~substr(p+1),line+1,last+p)
::method caret; expose caret; return caret
::method selection
  expose caret anchor
  a = anchor; b = caret
  if a > b then do; t=a; a=b; b=t; end
  return .array~of(a,b)
::method moveCaret
  expose text caret anchor
  use strict arg delta, extend = .false
  n = caret + delta
  if n < 1 then n = 1
  if n > text~length + 1 then n = text~length + 1
  caret = n
  if \extend then anchor = caret
  return caret
::method setCaret
  expose text caret anchor
  use strict arg position, extend = .false
  if position < 1 then position = 1
  if position > text~length + 1 then position = text~length + 1
  caret = position
  if \extend then anchor = caret
  return caret
::method replaceSelection
  expose text caret anchor modified
  use strict arg replacement
  range = self~selection; a=range[1]; b=range[2]
  text = text~substr(1,a-1) || replacement || text~substr(b)
  caret = a + replacement~length
  anchor = caret
  modified = .true
  return self
::method insert; use strict arg s; return self~replaceSelection(s)
::method backspace
  expose caret anchor
  if caret == anchor then do
    if caret > 1 then anchor=caret-1
  end
  return self~replaceSelection("")
::method delete
  expose text caret anchor
  if caret == anchor then do
    if caret <= text~length then anchor=caret+1
  end
  return self~replaceSelection("")
::method moveLine
  expose text
  use strict arg delta, extend=.false
  location=self~lineColumn
  wantedColumn=location[2]
  targetLine=location[1]+delta
  lines=text~makeArray("0a"x)
  if targetLine<1 then targetLine=1
  if targetLine>lines~items then targetLine=lines~items
  targetStart=self~lineStart(lines,targetLine)
  targetWidth=lines[targetLine]~length
  targetOffset=wantedColumn-1
  if targetOffset>targetWidth then targetOffset=targetWidth
  return self~setCaret(targetStart+targetOffset,extend)
::method lineStart
  use strict arg lines,targetLine
  if targetLine<=1 then return 1
  return self~lineStart(lines,targetLine-1)+lines[targetLine-1]~length+1
::method moveLineHome
  expose text caret
  use strict arg extend=.false
  prefix=text~substr(1,caret-1)
  separatorPosition=prefix~lastPos('0a'x)
  lineStart=1
  if separatorPosition>0 then lineStart=separatorPosition+1
  return self~setCaret(lineStart,extend)
::method moveLineEnd
  expose text caret
  use strict arg extend=.false
  separatorPosition=text~pos('0a'x,caret)
  lineEnd=text~length+1
  if separatorPosition>0 then lineEnd=separatorPosition
  return self~setCaret(lineEnd,extend)
