/* Requires recordset.cls and the compiled recordset native library. */
::requires "recordset.cls"

path = "recordset-smoke.txt"
w = .RecordSet~open(path, "WRITE")
w~write("alpha")
w~write("")
w~write("gamma")
w~close

r = .RecordSet~open(path)
if r~recordCount <> 3 then raise syntax 98.900 array("record count")
if r~read <> "alpha" then raise syntax 98.900 array("record 1")
if r~read <> "" then raise syntax 98.900 array("empty record")
if r~read <> "gamma" then raise syntax 98.900 array("record 3")
if \r~eof then raise syntax 98.900 array("EOF")
if r~read <> .nil then raise syntax 98.900 array("EOF return")
r~close
say "RecordSet Rexx smoke: PASS"
