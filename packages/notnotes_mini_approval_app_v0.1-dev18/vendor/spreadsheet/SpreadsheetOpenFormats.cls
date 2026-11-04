/* SpreadsheetOpenFormats.cls
 * Native ooRexx readers for the package-level structures used by OOXML .xlsx
 * and ODF .ods spreadsheets.
 *
 * The readers preserve stored values and formula text.  They do not pretend to
 * be Excel or Calc calculation engines and never recalculate formula results.
 */

::class SpreadsheetReader public
::method open class
  use arg path
  if strip(path) == "" then raise syntax 93.900 array("Spreadsheet path is required")
  ext = translate(filespec("E", path))
  if ext == "XLSX" then return .XlsxWorkbookReader~new~read(path)
  if ext == "ODS" then return .OdsWorkbookReader~new~read(path)
  raise syntax 93.900 array("Unsupported spreadsheet format:" ext)
::method declaredTables class
  use arg path
  ext = translate(filespec("E", path))
  if ext \== "XLSX" then return .Array~new
  return .XlsxWorkbookReader~new~declaredTables(path)
::method openDeclaredTable class
  use arg path, tableName
  ext = translate(filespec("E", path))
  if ext \== "XLSX" then raise syntax 93.900 array("Declared table opening is currently supported for XLSX only")
  return .XlsxWorkbookReader~new~readDeclaredTable(path, tableName)

::class SpreadsheetPackageReader public
::method extract
  use arg path
  tmp = SysTempFileName("/tmp/oorexx_spreadsheet_????????")
  if tmp == "" then raise syntax 93.900 array("Could not allocate temporary spreadsheet directory")
  command = "mkdir -p" self~shellQuote(tmp)
  address system command
  if rc \== 0 then raise syntax 93.900 array("Could not create temporary spreadsheet directory:" tmp)
  command = "unzip -qq -o" self~shellQuote(path) "-d" self~shellQuote(tmp)
  address system command
  if rc \== 0 then do
    self~removeTree(tmp)
    raise syntax 93.900 array("Could not unpack spreadsheet package:" path)
  end
  return tmp
::method removeTree
  use arg path
  if strip(path) == "" then return
  command = "rm -rf --" self~shellQuote(path)
  address system command
::method shellQuote
  use arg value
  return "'" || value || "'"
::method readText
  use arg path
  stream = .Stream~new(path)
  if stream~open("read") \== "READY:" then return ""
  count = stream~chars
  if count <= 0 then do
    stream~close
    return ""
  end
  data = stream~charin(1, count)
  stream~close
  return data
::method exists
  use arg path
  return stream(path, "C", "QUERY EXISTS") \== ""
::method joinPath
  use arg root, relative
  if right(root, 1) == "/" then return root || relative
  return root || "/" || relative

::class XlsxWorkbookReader subclass SpreadsheetPackageReader public
::method read
  use arg path
  root = self~extract(path)
  workbook = .SpreadsheetWorkbook~new(path, "XLSX")
  signal on syntax name cleanupError
  signal on error name cleanupError

  workbookXml = self~readText(self~joinPath(root, "xl/workbook.xml"))
  if workbookXml == "" then raise syntax 93.900 array("XLSX workbook.xml is missing")
  relsXml = self~readText(self~joinPath(root, "xl/_rels/workbook.xml.rels"))
  sharedStrings = self~readSharedStrings(root)
  styles = self~readStyles(root)
  relations = self~readWorkbookRelationships(relsXml)
  declaredTables = self~readDeclaredTables(root, workbookXml, relsXml)
  loop declaredIndex = 1 to declaredTables~items
    workbook~addDeclaredTable(declaredTables~at(declaredIndex))
  end
  sheets = .SpreadsheetXml~startTags(workbookXml, "sheet")

  loop i = 1 to sheets~items
    sheetTag = sheets~at(i)
    name = .SpreadsheetXml~attribute(sheetTag, "name")
    relationId = .SpreadsheetXml~attribute(sheetTag, "r:id")
    state = translate(.SpreadsheetXml~attribute(sheetTag, "state"))
    target = ""
    if relations~hasIndex(relationId) then target = relations~at(relationId)
    if target == "" then iterate
    part = self~normaliseXlsxTarget(target)
    sheet = .SpreadsheetSheet~new(name, part)
    if state == "HIDDEN" | state == "VERYHIDDEN" then sheet~hidden = .true
    self~readWorksheet(self~joinPath(root, part), sheet, sharedStrings, styles)
    workbook~addSheet(sheet)
  end

  self~removeTree(root)
  return workbook

