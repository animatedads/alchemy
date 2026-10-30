/* SpreadsheetInterchange.cls
 * Safe tabular interchange and new-workbook creation.
 *
 * This module deliberately creates new spreadsheets.  It does not mutate arbitrary
 * existing workbooks.  Text remains text, including values beginning with formula
 * sigils.  Formula creation requires a future explicit formula object/authority.
 */

::class SpreadsheetTableData public
::method init
  expose name columns rows types provenance
  use arg name = "Export", columns = .nil, rows = .nil, types = .nil, provenance = .nil
  if columns == .nil then columns = .Array~new
  if rows == .nil then rows = .Array~new
  if types == .nil then types = .Directory~new
  if provenance == .nil then provenance = .Directory~new
::attribute name get
::method columns
  expose columns
  return columns~copy
::method rows
  expose rows
  return rows~copy
::method types
  expose types
  return types~copy
::method provenance
  expose provenance
  return provenance
::method rowCount
  expose rows
  return rows~items
::method columnCount
  expose columns
  return columns~items
::method addRow
  expose rows
  use arg row
  if row \== .nil then rows~append(row)
  return self
::method fromRelation class
  use arg relation
  if relation == .nil then raise syntax 93.900 array("Spreadsheet relation is required")
  columns = relation~fieldNames
  types = .Directory~new
  fields = relation~fields
  loop i = 1 to fields~items
    field = fields~at(i)
    types~put(field~inferredType, field~name)
  end
  provenance = .Directory~new
  provenance~put(relation, "SOURCE_RELATION")
  provenance~put(relation~sheet, "SOURCE_SHEET")
  provenance~put(relation~name, "SOURCE_RELATION_NAME")
  return self~new(relation~name, columns, relation~records, types, provenance)

::class SpreadsheetInterchange public
::method writeXlsx class
  use arg data, path, sheetName = "Data"
  return .SpreadsheetNewWorkbookWriter~new~writeXlsx(data, path, sheetName)
::method writeOds class
  use arg data, path, sheetName = "Data"
  return .SpreadsheetNewWorkbookWriter~new~writeOds(data, path, sheetName)
::method writeCsv class
  use arg data, path
  return .SpreadsheetDelimitedWriter~new~write(data, path, ",")
::method writeTsv class
  use arg data, path
  return .SpreadsheetDelimitedWriter~new~write(data, path, "09"x)
::method readCsv class
  use arg path, name = "Imported"
  return .SpreadsheetDelimitedReader~new~read(path, ",", name)
::method readTsv class
  use arg path, name = "Imported"
  return .SpreadsheetDelimitedReader~new~read(path, "09"x, name)

::class SpreadsheetDelimitedWriter public
::method write
  use arg data, path, delimiter
  if data == .nil then raise syntax 93.900 array("Spreadsheet table data is required")
  if strip(path) == "" then raise syntax 93.900 array("Output path is required")
  stream = .Stream~new(path)
  if stream~open("write replace") \== "READY:" then raise syntax 93.900 array("Could not open output file:" path)
  columns = data~columns
  stream~lineout(self~line(columns, delimiter))
  rows = data~rows
  loop i = 1 to rows~items
    row = rows~at(i)
    values = .Array~new
    loop c = 1 to columns~items
      key = columns~at(c)
      value = ""
      if row~hasIndex(key) then value = row~at(key)
      values~append(value)
    end
    stream~lineout(self~line(values, delimiter))
  end
  stream~close
  return path
::method line
  use arg values, delimiter
  out = ""
  loop i = 1 to values~items
    if i > 1 then out = out || delimiter
    out = out || self~quote(values~at(i), delimiter)
  end
  return out
::method quote
  use arg value, delimiter
  text = value~string
  needs = pos(delimiter, text) > 0 | pos('"', text) > 0 | pos("0a"x, text) > 0 | pos("0d"x, text) > 0
  if \needs then return text
  return '"' || changestr('"', text, '""') || '"'

