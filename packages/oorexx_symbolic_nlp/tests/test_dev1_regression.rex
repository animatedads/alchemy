/* test_symbolic_nlp.rex - deterministic qualification for SymbolicNLPParser. */

failures = 0
parser = .SymbolicNLPParser~new

parser~registerIntent("OOREXX_CREATE_CLASS", "CREATE|MAKE|DEFINE", "CLASS", "OOREXX CLASS", 100)
parser~registerSlot("OOREXX_CREATE_CLASS", "CLASS_NAME", "NAMED|CALLED", "NEXT", 1)
parser~registerIntent("OOREXX_ADD_METHOD", "ADD|CREATE|DEFINE", "METHOD", "OOREXX METHOD", 95)
parser~registerSlot("OOREXX_ADD_METHOD", "METHOD_NAME", "NAMED|CALLED", "NEXT", 1)
parser~registerIntent("LIST_DIR_CURRENT", "LIST|SHOW", "DIRECTORY|FILES", "", 90)
parser~registerIntent("PWD", "SHOW|PRINT", "DIRECTORY", "WORKING DIRECTORY|CURRENT DIRECTORY", 80)

call AssertParse "create an ooRexx class called Widget", "MATCHED", "OOREXX_CREATE_CLASS", "POSITIVE", "CLASS_NAME", "Widget"
call AssertParse "make class named Invoice", "MATCHED", "OOREXX_CREATE_CLASS", "POSITIVE", "CLASS_NAME", "Invoice"
call AssertParse "add an ooRexx method called render", "MATCHED", "OOREXX_ADD_METHOD", "POSITIVE", "METHOD_NAME", "render"
call AssertParse "list directory", "MATCHED", "LIST_DIR_CURRENT", "POSITIVE", "", ""
call AssertParse "show current directory", "MATCHED", "PWD", "POSITIVE", "", ""
call AssertParse "create a class with no methods", "MATCHED", "OOREXX_CREATE_CLASS", "POSITIVE", "", ""
call AssertParse "do not create a class called Dangerous", "MATCHED", "OOREXX_CREATE_CLASS", "NEGATED", "CLASS_NAME", "Dangerous"
call AssertParse "creat a clas called TypoWidget", "MATCHED", "OOREXX_CREATE_CLASS", "POSITIVE", "CLASS_NAME", "TypoWidget"
call AssertParse "sing a song", "UNKNOWN", "", "POSITIVE", "", ""

/* The overlapping SHOW + DIRECTORY vocabulary must be visible as ambiguity,
   not silently hidden by registration priority. */
ambiguous = parser~parse("show directory")
if ambiguous~at("STATUS") \== "AMBIGUOUS" then do
  say "FAIL expected AMBIGUOUS for: show directory; got" ambiguous~at("STATUS")
  failures = failures + 1
end
else say "PASS ambiguity surfaced: show directory"

/* Word examination remains available separately from intent selection. */
tokens = parser~examine("creat clas")
if tokens~items \== 2 then do
  say "FAIL examine token count"
  failures = failures + 1
end
else do
  if tokens~at(1)~at("MATCH") \== "SOUNDEX" then do
    say "FAIL expected Soundex resolution for creat"
    failures = failures + 1
  end
  if tokens~at(2)~at("MATCH") \== "SOUNDEX" then do
    say "FAIL expected Soundex resolution for clas"
    failures = failures + 1
  end
end

if failures = 0 then do
  say "PASS SymbolicNLPParser qualification"
  exit 0
end

say "FAIL SymbolicNLPParser qualification failures="failures
exit 1

AssertParse: procedure expose parser failures
  use arg text, expectedStatus, expectedIntent, expectedPolarity, slotName, slotValue

  parseRecord = parser~parse(text)
  ok = 1

  if parseRecord~at("STATUS") \== expectedStatus then ok = 0
  if parseRecord~at("INTENT") \== expectedIntent then ok = 0
  if parseRecord~at("POLARITY") \== expectedPolarity then ok = 0

  if slotName \== "" then do
    slots = parseRecord~at("SLOTS")
    if slots~hasIndex(slotName) = 0 then ok = 0
    else if slots~at(slotName) \== slotValue then ok = 0
  end

  if ok = 1 then say "PASS" text "->" parseRecord~at("STATUS") parseRecord~at("INTENT") parseRecord~at("SCORE") parseRecord~at("POLARITY")
  else do
    say "FAIL" text
    say "  got     :" parseRecord~at("STATUS") parseRecord~at("INTENT") parseRecord~at("SCORE") parseRecord~at("POLARITY")
    say "  expected:" expectedStatus expectedIntent expectedPolarity
    failures = failures + 1
  end
  return

::requires "../src/SymbolicNLP.cls"