cleanupError:
  conditionCode = condition("C")
  conditionDescription = condition("D")
  say "Spreadsheet package read failed:" conditionCode conditionDescription "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate

::method normaliseXlsxTarget
  use arg target
  value = changestr("\\", target, "/")
  do while left(value, 3) == "../"
    value = substr(value, 4)
  end
  if left(value, 1) == "/" then value = substr(value, 2)
  if left(value, 3) == "xl/" then return value
  return "xl/" || value

::method declaredTables
  use arg path
  root = self~extract(path)
  signal on syntax name declaredCleanupError
  signal on error name declaredCleanupError
  workbookXml = self~readText(self~joinPath(root, "xl/workbook.xml"))
  relsXml = self~readText(self~joinPath(root, "xl/_rels/workbook.xml.rels"))
  tables = self~readDeclaredTables(root, workbookXml, relsXml)
  self~removeTree(root)
  return tables

declaredCleanupError:
  say "Spreadsheet declared-table read failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate

::method readDeclaredTable
  use arg path, tableName
  root = self~extract(path)
  signal on syntax name scopedCleanupError
  signal on error name scopedCleanupError
  workbookXml = self~readText(self~joinPath(root, "xl/workbook.xml"))
  relsXml = self~readText(self~joinPath(root, "xl/_rels/workbook.xml.rels"))
  tables = self~readDeclaredTables(root, workbookXml, relsXml)
  wanted = translate(strip(tableName))
  selected = .nil
  loop i = 1 to tables~items
    candidate = tables~at(i)
    if translate(candidate~name) == wanted then selected = candidate
    if translate(candidate~displayName) == wanted then selected = candidate
  end
  if selected == .nil then raise syntax 93.900 array("Declared XLSX table not found:" tableName)
  workbook = .SpreadsheetWorkbook~new(path, "XLSX")
  workbook~addDeclaredTable(selected)
  sharedStrings = self~readSharedStrings(root)
  styles = self~readStyles(root)
  sheet = .SpreadsheetSheet~new(selected~sheetName, selected~sheetPart)
  self~readWorksheetRange(self~joinPath(root, selected~sheetPart), sheet, sharedStrings, styles, selected~reference)
  workbook~addSheet(sheet)
  self~removeTree(root)
  return workbook

scopedCleanupError:
  say "Spreadsheet scoped-table read failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate

::method readDeclaredTables
  use arg root, workbookXml, relsXml
  out = .Array~new
  relations = self~readWorkbookRelationships(relsXml)
  sheetTags = .SpreadsheetXml~startTags(workbookXml, "sheet")
  loop sheetIndex = 1 to sheetTags~items
    sheetTag = sheetTags~at(sheetIndex)
    sheetName = .SpreadsheetXml~attribute(sheetTag, "name")
    relationId = .SpreadsheetXml~attribute(sheetTag, "r:id")
    if \relations~hasIndex(relationId) then iterate
    sheetPart = self~normaliseXlsxTarget(relations~at(relationId))
    relsPart = self~worksheetRelationshipsPath(sheetPart)
    relsPath = self~joinPath(root, relsPart)
    if \self~exists(relsPath) then iterate
    sheetRels = self~readWorkbookRelationships(self~readText(relsPath))
    sheetXml = self~readText(self~joinPath(root, sheetPart))
    tableParts = .SpreadsheetXml~startTags(sheetXml, "tablePart")
    loop partIndex = 1 to tableParts~items
      partTag = tableParts~at(partIndex)
      tableRelationId = .SpreadsheetXml~attribute(partTag, "r:id")
      if \sheetRels~hasIndex(tableRelationId) then iterate
      tablePart = self~normaliseTableTarget(sheetPart, sheetRels~at(tableRelationId))
      tableXml = self~readText(self~joinPath(root, tablePart))
      if tableXml == "" then iterate
      tableTags = .SpreadsheetXml~startTags(tableXml, "table")
      if tableTags~items == 0 then iterate
      tableTag = tableTags~at(1)
      name = .SpreadsheetXml~attribute(tableTag, "name")
      displayName = .SpreadsheetXml~attribute(tableTag, "displayName")
      reference = .SpreadsheetXml~attribute(tableTag, "ref")
      declared = .SpreadsheetDeclaredTable~new(name, displayName, reference, sheetName, sheetPart, tablePart)
      columns = .SpreadsheetXml~startTags(tableXml, "tableColumn")
      loop columnIndex = 1 to columns~items
        declared~addColumn(.SpreadsheetXml~attribute(columns~at(columnIndex), "name"))
      end
      out~append(declared)
    end
  end
  return out

