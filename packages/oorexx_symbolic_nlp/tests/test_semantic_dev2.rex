/* test_semantic_dev2.rex - dev2 compositional semantic qualification. */

failures = 0

parser = .SymbolicNLPParser~new
parser~registerConcept("CREATE", "VERB", "CREATE|MAKE|DEFINE")
parser~registerConcept("ADD", "VERB", "ADD|CREATE|DEFINE")
parser~registerConcept("COPY", "VERB", "COPY|DUPLICATE")
parser~registerConcept("LIST", "VERB", "LIST|SHOW")
parser~registerConcept("CLASS", "NOUN", "CLASS|TYPE")
parser~registerConcept("METHOD", "NOUN", "METHOD|FUNCTION")
parser~registerConcept("FILE", "NOUN", "FILE|DOCUMENT")
parser~registerConcept("DIRECTORY", "NOUN", "DIRECTORY|FILES")

parser~registerSemanticIntent("OOREXX_CREATE_CLASS", "CREATE", "CLASS", "OOREXX CLASS", 100)
parser~registerSlot("OOREXX_CREATE_CLASS", "CLASS_NAME", "NAMED|CALLED", "PHRASE", 1, "WITH|IN|USING")

parser~registerSemanticIntent("OOREXX_ADD_METHOD", "ADD", "METHOD", "OOREXX METHOD", 95)
parser~registerSlot("OOREXX_ADD_METHOD", "METHOD_NAME", "NAMED|CALLED", "PHRASE", 1, "TO|IN|WITH")

parser~registerSemanticIntent("COPY_FILE", "COPY", "FILE", "", 90)
parser~registerSlot("COPY_FILE", "SOURCE", "FROM", "PHRASE", 1, "TO")
parser~registerSlot("COPY_FILE", "DESTINATION", "TO", "REST", 1)

parser~registerSemanticIntent("LIST_DIR_CURRENT", "LIST", "DIRECTORY", "", 90)
parser~registerSemanticIntent("LIST_DIR_PATH", "LIST", "DIRECTORY", "", 95)
parser~registerSlot("LIST_DIR_PATH", "PATH", "IN", "REST", 1)

call AssertEq parser~version, "0.1-dev2", "version"
call AssertEq parser~conceptIds~items, 8, "concept count"

p = parser~parse('create an ooRexx class called "Invoice Line" with no methods')
call AssertEq p~at("STATUS"), "MATCHED", "quoted class status"
call AssertEq p~at("INTENT"), "OOREXX_CREATE_CLASS", "quoted class intent"
call AssertEq p~at("POLARITY"), "POSITIVE", "later no does not negate command"
call AssertEq p~at("SLOTS")~at("CLASS_NAME"), "Invoice Line", "quoted class slot"
call AssertEq p~at("COMPLETE"), 1, "quoted class complete"
call AssertEq p~at("SEMANTIC")~at("ACTION")~at("CONCEPT"), "CREATE", "action concept"
call AssertEq p~at("SEMANTIC")~at("OBJECT")~at("CONCEPT"), "CLASS", "object concept"
call AssertEq p~at("LOGICAL_FORM"), 'OOREXX_CREATE_CLASS[POSITIVE](ACTION=CREATE;OBJECT=CLASS;CLASS_NAME="Invoice Line")', "logical form"

p = parser~parse("please -- do not create a class called Dangerous")
call AssertEq p~at("INTENT"), "OOREXX_CREATE_CLASS", "punctuation-gap intent"
call AssertEq p~at("POLARITY"), "NEGATED", "punctuation-gap negation"
call AssertEq p~at("SLOTS")~at("CLASS_NAME"), "Dangerous", "punctuation-gap slot"
call AssertEq p~at("SEMANTIC")~at("RELATIONS")~items, 3, "negated relation count"

p = parser~parse("copy file from source.txt to backup/source.txt")
call AssertEq p~at("STATUS"), "MATCHED", "copy status"
call AssertEq p~at("INTENT"), "COPY_FILE", "copy intent"
call AssertEq p~at("SLOTS")~at("SOURCE"), "source.txt", "copy source"
call AssertEq p~at("SLOTS")~at("DESTINATION"), "backup/source.txt", "copy destination"
call AssertEq p~at("COMPLETE"), 1, "copy complete"
call AssertEq p~at("LOGICAL_FORM"), "COPY_FILE[POSITIVE](ACTION=COPY;OBJECT=FILE;SOURCE=source.txt;DESTINATION=backup/source.txt)", "copy logical form"

p = parser~parse("list directory")
call AssertEq p~at("INTENT"), "LIST_DIR_CURRENT", "parameterless list selected"
call AssertEq p~at("COMPLETE"), 1, "parameterless list complete"

p = parser~parse("list directory in src/lib")
call AssertEq p~at("INTENT"), "LIST_DIR_PATH", "slot evidence selects path recipe"
call AssertEq p~at("SLOTS")~at("PATH"), "src/lib", "path slot"
call AssertEq p~at("COMPLETE"), 1, "path list complete"

p = parser~parse("create a class")
call AssertEq p~at("INTENT"), "OOREXX_CREATE_CLASS", "missing-slot intent still identified"
call AssertEq p~at("COMPLETE"), 0, "missing required slot incomplete"
call AssertEq p~at("MISSING_SLOTS"), "CLASS_NAME", "missing required slot named"

p = parser~parse("creat a clas called TypoWidget")
call AssertEq p~at("INTENT"), "OOREXX_CREATE_CLASS", "soundex concept intent"
call AssertEq p~at("SEMANTIC")~at("ACTION")~at("CONCEPT"), "CREATE", "soundex action concept"
call AssertEq p~at("SEMANTIC")~at("OBJECT")~at("CONCEPT"), "CLASS", "soundex object concept"

if failures = 0 then do
  say "PASS dev2 semantic qualification"
  exit 0
end

say "FAIL dev2 semantic qualification failures=" failures
exit 1

AssertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then say "PASS" label
  else do
    say "FAIL" label
    say "  actual  :" actual
    say "  expected:" expected
    failures = failures + 1
  end
  return

::requires "../src/SymbolicNLP.cls"
