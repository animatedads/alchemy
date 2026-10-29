root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
if root = "" then root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
app = .MiniNotesApp~new(root)
ui = .MiniNotesCliUi~new(app)

ui~executeCommand("create a new document format called TPS Report")
ui~executeCommand("I need a field for the TPS Number")
ui~executeCommand("I need a user")
ui~executeCommand("I need a field for the Cost")
ui~executeCommand("SAVE")

fields = app~userFormatFields("TPS Report")
values = .Directory~new
values["TPSNumber"] = "TPS-SEM-001"
values["User"] = "alice"
values["Cost"] = "42.50"
doc = app~createUserDocument("TPS Report", fields, values)
call assertTrue doc \== .nil, "TPS document created"

appModel = app~semanticApplicationProjection
call assertEqual "MININOTES.SEMANTIC_APPLICATION/1", appModel["CONTRACT"], "application contract"
call assertTrue findSurface(appModel["SURFACES"], "documents") \== .nil, "documents surface"
call assertTrue findSurface(appModel["SURFACES"], "approvals") \== .nil, "approvals surface"
formatSurface = findSurface(appModel["SURFACES"], "format:TPS Report")
call assertTrue formatSurface \== .nil, "dynamic format surface"
call assertEqual "DOCUMENT_FORMAT", formatSurface["KIND"], "format surface kind"
call assertEqual "Ask NotNotes", appModel["ENTRY_POINTS"][1]["LABEL"], "renderer-neutral intention entry"

range = app~semanticCollectionRange("format:TPS Report", 0, 25)
call assertEqual "MININOTES.SEMANTIC_COLLECTION/1", range["CONTRACT"], "collection contract"
call assertEqual 1, range["TOTAL"], "format collection total"
call assertEqual doc~documentId, range["ROWS"][1]["IDENTITY"], "stable row identity"
call assertEqual doc~DocKey, range["ROWS"][1]["KEY"], "row key"

projection = app~semanticDocumentProjection(doc)
call assertEqual "MININOTES.SEMANTIC_DOCUMENT/1", projection["CONTRACT"], "document contract"
call assertEqual "TPS Report", projection["FORM"], "document form"
numberField = findField(projection["FIELDS"], "TPSNUMBER")
call assertTrue numberField \== .nil, "TPS number field projected"
call assertEqual "the TPS Number", numberField["LABEL"], "field label preserved"
call assertEqual "IDENTIFIER", numberField["SEMANTIC_TYPE"], "field type preserved"
call assertTrue numberField["WRITABLE"], "field write capability preserved"

submitAction = findAction(projection["ACTIONS"], "SUBMIT")
call assertTrue submitAction \== .nil, "submit action projected"
call assertTrue submitAction["ENABLED"], "draft submit action enabled"
call assertTrue findAction(projection["ACTIONS"], "APPROVE")["ENABLED"] = .false, "draft approve disabled"

app~select(doc~DocKey)
call assertEqual "PENDING APPROVAL", app~submitSelected("semantic projection test"), "submit succeeds"
projection = app~semanticDocumentProjection(doc)
call assertTrue findAction(projection["ACTIONS"], "SUBMIT")["ENABLED"] = .false, "pending submit disabled"
call assertTrue findAction(projection["ACTIONS"], "APPROVE")["ENABLED"], "pending approve enabled"

approvals = app~semanticCollectionRange("approvals", 0, 100)
call assertEqual 1, approvals["TOTAL"], "approval surface follows live state"
call assertEqual doc~documentId, approvals["ROWS"][1]["IDENTITY"], "approval row stable identity"

call assertRangeRejected app

say "PASS Mini NotNotes renderer-neutral semantic application / document / action / bounded collection projection"
exit 0

findSurface: procedure
  use arg surfaces, wanted
  do item over surfaces
    if item["ID"] = wanted then return item
  end
  return .nil

findField: procedure
  use arg fields, wanted
  do item over fields
    if item["NAME"]~upper = wanted~upper then return item
  end
  return .nil

findAction: procedure
  use arg actions, wanted
  do item over actions
    if item["ID"] = wanted then return item
  end
  return .nil

assertRangeRejected: procedure
  use arg app
  signal on syntax name RangeRejected
  ignore = app~semanticCollectionRange("documents", 0, 101)
  signal off syntax
  say "FAIL collection range over 100 was accepted"
  exit 1
RangeRejected:
  say "Expected bounded-range rejection rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  return

assertEqual: procedure
  parse arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  parse arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::requires "src/MiniNotesCliUi.cls"
