/* Native IBM 3270 presentation-space/data-stream engine v0.1.
 * Transport independent: TN3270 and a channel-attached 3270 may feed the
 * same engine.  Initial executable slice is Model 2 (24x80), basic fields,
 * W/EW/EWA, SBA/SF/IC/PT/RA/EUA and Read Modified input generation. */
::class Command3270 public
::constant WRITE "F1"x
::constant READ_BUFFER "F2"x
::constant ERASE_WRITE "F5"x
::constant READ_MODIFIED "F6"x
::constant ERASE_WRITE_ALTERNATE "7E"x

::class Order3270 public
::constant PT "05"x
::constant SBA "11"x
::constant EUA "12"x
::constant IC "13"x
::constant SF "1D"x
::constant SA "28"x
::constant SFE "29"x
::constant MF "2C"x
::constant RA "3C"x

::class Aid3270 public
::constant NO_AID "60"x
::constant PA1 "6C"x
::constant CLEAR "6D"x
::constant PA2 "6E"x
::constant PA3 "6B"x
::constant ENTER "7D"x
::constant PF1 "F1"x
::constant PF2 "F2"x
::constant PF3 "F3"x
::constant PF4 "F4"x
::constant PF5 "F5"x
::constant PF6 "F6"x
::constant PF7 "F7"x
::constant PF8 "F8"x
::constant PF9 "F9"x
::constant PF10 "7A"x
::constant PF11 "7B"x
::constant PF12 "7C"x
::constant PF13 "C1"x
::constant PF14 "C2"x
::constant PF15 "C3"x
::constant PF16 "C4"x
::constant PF17 "C5"x
::constant PF18 "C6"x
::constant PF19 "C7"x
::constant PF20 "C8"x
::constant PF21 "C9"x
::constant PF22 "4A"x
::constant PF23 "4B"x
::constant PF24 "4C"x

::class Address3270 public
::method sixBitTable class
  return "40C1C2C3C4C5C6C7C8C94A4B4C4D4E4F50D1D2D3D4D5D6D7D8D95A5B5C5D5E5F6061E2E3E4E5E6E7E8E96A6B6C6D6E6FF0F1F2F3F4F5F6F7F8F97A7B7C7D7E7F"x
::method encode class
  use arg addressArg
  address = addressArg // 4096
  table = self~sixBitTable
  hi = address % 64; lo = address // 64
  return table~substr(hi + 1,1) || table~substr(lo + 1,1)
::method decode class
  use arg bytes
  if bytes~length < 2 then return -1
  table = self~sixBitTable
  a = table~pos(bytes~substr(1,1)); b = table~pos(bytes~substr(2,1))
  if a > 0 & b > 0 then return (a - 1) * 64 + (b - 1)
  n1=x2d(bytes~substr(1,1)~c2x); n2=x2d(bytes~substr(2,1)~c2x)
  if n1 < 64 then return n1 * 256 + n2
  return -1

::class Field3270 public
::attribute address get
::attribute attribute get
::attribute modified
::method init
  expose address attribute modified
  use arg a, fa
  address=a; attribute=fa; modified=(bitand(fa,"01"x)=="01"x)
::method protected
  expose attribute
  return bitand(attribute,"20"x)=="20"x
::method numeric
  expose attribute
  return bitand(attribute,"10"x)=="10"x
::method nonDisplay
  expose attribute
  return bitand(attribute,"0C"x)=="0C"x

::class PresentationSpace3270 public
::attribute rows get
::attribute columns get
::attribute cursor
::attribute generation get
::attribute keyboardLocked
::method init
  expose rows columns cursor generation keyboardLocked cells fields currentField
  use arg rowsArg=24, columnsArg=80
  rows=rowsArg; columns=columnsArg; cursor=0; generation=0; keyboardLocked=.false
  cells=copies("00"x, rows*columns); fields=.array~new; currentField=.nil
::method clear
  expose rows columns cursor cells fields currentField
  cells=copies("00"x,rows*columns); fields=.array~new; currentField=.nil; cursor=0
::method size
  expose rows columns
  return rows*columns
::method putByte
  expose cells
  use arg address, byte
  address=address // self~size
  cells=cells~overlay(byte,address+1)
