ctl=.StateOfNationController~new
watch=.StateProgressWatcher~new(ctl,"emulator",2)
call assertFalse watch~poll,"first missing progress poll does not stall"
call assertTrue watch~poll,"second missing progress poll detects stall"
ctl~noteProgress("emulator",1)
call assertFalse watch~poll,"new progress resets stall counter"
call assertFalse watch~poll,"first unchanged poll is below threshold"
call assertTrue watch~poll,"second unchanged poll detects stall"
ctl~noteProgress("emulator",2)
call assertFalse watch~poll,"progress token advance clears stall"
say "PASS test_progress_watcher"
exit 0

::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)

::routine assertFalse
  use strict arg actual,label
  if actual then raise syntax 88.900 array("ASSERT_FALSE",label)

::requires "src/JournalPointedState.cls"
