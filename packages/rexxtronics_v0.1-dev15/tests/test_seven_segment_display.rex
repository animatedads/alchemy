/* Qualification: seven independent protected LED segments share one common
 * terminal and are solved electrically, rather than being a decorative digit.
 */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
d = c~add(.SevenSegmentDisplay~new('D1', 'COMMON_CATHODE', '1.7 V', '1 kOhm'))
c~connectGround(v~negative)
c~connectGround(d~common)
all = .array~new
all~append(v~positive)
do seg over d~segmentNames
  all~append(d~segmentPin(seg))
end
c~connect('VCC', all)
s = c~solveDC
if d~displayedDigit <> 8 then do; say 'FAIL: all segments should display 8'; exit 1; end
if d~litSegments~items <> 7 then do; say 'FAIL: expected seven lit segments'; exit 1; end
if d~segmentCurrent('A')~in(.Units~milliampere) < 3 then do; say 'FAIL: segment current too small'; exit 1; end
say 'REXX-TRONICS SEVEN SEGMENT DISPLAY: OK'
say 'digit:' d~displayedDigit
say 'segment A mA:' d~segmentCurrent('A')~in(.Units~milliampere)
exit 0
::requires 'RexxTronicsDisplays.cls'