::class SpreadsheetDelimitedReader public
::method read
  use arg path, delimiter, name = "Imported"
  stream = .Stream~new(path)
  if stream~open("read") \== "READY:" then raise syntax 93.900 array("Could not open input file:" path)
  records = .Array~new
  logical = ""
  do while stream~lines > 0
    physical = stream~linein
    if logical == "" then logical = physical
    else logical = logical || "0a"x || physical
    if self~quotesBalanced(logical) then do
      records~append(self~parseLine(logical, delimiter))
      logical = ""
    end
  end
  stream~close
  if logical \== "" then raise syntax 93.900 array("Unterminated quoted field in delimited input")
  if records~items == 0 then return .SpreadsheetTableData~new(name)
  headers = records~at(1)
  rows = .Array~new
  loop r = 2 to records~items
    fields = records~at(r)
    row = .Directory~new
    loop c = 1 to headers~items
      value = ""
      if c <= fields~items then value = fields~at(c)
      row~put(value, headers~at(c))
    end
    rows~append(row)
  end
  return .SpreadsheetTableData~new(name, headers, rows)
::method quotesBalanced
  use arg text
  inside = .false
  i = 1
  do while i <= length(text)
    if substr(text, i, 1) == '"' then do
      if inside then do
        if i < length(text) then do
          if substr(text, i + 1, 1) == '"' then do
            i = i + 2
            iterate
          end
        end
      end
      inside = \inside
    end
    i = i + 1
  end
  return \inside
::method parseLine
  use arg text, delimiter
  out = .Array~new
  field = ""
  inside = .false
  i = 1
  do while i <= length(text)
    ch = substr(text, i, 1)
    if ch == '"' then do
      if inside then do
        if i < length(text) then do
          if substr(text, i + 1, 1) == '"' then do
            field = field || '"'
            i = i + 2
            iterate
          end
        end
      end
      inside = \inside
      i = i + 1
      iterate
    end
    if ch == delimiter then do
      if \inside then do
        out~append(field)
        field = ""
        i = i + 1
        iterate
      end
    end
    field = field || ch
    i = i + 1
  end
  out~append(field)
  return out

::class SpreadsheetNewWorkbookWriter public
::method writeXlsx
  use arg data, path, sheetName = "Data"
  self~validate(data, path)
  root = SysTempFileName("/tmp/oorexx_spreadsheet_write_????????")
  if root == "" then raise syntax 93.900 array("Could not allocate spreadsheet write directory")
  signal on syntax name xlsxCleanupError
  signal on error name xlsxCleanupError
  self~mkdir(root || "/_rels")
  self~mkdir(root || "/xl/_rels")
  self~mkdir(root || "/xl/worksheets/_rels")
  self~mkdir(root || "/xl/tables")
  self~writeText(root || "/[Content_Types].xml", self~xlsxContentTypes)
  self~writeText(root || "/_rels/.rels", self~xlsxRootRels)
  self~writeText(root || "/xl/workbook.xml", self~xlsxWorkbook(sheetName))
  self~writeText(root || "/xl/_rels/workbook.xml.rels", self~xlsxWorkbookRels)
  self~writeText(root || "/xl/styles.xml", self~xlsxStyles)
  self~writeText(root || "/xl/worksheets/sheet1.xml", self~xlsxSheet(data))
  self~writeText(root || "/xl/worksheets/_rels/sheet1.xml.rels", self~xlsxSheetRels)
  self~writeText(root || "/xl/tables/table1.xml", self~xlsxTable(data))
  self~zipDirectory(root, path)
  self~removeTree(root)
  return path
xlsxCleanupError:
  say "Spreadsheet XLSX write failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate
::method writeOds
  use arg data, path, sheetName = "Data"
  self~validate(data, path)
  root = SysTempFileName("/tmp/oorexx_spreadsheet_write_????????")
  if root == "" then raise syntax 93.900 array("Could not allocate spreadsheet write directory")
  signal on syntax name odsCleanupError
  signal on error name odsCleanupError
  self~mkdir(root || "/META-INF")
  self~writeText(root || "/mimetype", "application/vnd.oasis.opendocument.spreadsheet")
  self~writeText(root || "/META-INF/manifest.xml", self~odsManifest)
  self~writeText(root || "/content.xml", self~odsContent(data, sheetName))
  self~zipOds(root, path)
  self~removeTree(root)
  return path
odsCleanupError:
  say "Spreadsheet ODS write failed:" condition("C") condition("D") "RC=" rc "SIGL=" sigl
  self~removeTree(root)
  raise propagate
::method validate
  use arg data, path
  if data == .nil then raise syntax 93.900 array("Spreadsheet table data is required")
  if strip(path) == "" then raise syntax 93.900 array("Output path is required")
  if data~columnCount == 0 then raise syntax 93.900 array("At least one output column is required")
