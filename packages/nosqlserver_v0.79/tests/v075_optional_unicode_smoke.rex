call directory directory("S")
parse arg tutorRoot
if tutorRoot = "" then do
  say "v0.75 optional Unicode smoke SKIP: pass TUTOR root as argument"
  exit 0
end

-- CLASSIC remains usable before TUTOR is loaded.
classic = .DatabaseColumn~new("classic_name", "VARCHAR", .true, .false, .false, "CLASSIC")
composed = "Caf" || x2c("C3A9")
decomposed = "Cafe" || x2c("CC81")
call assert classic~coerce(composed) == composed, "CLASSIC column works without TUTOR"
call assert classic~coerce(composed) \== classic~coerce(decomposed), "CLASSIC preserves byte distinction"

-- UNICODE is explicit and fails closed until the optional provider is enabled.
unicodeBefore = .DatabaseColumn~new("unicode_name", "VARCHAR", .true, .false, .false, "UNICODE")
caught = .false
signal on syntax name expectedMissingTutor
ignore = unicodeBefore~coerce(composed)
signal off syntax
call assert .false, "UNICODE should require explicit TUTOR enable"
expectedMissingTutor:
signal off syntax
caught = .true
call assert caught, "UNICODE missing provider fails closed"

call assert .NoSQLUnicodeSupport~enable(tutorRoot), "enable optional TUTOR provider"
call assert .NoSQLUnicodeSupport~available, "TUTOR Text/Codepoints available"

unicode = .DatabaseColumn~new("unicode_name", "VARCHAR", .true, .false, .false, "UNICODE")
uComposed = unicode~coerce(composed)
uDecomposed = unicode~coerce(decomposed)
call assert .NoSQLUnicodeSupport~isUnicodeValue(uComposed), "UNICODE column carries TUTOR Text"
call assert c2x(uComposed~makeString) = "436166C3A9", "UNICODE NFC canonical bytes"
call assert uComposed~makeString == uDecomposed~makeString, "canonical equivalents normalize equally"
call assert unicode~compare(uComposed, "=", decomposed), "column equality promotes literal through Unicode profile"
call assert .NoSQLUnicodeSupport~characterLength(uComposed) = 4, "grapheme-aware character length"
call assert .NoSQLUnicodeSupport~octetLength(uComposed) = 5, "UTF-8 octet length remains inspectable"

badCaught = .false
signal on syntax name invalidUtf8
ignore = unicode~coerce(x2c("C328"))
signal off syntax
call assert .false, "ill-formed UTF-8 should be rejected"
invalidUtf8:
signal off syntax
badCaught = .true
call assert badCaught, "ill-formed UTF-8 rejected"

-- Loading TUTOR must not change CLASSIC semantics.
call assert classic~coerce(composed) \== classic~coerce(decomposed), "CLASSIC unchanged after TUTOR load"

json = .JsonDatabaseEngine~new("fixtures/v075_unicode.json")
ucols = .array~new
ucols~append(.JsonColumnProjection~new("id", "$.id", "INTEGER", .false))
ucols~append(.JsonColumnProjection~new("name", "$.name", "VARCHAR", .false, "UNICODE"))
call assert json~registerProjection("unicode_names", "$.rows[*]", ucols), "register Unicode JSON relation"

ccols = .array~new
ccols~append(.JsonColumnProjection~new("id", "$.id", "INTEGER", .false))
ccols~append(.JsonColumnProjection~new("name", "$.name", "VARCHAR", .false, "CLASSIC"))
call assert json~registerProjection("classic_names", "$.rows[*]", ccols), "register classic JSON relation"

r = json~execute("SELECT id,name FROM unicode_names WHERE name='Cafe" || x2c("CC81") || "' ORDER BY id;")
call assert r~status = .Error~SUCCESS, "Unicode canonical-equivalence predicate"
call assert r~rows~items = 2, "Unicode predicate matches composed and decomposed rows"

r = json~execute("SELECT id FROM classic_names WHERE name='Cafe" || x2c("CC81") || "' ORDER BY id;")
call assert r~status = .Error~SUCCESS, "Classic predicate still executes"
call assert r~rows~items = 1, "Classic predicate keeps byte distinction"
call assert r~rows[1]["id"] = "2", "Classic predicate selects only decomposed row"

