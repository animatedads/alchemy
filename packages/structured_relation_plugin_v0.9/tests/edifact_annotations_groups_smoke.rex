text = "UNA:+.? '" || "0a"x || -
       "UNB+UNOC:3+SENDER+RECEIVER+260820:1816+CTRL1'" || "0a"x || -
       "/* demo annotation between envelopes */" || "0a"x || -
       "UNG+PNR+OLA+SHN+260820:1816+G07'" || "0a"x || -
       "/* group comment */ UNH+G07A+PNRGOV:11:1:IA'" || "0a"x || -
       "RCI+1A:OLAD5K1'" || "0a"x || -
       "SSR+NSST:HK:1:OA:1541:210826+SEAT NOT PURCHASED'" || "0a"x || -
       "UNT+4+G07A'" || "0a"x || -
       "UNH+G07B+PNRGOV:11:1:IA'" || "0a"x || -
       "SSR+SEAT:HK:1:OA:1541:210826+2A'" || "0a"x || -
       "UNT+3+G07B'" || "0a"x || -
       "UNE+2+G07'" || "0a"x || -
       "UNZ+1+CTRL1'"

doc = .EdiFactDocumentContext~fromText(text, "memory:groups.edi")
call assert doc~annotations~items = 2, "two comments retained"
call assert doc~annotations[1]~kind = "BLOCK_COMMENT", "annotation kind"
call assert doc~annotations[1]~lexicalValue~pos("demo annotation") > 0, "annotation text retained"
call assert doc~groups~items = 1, "functional group retained"
g = doc~groups[1]
call assert g~reference = "G07", "functional group reference"
call assert g~functionalId = "PNR", "functional group type"
call assert g~messages~items = 2, "group owns messages"
call assert g~messages[1]~group == g, "message group identity"
call assert doc~select("MESSAGE:PNRGOV")~count = 2, "messages selectable"
call assert doc~select("@GROUPREFERENCE", g~messages[1])~scalar = "G07", "message group selector"
ssr = doc~select("SEGMENT:SSR")
call assert ssr~count = 2, "SSR segments selectable"
call assert doc~select("@GROUPREFERENCE", ssr~nodes[1])~scalar = "G07", "segment group selector"
call assert ssr~nodes[1]~tag = "SSR", "comment did not corrupt segment tag"
report = doc~validateEnvelope
call assert report~status = "VALID", "well formed grouped envelope validates"
say "EDIFACT ANNOTATIONS/GROUPS SMOKE: OK"
exit 0

::routine assert
  use arg condition, message
  if condition then return
  say "ASSERTION FAILED:" message
  exit 1

::requires "../src/EdiFactNativeSource.cls"
