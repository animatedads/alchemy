/* Verify the exact user-authoritative wall-clock mapping for the four-file
 * 2023-10-10 00:00--05:00 FD night campaign. */
call assertEq .FDWallClock~differenceMs('2023-10-09T22:20:05','2023-10-10T00:00:00'),5995000,'tp0 analysis start'
call assertEq .FDWallClock~differenceMs('2023-10-10T00:23:59','2023-10-10T05:00:00'),16561000,'tp1 05:00 offset'
call assertEq .FDWallClock~differenceMs('2023-10-10T03:01:55','2023-10-10T03:12:00'),605000,'tp2 exclusion start'
call assertEq .FDWallClock~differenceMs('2023-10-10T03:01:55','2023-10-10T03:28:00'),1565000,'tp2 exclusion end'
call assertEq .FDWallClock~differenceMs('2023-10-10T03:35:44','2023-10-10T05:00:00'),5056000,'tp3 analysis end'

cfg=.FDDoorMicroMotionConfig~nightF11
cfg~setWallWindow('2023-10-10T03:01:55','2023-10-10T00:00:00','2023-10-10T05:00:00')
call assertEq cfg~analysisStartMs,0,'tp2 clamped analysis start'
call assertEq cfg~analysisEndMs,7085000,'tp2 analysis end'
cfg~addWallExclusion('FDX-POLICE-F11','2023-10-10T03:12:00','2023-10-10T03:28:00','USER_DECLARED_SCENE_OCCLUSION')
if cfg~exclusions~items<>1 then call fail 'tp2 exclusion count'
call assertEq cfg~exclusions[1]~startMs,605000,'tp2 config exclusion start'
call assertEq cfg~exclusions[1]~endMs,1565000,'tp2 config exclusion end'
round=.FDDoorMicroMotionConfig~fromCompactText(cfg~compactText)
if round~compactText<>cfg~compactText then call fail 'compact config round trip'

say 'PASS wall clock campaign mapping tp0_start_ms=5995000 tp2_exclusion=605000..1565000 tp3_end_ms=5056000'
exit 0

assertEq: procedure
  use arg actual,expected,label
  if actual<>expected then call fail label||' actual='||actual||' expected='||expected
  return
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
