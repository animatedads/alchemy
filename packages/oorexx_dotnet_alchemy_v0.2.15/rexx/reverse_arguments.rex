use strict arg handle
return .ReverseReceiver~new
::class ReverseReceiver
::method slots
  use arg a,b,c,d
  tags=.array~new
  do i=1 to 4
    if \arg(i,'E') then tags[i]='OMITTED'
    else if arg(i) == .nil then tags[i]='NIL'
    else if arg(i) == '' then tags[i]='EMPTY'
    else tags[i]=arg(i)
  end
  return tags[1]'|'tags[2]'|'tags[3]'|'tags[4]
::method numeric
  use strict arg i,d
  return i~datatype('W') || '|' || d~datatype('N') || '|' || (i+1) || '|' || (d+0.5)
::requires 'AlchemyDotNetObject.cls'
::method sameObject
  use strict arg candidate
  return candidate == self
::method echoObject
  use strict arg candidate
  return candidate
