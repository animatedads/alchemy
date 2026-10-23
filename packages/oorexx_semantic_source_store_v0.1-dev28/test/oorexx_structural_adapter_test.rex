parse source . . here
root = filespec('L', here)
call testMain
exit 0

testMain:
  sample = "say 'boot'" || '0d0a'x ||,
           "" || '0d0a'x ||,
           "::options digits 20" || '0d0a'x ||,
           '::requires "Helper.cls"' || '0d0a'x ||,
           "::class HouseCat subclass Cat inherit Pet" || '0d0a'x ||,
           "::constant KIND cat" || '0d0a'x ||,
           "::attribute name" || '0d0a'x ||,
           "::method speak" || '0d0a'x ||,
           "  expose name" || '0d0a'x ||,
           "  return name" || '0d0a'x ||,
           "::method create class" || '0d0a'x ||,
           "  return .HouseCat~new" || '0d0a'x ||,
           "::routine helper public" || '0d0a'x ||,
           "  return 1" || '0d0a'x

  adapter = .SemanticSourceOorexxStructuralAdapter~new
  graph = adapter~parse(sample, "src/HouseCat.cls", "Cats")
  call assert graph~reconstruct == sample, "byte-exact reconstruction"
  call assert graph~sourceUnit["source_unit_kind"] == "PACKAGE_SOURCE", "package source kind"
  call assert graph~objects~items == 9, "expected 9 semantic source objects, got" graph~objects~items
  call assert graph~projectionMembers~items == graph~objects~items, "one projection member per source object"

  foundClass = 0; foundSpeak = 0; foundRoutine = 0; foundRequires = 0
  do object over graph~objects
    if object["object_kind"] == "CLASS" then do
      foundClass = 1
      call assert object["source_spelling"] == "HouseCat", "class source spelling"
      call assert object["class_tree"]~items == 2, "class tree size"
      call assert object["class_tree"][1] == "Cat", "subclass parent"
      call assert object["class_tree"][2] == "Pet", "inherited mixin"
    end
    if object["object_kind"] == "METHOD" & object["source_spelling"] == "speak" then do
      foundSpeak = 1
      call assert object["semantic_owner"] == "HouseCat", "method owner"
      call assert object["exposes"]~items == 1, "expose count"
      call assert object["exposes"][1] == "name", "exposed name"
      call assert object["return_expression"] == "name", "return expression"
    end
    if object["object_kind"] == "ROUTINE" then foundRoutine = 1
    if object["object_kind"] == "REQUIRES" then foundRequires = 1
  end
  call assert foundClass & foundSpeak & foundRoutine & foundRequires, "required semantic kinds present"
  say "OOREXX STRUCTURAL ADAPTER TEST: PASS"
  return

assert:
  use arg condition, message
  if \condition then do
    say "FAIL:" message
    exit 1
  end
  return

::requires "../src/SemanticSourceOorexxStructuralAdapter.cls"
