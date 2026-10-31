/* Tombstone Sydney v0.17: strict native V5V observation receipt.
   Validates outputs of the repository's existing Vision/V5V script.
   No video decoding, classification, tracking or SLAM authority here. */
numeric digits 18
parse arg manlyFile earlierFile
if manlyFile='' | earlierFile='' then do
  say 'USAGE: rexx verify_v5v_full.rex manly.psv earlier.psv'
  exit 2
end
manlyHash='2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192'
earlierHash='6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb'
if \checkClip(manlyFile,manlyHash,156,'MANLY') then exit 3
if \checkClip(earlierFile,earlierHash,130,'EARLIER') then exit 4
say 'SYDNEY V5V FULL SOURCE QUALIFICATION PASS: 286 native indexed frames; NO TRACK OR SLAM PROMOTION'
exit 0

checkClip: procedure
 numeric digits 18
 use arg path,expectedHash,expectedFrames,label
 if stream(path,'c','query exists')='' then return fail('SOURCE FILE MISSING:' label)
 call stream path,'c','open read'
 header=linein(path)
 if header\=='frame|record|changed_cells|fraction|regions_ge3|ferry_palette_cells|roundtrip_exact|source_ref|evidence_state' then do
   call stream path,'c','close'
   return fail('HEADER MISMATCH:' label)
 end
 expectedSource='sha256:'||expectedHash
 count=0;keyframes=0;deltas=0;changedDelta=0;regionTotal=0;paletteTotal=0
 do while lines(path)>0
   record=linein(path)
   if record='' then do
     call stream path,'c','close'
     return fail('EMPTY ROW:' label)
   end
   if count>=expectedFrames then do
     call stream path,'c','close'
     return fail('UNEXPECTED EXTRA FRAME:' label)
   end
   separators=0
   do i=1 to length(record)
     if substr(record,i,1)='|' then separators=separators+1
   end
   if separators<>8 then do
     call stream path,'c','close'
     return fail('FIELD COUNT:' label)
   end
   parse var record frame '|' kind '|' changed '|' fraction '|' regions '|' palette '|' exact '|' source '|' state
   if \datatype(frame,'W') | \datatype(changed,'W') | \datatype(regions,'W') | \datatype(palette,'W') then do
     call stream path,'c','close'
     return fail('NON-INTEGER FIELD:' label)
   end
   if frame<>count | changed<0 | changed>3600 | regions<0 | regions>changed | palette<0 | palette>3600 then do
     call stream path,'c','close'
     return fail('FRAME OR MEASUREMENT BOUNDS:' label)
   end
   if \datatype(fraction,'N') then do
     call stream path,'c','close'
     return fail('NONNUMERIC FRACTION:' label)
   end
   if abs(fraction-changed/3600)>.0000001 then do
     call stream path,'c','close'
     return fail('CHANGED FRACTION MISMATCH:' label)
   end
   if exact\=='1' | source\==expectedSource | state\=='OBSERVED_UNTESTED' then do
     call stream path,'c','close'
     return fail('PROVENANCE/EXACTNESS/STATUS:' label)
   end
   if count//10=0 then do
     if kind\=='KEYFRAME' | changed<>3600 | regions<>0 then do
       call stream path,'c','close'
       return fail('KEYFRAME CADENCE/CONTENT:' label)
     end
     keyframes=keyframes+1
   end
   else do
     if kind\=='DELTA' then do
       call stream path,'c','close'
       return fail('DELTA CADENCE:' label)
     end
     deltas=deltas+1
     changedDelta=changedDelta+changed
   end
   regionTotal=regionTotal+regions
   paletteTotal=paletteTotal+palette
   count=count+1
 end
 call stream path,'c','close'
 if count<>expectedFrames then return fail('MISSING FRAME:' label)
 say label 'PASS frames='count 'keyframes='keyframes 'deltas='deltas 'delta_changed_cells='changedDelta 'regions_ge3='regionTotal 'palette_cells='paletteTotal 'evidence=OBSERVED_UNTESTED'
 return .true
fail: procedure
 use arg message
 say 'SYDNEY V5V FULL SOURCE QUALIFICATION FAIL:' message
 return .false
