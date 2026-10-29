/* Presentation-only coordinate and reserved-footer boundary. */
::class CliUiBoundedRenderer public
::method init
  expose target rows cols reserved regionStart regionEnd
  use strict arg target,rows,cols,reserved=2
  if rows<1 | cols<1 then raise syntax 93.900 array('Invalid terminal geometry')
  if reserved<0 then raise syntax 93.900 array('Invalid footer reservation')
  regionStart=1; regionEnd=rows-reserved
::method region
  expose regionStart regionEnd rows reserved
  use strict arg first,last
  regionStart=first; regionEnd=last
  if regionStart<1 then regionStart=1
  if regionEnd>rows-reserved then regionEnd=rows-reserved
  return self
::method beginFrame
  expose target
  return target~beginFrame
::method endFrame
  expose target
  return target~endFrame
::method drawText
  expose target rows cols reserved regionStart regionEnd
  use strict arg row,col,value,style='default'
  if row<1 | row>rows | col>cols then return self
  if col<1 then do
    skip=1-col
    if skip>=value~length then return self
    value=value~substr(skip+1)
    col=1
  end
  if row>rows-reserved | row<regionStart | row>regionEnd then return self
  available=cols-col+1
  if available<1 then return self
  target~drawText(row,col,value~left(available),style)
  return self
::method drawFooter
  expose target rows cols reserved
  use strict arg row,col,value,style='status'
  if row<1 | row>rows | col<1 | col>cols then return self
  if row<=rows-reserved then return self
  target~drawText(row,col,value~left(cols-col+1),style)
  return self
::method setCursor
  expose target rows cols
  use arg row,col
  if row<1 then row=1
  if row>rows then row=rows
  if col<1 then col=1
  if col>cols then col=cols
  target~setCursor(row,col)
  return self
