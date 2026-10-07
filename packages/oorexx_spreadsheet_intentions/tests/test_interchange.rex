/* dev6 interchange qualification */
call RxFuncAdd "SysLoadFuncs", "RexxUtil", "SysLoadFuncs"
call SysLoadFuncs

columns = .Array~of("TPS ID", "Owner", "Pages", "Comment")
types = .Directory~new
types~put("INTEGER", "Pages")
rows = .Array~new
r = .Directory~new
r~put("TPS-001", "TPS ID"); r~put("Angela", "Owner"); r~put(17, "Pages"); r~put("=2+2", "Comment"); rows~append(r)
r = .Directory~new
r~put("TPS-002", "TPS ID"); r~put("Oscar", "Owner"); r~put(23, "Pages"); r~put("contains, comma", "Comment"); rows~append(r)
r = .Directory~new
r~put("TPS-003", "TPS ID"); r~put("Kevin", "Owner"); r~put(3, "Pages"); r~put('He said "Keleven"', "Comment"); rows~append(r)

data = .SpreadsheetTableData~new("TPS Reports", columns, rows, types)
base = SysTempFileName("/tmp/oorexx_interchange_????????")
call SysMkDir base
xlsx = base || "/tps.xlsx"
ods = base || "/tps.ods"
csv = base || "/tps.csv"
tsv = base || "/tps.tsv"

.SpreadsheetInterchange~writeXlsx(data, xlsx, "TPS Reports")
.SpreadsheetInterchange~writeOds(data, ods, "TPS Reports")
.SpreadsheetInterchange~writeCsv(data, csv)
.SpreadsheetInterchange~writeTsv(data, tsv)

call assertTrue stream(xlsx, "C", "QUERY EXISTS") \== "", "xlsx created"
call assertTrue stream(ods, "C", "QUERY EXISTS") \== "", "ods created"
call assertTrue stream(csv, "C", "QUERY EXISTS") \== "", "csv created"
call assertTrue stream(tsv, "C", "QUERY EXISTS") \== "", "tsv created"

wb = .SpreadsheetReader~open(xlsx)
cat = .SpreadsheetRelationDiscoverer~new~discover(wb)
rel = cat~relation("TPS_REPORTS")
if rel == .nil then rel = cat~relations~at(1)
call assertEquals 3, rel~records~items, "xlsx row round trip"
call assertEquals "=2+2", rel~records~at(1)~at("Comment"), "xlsx formula-looking text remains text"
cell = wb~sheets~at(1)~cell("D2")
call assertTrue \cell~hasFormula, "xlsx text is not formula"
call assertEquals "TEXT", cell~valueType, "xlsx formula-looking text type"

wb = .SpreadsheetReader~open(ods)
cat = .SpreadsheetRelationDiscoverer~new~discover(wb)
rel = cat~relations~at(1)
call assertEquals 3, rel~records~items, "ods row round trip"
call assertEquals "=2+2", rel~records~at(1)~at("Comment"), "ods formula-looking text remains text"
cell = wb~sheets~at(1)~cell("D2")
call assertTrue \cell~hasFormula, "ods text is not formula"

fromCsv = .SpreadsheetInterchange~readCsv(csv, "TPS Imported")
call assertEquals 3, fromCsv~rowCount, "csv row round trip"
call assertEquals "contains, comma", fromCsv~rows~at(2)~at("Comment"), "csv comma quoting"
call assertEquals 'He said "Keleven"', fromCsv~rows~at(3)~at("Comment"), "csv quote escaping"

fromTsv = .SpreadsheetInterchange~readTsv(tsv, "TPS Imported")
call assertEquals 3, fromTsv~rowCount, "tsv row round trip"

sourceWb = .SpreadsheetReader~open(xlsx)
sourceCatalog = .SpreadsheetRelationDiscoverer~new~discover(sourceWb)
sourceRel = sourceCatalog~relations~at(1)
bridge = .SpreadsheetTableData~fromRelation(sourceRel)
call assertTrue bridge~provenance~at("SOURCE_RELATION") == sourceRel, "relation provenance object identity"
call assertEquals 3, bridge~rowCount, "relation export row count"

address system "rm -rf -- '" || base || "'"
say "PASS test_interchange"
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 20
  end
  return
assertEquals: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 21
  end
  return

::requires "SpreadsheetInterchange.cls"
::requires "SpreadsheetOpenFormats.cls"
::requires "SpreadsheetRelations.cls"
