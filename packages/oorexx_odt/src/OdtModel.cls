/* OdtModel.cls - semantic OpenDocument Text objects. */

::class OdtDocument public
::method init
  expose title creator blocks sourcePath format
  use strict arg title = "", creator = ""
  blocks = .Array~new
  sourcePath = ""
  format = "ODT"
::attribute title
::attribute creator
::attribute sourcePath
::attribute format get
::attribute blocks get
::method addParagraph
  expose blocks
  use strict arg text, styleName = ""
  block = .OdtParagraph~new(text, styleName)
  blocks~append(block)
  return block
::method addHeading
  expose blocks
  use strict arg text, level = 1, styleName = ""
  block = .OdtHeading~new(text, level, styleName)
  blocks~append(block)
  return block
::method addTable
  expose blocks
  use strict arg table
  if \table~isA(.OdtTable) then raise syntax 93.900 array("addTable requires OdtTable")
  blocks~append(table)
  return table
::method paragraphs
  expose blocks
  out = .Array~new
  loop i = 1 to blocks~items
    b = blocks~at(i)
    if b~isA(.OdtParagraph) then out~append(b)
  end
  return out
::method headings
  expose blocks
  out = .Array~new
  loop i = 1 to blocks~items
    b = blocks~at(i)
    if b~isA(.OdtHeading) then out~append(b)
  end
  return out
::method tables
  expose blocks
  out = .Array~new
  loop i = 1 to blocks~items
    b = blocks~at(i)
    if b~isA(.OdtTable) then out~append(b)
  end
  return out
::method plainText
  expose blocks
  out = ""
  loop i = 1 to blocks~items
    b = blocks~at(i)
    if b~isA(.OdtHeading) | b~isA(.OdtParagraph) then do
      if out \== "" then out = out || .endOfLine
      out = out || b~text
    end
    else if b~isA(.OdtTable) then do
      rows = b~rows
      loop r = 1 to rows~items
        row = rows~at(r)
        line = ""
        loop c = 1 to row~items
          if c > 1 then line = line || "09"x
          line = line || row~at(c)
        end
        if out \== "" then out = out || .endOfLine
        out = out || line
      end
    end
  end
  return out

::class OdtParagraph public
::method init
  expose text styleName
  use strict arg text, styleName = ""
::attribute text
::attribute styleName

::class OdtHeading subclass OdtParagraph public
::method init
  expose level
  use strict arg text, level = 1, styleName = ""
  self~init:super(text, styleName)
::attribute level

::class OdtTable public
::method init
  expose name rows
  use strict arg name = "Table"
  rows = .Array~new
::attribute name
::attribute rows get
::method addRow
  expose rows
  use strict arg row
  if \row~isA(.Array) then raise syntax 93.900 array("ODT table row must be an Array")
  rows~append(row)
  return row
::method addValues
  expose rows
  use arg values
  row = .Array~new
  if values~isA(.Array) then do
    loop i = 1 to values~items
      row~append(values~at(i))
    end
  end
  else row~append(values)
  rows~append(row)
  return row
