/* SpreadsheetModel.cls
 * Engine-neutral spreadsheet object model.
 *
 * A cell deliberately keeps storage value, rendered text hint, formula and style
 * metadata separate.  A reader must never turn a display string into authoritative
 * numeric truth merely because it looks numeric.
 */

::class SpreadsheetWorkbook public
::method init
  expose sourcePath format sheets metadata
  use arg sourcePath = "", format = "UNKNOWN"
  sheets = .Array~new
  metadata = .Directory~new
::attribute sourcePath get
::attribute format get
::attribute format set
::method sheets
  expose sheets
  return sheets~copy
::method addSheet
  expose sheets
  use arg sheet
  if sheet == .nil then return self
  sheets~append(sheet)
  return self
::method sheet
  expose sheets
  use arg name
  wanted = translate(strip(name))
  loop i = 1 to sheets~items
    candidate = sheets~at(i)
    if translate(candidate~name) == wanted then return candidate
  end
  return .nil
::method sheetNames
  expose sheets
  out = .Array~new
  loop i = 1 to sheets~items
    out~append(sheets~at(i)~name)
  end
  return out
::method metadata
  expose metadata
  return metadata
::method declaredTables
  expose metadata
  if metadata~hasIndex("DECLARED_TABLES") then return metadata~at("DECLARED_TABLES")~copy
  return .Array~new
::method addDeclaredTable
  expose metadata
  use arg table
  if \metadata~hasIndex("DECLARED_TABLES") then metadata~put(.Array~new, "DECLARED_TABLES")
  metadata~at("DECLARED_TABLES")~append(table)
  return self

::class SpreadsheetSheet public
::method init
  expose name cells maxRow maxColumn hidden sourcePart
  use arg name = "Sheet", sourcePart = ""
  cells = .Directory~new
  maxRow = 0
  maxColumn = 0
  hidden = .false
::attribute name get
::attribute sourcePart get
::attribute hidden get
::attribute hidden set
::attribute maxRow get
::attribute maxColumn get
::method putCell
  expose cells maxRow maxColumn
  use arg cell
  if cell == .nil then return self
  key = translate(cell~address)
  cells~put(cell, key)
  if cell~row > maxRow then maxRow = cell~row
  if cell~column > maxColumn then maxColumn = cell~column
  return self
::method cell
  expose cells
  use arg address
  key = translate(strip(address))
  if cells~hasIndex(key) then return cells~at(key)
  return .nil
::method cellAt
  use arg row, column
  return self~cell(.SpreadsheetAddress~fromRowColumn(row, column))
::method cells
  expose cells
  out = .Array~new
  supplier = cells~supplier
  do while supplier~available
    out~append(supplier~item)
    supplier~next
  end
  return out
::method nonEmptyCount
  expose cells
  count = 0
  supplier = cells~supplier
  do while supplier~available
    cell = supplier~item
    if \cell~isBlank then count = count + 1
    supplier~next
  end
  return count

::class SpreadsheetCell public
::method init
  expose address row column valueType rawValue textValue formula cachedValue styleIndex numberFormatId numberFormatCode storageType
  use arg address, row, column
  valueType = "BLANK"
  rawValue = ""
  textValue = ""
  formula = ""
  cachedValue = ""
  styleIndex = ""
  numberFormatId = ""
  numberFormatCode = ""
  storageType = ""
::attribute address get
::attribute row get
::attribute column get
::attribute valueType get
::attribute valueType set
::attribute rawValue get
::attribute rawValue set
::attribute textValue get
::attribute textValue set
::attribute formula get
::attribute formula set
::attribute cachedValue get
::attribute cachedValue set
::attribute styleIndex get
::attribute styleIndex set
::attribute numberFormatId get
::attribute numberFormatId set
::attribute numberFormatCode get
::attribute numberFormatCode set
::attribute storageType get
::attribute storageType set
::method isBlank
  expose rawValue textValue formula valueType
  if formula \== "" then return .false
  if rawValue \== "" then return .false
  if textValue \== "" then return .false
  return valueType == "BLANK"
::method semanticValue
  expose valueType rawValue textValue
  if valueType == "TEXT" then return textValue
  if valueType == "BOOLEAN" then return rawValue
  if valueType == "DATE" then return rawValue
  if valueType == "ERROR" then return rawValue
  if rawValue \== "" then return rawValue
  return textValue
::method hasFormula
  expose formula
  return formula \== ""
::method looksNumericText
  expose valueType textValue
  if valueType \== "TEXT" then return .false
  candidate = strip(textValue)
  if candidate == "" then return .false
  if datatype(candidate, "N") then return .true
  candidate = changestr(",", candidate, "")
  if datatype(candidate, "N") then return .true
  if left(candidate, 1) == "$" | left(candidate, 1) == "£" | left(candidate, 1) == "€" then do
    candidate = strip(substr(candidate, 2))
    candidate = changestr(",", candidate, "")
    if datatype(candidate, "N") then return .true
  end
  return .false

::class SpreadsheetAddress public
::method fromRowColumn class
  use arg row, column
  if \datatype(row, "W") then return ""
  if \datatype(column, "W") then return ""
  if row < 1 | column < 1 then return ""
  n = column
  letters = ""
  do while n > 0
    remainder = (n - 1) // 26
    letters = d2c(65 + remainder) || letters
    n = (n - 1 - remainder) % 26
  end
  return letters || row
::method rowColumn class
  use arg address
  text = translate(strip(address))
  letters = ""
  digits = ""
  loop i = 1 to length(text)
    ch = substr(text, i, 1)
    if ch >= "A" then do
      if ch <= "Z" then letters = letters || ch
      else if ch >= "0" then do
        if ch <= "9" then digits = digits || ch
      end
    end
    else if ch >= "0" then do
      if ch <= "9" then digits = digits || ch
    end
  end
  if letters == "" | digits == "" then return .nil
  column = 0
  loop i = 1 to length(letters)
    column = column * 26 + c2d(substr(letters, i, 1)) - 64
  end
  return .Array~of(digits, column)

::class SpreadsheetDiagnostic public
::method init
  expose code severity sheet address message evidence
  use arg code, severity, sheet = "", address = "", message = "", evidence = ""
::attribute code get
::attribute severity get
::attribute sheet get
::attribute address get
::attribute message get
::attribute evidence get

::class SpreadsheetDeclaredTable public
::method init
  expose name displayName reference sheetName sheetPart tablePart columns
  use arg name, displayName, reference, sheetName, sheetPart, tablePart
  columns = .Array~new
::attribute name get
::attribute displayName get
::attribute reference get
::attribute sheetName get
::attribute sheetPart get
::attribute tablePart get
::method columns
  expose columns
  return columns~copy
::method addColumn
  expose columns
  use arg name
  columns~append(name)
  return self
::method describe
  expose name displayName reference sheetName columns
  return name || " sheet=" || sheetName || " ref=" || reference || " columns=" || columns~items
