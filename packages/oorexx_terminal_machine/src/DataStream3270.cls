/* Native IBM 3270 presentation-space/data-stream engine v0.1.
 * Transport independent: TN3270 and a channel-attached 3270 may feed the
 * same engine.  Initial executable slice is Model 2 (24x80), basic fields,
 * W/EW/EWA, SBA/SF/IC/PT/RA/EUA and Read Modified input generation. */
::class Command3270 public
::constant WRITE "F1"x
::constant READ_BUFFER "F2"x
::constant ERASE_WRITE "F5"x
::constant READ_MODIFIED "F6"x
::constant WRITE_STRUCTURED_FIELD "F3"x
::constant READ_MODIFIED_ALL "6E"x
::constant ERASE_ALL_UNPROTECTED "6F"x
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

::class Attribute3270 public
/* Extended-field / character attribute types used by 3270 SFE/SA/MF. */
::constant BASIC_FIELD "C0"x
::constant HIGHLIGHT "41"x
::constant FOREGROUND "42"x
::constant CHARACTER_SET "43"x
::constant BACKGROUND "45"x
::constant RESET_ALL "00"x

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
::constant STRUCTURED_FIELD "88"x

::class StructuredField3270 public
::constant READ_PARTITION "01"x
::constant ERASE_RESET "03"x
::constant SET_REPLY_MODE "09"x
::constant OUTBOUND_3270DS "40"x
::constant QUERY_REPLY "81"x
::constant RP_QUERY "02"x
::constant RP_QUERY_LIST "03"x
::constant RPQ_LIST "00"x
::constant RPQ_EQUIV "40"x
::constant RPQ_ALL "80"x
::constant REPLY_MODE_FIELD "00"x
::constant REPLY_MODE_EXTENDED_FIELD "01"x
::constant REPLY_MODE_CHARACTER "02"x
::constant QR_NULL "FF"x
::constant QR_SUMMARY "80"x
::constant QR_USABLE_AREA "81"x
::constant QR_COLOR "86"x
::constant QR_HIGHLIGHTING "87"x

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
  /* 14-bit binary addressing is identified by zero high bits. */
  n1=x2d(bytes~substr(1,1)~c2x); n2=x2d(bytes~substr(2,1)~c2x)
  if n1 < 64 then return n1 * 256 + n2
  return -1

