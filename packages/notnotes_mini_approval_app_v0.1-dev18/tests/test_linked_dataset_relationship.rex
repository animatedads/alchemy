root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
app = .MiniNotesApp~new(root)

call assertEqual "TPS Report", app~relationshipTarget("TPS Report Review", "TheTPSReport"), "relationship metadata loaded"
review = .nil
do document over app~allDocuments
  if document~formName = "TPS Report Review" then do
    review = document
    leave
  end
end
call assertTrue review \== .nil, "review exists"
refKey = review~field("TheTPSReport")
call assertTrue refKey \== .nil, "review reference value exists"
target = app~referencedDocument(review, "TheTPSReport")
call assertTrue target \== .nil, "review reference resolves"
call assertEqual "TPS Report", target~formName, "review resolves to TPS Report"
call assertEqual refKey~string, target~DocKey~string, "stored reference is stable DocKey"
call assertEqual 0, app~subviewDefinitionNames~items, "supplied dataset has no persisted subviews"
ignore = app~persistNow

app2 = .MiniNotesApp~new(root)
call assertEqual "TPS Report", app2~relationshipTarget("TPS Report Review", "TheTPSReport"), "relationship survives save/reload"
review2 = app2~byKey(review~DocKey)
call assertTrue review2 \== .nil, "review survives reload"
target2 = app2~referencedDocument(review2, "TheTPSReport")
call assertTrue target2 \== .nil, "reference resolves after reload"
call assertEqual target~DocKey, target2~DocKey, "same target after reload"
say "PASS linked TPS dataset relationship metadata / save / reload"
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires 'src/MiniNotesApp.cls'
::requires 'src/MiniNotesPersistence.cls'
