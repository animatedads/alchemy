call addSearchPath
m=.FontManager~new
p=.FontManifestProvider~new
p~add(.FontFace~new("Test Sans","/fonts/test-regular.ttf","Regular","Test Sans Regular","TestSans-Regular",80,0,0,.true,"TrueType","TEST"))
p~add(.FontFace~new("Test Sans","/fonts/test-bold.ttf","Bold","Test Sans Bold","TestSans-Bold",180,0,0,.true,"TrueType","TEST"))
p~add(.FontFace~new("Test Mono","/fonts/test-mono.ttf","Regular","Test Mono","TestMono-Regular",80,0,100,.true,"TrueType","TEST"))
m~registerProvider(p); n=m~discover
if n \== 3 then call fail "discover count"
q=.FontQuery~new~family("Test Sans"); q~weight=180
match=m~find(q)
if match==.nil then call fail "bold matching nil"
if match~face~style \== "Bold" then call fail "bold matching"
q2=.FontQuery~new; q2~monospace=.true
match2=m~find(q2)
if match2==.nil then call fail "monospace matching nil"
if \match2~face~isMonospace then call fail "monospace matching"
body=m~queryForPurpose("BODY")
if body~size <= 0 | body~families~items==0 then call fail "purpose profile"
css=m~cssFaceRule(match~face,"fonts/test.woff2","woff2")
if pos("@font-face",css)==0 | pos("woff2",css)==0 then call fail "css rule"
say "PASS FontManager core"
exit 0
fail: procedure
  parse arg why
  say "FAIL" why
  exit 1
addSearchPath: procedure
  return
::requires "FontManager.cls"
::requires "FontProviders.cls"
