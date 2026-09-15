ccw=.IBM370CCW0~new("1F0052D560100001")
if ccw~commandCode<>x2d("1F") then raise syntax 40.900 array('bad command')
if ccw~reserved<>x2d("10") then raise syntax 40.900 array('format-0 ignored byte not preserved')
if ccw~count<>1 then raise syntax 40.900 array('bad count')
say 'PASS test_ccw0_ignored_byte'
::requires "IBM370IO.cls"
