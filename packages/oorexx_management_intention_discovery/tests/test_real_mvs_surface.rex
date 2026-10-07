/* Proves Management discovers and delegates to the real MVS Intention Runner
 * rather than carrying MVS keywords or operations itself. */

runner = .MvsIntentionRunner~new('ED209Z', .MvsFixtureDiscoveryBackend~new)
source = .ManagementMvsIntentionSurfaceSource~new(runner)
directory = .ManagementIntentionDirectory~new
directory~registerSource(source)

snapshot = directory~discover(.Directory~new)
call assertEqual 1, snapshot~entries~items, 'MVS surface discovered'
surface = snapshot~entries[1]~surface
call assertEqual 'mvs.intention.runner/0.1-dev3', surface['provider'], 'real MVS runner projected'
call assertEqual 5, surface['operations']~items, 'current MVS registrations projected'
call assertTrue surface['runner'] == runner, 'runner object preserved'
call assertTrue surface['snapshot']~isA(.MvsDiscoverySnapshot), 'MVS discovery snapshot preserved'
call assertTrue surface['snapshot']~probeCount > 0, 'MVS safe discovery executed'

resolution = directory~resolve('show jobs', .Directory~new)
call assertEqual 1, resolution~relevantCandidates~items, 'MVS runner owns relevance decision'
candidate = resolution~relevantCandidates[1]
call assertEqual 'mvs', candidate~entry~sourceId, 'MVS source selected'
call assertTrue candidate~assessment~evidence~status \== 'UNKNOWN', 'MVS Intention decision retained as evidence'
call assertEqual 'LIST_JOBS', candidate~assessment~evidence~registration~id, 'actual MVS intention selected'

unknown = directory~resolve('calculate the orbit of jupiter', .Directory~new)
call assertEqual 0, unknown~relevantCandidates~items, 'non-MVS request remains irrelevant'

say 'PASS test_real_mvs_surface'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
return

::requires '../src/ManagementIntentionDiscovery.cls'
::requires '../src/MvsIntentionSurfaceAdapter.cls'
::requires '../vendor/mvs-intentions/MvsIntention.cls'
