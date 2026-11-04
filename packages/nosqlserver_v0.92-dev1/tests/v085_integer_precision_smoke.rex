root = .NoSQLServerTestSupport~createBlankDatabase("v085-integer-precision")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE country (code VARCHAR(3) PRIMARY KEY, name VARCHAR(64) NOT NULL, population INTEGER NOT NULL)")

-- Classic World-scale 10-digit populations must not be rejected merely because
-- the invoking Rexx activation is using the default numeric precision.
call assertSuccess sql~execute("INSERT INTO country (code,name,population) VALUES ('CHN','China',1277558000)")
call assertSuccess sql~execute("INSERT INTO country (code,name,population) VALUES ('IND','India',1013662000)")
call assertSuccess sql~execute("INSERT INTO country (code,name,population) VALUES ('TST','TenDigit',2147483647)")

rs = sql~execute("SELECT population FROM country WHERE code='CHN'")
call assertSuccess rs
call assertEqual "1277558000", rs~rows[1]["population"], "10-digit INTEGER preserved exactly"

-- Exact INTEGER ordering must also avoid ambient numeric rounding.
rs = sql~execute("SELECT code FROM country WHERE population > 1100000000 ORDER BY population")
call assertSuccess rs
call assertEqual 2, rs~rows~items, "exact large INTEGER predicate count"
call assertEqual "CHN", rs~rows[1]["code"], "exact large INTEGER order lower"
call assertEqual "TST", rs~rows[2]["code"], "exact large INTEGER order upper"

-- DatabaseValue/prepared-parameter validation uses the same precision-independent path.
large = .DatabaseValue~integer("1277558000")
call assertTrue \large~typeName~startsWith("INVALID:"), "DatabaseValue accepts 10-digit INTEGER"
stmt = .DatabasePreparedStatement~new("large-int", "SELECT code FROM country WHERE population = ?", 1, "")
params = .array~of(large)
bound = .DatabaseParameterBinder~bind(stmt, params)
call assertTrue \bound~isA(.DatabaseResult), "prepared INTEGER parameter renders successfully"
rs = sql~execute(bound)
call assertSuccess rs
call assertEqual 1, rs~rows~items, "prepared 10-digit INTEGER match"
call assertEqual "CHN", rs~rows[1]["code"], "prepared 10-digit INTEGER preserved"

-- INTEGER remains lexically integral; decimal/exponent spellings do not become INTEGER.
bad = sql~execute("INSERT INTO country (code,name,population) VALUES ('BAD','Bad',12.5)")
call assertTrue bad~status \= .Error~SUCCESS, "fractional value rejected for INTEGER"
badValue = .DatabaseValue~integer("12.5")
call assertTrue badValue~typeName~startsWith("INVALID:"), "DatabaseValue rejects fractional INTEGER"

-- Leading sign/zero spellings remain valid integers and preserve source text.
call assertTrue .NoSQLIntegerSupport~isInteger("+00000000001234567890"), "signed/zero-padded integer lexical validation"
call assertTrue \.NoSQLIntegerSupport~isInteger("1E9"), "exponent spelling is not INTEGER"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.85 INTEGER PRECISION SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: expected SUCCESS got" rs~status rs~error rs~message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
