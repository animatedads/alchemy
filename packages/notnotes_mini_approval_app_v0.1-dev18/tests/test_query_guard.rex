app = .MiniNotesApp~new
app~seedFive

call assertCount 0, app~query("nonexistent"), "bare absent term"
call assertCount 0, app~query("purchase nonexistent"), "mixed absent term"
call assertCount 0, app~query("lunar base not present"), "multiword absent terms"
call assertCount 2, app~query("gpu"), "free text finds both GPU documents"
call assertCount 1, app~query("purchase gpu"), "type plus free text"
call assertCount 1, app~query("security gpu"), "security plus free text"
call assertCount 1, app~viewDocuments("release pending"), "release view is not all-documents fallback"
call assertCount 0, app~viewDocuments("purchase rejected"), "purchase view subset no rows"

say "PASS test_query_guard"
exit 0

assertCount: procedure
  use arg expected, documents, label
  actual = documents~items
  if expected = actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::requires 'src/MiniNotesApp.cls'
