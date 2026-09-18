/* Detached IBM 3270 presentation-space evidence adapter v0.1.
 * Native 3270 addresses/attributes remain authoritative underneath this view.
 * NONDISPLAY values are never copied into detached evidence. */
::class Terminal3270SnapshotFactory public
::method fromPresentationSpace class
  use arg model, codepage, sessionState="OPEN"
  if model==.nil then return .TerminalResult~failure("3270_MODEL_REQUIRED")
  if codepage==.nil then return .TerminalResult~failure("3270_CODEPAGE_REQUIRED")
  rows=model~rows; cols=model~columns
  rendered=model~text(codepage); textRows=rendered~makeArray('0A'x)
  fields=.array~new; native=model~fields
  do i=1 to native~items
    f=native[i]; start=(f~address+1)//model~size
    nextAddress=model~size
    do j=1 to native~items
      candidate=native[j]~address
      if candidate>f~address & candidate<nextAddress then nextAddress=candidate
    end
    if nextAddress==model~size then length=model~size-(f~address+1)
    else length=nextAddress-(f~address+1)
    if length<0 then length=0
    row=(start%cols)+1; col=(start//cols)+1
    value=""
    if \f~nonDisplay then value=model~fieldText(f,codepage)
    attrs=.directory~new
    attrs["bufferAddress"]=f~address
    attrs["fieldAttributeHex"]=f~attribute~c2x
    attrs["nativeFamily"]="IBM3270"
    id="3270:"||right(f~address,4,"0")
    fields~append(.TerminalFieldSnapshot~new(id,row,col,length,value,\f~protected,f~protected,f~nonDisplay,f~modified,f~numeric,attrs))
  end
  cursor=model~cursor
  cursorRow=(cursor%cols)+1; cursorColumn=(cursor//cols)+1
  keyboard="UNLOCKED"; if model~keyboardLocked then keyboard="LOCKED"
  caps=.TerminalCapabilities~new
  caps~add("OBSERVE")
  meta=.directory~new; meta["nativeFamily"]="IBM3270"; meta["presentationSpaceSize"]=model~size
  return .TerminalResult~success(.TerminalSnapshot~new(model~generation,"IBM3270",rows,cols,cursorRow,cursorColumn,keyboard,sessionState,textRows,fields,caps,meta))
::requires "TerminalCore.cls"
