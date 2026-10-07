/*----------------------------------------------------------------------------*/
/* Serial framing layer. Raw serial remains a byte stream; framing is adopted. */
/*----------------------------------------------------------------------------*/

::class SerialFrameData public
::attribute stream get
::attribute port get
::attribute bytes get
::attribute frameNumber get
::method init
  expose stream port bytes frameNumber
  use strict arg streamArg,portArg,bytesArg,numberArg
  stream=streamArg; port=portArg; bytes=bytesArg; frameNumber=numberArg+0
::method copyDetached
  expose stream port bytes frameNumber
  return .SerialFrameData~new(stream,port,bytes,frameNumber)

::class SerialFramer public mixinclass Object
::method streamFor
  use strict arg port,name=''
  return .SerialFrameStream~new(port,self,name)
::method feed abstract
::method reset abstract

::class SerialDelimiterFramer public inherit SerialFramer
::method init
  expose delimiter includeDelimiter buffer
  use strict arg delimiterArg,includeDelimiterArg=.false
  if delimiterArg~length=0 then raise syntax 93.900 array('delimiter must not be empty')
  delimiter=delimiterArg; includeDelimiter=includeDelimiterArg; buffer=''
::method feed guarded
  expose delimiter includeDelimiter buffer
  use strict arg bytes
  buffer=buffer||bytes
  out=.array~new
  do forever
    p=pos(delimiter,buffer)
    if p=0 then leave
    if includeDelimiter then n=p+delimiter~length-1
    else n=p-1
    frame=''; if n>0 then frame=buffer~left(n)
    out~append(frame)
    buffer=buffer~substr(p+delimiter~length)
  end
  return out
::method reset guarded
  expose buffer
  buffer=''; return self

::class SerialLineFramer public subclass SerialDelimiterFramer
::method init
  expose stripCR
  use strict arg delimiter='0A'x,stripCRArg=.true
  self~init:super(delimiter,.false)
  stripCR=stripCRArg
::method feed
  expose stripCR
  use strict arg bytes
  frames=self~feed:super(bytes)
  if \stripCR then return frames
  out=.array~new
  do frame over frames
    if frame~right(1)='0D'x then frame=frame~left(frame~length-1)
    out~append(frame)
  end
  return out

::class SerialFixedLengthFramer public inherit SerialFramer
::method init
  expose frameLength buffer
  use strict arg lengthArg
  if lengthArg~datatype('W')<>1 | lengthArg<1 then raise syntax 93.905 array('frameLength',lengthArg)
  frameLength=lengthArg+0; buffer=''
::method feed guarded
  expose frameLength buffer
  use strict arg bytes
  buffer=buffer||bytes; out=.array~new
  do while buffer~length>=frameLength
    out~append(buffer~left(frameLength)); buffer=buffer~substr(frameLength+1)
  end
  return out
::method reset guarded
  expose buffer
  buffer=''; return self

::class SerialLengthPrefixedFramer public inherit SerialFramer
::method init
  expose prefixBytes endian includePrefix maxFrame buffer
  use strict arg prefixBytesArg=2,endianArg='BIG',includePrefixArg=.false,maxFrameArg=1048576
  if prefixBytesArg<1 | prefixBytesArg>4 then raise syntax 93.900 array('prefixBytes must be 1..4')
  endian=endianArg~string~upper
  if endian<>'BIG' & endian<>'LITTLE' then raise syntax 93.900 array('endian must be BIG or LITTLE')
  prefixBytes=prefixBytesArg+0; includePrefix=includePrefixArg; maxFrame=maxFrameArg+0; buffer=''
::method _length private
  expose endian
  use strict arg prefix
  if endian='LITTLE' then prefix=prefix~reverse
  return x2d(c2x(prefix))
::method feed guarded
  expose prefixBytes includePrefix maxFrame buffer
  use strict arg bytes
  buffer=buffer||bytes; out=.array~new
  do while buffer~length>=prefixBytes
    prefix=buffer~left(prefixBytes); n=self~_length(prefix)
    if n>maxFrame then raise syntax 93.900 array('serial frame exceeds maxFrame')
    total=prefixBytes+n
    if buffer~length<total then leave
    if includePrefix then frame=buffer~left(total)
    else frame=buffer~substr(prefixBytes+1,n)
    out~append(frame); buffer=buffer~substr(total+1)
  end
  return out
::method reset guarded
  expose buffer
  buffer=''; return self

::class SerialFrameStream public
::attribute port get
::attribute framer get
::attribute source get
::attribute name get
::attribute frameCount get

::method init
  expose port framer source name frameCount registration
  use strict arg portArg,framerArg,nameArg=''
  port=portArg; framer=framerArg; name=nameArg~string; frameCount=0
  if name='' then name='frames'
  source=.EventSource~new(port~source~sourceId||'/'||name)
  registration=port~on('DATA',self,'_ONDATA','SYNC')

::method on
  expose source
  use strict arg eventName,target,messageName,delivery='SYNC'
  type=.SerialEvents~resolve(eventName)
  if eventName~string~upper='FRAME' then type=.SerialEvents~FRAME
  return source~on(type,target,messageName,delivery)

::method when
  expose source
  use strict arg filter
  return source~when(filter)

::method _onData
  expose framer source port frameCount
  use strict arg event
  data=event~data
  frames=framer~feed(data~bytes)
  do frame over frames
    frameCount+=1
    source~emit(.SerialEvents~FRAME,.SerialFrameData~new(self,port,frame,frameCount))
  end

::method reset
  expose framer frameCount
  framer~reset; frameCount=0; return self

::requires 'SerialRuntime.cls'
