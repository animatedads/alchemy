/*
 * s3270 reference snapshot parser and semantic differential support.
 *
 * This is deliberately a reference-adapter boundary, not a second terminal
 * implementation. It consumes s3270 ReadBuffer(Ascii) evidence and can also
 * parse the complete peer-script response envelope: data lines, 12-field
 * emulator status and final ok/error. Raw NONDISPLAY bytes are never retained
 * in the exported reference snapshot.
 */
::class S3270ReferenceField public
::attribute address get
::attribute row get
::attribute column get
::attribute length get
::attribute basicAttribute get
::attribute protected get
::attribute numeric get
::attribute modified get
::attribute nonDisplay get

::method init
  expose address row column length basicAttribute protected numeric modified nonDisplay
  use arg addressArg, rowArg, columnArg, lengthArg, basicArg
  address=addressArg; row=rowArg; column=columnArg; length=lengthArg
  basicAttribute=basicArg~string~strip~upper
  n=x2d(basicAttribute)
  /* ooRexx // is remainder. These expressions test the documented low-six-bit
   * c0 attribute masks without introducing a binary helper dependency. */
  protected=(n//64)>=32
  numeric=(n//32)>=16
  modified=(n//2)==1
  low=n//16
  nonDisplay=low>=12

::class S3270ScriptStatus public
::attribute keyboardCode get
::attribute keyboardState get
::attribute formatted get
::attribute cursorFieldProtected get
::attribute connectionState get
::attribute emulatorMode get
::attribute modelNumber get
::attribute rows get
::attribute columns get
::attribute cursorRow0 get
::attribute cursorColumn0 get
::attribute windowId get
::attribute executionTime get

::method init
  expose keyboardCode keyboardState formatted cursorFieldProtected connectionState emulatorMode modelNumber rows columns cursorRow0 cursorColumn0 windowId executionTime
  use arg keyboardCodeArg, formatArg, protectionArg, connectionArg, modeArg, modelArg, rowsArg, columnsArg, cursorRowArg, cursorColumnArg, windowArg, timeArg
  keyboardCode=keyboardCodeArg~string~strip~upper
  if keyboardCode=="U" then keyboardState="UNLOCKED"
  else if keyboardCode=="L" | keyboardCode=="E" then keyboardState="LOCKED"
  else keyboardState="UNKNOWN"
  formatted=formatArg~string~strip~upper=="F"
  cursorFieldProtected=protectionArg~string~strip~upper=="P"
  connectionState=connectionArg~string
  emulatorMode=modeArg~string~strip~upper
  modelNumber=modelArg
  rows=rowsArg; columns=columnsArg
  cursorRow0=cursorRowArg; cursorColumn0=cursorColumnArg
  windowId=windowArg~string; executionTime=timeArg~string

::class S3270ReferenceSnapshot public
::attribute rows get
::attribute columns get
::attribute cursorRow get
::attribute cursorColumn get
::attribute keyboardState get
::attribute fields get
::attribute textRows get
::attribute status get

::method init
  expose rows columns cursorRow cursorColumn keyboardState fields textRows status
  use arg rowsArg, columnsArg, cursorRowArg, cursorColumnArg, fieldsArg, textRowsArg, keyboardStateArg="UNKNOWN", statusArg=.nil
  rows=rowsArg; columns=columnsArg; cursorRow=cursorRowArg; cursorColumn=cursorColumnArg
  keyboardState=keyboardStateArg~string~strip~upper
  fields=.TerminalUtil~copyArray(fieldsArg)
  textRows=.TerminalUtil~copyArray(textRowsArg)
  status=statusArg

::method rowText
  expose rows textRows
  use arg rowArg
  if rowArg<1 | rowArg>rows then return ""
  return textRows[rowArg]

::class S3270ReferenceParser public

/* Parse a complete s3270 peer-script action response. Every successful action
 * ends with a 12-field status line and "ok"; failures end in "error". The
 * status itself carries rows, columns and zero-origin cursor coordinates, so
 * callers cannot accidentally pair one screen buffer with separately sampled
 * dimensions/cursor facts. */
::method parseActionResponse class
  use arg responseText
  lines=responseText~makeArray("0a"x)
  nonEmpty=.array~new
  dataText=""
  do rawLine over lines
    line=rawLine~strip("T","0d"x)
    if line=="" then iterate
    nonEmpty~append(line)
    if left(line,5)=="data:" then do
      if dataText<>"" then dataText||="0a"x
      dataText||=line
    end
  end
  if nonEmpty~items<2 then return .TerminalResult~failure("S3270_RESPONSE_INCOMPLETE","status/ok lines missing")
  completion=nonEmpty[nonEmpty~items]~strip~lower
  statusLine=nonEmpty[nonEmpty~items-1]
  if completion=="error" then return .TerminalResult~failure("S3270_ACTION_ERROR",statusLine)
  if completion<>"ok" then return .TerminalResult~failure("S3270_COMPLETION_INVALID",completion)
  status=self~parseStatus(statusLine)
  if \status~ok then return status
  if dataText=="" then return .TerminalResult~failure("S3270_RESPONSE_DATA_REQUIRED","no data: lines")
  st=status~value
  parsed=self~parse(dataText,st~rows,st~columns,st~cursorRow0,st~cursorColumn0)
  if \parsed~ok then return parsed
  base=parsed~value
  snap=.S3270ReferenceSnapshot~new(base~rows,base~columns,base~cursorRow,base~cursorColumn,base~fields,base~textRows,st~keyboardState,st)
  return .TerminalResult~success(snap)

::method parseStatus class
  use arg statusLineArg
  statusLine=statusLineArg~string~strip
  if words(statusLine)<>12 then return .TerminalResult~failure("S3270_STATUS_FIELD_COUNT",words(statusLine))
  k=word(statusLine,1)~upper
  fmt=word(statusLine,2)~upper
  prot=word(statusLine,3)~upper
  conn=word(statusLine,4)
  mode=word(statusLine,5)~upper
  model=word(statusLine,6)
  rows=word(statusLine,7); cols=word(statusLine,8)
  cr=word(statusLine,9); cc=word(statusLine,10)
  win=word(statusLine,11); elapsed=word(statusLine,12)
  if pos(k,"ULE")==0 | length(k)<>1 then return .TerminalResult~failure("S3270_STATUS_KEYBOARD",k)
  if fmt<>"F" & fmt<>"U" then return .TerminalResult~failure("S3270_STATUS_FORMAT",fmt)
  if prot<>"P" & prot<>"U" then return .TerminalResult~failure("S3270_STATUS_PROTECTION",prot)
  if \datatype(model,"W") | model<2 | model>5 then return .TerminalResult~failure("S3270_STATUS_MODEL",model)
  if \datatype(rows,"W") | rows<1 then return .TerminalResult~failure("S3270_STATUS_ROWS",rows)
  if \datatype(cols,"W") | cols<1 then return .TerminalResult~failure("S3270_STATUS_COLUMNS",cols)
  if \datatype(cr,"W") | cr<0 | cr>=rows then return .TerminalResult~failure("S3270_STATUS_CURSOR_ROW",cr)
  if \datatype(cc,"W") | cc<0 | cc>=cols then return .TerminalResult~failure("S3270_STATUS_CURSOR_COLUMN",cc)
  return .TerminalResult~success(.S3270ScriptStatus~new(k,fmt,prot,conn,mode,model,rows,cols,cr,cc,win,elapsed))

/* readBufferText accepts the data portion of s3270 ReadBuffer(Ascii). "data: "
 * prefixes are optional for retained fixture use. cursorRow0/cursorColumn0 use
 * s3270's documented zero-origin convention. */
::method parse class
  use arg readBufferText, rowsArg=24, columnsArg=80, cursorRow0=0, cursorColumn0=0
  if \datatype(rowsArg,"W") | rowsArg<1 then return .TerminalResult~failure("S3270_BAD_ROWS",rowsArg)
  if \datatype(columnsArg,"W") | columnsArg<1 then return .TerminalResult~failure("S3270_BAD_COLUMNS",columnsArg)
  if \datatype(cursorRow0,"W") | cursorRow0<0 | cursorRow0>=rowsArg then return .TerminalResult~failure("S3270_BAD_CURSOR_ROW",cursorRow0)
  if \datatype(cursorColumn0,"W") | cursorColumn0<0 | cursorColumn0>=columnsArg then return .TerminalResult~failure("S3270_BAD_CURSOR_COLUMN",cursorColumn0)
  size=rowsArg*columnsArg
  cells=copies("00"x,size)
  fieldAddresses=.array~new
  fieldBasics=.array~new
  address=0
  sourceLines=readBufferText~makeArray("0a"x)
  rowSeen=0

  do rawLine over sourceLines
    line=rawLine~strip("T","0d"x)
    if left(line,6)=="data: " then line=substr(line,7)
    else if left(line,5)=="data:" then line=substr(line,6)~strip("L")
    if line=="" then iterate
    rowSeen+=1
    if rowSeen>rowsArg then return .TerminalResult~failure("S3270_TOO_MANY_DATA_ROWS",rowSeen)
    expectedStart=(rowSeen-1)*columnsArg
    if address<expectedStart then address=expectedStart
    do tokenIndex=1 to words(line)
      token=word(line,tokenIndex)
      upper=token~upper
      if left(upper,3)=="SA(" then iterate
      if left(upper,3)=="SF(" then do
        basic=self~basicAttribute(upper)
        if basic=="" then return .TerminalResult~failure("S3270_BAD_SF",token)
        fieldAddresses~append(address//size)
        fieldBasics~append(basic)
        address=(address+1)//size
        iterate
      end
      if left(upper,3)=="GE(" then do
        p1=pos("(",upper); p2=pos(")",upper)
        if p1=0 | p2<=p1+2 then return .TerminalResult~failure("S3270_BAD_GE",token)
        hex=substr(upper,p1+1,p2-p1-1)
        if length(hex)<>2 | verify(hex,"0123456789ABCDEF")<>0 then return .TerminalResult~failure("S3270_BAD_GE",token)
        cells=cells~overlay(x2c(hex),address+1)
        address=(address+1)//size
        iterate
      end
      /* In the single-byte TK5/MVS qualification path each display position is
       * represented by one two-digit code. Multi-byte/DBCS tokens fail closed
       * rather than being flattened into a false one-cell comparison. */
      if length(upper)<>2 | verify(upper,"0123456789ABCDEF")<>0 then return .TerminalResult~failure("S3270_UNSUPPORTED_CELL_TOKEN",token)
      cells=cells~overlay(x2c(upper),address+1)
      address=(address+1)//size
    end
  end

  fields=.array~new
  do i=1 to fieldAddresses~items
    a=fieldAddresses[i]
    if fieldAddresses~items==1 then next=a
    else if i<fieldAddresses~items then next=fieldAddresses[i+1]
    else next=fieldAddresses[1]
    fieldLength=(next-a-1+size)//size
    row=(a//columnsArg)+1
    column=(a//columnsArg)+1
    fields~append(.S3270ReferenceField~new(a,row,column,fieldLength,fieldBasics[i]))
  end

  textRows=.array~new
  do r=1 to rowsArg
    rowText=""
    do c=1 to columnsArg
      a=(r-1)*columnsArg+(c-1)
      f=self~fieldAt(fields,a,size)
      if f\==.nil & f~nonDisplay then ch=" "
      else do
        b=cells~substr(a+1,1)
        if b=="00"x then ch=" "
        else ch=b
      end
      rowText||=ch
    end
    textRows~append(rowText)
  end

  snap=.S3270ReferenceSnapshot~new(rowsArg,columnsArg,cursorRow0+1,cursorColumn0+1,fields,textRows)
  return .TerminalResult~success(snap)

::method basicAttribute class private
  use arg token
  inside=substr(token,pos("(",token)+1)
  inside=left(inside,length(inside)-1)
  do i=1 to words(translate(inside," ",","))
    pair=word(translate(inside," ",","),i)
    parse var pair key "=" value
    if key~upper=="C0" then do
      value=value~strip~upper
      if length(value)==2 & verify(value,"0123456789ABCDEF")==0 then return value
    end
  end
  return ""

::method fieldAt class private
  use arg fields,address,size
  best=.nil; bestDistance=size+1
  do f over fields
    d=(address-f~address+size)//size
    if d>0 & d<bestDistance then do; best=f; bestDistance=d; end
  end
  return best

::class S3270DifferentialResult public
::attribute equivalent get
::attribute mismatches get
::method init
  expose equivalent mismatches
  use arg mismatchesArg
  mismatches=.TerminalUtil~copyArray(mismatchesArg)
  equivalent=mismatches~items==0

::class S3270Differential public
::method compare class
  use arg terminalSnapshot, referenceSnapshot
  mismatches=.array~new
  if terminalSnapshot==.nil | referenceSnapshot==.nil then do
    mismatches~append("SNAPSHOT_REQUIRED")
    return .S3270DifferentialResult~new(mismatches)
  end
  if terminalSnapshot~rows<>referenceSnapshot~rows then mismatches~append("ROWS:"||terminalSnapshot~rows||"<>"||referenceSnapshot~rows)
  if terminalSnapshot~columns<>referenceSnapshot~columns then mismatches~append("COLUMNS:"||terminalSnapshot~columns||"<>"||referenceSnapshot~columns)
  if terminalSnapshot~cursorRow<>referenceSnapshot~cursorRow | terminalSnapshot~cursorColumn<>referenceSnapshot~cursorColumn then mismatches~append("CURSOR:r"||terminalSnapshot~cursorRow||"c"||terminalSnapshot~cursorColumn||"<>r"||referenceSnapshot~cursorRow||"c"||referenceSnapshot~cursorColumn)
  if referenceSnapshot~keyboardState<>"UNKNOWN" then do
    if terminalSnapshot~keyboardState<>referenceSnapshot~keyboardState then mismatches~append("KEYBOARD:"||terminalSnapshot~keyboardState||"<>"||referenceSnapshot~keyboardState)
  end

  maxRows=terminalSnapshot~rows
  if referenceSnapshot~rows<maxRows then maxRows=referenceSnapshot~rows
  do r=1 to maxRows
    leftRow=terminalSnapshot~rowText(r)
    rightRow=referenceSnapshot~rowText(r)
    if leftRow<>rightRow then mismatches~append("ROW:"||r)
  end

  tf=terminalSnapshot~fields; rf=referenceSnapshot~fields
  if tf~items<>rf~items then mismatches~append("FIELD_COUNT:"||tf~items||"<>"||rf~items)
  do f over tf
    if left(f~fieldId,1)<>"A" then do; mismatches~append("FIELD_ID:"||f~fieldId); iterate; end
    address=x2d(substr(f~fieldId,2))
    ref=self~fieldByAddress(rf,address)
    if ref==.nil then do; mismatches~append("FIELD_MISSING:A"||right(d2x(address),4,"0")); iterate; end
    if f~length<>ref~length then mismatches~append("FIELD_LENGTH:A"||right(d2x(address),4,"0")||":"||f~length||"<>"||ref~length)
    if f~protected<>ref~protected then mismatches~append("FIELD_PROTECTED:A"||right(d2x(address),4,"0"))
    if f~numeric<>ref~numeric then mismatches~append("FIELD_NUMERIC:A"||right(d2x(address),4,"0"))
    if f~modified<>ref~modified then mismatches~append("FIELD_MDT:A"||right(d2x(address),4,"0"))
    if f~nonDisplay<>ref~nonDisplay then mismatches~append("FIELD_NONDISPLAY:A"||right(d2x(address),4,"0"))
  end
  return .S3270DifferentialResult~new(mismatches)

::method fieldByAddress class private
  use arg fields,address
  do f over fields
    if f~address==address then return f
  end
  return .nil

::requires "TerminalCore.cls"