::method worksheetRelationshipsPath
  use arg sheetPart
  slash = lastpos("/", sheetPart)
  if slash == 0 then return ""
  directory = substr(sheetPart, 1, slash)
  file = substr(sheetPart, slash + 1)
  return directory || "_rels/" || file || ".rels"

::method normaliseTableTarget
  use arg sheetPart, target
  value = changestr("\\", target, "/")
  directory = substr(sheetPart, 1, lastpos("/", sheetPart))
  do while left(value, 3) == "../"
    value = substr(value, 4)
    trimmed = strip(directory, "T", "/")
    slash = lastpos("/", trimmed)
    if slash == 0 then directory = ""
    else directory = substr(trimmed, 1, slash)
  end
  if left(value, 1) == "/" then value = substr(value, 2)
  if left(value, 3) == "xl/" then return value
  return directory || value

::method readWorksheetRange
  use arg path, sheet, sharedStrings, styles, reference
  bounds = self~rangeBounds(reference)
  if bounds == .nil then return self~readWorksheet(path, sheet, sharedStrings, styles)
  xml = self~readText(path)
  if xml == "" then return sheet
  blocks = .SpreadsheetXml~elementBlocks(xml, "c")
  loop i = 1 to blocks~items
    block = blocks~at(i)
    openTag = .SpreadsheetXml~openingTag(block)
    address = .SpreadsheetXml~attribute(openTag, "r")
    if address == "" then iterate
    rc = .SpreadsheetAddress~rowColumn(address)
    if rc == .nil then iterate
    row = rc~at(1)
    column = rc~at(2)
    if row < bounds~at(1) then iterate
    if row > bounds~at(3) then iterate
    if column < bounds~at(2) then iterate
    if column > bounds~at(4) then iterate
    cell = .SpreadsheetCell~new(address, row, column)
    storageType = .SpreadsheetXml~attribute(openTag, "t")
    styleIndex = .SpreadsheetXml~attribute(openTag, "s")
    cell~storageType = storageType
    cell~styleIndex = styleIndex
    if styleIndex \== "" then do
      cell~numberFormatId = styles~numberFormatId(styleIndex)
      cell~numberFormatCode = styles~numberFormatCode(styleIndex)
    end
    formulas = .SpreadsheetXml~textContents(block, "f")
    if formulas~items > 0 then cell~formula = formulas~at(1)
    values = .SpreadsheetXml~textContents(block, "v")
    stored = ""
    if values~items > 0 then stored = values~at(1)
    cell~cachedValue = stored
    self~populateXlsxCell(cell, storageType, stored, block, sharedStrings, styles)
    sheet~putCell(cell)
  end
  return sheet

::method rangeBounds
  use arg reference
  colon = pos(":", reference)
  if colon == 0 then return .nil
  first = .SpreadsheetAddress~rowColumn(substr(reference, 1, colon - 1))
  last = .SpreadsheetAddress~rowColumn(substr(reference, colon + 1))
  if first == .nil then return .nil
  if last == .nil then return .nil
  return .Array~of(first~at(1), first~at(2), last~at(1), last~at(2))

::method readWorkbookRelationships
  use arg xml
  out = .Directory~new
  tags = .SpreadsheetXml~startTags(xml, "Relationship")
  loop i = 1 to tags~items
    tag = tags~at(i)
    id = .SpreadsheetXml~attribute(tag, "Id")
    target = .SpreadsheetXml~attribute(tag, "Target")
    if id \== "" then out~put(target, id)
  end
  return out

