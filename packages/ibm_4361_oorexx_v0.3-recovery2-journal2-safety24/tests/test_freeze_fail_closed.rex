/* Unknown device codecs must not silently disappear from a checkpoint. */
m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IODevice~new(1,"MYSTERY")
m~attachDevice(d)
signal on syntax name expected
f=.IBM4361State~new~freeze(m)
say "FAIL freeze accepted device without explicit codec"
exit 1
expected:
  say "PASS test_freeze_fail_closed"
  exit 0

::requires "IBM4361State.cls"
