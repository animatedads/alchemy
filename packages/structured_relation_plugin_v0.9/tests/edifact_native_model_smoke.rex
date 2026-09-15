text = "UNA:+.? '" || "0a"x || -
       "UNB+UNOC:3+SENDER+RECEIVER+260820:1045+CTRL1'" || "0a"x || -
       "UNH+1+ORDERS:D:96A:UN'" || "0a"x || -
       "BGM+220+PO12345+9'" || "0a"x || -
       "DTM+137:20260820:102'" || "0a"x || -
       "NAD+BY+123456::91'" || "0a"x || -
       "FTX+AAI+++Handle ?+ safely ?: colon ?' apostrophe??'" || "0a"x || -
       "UNT+6+1'" || "0a"x || -
       "UNZ+1+CTRL1'"

doc = .EdiFactDocumentContext~fromText(text, "memory:orders.edi")
call assert doc~separators~explicitUna, "UNA detected"
call assert doc~messages~items = 1, "one message"
call assert doc~interchanges~items = 1, "one interchange"
call assert doc~messages[1]~messageType = "ORDERS", "message type retained"
call assert doc~messages[1]~reference = "1", "message reference retained"
call assert doc~messages[1]~version = "D", "message version retained"
call assert doc~messages[1]~release = "96A", "message release retained"
call assert doc~messages[1]~agency = "UN", "message agency retained"

sel = doc~select("BGM/2", doc~messages[1])
call assert sel~count = 1, "BGM order id selected"
call assert sel~firstNode~isA(.EdiFactElement), "selection retains element object"
call assert sel~firstNode~scalarValue = "PO12345", "order id scalar"
call assert sel~firstNode~lexicalValue = "PO12345", "order id lexical retained"
call assert sel~firstNode~path~pos("/BGM[1]/E2") > 0, "order id structural path"
call assert sel~firstNode~line = 4, "order id source line"

sel = doc~select("DTM[=137]/1/2", doc~messages[1])
call assert sel~count = 1, "qualified DTM selected"
call assert sel~firstNode~isA(.EdiFactComponent), "DTM component object retained"
call assert sel~firstNode~value = "20260820", "DTM date component"

sel = doc~select("NAD[=BY]/2/1", doc~messages[1])
call assert sel~firstNode~value = "123456", "qualified NAD buyer"

sel = doc~select("FTX[=AAI]/4", doc~messages[1])
call assert sel~firstNode~scalarValue = "Handle + safely : colon ' apostrophe?", "release characters decoded"
call assert sel~firstNode~lexicalValue~pos("?+") > 0, "release lexical form retained"
call assert sel~firstNode~lexicalValue~pos("?'") > 0, "escaped segment terminator retained"

report = doc~validateEnvelope
call assert report~status = "VALID", "valid envelope"
call assert report~findings~items = 0, "no envelope findings"
call assert doc~history~items >= 6, "processing history retained"

say "EDIFACT NATIVE MODEL SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/EdiFactNativeSource.cls"