::method readSharedStrings
  use arg root
  path = self~joinPath(root, "xl/sharedStrings.xml")
  values = .Array~new
  if \self~exists(path) then return values
  xml = self~readText(path)
  blocks = .SpreadsheetXml~elementBlocks(xml, "si")
  loop i = 1 to blocks~items
    texts = .SpreadsheetXml~textContents(blocks~at(i), "t")
    value = ""
    loop j = 1 to texts~items
      value = value || texts~at(j)
    end
    values~append(value)
  end
  return values

::method readStyles
  use arg root
  catalog = .SpreadsheetStyleCatalog~new
  path = self~joinPath(root, "xl/styles.xml")
  if \self~exists(path) then return catalog
  xml = self~readText(path)
  numFmtTags = .SpreadsheetXml~startTags(xml, "numFmt")
  loop i = 1 to numFmtTags~items
    tag = numFmtTags~at(i)
    id = .SpreadsheetXml~attribute(tag, "numFmtId")
    code = .SpreadsheetXml~attribute(tag, "formatCode")
    catalog~defineFormat(id, code)
  end
  cellXfs = .SpreadsheetXml~firstBlock(xml, "cellXfs")
  if cellXfs \== "" then do
    xfTags = .SpreadsheetXml~startTags(cellXfs, "xf")
    loop i = 1 to xfTags~items
      numFmtId = .SpreadsheetXml~attribute(xfTags~at(i), "numFmtId")
      catalog~addCellStyle(numFmtId)
    end
  end
  return catalog

::method readWorksheet
  use arg path, sheet, sharedStrings, styles
  xml = self~readText(path)
  if xml == "" then return sheet
  blocks = .SpreadsheetXml~elementBlocks(xml, "c")
  loop i = 1 to blocks~items
    block = blocks~at(i)
    openTag = .SpreadsheetXml~openingTag(block)
    address = .SpreadsheetXml~attribute(openTag, "r")
    if address == "" then iterate
    rc = .SpreadsheetAddress~rowColumn(address)
    if rc == .nil then iterate
    cell = .SpreadsheetCell~new(address, rc~at(1), rc~at(2))
    storageType = .SpreadsheetXml~attribute(openTag, "t")
    styleIndex = .SpreadsheetXml~attribute(openTag, "s")
    cell~storageType = storageType
    cell~styleIndex = styleIndex
    if styleIndex \== "" then do
      cell~numberFormatId = styles~numberFormatId(styleIndex)
      cell~numberFormatCode = styles~numberFormatCode(styleIndex)
    end
    formulas = .SpreadsheetXml~textContents(block, "f")
    if formulas~items > 0 then cell~formula = formulas~at(1)
    values = .SpreadsheetXml~textContents(block, "v")
    stored = ""
    if values~items > 0 then stored = values~at(1)
    cell~cachedValue = stored
    self~populateXlsxCell(cell, storageType, stored, block, sharedStrings, styles)
    sheet~putCell(cell)
  end
  return sheet

::method populateXlsxCell
  use arg cell, storageType, stored, block, sharedStrings, styles
  select
    when storageType == "s" then do
      cell~valueType = "TEXT"
      if datatype(stored, "W") then do
        index = stored + 1
        if index >= 1 then do
          if index <= sharedStrings~items then cell~textValue = sharedStrings~at(index)
        end
      end
      cell~rawValue = stored
    end
    when storageType == "inlineStr" then do
      cell~valueType = "TEXT"
      texts = .SpreadsheetXml~textContents(block, "t")
      text = ""
      loop i = 1 to texts~items
        text = text || texts~at(i)
      end
      cell~textValue = text
      cell~rawValue = text
    end
    when storageType == "str" then do
      cell~valueType = "TEXT"
      cell~textValue = stored
      cell~rawValue = stored
    end
    when storageType == "b" then do
      cell~valueType = "BOOLEAN"
      if stored == "1" then cell~rawValue = "TRUE"
      else cell~rawValue = "FALSE"
    end
    when storageType == "e" then do
      cell~valueType = "ERROR"
      cell~rawValue = stored
    end
    otherwise do
      cell~rawValue = stored
      if stored == "" then cell~valueType = "BLANK"
      else if styles~isDateStyle(cell~styleIndex) then cell~valueType = "DATE_SERIAL"
      else if datatype(stored, "N") then cell~valueType = "NUMBER"
      else do
        cell~valueType = "TEXT"
        cell~textValue = stored
      end
    end
  end

