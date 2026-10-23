s=.IntentionService~new
.FontIntentions~install(s)
if s~registration("FIND_FONT") == .nil then call fail "find intention missing"
if s~registration("PACKAGE_FONT") == .nil then call fail "package intention missing"
d=s~input("find a font")
if d~status \== "READY" then call fail "find intent status="||d~status
if d~event \== "FONT.FIND" then call fail "find intent event="||d~event
d=s~input("package font for web")
if d~status \== "READY" then call fail "package intent status="||d~status
if d~event \== "FONT.PACKAGE_WEB" then call fail "package intent event="||d~event
say "PASS Font intentions"
exit 0
fail: procedure
 parse arg why
 say "FAIL" why
 exit 1
::requires "FontIntentions.cls"
