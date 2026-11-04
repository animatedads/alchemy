/* Run this before any database mutation. */
numeric digits 18
parse arg csvPath expectedCount
if expectedCount = '' then expectedCount = 9096
if csvPath = '' then do
  say 'Usage: rexx bsc5_preflight.rex SOURCE.csv [EXPECTED_ROWS]'
  exit 2
end
report = .MoonsaultBSC5Validator~new~scan(csvPath, expectedCount)
say 'MOONSAULT BSC5 PREFLIGHT'
say 'Rows:' report['count']
say 'HIP missing:' report['missingHIP']
say 'B-V missing:' report['missingBV']
say 'Distance missing:' report['missingDistance']
say 'Proper name missing:' report['missingName']
if \report['ok'] then do
  do problem over report['errors']
    say 'REJECT:' problem
  end
  exit 1
end
say 'PASS: CSV structure, numerical coordinates and unique HD/HIP identifiers'
say 'NOT VALIDATED: proper motion, precession, ephemerides or geolocation'
exit 0
::requires 'MoonsaultBSC5Validator.cls'