::class OdsWorkbookReader subclass SpreadsheetPackageReader public
::method read
  use arg path
  root = self~extract(path)
  workbook = .SpreadsheetWorkbook~new(path, "ODS")
  signal on syntax name cleanupError
  signal on error name cleanupError
  contentPath = self~joinPath(root, "content.xml")
  xml = self~readText(contentPath)
  if xml == "" then raise syntax 93.900 array("ODS content.xml is missing")
  tables = .SpreadsheetXml~elementBlocks(xml, "table:table")
  loop tableIndex = 1 to tables~items
    block = tables~at(tableIndex)
    tag = .SpreadsheetXml~openingTag(block)
    name = .SpreadsheetXml~attribute(tag, "table:name")
    if name == "" then name = "Sheet" || tableIndex
    sheet = .SpreadsheetSheet~new(name, "content.xml")
    visibility = translate(.SpreadsheetXml~attribute(tag, "table:display"))
    if visibility == "FALSE" then sheet~hidden = .true
    self~readOdsTable(block, sheet)
    workbook~addSheet(sheet)
  end
  self~removeTree(root)
  return workbook

cleanupError:
  conditionCode = condition("C")
  conditionDescription = condition("D")
  say "Spreadsheet package read failed:" conditionCode conditionDescription "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate

::method readOdsTable
  use arg tableBlock, sheet
  rows = .SpreadsheetXml~elementBlocks(tableBlock, "table:table-row")
  outputRow = 1
  loop rowIndex = 1 to rows~items
    rowBlock = rows~at(rowIndex)
    rowTag = .SpreadsheetXml~openingTag(rowBlock)
    repeatedRows = self~positiveCount(.SpreadsheetXml~attribute(rowTag, "table:number-rows-repeated"))
    cells = .SpreadsheetXml~elementBlocksAny(rowBlock, .Array~of("table:table-cell", "table:covered-table-cell"))
    if repeatedRows > 1 then do
      if \self~odsRowHasContent(rowBlock) then do
        outputRow = outputRow + repeatedRows
        iterate
      end
    end
    loop repetition = 1 to repeatedRows
      outputColumn = 1
      loop cellIndex = 1 to cells~items
        cellBlock = cells~at(cellIndex)
        cellTag = .SpreadsheetXml~openingTag(cellBlock)
        repeatedColumns = self~positiveCount(.SpreadsheetXml~attribute(cellTag, "table:number-columns-repeated"))
        if left(cellTag, 25) == "<table:covered-table-cell" then do
          outputColumn = outputColumn + repeatedColumns
          iterate
        end
        if \self~odsCellHasContent(cellBlock) then do
          outputColumn = outputColumn + repeatedColumns
          iterate
        end
        loop columnRepeat = 1 to repeatedColumns
          cell = self~makeOdsCell(cellBlock, outputRow, outputColumn)
          if \cell~isBlank then sheet~putCell(cell)
          outputColumn = outputColumn + 1
        end
      end
      outputRow = outputRow + 1
    end
  end
  return sheet

::method positiveCount
  use arg value
  if datatype(value, "W") then do
    if value > 0 then return value
  end
  return 1

::method odsRowHasContent
  use arg rowBlock
  if pos("office:value-type=", rowBlock) > 0 then return .true
  if pos("office:value=", rowBlock) > 0 then return .true
  if pos("office:string-value=", rowBlock) > 0 then return .true
  if pos("office:boolean-value=", rowBlock) > 0 then return .true
  if pos("office:date-value=", rowBlock) > 0 then return .true
  if pos("office:time-value=", rowBlock) > 0 then return .true
  if pos("table:formula=", rowBlock) > 0 then return .true
  if pos("<text:p", rowBlock) > 0 then return .true
  return .false

::method odsCellHasContent
  use arg cellBlock
  if pos("office:value-type=", cellBlock) > 0 then return .true
  if pos("office:value=", cellBlock) > 0 then return .true
  if pos("office:string-value=", cellBlock) > 0 then return .true
  if pos("office:boolean-value=", cellBlock) > 0 then return .true
  if pos("office:date-value=", cellBlock) > 0 then return .true
  if pos("office:time-value=", cellBlock) > 0 then return .true
  if pos("table:formula=", cellBlock) > 0 then return .true
  if pos("<text:p", cellBlock) > 0 then return .true
  return .false

