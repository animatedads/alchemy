/*----------------------------------------------------------------------------*/
/* Minimal deterministic CBOR model for CTAP2.                               */
/* Supports integers, byte/text strings, arrays, maps, booleans and null.     */
/*----------------------------------------------------------------------------*/

::class CborBytes public
::attribute bytes get
::method init
  expose bytes
  use strict arg value=''
  bytes=value
::method hex
  expose bytes
  return c2x(bytes)

::class CborText public
::attribute text get
::method init
  expose text
  use strict arg value=''
  text=value~string
::method string
  expose text
  return text

::class CborBool public
::attribute value get
::method init
  expose value
  use strict arg v
  value=(v==.true)
::method booleanValue
  expose value
  return value

::class CborNull public

::class CborPair public
::attribute key get
::attribute value get
::method init
  expose key value
  use strict arg keyArg, valueArg
  key=keyArg; value=valueArg

::class CborMap public
::attribute entries get
::method init
  expose entries
  entries=.array~new

::method put
  expose entries
  use strict arg key,value
  id=self~keyId(key)
  do i=1 to entries~items
    if self~keyId(entries[i]~key)==id then do
      entries[i]=.CborPair~new(key,value)
      return self
    end
  end
  entries~append(.CborPair~new(key,value))
  return self

::method putInt
  use strict arg key,value
  return self~put(key+0,value)
::method putText
  use strict arg key,value
  return self~put(.CborText~new(key),value)

::method get
  expose entries
  use strict arg key, default=.nil
  id=self~keyId(key)
  do pair over entries
    if self~keyId(pair~key)==id then return pair~value
  end
  return default
::method getInt
  use strict arg key, default=.nil
  return self~get(key+0,default)
::method getText
  use strict arg key, default=.nil
  return self~get(.CborText~new(key),default)
::method hasInt
  use strict arg key
  return self~getInt(key,.CborMissing~new)~class<>.CborMissing
::method items
  expose entries
  return entries~items

::method keyId private
  use strict arg key
  if key~isA(.CborText) then return 'T:'||key~text
  if key~datatype('W') then return 'I:'||key
  return 'O:'||key~string

::class CborMissing public

::class CborBinary public
::method u16be class
  use strict arg value
  return d2c(value,2)
::method u32be class
  use strict arg value
  return d2c(value,4)
::method fromU16be class
  use strict arg bytes
  if bytes~length<>2 then raise syntax 93.900 array('u16be requires 2 bytes')
  return c2d(bytes)
::method fromU32be class
  use strict arg bytes
  if bytes~length<>4 then raise syntax 93.900 array('u32be requires 4 bytes')
  return c2d(bytes)

::class CborCodec public
::method encode class
  use strict arg value
  if value~isA(.CborBytes) then return self~majorLength(2,value~bytes~length)||value~bytes
  if value~isA(.CborText) then do
    text=value~text
    return self~majorLength(3,text~length)||text
  end
  if value~isA(.CborBool) then do
    if value~value then return 'F5'x
    return 'F4'x
  end
  if value~isA(.CborNull) then return 'F6'x
  if value~isA(.CborMap) then do
    out=self~majorLength(5,value~entries~items)
    do pair over value~entries
      out=out||self~encode(pair~key)||self~encode(pair~value)
    end
    return out
  end
  if value~isA(.Array) then do
    out=self~majorLength(4,value~items)
    do item over value
      out=out||self~encode(item)
    end
    return out
  end
  if value~datatype('W') then do
    n=value+0
    if n>=0 then return self~majorLength(0,n)
    return self~majorLength(1,-1-n)
  end
  text=value~string
  return self~majorLength(3,text~length)||text

::method decode class
  use strict arg bytes
  decoder=.CborDecoder~new(bytes)
  value=decoder~readOne
  if decoder~remaining<>0 then raise syntax 93.900 array('trailing CBOR bytes')
  return value

::method majorLength class private
  use strict arg major,length
  if length<0 then raise syntax 93.900 array('negative CBOR length')
  base=major*32
  if length<24 then return d2c(base+length)
  if length<=255 then return d2c(base+24)||d2c(length)
  if length<=65535 then return d2c(base+25)||.CborBinary~u16be(length)
  if length<=4294967295 then return d2c(base+26)||.CborBinary~u32be(length)
  raise syntax 93.900 array('CBOR length exceeds dev3 codec range')

::class CborDecoder public
::attribute bytes get
::attribute position get
::method init
  expose bytes position
  use strict arg bytesArg
  bytes=bytesArg; position=1
::method remaining
  expose bytes position
  return bytes~length-position+1
::method readBytes private
  expose bytes position
  use strict arg count
  if count<0 | position+count-1>bytes~length then raise syntax 93.900 array('truncated CBOR')
  out=bytes~substr(position,count)
  position+=count
  return out
::method readByte private
  return c2d(self~readBytes(1))
::method readLength private
  use strict arg ai
  select
    when ai<24 then return ai
    when ai=24 then return self~readByte
    when ai=25 then return .CborBinary~fromU16be(self~readBytes(2))
    when ai=26 then return .CborBinary~fromU32be(self~readBytes(4))
    otherwise raise syntax 93.900 array('unsupported or indefinite CBOR length')
  end
::method readOne
  first=self~readByte
  major=first%32
  ai=first//32
  if major=7 then do
    select
      when ai=20 then return .CborBool~new(.false)
      when ai=21 then return .CborBool~new(.true)
      when ai=22 then return .CborNull~new
      otherwise raise syntax 93.900 array('unsupported CBOR simple value')
    end
  end
  n=self~readLength(ai)
  select
    when major=0 then return n
    when major=1 then return -1-n
    when major=2 then return .CborBytes~new(self~readBytes(n))
    when major=3 then return .CborText~new(self~readBytes(n))
    when major=4 then do
      arr=.array~new
      do n; arr~append(self~readOne); end
      return arr
    end
    when major=5 then do
      map=.CborMap~new
      do n; map~put(self~readOne,self~readOne); end
      return map
    end
    otherwise raise syntax 93.900 array('unsupported CBOR major type '||major)
  end
