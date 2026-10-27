/* Direct ooRexx API smoke: code can pass an Array and bypass flattened argv. */
app = .CloudApp~new
tokens = .Array~of("workspace", "--json")
rc = app~runTokens(tokens)
if rc \= 0 then do
  say "FAIL API rc=" rc
  exit 1
end
exit 0
::requires "CloudConsole.cls"