::method makeOdsCell
  use arg block, row, column
  tag = .SpreadsheetXml~openingTag(block)
  address = .SpreadsheetAddress~fromRowColumn(row, column)
  cell = .SpreadsheetCell~new(address, row, column)
  valueType = translate(.SpreadsheetXml~attribute(tag, "office:value-type"))
  formula = .SpreadsheetXml~attribute(tag, "table:formula")
  cell~storageType = valueType
  cell~formula = formula
  select
    when valueType == "FLOAT" | valueType == "CURRENCY" | valueType == "PERCENTAGE" then do
      cell~valueType = "NUMBER"
      cell~rawValue = .SpreadsheetXml~attribute(tag, "office:value")
    end
    when valueType == "BOOLEAN" then do
      cell~valueType = "BOOLEAN"
      cell~rawValue = translate(.SpreadsheetXml~attribute(tag, "office:boolean-value"))
    end
    when valueType == "DATE" then do
      cell~valueType = "DATE"
      cell~rawValue = .SpreadsheetXml~attribute(tag, "office:date-value")
    end
    when valueType == "TIME" then do
      cell~valueType = "TIME"
      cell~rawValue = .SpreadsheetXml~attribute(tag, "office:time-value")
    end
    when valueType == "STRING" then do
      cell~valueType = "TEXT"
      texts = .SpreadsheetXml~textContents(block, "text:p")
      text = ""
      loop i = 1 to texts~items
        if i > 1 then text = text || .endOfLine
        text = text || texts~at(i)
      end
      if text == "" then text = .SpreadsheetXml~attribute(tag, "office:string-value")
      cell~textValue = text
      cell~rawValue = text
    end
    otherwise do
      texts = .SpreadsheetXml~textContents(block, "text:p")
      if texts~items > 0 then do
        cell~valueType = "TEXT"
        cell~textValue = texts~at(1)
        cell~rawValue = texts~at(1)
      end
    end
  end
  displayText = .SpreadsheetXml~textContents(block, "text:p")
  if displayText~items > 0 then do
    if cell~textValue == "" then cell~textValue = displayText~at(1)
  end
  cell~cachedValue = cell~rawValue
  return cell

::class SpreadsheetStyleCatalog public
::method init
  expose formats styles
  formats = .Directory~new
  styles = .Array~new
  self~installBuiltIns
::method installBuiltIns
  expose formats
  formats~put("0", "0")
  formats~put("0.00", "2")
  formats~put("m/d/yy", "14")
  formats~put("d-mmm-yy", "15")
  formats~put("d-mmm", "16")
  formats~put("mmm-yy", "17")
  formats~put("h:mm AM/PM", "18")
  formats~put("h:mm:ss AM/PM", "19")
  formats~put("h:mm", "20")
  formats~put("h:mm:ss", "21")
  formats~put("m/d/yy h:mm", "22")
::method defineFormat
  expose formats
  use arg id, code
  if strip(id) \== "" then formats~put(code, id)
  return self
::method addCellStyle
  expose styles
  use arg numFmtId
  styles~append(numFmtId)
  return self
::method numberFormatId
  expose styles
  use arg styleIndex
  if \datatype(styleIndex, "W") then return ""
  index = styleIndex + 1
  if index < 1 | index > styles~items then return ""
  return styles~at(index)
::method numberFormatCode
  expose formats
  use arg styleIndex
  id = self~numberFormatId(styleIndex)
  if id == "" then return ""
  if formats~hasIndex(id) then return formats~at(id)
  return ""
::method isDateStyle
  use arg styleIndex
  id = self~numberFormatId(styleIndex)
  if datatype(id, "W") then do
    if id >= 14 then do
      if id <= 22 then return .true
    end
    if id >= 45 then do
      if id <= 47 then return .true
    end
  end
  code = translate(self~numberFormatCode(styleIndex))
  if code == "" then return .false
  if pos("YY", code) > 0 then return .true
  if pos("DD", code) > 0 then return .true
  if pos("HH", code) > 0 then return .true
  return .false

::class SpreadsheetXml public
::method attribute class
  use arg tag, name
  marker = name || "="
  position = pos(marker, tag)
  if position == 0 then return ""
  position = position + length(marker)
  if position > length(tag) then return ""
  quote = substr(tag, position, 1)
  if quote \== '"' then do
    if quote \== "'" then return ""
  end
  ending = pos(quote, tag, position + 1)
  if ending == 0 then return ""
  return self~decode(substr(tag, position + 1, ending - position - 1))