r = json~execute("SELECT CHAR_LENGTH(name) AS chars,OCTET_LENGTH(name) AS octets,SUBSTR(name,4,1) AS tail,UPPER(name) AS upper_name FROM unicode_names WHERE id=1;")
call assert r~status = .Error~SUCCESS, "Unicode scalar functions"
call assert r~rows~items = 1, "Unicode scalar function row count"
call assert r~rows[1]["chars"] = "4", "CHAR_LENGTH counts graphemes"
call assert r~rows[1]["octets"] = "5", "OCTET_LENGTH counts UTF-8 bytes"
call assert .NoSQLUnicodeSupport~raw(r~rows[1]["tail"]) == x2c("C3A9"), "SUBSTR is grapheme-aware"
call assert .NoSQLUnicodeSupport~raw(r~rows[1]["upper_name"]) == "CAF" || x2c("C389"), "UPPER uses Unicode case mapping"

r = json~execute("SELECT id FROM unicode_names WHERE name LIKE '____' ORDER BY id;")
call assert r~status = .Error~SUCCESS, "Unicode LIKE"
call assert r~rows~items >= 1, "Unicode LIKE underscore counts graphemes"
foundCafe = .false
do row over r~rows
  if row["id"] = "1" then foundCafe = .true
end
call assert foundCafe, "Unicode LIKE four underscores matches Café"

r = json~execute("SELECT id,name FROM unicode_names ORDER BY name;")
call assert r~status = .Error~SUCCESS, "Unicode deterministic ORDER BY"
call assert r~rows~items = 5, "Unicode ORDER BY row count"


-- FILE storage and constraints use the normalized value when Unicode is opted in.
dbRoot = .NoSQLServerTestSupport~createBlankDatabase("v075-unicode-file")
fileEngine = .FileDatabaseEngine~new(dbRoot)
fileSql = .NoSQLServerSQL~new(fileEngine)
r = fileSql~execute("CREATE TABLE unicode_pk (name VARCHAR PRIMARY KEY);")
call assert r~status = .Error~SUCCESS, "create Unicode PK probe table"
schemaPath = dbRoot || "/tables/unicode_pk/table.yaml"
schema = .Yaml~new~parseFile(schemaPath)
schema["textMode"] = "UNICODE"
.Yaml~toYamlFile(schema, schemaPath)
fileEngine = .FileDatabaseEngine~new(dbRoot)
fileSql = .NoSQLServerSQL~new(fileEngine)
r = fileSql~execute("INSERT INTO unicode_pk VALUES ('Caf" || x2c("C3A9") || "');")
call assert r~status = .Error~SUCCESS, "insert composed Unicode PK"
r = fileSql~execute("INSERT INTO unicode_pk VALUES ('Cafe" || x2c("CC81") || "');")
call assert r~status = .Error~NOTEXECUTED, "canonical-equivalent Unicode PK rejected"
call assert r~error = .Error~CONSTRAINT, "Unicode PK canonical equivalence reaches constraint layer"
r = fileSql~execute("SELECT name FROM unicode_pk;")
call assert r~status = .Error~SUCCESS, "read Unicode FILE relation"
call assert r~rows~items = 1, "Unicode FILE relation row count"
call assert c2x(.NoSQLUnicodeSupport~raw(r~rows[1]["name"])) = "436166C3A9", "Unicode FILE round-trip NFC"
ignoredCleanup = .NoSQLServerTestSupport~removeDatabase(dbRoot)

v = .NoSQLServerVersionInfo~new
call assert arrayContains(v~features, "OPTIONAL_TUTOR_UNICODE"), "version advertises optional TUTOR Unicode"
call assert arrayContains(v~features, "UNICODE_NFC_TEXT"), "version advertises NFC text"
call assert arrayContains(v~features, "UNICODE_GRAPHEME_FUNCTIONS"), "version advertises grapheme functions"

say "v0.75 optional Unicode smoke PASS"
exit 0

arrayContains: procedure
  use arg array, wanted
  do item over array
    if item = wanted then return .true
  end
  return .false

assert: procedure
  use arg condition, description
  if \condition then do
    say "ASSERT FAILED:" description
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