::method byteAt
  expose cells
  use arg address
  return cells~substr((address//self~size)+1,1)
::method addField
  expose fields currentField
  use arg address, fa
  f=.Field3270~new(address,fa); fields~append(f); currentField=f
  return f
::method fields
  expose fields
  return .TerminalUtil~copyArray(fields)
::method fieldAt
  expose fields
  use arg address
  best=.nil; bestDistance=self~size+1
  do f over fields
    d=(address-f~address+self~size)//self~size
    if d>0 & d<bestDistance then do; best=f; bestDistance=d; end
  end
  return best
::method fieldEnd private
  expose fields
  use arg field
  finish=self~size-1
  do f over fields
    if f~address>field~address & f~address-1<finish then finish=f~address-1
  end
  return finish
::method fieldText
  use arg field, codepage
  start=field~address+1; finish=self~fieldEnd(field)
  bytes=""
  do a=start to finish; bytes ||= self~byteAt(a); end
  return codepage~decode(bytes)
::method setFieldText
  use arg field, text, codepage
  if field==.nil then return .TerminalResult~failure("3270_NO_FIELD")
  if field~protected then return .TerminalResult~failure("3270_PROTECTED_FIELD")
  start=field~address+1; finish=self~fieldEnd(field); capacity=finish-start+1
  encoded=codepage~encode(text)
  if encoded~length>capacity then return .TerminalResult~failure("3270_FIELD_OVERFLOW",encoded~length||"/"||capacity)
  encoded=encoded||copies("00"x,capacity-encoded~length)
  do i=1 to capacity; self~putByte(start+i-1,encoded~substr(i,1)); end
  field~modified=.true
  return .TerminalResult~success
::method text
  expose rows columns
  use arg codepage
  answer=""
  do r=0 to rows-1
    line=""
    do c=0 to columns-1
      a=r*columns+c; f=self~fieldAt(a)
      if f<>.nil & f~nonDisplay then line||=" "
      else line||=codepage~decode(self~byteAt(a))
    end
    answer||=line
    if r<rows-1 then answer||='0A'x
  end
  return answer
::method advanceGeneration
  expose generation
  generation += 1
  return generation

::class DataStream3270 public
::attribute model get
::attribute codepage get
::method init
  expose model codepage
  use arg modelArg=.nil, codepageArg=.nil
  if modelArg==.nil then model=.PresentationSpace3270~new; else model=modelArg
  if codepageArg==.nil then codepage=.CodePage3270Registry~forName("37"); else codepage=codepageArg
::method applyHostRecord
  expose model
  use arg record
  if record~length<1 then return .TerminalResult~failure("3270_EMPTY_RECORD")
  cmd=record~substr(1,1)
  if cmd==.Command3270~READ_BUFFER | cmd==.Command3270~READ_MODIFIED then return .TerminalResult~success(cmd)
  if cmd<>.Command3270~WRITE & cmd<>.Command3270~ERASE_WRITE & cmd<>.Command3270~ERASE_WRITE_ALTERNATE then return .TerminalResult~failure("3270_UNSUPPORTED_COMMAND",cmd~c2x)
  if record~length<2 then return .TerminalResult~failure("3270_MISSING_WCC")
  if cmd<>.Command3270~WRITE then model~clear
  wcc=x2d(record~substr(2,1)~c2x)
  if bitand(wcc,"02"x)=="02"x then model~keyboardLocked=.false
  addr=0; i=3
  do while i<=record~length
    b=record~substr(i,1)
    select
      when b==.Order3270~SBA then do
        if i+2>record~length then return .TerminalResult~failure("3270_TRUNCATED_SBA")
        addr=.Address3270~decode(record~substr(i+1,2)); if addr<0 then return .TerminalResult~failure("3270_BAD_ADDRESS")
        i+=3
      end
      when b==.Order3270~SF then do
        if i+1>record~length then return .TerminalResult~failure("3270_TRUNCATED_SF")
        model~putByte(addr,"00"x); model~addField(addr,record~substr(i+1,1)); addr=(addr+1)//model~size; i+=2
      end
      when b==.Order3270~IC then do; model~cursor=addr; i+=1; end
      when b==.Order3270~RA then do
        if i+3>record~length then return .TerminalResult~failure("3270_TRUNCATED_RA")
        target=.Address3270~decode(record~substr(i+1,2)); ch=record~substr(i+3,1)
        do while addr<>target; model~putByte(addr,ch); addr=(addr+1)//model~size; end
        i+=4
      end
      when b==.Order3270~EUA then do
        if i+2>record~length then return .TerminalResult~failure("3270_TRUNCATED_EUA")
        target=.Address3270~decode(record~substr(i+1,2))
        do while addr<>target
          f=model~fieldAt(addr); if f==.nil | \f~protected then model~putByte(addr,"00"x)
          addr=(addr+1)//model~size
        end
        i+=3
      end
      when b==.Order3270~PT then do
        found=.false
        do f over model~fields
          if \f~protected & f~address+1>addr then do; addr=(f~address+1)//model~size; found=.true; leave; end
        end
        if \found then do f over model~fields; if \f~protected then do; addr=(f~address+1)//model~size; leave; end; end
        i+=1
      end
      when b==.Order3270~SFE | b==.Order3270~SA | b==.Order3270~MF then return .TerminalResult~failure("3270_EXTENDED_ATTRIBUTE_NOT_IMPLEMENTED",b~c2x)
      otherwise do; model~putByte(addr,b); addr=(addr+1)//model~size; i+=1; end
    end
  end
  g=model~advanceGeneration
  return .TerminalResult~success(g)
::method buildReadModified
  expose model codepage
  use arg aid="7D"x
  bytes=aid||.Address3270~encode(model~cursor)
  do f over model~fields
    if \f~protected & f~modified then do
      raw=""; start=f~address+1
      finish=model~size-1
      fs=model~fields
      do nf over fs; if nf~address>f~address & nf~address-1<finish then finish=nf~address-1; end
      do a=start to finish; raw||=model~byteAt(a); end
      do while raw~length>0 & raw~right(1)=="00"x; raw=raw~left(raw~length-1); end
      bytes||=.Order3270~SBA||.Address3270~encode(start)||raw
    end
  end
  return bytes

::requires "TerminalCore.cls"
::requires "CodePage3270.cls"
