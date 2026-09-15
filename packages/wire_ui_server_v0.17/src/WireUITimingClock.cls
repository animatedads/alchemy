/* Injectable server-side clock for factual Wire UI journey timing evidence. */
::class WireUITimingClock subclass AlchemyObject public
::method init
  self~init:super(.WireUIAlchemy~metadata("Server-side clock for factual Wire UI journey timing evidence"))

::method nowMicros
  /* date('B') is an ooRexx base-day count; time('L') supplies microseconds. */
  day=date("B")
  long=time("L")
  hh=long~substr(1,2)+0
  mm=long~substr(4,2)+0
  ss=long~substr(7,2)+0
  dot=long~pos(".")
  micros=0
  if dot>0 then do
    fraction=long~substr(dot+1)
    if fraction~length<6 then fraction=fraction||copies("0",6-fraction~length)
    if fraction~length>6 then fraction=fraction~left(6)
    micros=fraction+0
  end
  return day*86400000000 + hh*3600000000 + mm*60000000 + ss*1000000 + micros

::method wallStamp
  return date("S")"T"time("L")

::requires "WireUIAlchemy.cls"
