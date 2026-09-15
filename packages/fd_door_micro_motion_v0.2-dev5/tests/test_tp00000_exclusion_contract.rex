/* Regression: TP00000 profile itself must carry no police-scene exclusion.
 * The 03:12--03:28 omission belongs only to TP00002 campaign job data. */
c=.FDDoorMicroMotionConfig~tp00000Night
if c~exclusions~items<>0 then call fail 'TP00000 profile has a hard-coded exclusion'
if c~exclusionAt(192000)<>.nil then call fail 'TP00000 wrongly excludes media 00:03:12'
if c~sampleEveryFrames<>1 then call fail 'TP00000 must analyse every eligible decoded frame'

c2=.FDDoorMicroMotionConfig~nightF11
c2~setWallWindow('2023-10-10T03:01:55','2023-10-10T00:00:00','2023-10-10T05:00:00')
e=c2~addWallExclusion('FDX-POLICE-F11','2023-10-10T03:12:00','2023-10-10T03:28:00','USER_DECLARED_SCENE_OCCLUSION')
if e==.nil then call fail 'TP00002 exclusion missing'
if e~startMs<>605000 | e~endMs<>1565000 then call fail 'TP00002 exclusion relative mapping wrong start='||e~startMs||' end='||e~endMs
if c2~exclusionAt(604999)<>.nil then call fail 'before TP00002 exclusion'
if c2~exclusionAt(605000)==.nil then call fail 'TP00002 exclusion start'
if c2~exclusionAt(1564999)==.nil then call fail 'TP00002 exclusion last millisecond'
if c2~exclusionAt(1565000)<>.nil then call fail 'TP00002 exclusion end must be exclusive'
say 'PASS exclusion scope TP00000=none TP00002=00:10:05..00:26:05 relative to 03:01:55 wall origin'
exit 0
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
