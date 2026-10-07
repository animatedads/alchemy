d=.CliUiDocument~new("abc","plain")
if d~caret <> 4 then exit 1
d~moveCaret(-1)
d~backspace
if d~text <> "ac" then exit 2
d~setCaret(2)
d~insert("B")
if d~text <> "aBc" then exit 3
say 'PASS document runtime'
exit 0
::requires 'CliUiDocument.cls'
