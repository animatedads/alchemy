/* Six-line ASCII guitar-tab parser.  Timing is column based. */

::class TabEvent public
::method init
  expose _string _fret _column _kind _articulation
  use strict arg stringNumber,fret,column,kind='NOTE',articulation='PICK'
  _string=stringNumber; _fret=fret; _column=column; _kind=kind; _articulation=articulation
::method stringNumber; expose _string; return _string
::method fret; expose _fret; return _fret
::method column; expose _column; return _column
::method kind; expose _kind; return _kind
::method articulation; expose _articulation; return _articulation

::class AsciiTabParser public
::method parse class
  use strict arg lines
  if lines~items<>6 then raise syntax 88.900 array('exactly six tab lines required',lines~items)
  events=.array~new
  do s=1 to 6
    raw=lines[s]
    bar=raw~pos('|')
    if bar=0 then raise syntax 88.900 array('tab line missing | delimiter',raw)
    body=raw~substr(bar+1)
    pending='PICK'
    i=1
    do while i<=body~length
      ch=body~substr(i,1)
      if ch>='0' then if ch<='9' then do
        j=i
        digits=''
        do while j<=body~length
          d=body~substr(j,1)
          if d<'0' | d>'9' then leave
          digits=digits||d
          j+=1
        end
        if datatype(digits,'W')=0 then raise syntax 88.900 array('tab fret is not a whole number',digits)
        events~append(.TabEvent~new(s,digits,i,'NOTE',pending))
        pending='PICK'
        i=j
        iterate
      end
      select
        when ch='x' | ch='X' then events~append(.TabEvent~new(s,0,i,'DEAD','MUTE'))
        when ch='h' | ch='H' then pending='HAMMER'
        when ch='p' | ch='P' then pending='PULL'
        when ch='/' then pending='SLIDE_UP'
        when ch='\' then pending='SLIDE_DOWN'
        otherwise nop
      end
      i+=1
    end
  end
  return self~sortEvents(events)

::method sortEvents class
  use strict arg events
  out=.array~new
  used=.array~new(events~items)
  do n=1 to events~items
    best=0
    do i=1 to events~items
      if used[i]=.true then iterate
      if best=0 then best=i
      else do
        a=events[i]; b=events[best]
        if a~column<b~column then best=i
      else if a~column=b~column then if a~stringNumber<b~stringNumber then best=i
      end
    end
    used[best]=.true
    out~append(events[best])
  end
  return out