::method mkdir
  use arg path
  address system "mkdir -p" self~shellQuote(path)
  if rc \== 0 then raise syntax 93.900 array("Could not create output directory:" path)
::method writeText
  use arg path, text
  stream = .Stream~new(path)
  if stream~open("write replace") \== "READY:" then raise syntax 93.900 array("Could not create package part:" path)
  stream~charout(text)
  stream~close
::method zipDirectory
  use arg root, path
  absolute = self~absolutePath(path)
  address system "rm -f --" self~shellQuote(absolute)
  address system "cd" self~shellQuote(root) "&& zip -q -r" self~shellQuote(absolute) "."
  if rc \== 0 then raise syntax 93.900 array("Could not create XLSX package:" path)
::method zipOds
  use arg root, path
  absolute = self~absolutePath(path)
  address system "rm -f --" self~shellQuote(absolute)
  address system "cd" self~shellQuote(root) "&& zip -q -0" self~shellQuote(absolute) "mimetype"
  if rc \== 0 then raise syntax 93.900 array("Could not create ODS mimetype member")
  address system "cd" self~shellQuote(root) "&& zip -q -r" self~shellQuote(absolute) "META-INF content.xml"
  if rc \== 0 then raise syntax 93.900 array("Could not create ODS package:" path)
::method absolutePath
  use arg path
  if left(path, 1) == "/" then return path
  directory = directory()
  if right(directory, 1) == "/" then return directory || path
  return directory || "/" || path
::method removeTree
  use arg path
  if strip(path) == "" then return
  address system "rm -rf --" self~shellQuote(path)
::method shellQuote
  use arg value
  return "'" || value || "'"
::method xlsxContentTypes
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' || -
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' || -
    '<Default Extension="xml" ContentType="application/xml"/>' || -
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' || -
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' || -
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' || -
    '<Override PartName="/xl/tables/table1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml"/>' || -
    '</Types>'
::method xlsxRootRels
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' || -
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' || -
    '</Relationships>'
::method xlsxWorkbook
  use arg sheetName
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' || -
    '<sheets><sheet name="' || self~xml(sheetName) || '" sheetId="1" r:id="rId1"/></sheets></workbook>'
::method xlsxWorkbookRels
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' || -
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' || -
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' || -
    '</Relationships>'
::method xlsxStyles
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' || -
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>' || -
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' || -
    '<borders count="1"><border/></borders>' || -
    '<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="1"><xf xfId="0"/></cellXfs>' || -
    '</styleSheet>'
::method xlsxSheet
  use arg data
  columns = data~columns
  rows = data~rows
  types = data~types
  xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData>'
  xml = xml || '<row r="1">'
  loop c = 1 to columns~items
    address = .SpreadsheetAddress~fromRowColumn(1, c)
    xml = xml || self~xlsxTextCell(address, columns~at(c))
  end
  xml = xml || '</row>'
  loop r = 1 to rows~items
    excelRow = r + 1
    xml = xml || '<row r="' || excelRow || '">'
    row = rows~at(r)
    loop c = 1 to columns~items
      key = columns~at(c)
      value = ""
      if row~hasIndex(key) then value = row~at(key)
      type = "UNKNOWN"
      if types~hasIndex(key) then type = translate(types~at(key))
      address = .SpreadsheetAddress~fromRowColumn(excelRow, c)
      xml = xml || self~xlsxValueCell(address, value, type)
    end
    xml = xml || '</row>'
  end
  xml = xml || '</sheetData><tableParts count="1"><tablePart r:id="rId1"/></tableParts></worksheet>'
  return xml
::method xlsxTextCell
  use arg address, value
  return '<c r="' || address || '" t="inlineStr"><is><t xml:space="preserve">' || self~xml(value) || '</t></is></c>'
::method xlsxValueCell
  use arg address, value, type
  text = value~string
  if self~numericType(type) then do
    if datatype(text, "N") then return '<c r="' || address || '"><v>' || text || '</v></c>'
  end
  if type == "BOOLEAN" then do
    normalized = translate(strip(text))
    if normalized == "TRUE" | normalized == "1" then return '<c r="' || address || '" t="b"><v>1</v></c>'
    if normalized == "FALSE" | normalized == "0" then return '<c r="' || address || '" t="b"><v>0</v></c>'
  end
  return self~xlsxTextCell(address, text)