::method startTags class
  use arg xml, name
  out = .Array~new
  marker = "<" || name
  start = 1
  do while start <= length(xml)
    position = pos(marker, xml, start)
    if position == 0 then leave
    following = position + length(marker)
    if following <= length(xml) then do
      delimiter = substr(xml, following, 1)
      if \self~validDelimiter(delimiter) then do
        start = following
        iterate
      end
    end
    ending = pos(">", xml, following)
    if ending == 0 then leave
    out~append(substr(xml, position, ending - position + 1))
    start = ending + 1
  end
  return out
::method validDelimiter class
  use arg delimiter
  if delimiter == " " then return .true
  if delimiter == ">" then return .true
  if delimiter == "/" then return .true
  if delimiter == .endOfLine then return .true
  if delimiter == "09"x then return .true
  return .false
::method elementBlocks class
  use arg xml, name
  out = .Array~new
  marker = "<" || name
  closeMarker = "</" || name || ">"
  start = 1
  do while start <= length(xml)
    position = pos(marker, xml, start)
    if position == 0 then leave
    following = position + length(marker)
    if following <= length(xml) then do
      delimiter = substr(xml, following, 1)
      if \self~validDelimiter(delimiter) then do
        start = following
        iterate
      end
    end
    openEnd = pos(">", xml, following)
    if openEnd == 0 then leave
    if substr(xml, openEnd - 1, 2) == "/>" then do
      out~append(substr(xml, position, openEnd - position + 1))
      start = openEnd + 1
      iterate
    end
    closePos = pos(closeMarker, xml, openEnd + 1)
    if closePos == 0 then leave
    endPos = closePos + length(closeMarker) - 1
    out~append(substr(xml, position, endPos - position + 1))
    start = endPos + 1
  end
  return out
::method elementBlocksAny class
  use arg xml, names
  tagged = .Array~new
  loop i = 1 to names~items
    name = names~at(i)
    blocks = self~elementBlocks(xml, name)
    loop j = 1 to blocks~items
      block = blocks~at(j)
      position = pos(block, xml)
      tagged~append(.Array~of(position, block))
    end
  end
  /* insertion sort is sufficient for row-sized cell sets and preserves document order. */
  loop i = 2 to tagged~items
    current = tagged~at(i)
    j = i - 1
    do while j >= 1
      if tagged~at(j)~at(1) <= current~at(1) then leave
      tagged~put(tagged~at(j), j + 1)
      j = j - 1
    end
    tagged~put(current, j + 1)
  end
  out = .Array~new
  loop i = 1 to tagged~items
    out~append(tagged~at(i)~at(2))
  end
  return out
::method firstBlock class
  use arg xml, name
  blocks = self~elementBlocks(xml, name)
  if blocks~items == 0 then return ""
  return blocks~at(1)
::method openingTag class
  use arg block
  ending = pos(">", block)
  if ending == 0 then return block
  return substr(block, 1, ending)
::method textContents class
  use arg xml, name
  out = .Array~new
  blocks = self~elementBlocks(xml, name)
  loop i = 1 to blocks~items
    block = blocks~at(i)
    openEnd = pos(">", block)
    closeStart = lastpos("</" || name || ">", block)
    if openEnd > 0 then do
      if closeStart > openEnd then do
        value = substr(block, openEnd + 1, closeStart - openEnd - 1)
        value = self~stripTags(value)
        out~append(self~decode(value))
      end
    end
  end
  return out
::method stripTags class
  use arg text
  out = ""
  cursor = 1
  do while cursor <= length(text)
    opening = pos("<", text, cursor)
    if opening == 0 then do
      out = out || substr(text, cursor)
      leave
    end
    if opening > cursor then out = out || substr(text, cursor, opening - cursor)
    ending = pos(">", text, opening + 1)
    if ending == 0 then leave
    cursor = ending + 1
  end
  return out
::method decode class
  use arg text
  value = changestr("&lt;", text, "<")
  value = changestr("&gt;", value, ">")
  value = changestr("&quot;", value, '"')
  value = changestr("&apos;", value, "'")
  value = changestr("&amp;", value, "&")
  return value

::requires "SpreadsheetModel.cls"