::class Field3270 public
::attribute address get
::attribute attribute get
::attribute modified
::method init
  expose address attribute modified extendedAttributes
  use arg a, fa, extArg=.nil
  address=a; attribute=fa; n=x2d(fa~c2x); modified=(n//2==1)
  extendedAttributes=.TerminalUtil~copyDirectory(extArg)
::method protected
  expose attribute
  n=x2d(attribute~c2x); return (n//64)>=32
::method numeric
  expose attribute
  n=x2d(attribute~c2x); return (n//32)>=16
::method nonDisplay
  expose attribute
  n=x2d(attribute~c2x)//16
  return n>=12
::method setBasicAttribute
  expose attribute modified
  use arg fa
  attribute=fa; n=x2d(fa~c2x); modified=(n//2==1)
  return self
::method setExtendedAttribute
  expose extendedAttributes
  use arg type, value
  extendedAttributes[type~c2x]=value
  return self
::method extendedAttribute
  expose extendedAttributes
  use arg type
  return extendedAttributes~at(type~c2x)
::method extendedAttributes
  expose extendedAttributes
  return .TerminalUtil~copyDirectory(extendedAttributes)
::method hasExtendedAttributes
  expose extendedAttributes
  return extendedAttributes~items>0

::class PresentationSpace3270 public
::attribute rows get
::attribute columns get
::attribute cursor
::attribute generation get
::attribute keyboardLocked
::method init
  expose rows columns cursor generation keyboardLocked cells fields currentField characterAttributes
  use arg rowsArg=24, columnsArg=80
  rows=rowsArg; columns=columnsArg; cursor=0; generation=0; keyboardLocked=.false
  cells=copies("00"x, rows*columns); fields=.array~new; currentField=.nil; characterAttributes=.directory~new
::method clear
  expose rows columns cursor cells fields currentField characterAttributes
  cells=copies("00"x,rows*columns); fields=.array~new; currentField=.nil; characterAttributes=.directory~new; cursor=0
::method size
  expose rows columns
  return rows*columns
::method putByte
  expose cells
  use arg address, byte
  address=address // self~size
  cells=cells~overlay(byte,address+1)
::method setCharacterAttributes
  expose characterAttributes
  use arg address, attrs
  key=(address//self~size)~string
  if attrs==.nil | attrs~items==0 then do
    characterAttributes~remove(key)
    return self
  end
  characterAttributes[key]=.TerminalUtil~copyDirectory(attrs)
  return self
::method clearCharacterAttributesAt
  expose characterAttributes
  use arg address
  characterAttributes~remove((address//self~size)~string)
  return self
::method characterAttributesAt
  expose characterAttributes
  use arg address
  attrs=characterAttributes~at((address//self~size)~string)
  return .TerminalUtil~copyDirectory(attrs)
::method byteAt
  expose cells
  use arg address
  return cells~substr((address//self~size)+1,1)
::method addField
  expose fields currentField
  use arg address, fa, extArg=.nil
  f=.Field3270~new(address,fa,extArg); fields~append(f); currentField=f
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
::method nextFieldAddress private
  expose fields
  use arg field
  if fields~items<=1 then return field~address
  best=.nil; bestDistance=self~size+1
  do f over fields
    if f==field then iterate
    d=(f~address-field~address+self~size)//self~size
    if d>0 & d<bestDistance then do; best=f~address; bestDistance=d; end
  end
  if best==.nil then return field~address
  return best
::method fieldDataBytes
  use arg field
  if field==.nil then return ""
  answer=""; a=(field~address+1)//self~size; stop=self~nextFieldAddress(field)
  do while a<>stop
    answer||=self~byteAt(a)
    a=(a+1)//self~size
  end
  return answer
::method fieldText
  use arg field, codepage
  return codepage~decode(self~fieldDataBytes(field))
::method linearAddress
  expose rows columns
  use arg row, column
  if row<1 | row>rows | column<1 | column>columns then return -1
  return (row-1)*columns+(column-1)
::method rowForAddress
  expose columns
  use arg address
  return ((address//self~size)%columns)+1
::method columnForAddress
  expose columns
  use arg address
  return ((address//self~size)//columns)+1
::method inputFields
  expose fields
  answer=.array~new
  do f over fields
    if \f~protected then answer~append(f)
  end
  return answer
::method fieldAtPosition
  use arg row, column
  address=self~linearAddress(row,column)
  if address<0 then return .nil
  return self~fieldAt(address)
::method setCursorPosition
  expose cursor
  use arg row, column
  address=self~linearAddress(row,column)
  if address<0 then return .TerminalResult~failure("3270_CURSOR_RANGE",row||","||column)
  cursor=address
  return .TerminalResult~success(address)
::method setInputTextAt
  expose cursor
  use arg row, column, text, codepage
  address=self~linearAddress(row,column)
  if address<0 then return .TerminalResult~failure("3270_CURSOR_RANGE",row||","||column)
  if self~fieldStartingAt(address)<>.nil then return .TerminalResult~failure("3270_FIELD_ATTRIBUTE_POSITION",row||","||column)
  f=self~fieldAt(address)
  if f==.nil then return .TerminalResult~failure("3270_NO_FIELD",row||","||column)
  opResult=self~setFieldText(f,text,codepage)
  if opResult~ok then cursor=address
  return opResult
::method setInputTextAtCursor
  expose cursor
  use arg text, codepage
  row=self~rowForAddress(cursor); column=self~columnForAddress(cursor)
  return self~setInputTextAt(row,column,text,codepage)
::method fieldStartingAt
  expose fields
  use arg address
  a=address//self~size
  do f over fields
    if f~address==a then return f
  end
  return .nil
::method resetModified
  expose fields
  do f over fields; f~modified=.false; end
  return self
::method setFieldText
  use arg field, text, codepage
  if field==.nil then return .TerminalResult~failure("3270_NO_FIELD")
  if field~protected then return .TerminalResult~failure("3270_PROTECTED_FIELD")
  capacity=self~fieldDataBytes(field)~length
  encoded=codepage~encode(text)
  if encoded~length>capacity then return .TerminalResult~failure("3270_FIELD_OVERFLOW",encoded~length||"/"||capacity)
  encoded=encoded||copies("00"x,capacity-encoded~length)
  a=(field~address+1)//self~size
  do i=1 to capacity
    self~putByte(a,encoded~substr(i,1)); a=(a+1)//self~size
  end
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
      if f<>.nil then do
        if f~nonDisplay then line||=" "
        else line||=codepage~decode(self~byteAt(a))
      end
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
  expose model codepage pendingStructuredReply replyMode
  use arg modelArg=.nil, codepageArg=.nil
  if modelArg==.nil then model=.PresentationSpace3270~new; else model=modelArg
  if codepageArg==.nil then codepage=.CodePage3270Registry~forName("37"); else codepage=codepageArg
  pendingStructuredReply=""; replyMode=.StructuredField3270~REPLY_MODE_FIELD
::method replyMode
  expose replyMode
  return replyMode
::method drainStructuredReply
  expose pendingStructuredReply
  out=pendingStructuredReply; pendingStructuredReply=""; return out
::method applyHostRecord
  expose model
  use arg record
  if record~length<1 then return .TerminalResult~failure("3270_EMPTY_RECORD")
  cmd=record~substr(1,1)
  if cmd==.Command3270~READ_BUFFER | cmd==.Command3270~READ_MODIFIED | cmd==.Command3270~READ_MODIFIED_ALL then return .TerminalResult~success(cmd)
  if cmd==.Command3270~ERASE_ALL_UNPROTECTED then return self~eraseAllUnprotected
  if cmd==.Command3270~WRITE_STRUCTURED_FIELD then return self~applyStructuredFields(record~substr(2))
  if cmd<>.Command3270~WRITE & cmd<>.Command3270~ERASE_WRITE & cmd<>.Command3270~ERASE_WRITE_ALTERNATE then return .TerminalResult~failure("3270_UNSUPPORTED_COMMAND",cmd~c2x)
  if record~length<2 then return .TerminalResult~failure("3270_MISSING_WCC")
  if cmd<>.Command3270~WRITE then model~clear
  wcc=x2d(record~substr(2,1)~c2x)
  if (wcc//4)>=2 then model~keyboardLocked=.false
  /* WCC reset-MDT is represented by bit 6 in the unencoded control byte. */
  if wcc>=64 then model~resetModified
  addr=0; i=3; activeCharacterAttributes=.directory~new
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
        model~putByte(addr,"00"x); model~clearCharacterAttributesAt(addr)
        model~addField(addr,record~substr(i+1,1)); addr=(addr+1)//model~size; i+=2
      end
      when b==.Order3270~SFE then do
        if i+1>record~length then return .TerminalResult~failure("3270_TRUNCATED_SFE")
        count=x2d(record~substr(i+1,1)~c2x)
        if i+1+(count*2)>record~length then return .TerminalResult~failure("3270_TRUNCATED_SFE_ATTRIBUTES")
        basic="00"x; ext=.directory~new; p=i+2
        do n=1 to count
          atype=record~substr(p,1); avalue=record~substr(p+1,1); p+=2
          if atype==.Attribute3270~BASIC_FIELD then basic=avalue
          else ext[atype~c2x]=avalue
        end
        model~putByte(addr,"00"x); model~clearCharacterAttributesAt(addr)
        model~addField(addr,basic,ext); addr=(addr+1)//model~size; i=p
      end
      when b==.Order3270~SA then do
        if i+2>record~length then return .TerminalResult~failure("3270_TRUNCATED_SA")
        atype=record~substr(i+1,1); avalue=record~substr(i+2,1)
        if atype==.Attribute3270~RESET_ALL then activeCharacterAttributes=.directory~new
        else activeCharacterAttributes[atype~c2x]=avalue
        i+=3
      end
      when b==.Order3270~MF then do
        if i+1>record~length then return .TerminalResult~failure("3270_TRUNCATED_MF")
        count=x2d(record~substr(i+1,1)~c2x)
        if i+1+(count*2)>record~length then return .TerminalResult~failure("3270_TRUNCATED_MF_ATTRIBUTES")
        f=model~fieldStartingAt(addr)
        if f==.nil then return .TerminalResult~failure("3270_MF_NOT_FIELD_ATTRIBUTE",addr)
        p=i+2
        do n=1 to count
          atype=record~substr(p,1); avalue=record~substr(p+1,1); p+=2
          if atype==.Attribute3270~BASIC_FIELD then f~setBasicAttribute(avalue)
          else f~setExtendedAttribute(atype,avalue)
        end
        i=p
      end
      when b==.Order3270~IC then do; model~cursor=addr; i+=1; end
      when b==.Order3270~RA then do
        if i+3>record~length then return .TerminalResult~failure("3270_TRUNCATED_RA")
        target=.Address3270~decode(record~substr(i+1,2)); ch=record~substr(i+3,1)
        if target<0 then return .TerminalResult~failure("3270_BAD_ADDRESS")
        do while addr<>target
          model~putByte(addr,ch); model~setCharacterAttributes(addr,activeCharacterAttributes); addr=(addr+1)//model~size
        end
        i+=4
      end
      when b==.Order3270~EUA then do
        if i+2>record~length then return .TerminalResult~failure("3270_TRUNCATED_EUA")
        target=.Address3270~decode(record~substr(i+1,2)); if target<0 then return .TerminalResult~failure("3270_BAD_ADDRESS")
        do while addr<>target
          f=model~fieldAt(addr)
          if f==.nil | \f~protected then do; model~putByte(addr,"00"x); model~clearCharacterAttributesAt(addr); end
          addr=(addr+1)//model~size
        end
        i+=3
      end
      when b==.Order3270~PT then do
        /* Move to first position of next unprotected field. */
        found=.false
        do f over model~fields
          if \f~protected & f~address+1>addr then do; addr=(f~address+1)//model~size; found=.true; leave; end
        end
        if \found then do f over model~fields; if \f~protected then do; addr=(f~address+1)//model~size; leave; end; end
        i+=1
      end
      otherwise do
        model~putByte(addr,b); model~setCharacterAttributes(addr,activeCharacterAttributes)
        addr=(addr+1)//model~size; i+=1
      end
    end
  end
  g=model~advanceGeneration
  return .TerminalResult~success(g)

::method eraseAllUnprotected private
  expose model
  fs=model~fields
  if fs~items==0 then do
    model~clear; model~keyboardLocked=.false
    g=model~advanceGeneration
    return .TerminalResult~success(g)
  end
  first=-1
  do f over fs
    if f~protected then iterate
    if first<0 then first=(f~address+1)//model~size
    capacity=model~fieldDataBytes(f)~length
    a=(f~address+1)//model~size
    do i=1 to capacity
      model~putByte(a,"00"x); model~clearCharacterAttributesAt(a); a=(a+1)//model~size
    end
    f~modified=.false
  end
  if first>=0 then model~cursor=first; else model~cursor=0
  model~keyboardLocked=.false
  g=model~advanceGeneration
  return .TerminalResult~success(g)
::method be16 private
  use arg value
  n=value//65536
  return d2c(n%256)||d2c(n//256)
::method structuredField private
  use arg id, body=""
  length=3+body~length
  return self~be16(length)||id||body
::method supportedQueryCodes private
  return .array~of(.StructuredField3270~QR_SUMMARY,.StructuredField3270~QR_USABLE_AREA,.StructuredField3270~QR_COLOR,.StructuredField3270~QR_HIGHLIGHTING)
::method queryReplyFor private
  expose model
  use arg code
  select
    when code==.StructuredField3270~QR_NULL then body=""
    when code==.StructuredField3270~QR_SUMMARY then do
      body=""; do q over self~supportedQueryCodes; body||=q; end
    end
    when code==.StructuredField3270~QR_USABLE_AREA then do
      body="01"x||"00"x||self~be16(model~columns)||self~be16(model~rows)||"01"x
      body||=self~be16(1)||self~be16(1)||self~be16(1)||self~be16(1)
      body||=d2c(10)||d2c(20)||self~be16(model~size)
    end
    when code==.StructuredField3270~QR_COLOR then do
      body="00"x||d2c(16)||"00F4"x
      do n=241 to 255; body||=d2c(n)||d2c(n); end
    end
    when code==.StructuredField3270~QR_HIGHLIGHTING then body=d2c(5)||"00F0F1F1F2F2F4F4F8F8"x
    otherwise return ""
  end
  return self~structuredField(.StructuredField3270~QUERY_REPLY,code||body)
::method buildQueryReply private
  use arg requested=.nil, requestType=.nil
  if requestType==.nil then requestType=.StructuredField3270~RPQ_ALL
  selected=.array~new; supported=self~supportedQueryCodes
  if requestType==.StructuredField3270~RPQ_LIST then do
    if requested<>.nil then do q over supported
      if requested~pos(q)>0 then selected~append(q)
    end
  end
  else do q over supported; selected~append(q); end
  if selected~items==0 then selected~append(.StructuredField3270~QR_NULL)
  bytes=.Aid3270~STRUCTURED_FIELD
  do q over selected; bytes||=self~queryReplyFor(q); end
  return bytes
::method applyReadPartition private
  expose pendingStructuredReply
  use arg sf
  if sf~length<5 then return .TerminalResult~failure("3270_WSF_READ_PARTITION_SHORT")
  partition=sf~substr(4,1); operation=sf~substr(5,1)
  if operation==.StructuredField3270~RP_QUERY then do
    if partition<>"FF"x then return .TerminalResult~failure("3270_WSF_BAD_PARTITION",partition~c2x)
    pendingStructuredReply=self~buildQueryReply
    return .TerminalResult~success("QUERY_REPLY")
  end
  if operation==.StructuredField3270~RP_QUERY_LIST then do
    if partition<>"FF"x then return .TerminalResult~failure("3270_WSF_BAD_PARTITION",partition~c2x)
    if sf~length<6 then return .TerminalResult~failure("3270_WSF_QUERY_LIST_SHORT")
    requestType=sf~substr(6,1)
    if requestType<>.StructuredField3270~RPQ_LIST & requestType<>.StructuredField3270~RPQ_EQUIV & requestType<>.StructuredField3270~RPQ_ALL then return .TerminalResult~failure("3270_WSF_QUERY_LIST_TYPE",requestType~c2x)
    requested=sf~substr(7)
    pendingStructuredReply=self~buildQueryReply(requested,requestType)
    return .TerminalResult~success("QUERY_REPLY")
  end
  /* Candidate8 implements the implicit-partition read operations as defined
   * for Read Partition.  Explicit partition creation is still unsupported. */
  if partition<>"00"x then return .TerminalResult~failure("3270_WSF_BAD_PARTITION",partition~c2x)
  if operation==.Command3270~READ_BUFFER then do
    pendingStructuredReply=self~buildReadBuffer
    return .TerminalResult~success("READ_BUFFER")
  end
  if operation==.Command3270~READ_MODIFIED then do
    pendingStructuredReply=self~buildReadModified
    return .TerminalResult~success("READ_MODIFIED")
  end
  if operation==.Command3270~READ_MODIFIED_ALL then do
    pendingStructuredReply=self~buildReadModified(.Aid3270~NO_AID,.true)
    return .TerminalResult~success("READ_MODIFIED_ALL")
  end
  return .TerminalResult~failure("3270_WSF_READ_PARTITION_OPERATION",operation~c2x)

::method applyOutbound3270DS private
  use arg sf
  if sf~length<5 then return .TerminalResult~failure("3270_WSF_OUTBOUND_DS_SHORT")
  partition=sf~substr(4,1)
  if partition<>"00"x then return .TerminalResult~failure("3270_WSF_BAD_PARTITION",partition~c2x)
  command=sf~substr(5,1)
  if command<>.Command3270~WRITE & command<>.Command3270~ERASE_WRITE & command<>.Command3270~ERASE_WRITE_ALTERNATE & command<>.Command3270~ERASE_ALL_UNPROTECTED then return .TerminalResult~failure("3270_WSF_OUTBOUND_DS_COMMAND",command~c2x)
  embedded=command||sf~substr(6)
  return self~applyHostRecord(embedded)
::method applyStructuredFields private
  expose replyMode
  use arg bytes
  if bytes~length==0 then return .TerminalResult~failure("3270_WSF_EMPTY")
  offset=1; last=.TerminalResult~success
  do while offset<=bytes~length
    if offset+2>bytes~length then return .TerminalResult~failure("3270_WSF_TRUNCATED_LENGTH")
    n=x2d(bytes~substr(offset,2)~c2x)
    if n==0 then n=bytes~length-offset+1
    if n<3 | offset+n-1>bytes~length then return .TerminalResult~failure("3270_WSF_BAD_LENGTH",n)
    sf=bytes~substr(offset,n); id=sf~substr(3,1)
    select
      when id==.StructuredField3270~READ_PARTITION then last=self~applyReadPartition(sf)
      when id==.StructuredField3270~OUTBOUND_3270DS then last=self~applyOutbound3270DS(sf)
      when id==.StructuredField3270~SET_REPLY_MODE then do
        if n<5 then return .TerminalResult~failure("3270_WSF_SET_REPLY_MODE_SHORT")
        if sf~substr(4,1)<>"00"x then return .TerminalResult~failure("3270_WSF_BAD_PARTITION",sf~substr(4,1)~c2x)
        mode=sf~substr(5,1)
        if mode<>.StructuredField3270~REPLY_MODE_FIELD then return .TerminalResult~failure("3270_WSF_REPLY_MODE_UNSUPPORTED",mode~c2x)
        replyMode=mode; last=.TerminalResult~success("REPLY_MODE_FIELD")
      end
      otherwise return .TerminalResult~failure("3270_WSF_UNSUPPORTED_ID",id~c2x)
    end
    if \last~ok then return last
    offset+=n
  end
  return last

::method buildReadModified
  expose model
  use arg aid="7D"x, includeProtected=.false
  bytes=aid||.Address3270~encode(model~cursor)
  fs=model~fields
  if fs~items==0 then do
    raw=""
    do a=0 to model~size-1; raw||=model~byteAt(a); end
    do while raw~length>0 & raw~right(1)=="00"x; raw=raw~left(raw~length-1); end
    if raw~length>0 then bytes||=.Order3270~SBA||.Address3270~encode(0)||raw
    return bytes
  end
  do f over fs
    if f~modified & (includeProtected | \f~protected) then do
      raw=model~fieldDataBytes(f)
      do while raw~length>0 & raw~right(1)=="00"x; raw=raw~left(raw~length-1); end
      bytes||=.Order3270~SBA||.Address3270~encode((f~address+1)//model~size)||raw
    end
  end
  return bytes
::method appendAttributePairs private
  use arg attrs
  bytes=""
  /* Keep standard 3270 character attribute types in stable wire order. */
  order=.array~of(.Attribute3270~HIGHLIGHT,.Attribute3270~FOREGROUND,.Attribute3270~CHARACTER_SET,.Attribute3270~BACKGROUND)
  emitted=.directory~new
  do atype over order
    value=attrs~at(atype~c2x)
    if value<>.nil then do; bytes||=atype||value; emitted[atype~c2x]=.true; end
  end
  do key over attrs~allIndexes
    if emitted~at(key)<>.nil then iterate
    bytes||=x2c(key)||attrs~at(key)
  end
  return bytes
::method attributeSignature private
  use arg attrs
  if attrs==.nil | attrs~items==0 then return ""
  return self~appendAttributePairs(attrs)~c2x
::method buildReadBuffer
  expose model
  use arg aid="60"x
  bytes=aid||.Address3270~encode(model~cursor); lastSignature=""
  do a=0 to model~size-1
    f=model~fieldStartingAt(a)
    if f<>.nil then do
      /* Field attributes terminate any active character-attribute run. */
      lastSignature=""
      if f~hasExtendedAttributes then do
        ext=f~extendedAttributes; pairs=.Attribute3270~BASIC_FIELD||f~attribute||self~appendAttributePairs(ext)
        count=pairs~length%2
        bytes||=.Order3270~SFE||d2c(count)||pairs
      end
      else bytes||=.Order3270~SF||f~attribute
    end
    else do
      attrs=model~characterAttributesAt(a); signature=self~attributeSignature(attrs)
      if signature<>lastSignature then do
        bytes||=.Order3270~SA||.Attribute3270~RESET_ALL||"00"x
        if attrs~items>0 then do
          pairs=self~appendAttributePairs(attrs)
          p=1
          do while p<=pairs~length
            bytes||=.Order3270~SA||pairs~substr(p,2); p+=2
          end
        end
        lastSignature=signature
      end
      bytes||=model~byteAt(a)
    end
  end
  return bytes
::method buildReadResponse
  use arg command, aid="60"x
  if command==.Command3270~READ_BUFFER then return .TerminalResult~success(self~buildReadBuffer(aid))
  if command==.Command3270~READ_MODIFIED then return .TerminalResult~success(self~buildReadModified(aid,.false))
  if command==.Command3270~READ_MODIFIED_ALL then return .TerminalResult~success(self~buildReadModified(aid,.true))
  return .TerminalResult~failure("3270_NOT_A_READ_COMMAND",command~c2x)

::requires "TerminalCore.cls"
::requires "CodePage3270.cls"
