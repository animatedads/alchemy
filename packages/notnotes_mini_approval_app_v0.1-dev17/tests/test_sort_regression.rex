/* Native 10,000-document sort regression without persistence side effects.
 * Uses the actual MiniNotesApp~sortByKey method through a subclass that
 * bypasses application startup and therefore needs no SQLite function pkg.
 */
sorter = .SortHarness~new
docs = .Array~new
do i = 10000 to 1 by -1
  key = "NN-" || i~right(7,"0")
  docs~append(.SortFixtureDocument~new(key, i))
end
/* Include repeated keys: every distinct object must survive the bucket sort. */
docs~append(.SortFixtureDocument~new("NN-0000100", 10001))
docs~append(.SortFixtureDocument~new("NN-0000100", 10002))
timer = .StopWatch~new
timer~start
sorted = sorter~sortByKey(docs)
timer~stop
if sorted~items \= 10002 then raise syntax 93.900 array("Document count changed in native sort")
previous = ""
duplicateCount = 0
do document over sorted
  if previous \= "" then do
    if document~DocKey < previous then -
      raise syntax 93.900 array("Non-monotone sort key:" document~DocKey previous)
  end
  if document~DocKey = "NN-0000100" then duplicateCount += 1
  previous = document~DocKey
end
if duplicateCount \= 3 then -
  raise syntax 93.900 array("Duplicate key objects dropped:" duplicateCount)
say "NOTNOTES_NATIVE_SORT_PASS docs=" sorted~items "elapsed=" timer~elapsed
exit 0

::class SortHarness subclass MiniNotesApp
::method init
  nop

::class SortFixtureDocument
::method init
  expose key serial
  use arg key, serial
::method DocKey
  expose key
  return key
::method serial
  expose serial
  return serial

::requires 'src/MiniNotesApp.cls'