::method numericType
  use arg type
  t = translate(strip(type))
  return t == "NUMBER" | t == "INTEGER" | t == "DECIMAL" | t == "NUMERIC" | t == "MONEY" | t == "PERCENT"
::method xlsxSheetRels
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' || -
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/table" Target="../tables/table1.xml"/>' || -
    '</Relationships>'
::method xlsxTable
  use arg data
  columns = data~columns
  last = .SpreadsheetAddress~fromRowColumn(data~rowCount + 1, data~columnCount)
  ref = "A1:" || last
  name = self~xlsxName(data~name)
  xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' || -
    '<table xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" id="1" name="' || name || '" displayName="' || name || '" ref="' || ref || '" totalsRowShown="0">' || -
    '<autoFilter ref="' || ref || '"/><tableColumns count="' || columns~items || '">'
  loop i = 1 to columns~items
    xml = xml || '<tableColumn id="' || i || '" name="' || self~xml(columns~at(i)) || '"/>'
  end
  xml = xml || '</tableColumns><tableStyleInfo name="TableStyleMedium2" showFirstColumn="0" showLastColumn="0" showRowStripes="1" showColumnStripes="0"/></table>'
  return xml
::method xlsxName
  use arg value
  text = translate(strip(value))
  out = ""
  loop i = 1 to length(text)
    ch = substr(text, i, 1)
    valid = .false
    if ch >= "A" then do
      if ch <= "Z" then valid = .true
    end
    if \valid then do
      if ch >= "0" then do
        if ch <= "9" then valid = .true
      end
    end
    if ch == "_" then valid = .true
    if valid then out = out || ch
    else out = out || "_"
  end
  if out == "" then out = "EXPORT"
  if left(out, 1) >= "0" then do
    if left(out, 1) <= "9" then out = "T_" || out
  end
  return out
::method odsManifest
  return '<?xml version="1.0" encoding="UTF-8"?>' || -
    '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">' || -
    '<manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>' || -
    '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>' || -
    '</manifest:manifest>'
::method odsContent
  use arg data, sheetName
  columns = data~columns
  rows = data~rows
  types = data~types
  xml = '<?xml version="1.0" encoding="UTF-8"?>' || -
    '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3"><office:body><office:spreadsheet>' || -
    '<table:table table:name="' || self~xml(sheetName) || '">'
  xml = xml || '<table:table-row>'
  loop c = 1 to columns~items
    xml = xml || self~odsTextCell(columns~at(c))
  end
  xml = xml || '</table:table-row>'
  loop r = 1 to rows~items
    row = rows~at(r)
    xml = xml || '<table:table-row>'
    loop c = 1 to columns~items
      key = columns~at(c)
      value = ""
      if row~hasIndex(key) then value = row~at(key)
      type = "UNKNOWN"
      if types~hasIndex(key) then type = translate(types~at(key))
      xml = xml || self~odsValueCell(value, type)
    end
    xml = xml || '</table:table-row>'
  end
  xml = xml || '</table:table></office:spreadsheet></office:body></office:document-content>'
  return xml
::method odsTextCell
  use arg value
  return '<table:table-cell office:value-type="string"><text:p>' || self~xml(value) || '</text:p></table:table-cell>'
::method odsValueCell
  use arg value, type
  text = value~string
  if self~numericType(type) then do
    if datatype(text, "N") then return '<table:table-cell office:value-type="float" office:value="' || text || '"><text:p>' || self~xml(text) || '</text:p></table:table-cell>'
  end
  if type == "BOOLEAN" then do
    normalized = translate(strip(text))
    if normalized == "TRUE" | normalized == "1" then return '<table:table-cell office:value-type="boolean" office:boolean-value="true"><text:p>TRUE</text:p></table:table-cell>'
    if normalized == "FALSE" | normalized == "0" then return '<table:table-cell office:value-type="boolean" office:boolean-value="false"><text:p>FALSE</text:p></table:table-cell>'
  end
  return self~odsTextCell(text)
::method xml
  use arg value
  text = value~string
  text = changestr("&", text, "&amp;")
  text = changestr("<", text, "&lt;")
  text = changestr(">", text, "&gt;")
  text = changestr('"', text, "&quot;")
  text = changestr("'", text, "&apos;")
  return text

::requires "SpreadsheetModel.cls"
::requires "SpreadsheetRelations.cls"
