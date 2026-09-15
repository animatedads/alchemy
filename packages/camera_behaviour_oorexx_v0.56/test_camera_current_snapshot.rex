/* Immutable current-condition materialization snapshot tests for CameraCore.cls */

say 'CAMERA CURRENT SNAPSHOT SMOKE START'

condition = .CameraCurrentCondition~new(4500, .CameraConstant~DAY_WEEKDAY, 300)
condition~transitionCount = 7
condition~uniqueTransitionCount = 3
condition~empiricalEntropyBits = 1.25
condition~baselineEntropyBits = 0.75
condition~averageContextSurpriseBits = 2.5
condition~excessSurpriseBits = 1.75
condition~dominantTransitionId = 'MT2>MT7'
condition~dominantTransitionShare = 0.6
condition~baselineContext = 'DAY:' || .CameraConstant~DAY_WEEKDAY
condition~metricAssessmentCount = 5
condition~usableMetricCount = 2
condition~elevatedMetricCount = 1
condition~strongestMetricName = 'TRACK_RATE'
condition~strongestMetricZ = 3.5
condition~trendingMetricCount = 1
condition~strongestTrendMetricName = 'INTERACTION_RATE'
condition~strongestTrendDelta = 2.2
condition~persistencePhase = .CameraConstant~CONDITION_PHASE_PERSISTENT
condition~shiftedStreak = 4
condition~expectedStreak = 0
condition~phaseStartSecond = 4400
condition~activeRegimeId = 'CR7'
condition~state = .CameraConstant~CONDITION_SHIFTED

trackSignal = .CameraConditionMetricSignal~new('TRACK_RATE')
trackSignal~sampleCount = 3
trackSignal~averageZ = 3.5
trackSignal~maximumAbsoluteZ = 4.1
trackSignal~firstZ = 2.7
trackSignal~lastZ = 3.8
trackSignal~trendDelta = 1.1
trackSignal~trendState = .CameraConstant~TREND_STABLE
trackSignal~elevated = .true
trackSignal~baselineContext = 'DAY:' || .CameraConstant~DAY_WEEKDAY
condition~addMetricSignal(trackSignal)

interactionSignal = .CameraConditionMetricSignal~new('INTERACTION_RATE')
interactionSignal~sampleCount = 2
interactionSignal~averageZ = 1.2
interactionSignal~maximumAbsoluteZ = 2.3
interactionSignal~firstZ = 0.1
interactionSignal~lastZ = 2.3
interactionSignal~trendDelta = 2.2
interactionSignal~trendState = .CameraConstant~TREND_RISING
interactionSignal~elevated = .false
interactionSignal~baselineContext = 'ALL'
condition~addMetricSignal(interactionSignal)

snapshot = condition~snapshot
canonicalBefore = snapshot~canonicalText

call assertEqual 'snapshot version', .CameraConstant~CURRENT_CONDITION_SNAPSHOT_VERSION, snapshot~version
call assertEqual 'state copied', condition~state, snapshot~state
call assertEqual 'phase copied', condition~persistencePhase, snapshot~persistencePhase
call assertEqual 'active regime copied', 'CR7', snapshot~activeRegimeId
call assertEqual 'signal count', 2, snapshot~metricSignals~items
call assertEqual 'track signal frozen value', 3.5, snapshot~metricSignal('TRACK_RATE')~averageZ
call assertTrue 'canonical signal ordering', pos('SIGNAL=INTERACTION_RATE', canonicalBefore) < pos('SIGNAL=TRACK_RATE', canonicalBefore)

/* Mutating the live condition and its signal must not mutate the materialized snapshot. */
condition~strongestMetricZ = 99
condition~activeRegimeId = 'CR99'
trackSignal~averageZ = 88
trackSignal~lastZ = 88
call assertEqual 'snapshot scalar immutable by copy', 3.5, snapshot~strongestMetricZ
call assertEqual 'snapshot regime immutable by copy', 'CR7', snapshot~activeRegimeId
call assertEqual 'snapshot signal immutable by copy', 3.5, snapshot~metricSignal('TRACK_RATE')~averageZ
call assertEqual 'canonical content stable after source mutation', canonicalBefore, snapshot~canonicalText

/* A logically identical condition with reverse signal insertion order must canonicalize identically. */
condition2 = .CameraCurrentCondition~new(4500, .CameraConstant~DAY_WEEKDAY, 300)
call copyConditionScalars snapshot, condition2
condition2~addMetricSignal(copySignal(snapshot~metricSignal('INTERACTION_RATE')))
condition2~addMetricSignal(copySignal(snapshot~metricSignal('TRACK_RATE')))
snapshot2 = condition2~snapshot
call assertEqual 'canonical content independent of directory insertion order', canonicalBefore, snapshot2~canonicalText

say '  canonical bytes:' length(canonicalBefore)
say 'CAMERA CURRENT SNAPSHOT SMOKE: OK'
exit 0

copyConditionScalars: procedure
  use arg source, target
  target~transitionCount = source~transitionCount
  target~uniqueTransitionCount = source~uniqueTransitionCount
  target~empiricalEntropyBits = source~empiricalEntropyBits
  target~baselineEntropyBits = source~baselineEntropyBits
  target~averageContextSurpriseBits = source~averageContextSurpriseBits
  target~excessSurpriseBits = source~excessSurpriseBits
  target~dominantTransitionId = source~dominantTransitionId
  target~dominantTransitionShare = source~dominantTransitionShare
  target~baselineContext = source~baselineContext
  target~metricAssessmentCount = source~metricAssessmentCount
  target~usableMetricCount = source~usableMetricCount
  target~elevatedMetricCount = source~elevatedMetricCount
  target~strongestMetricName = source~strongestMetricName
  target~strongestMetricZ = source~strongestMetricZ
  target~trendingMetricCount = source~trendingMetricCount
  target~strongestTrendMetricName = source~strongestTrendMetricName
  target~strongestTrendDelta = source~strongestTrendDelta
  target~persistencePhase = source~persistencePhase
  target~shiftedStreak = source~shiftedStreak
  target~expectedStreak = source~expectedStreak
  target~phaseStartSecond = source~phaseStartSecond
  target~activeRegimeId = source~activeRegimeId
  target~state = source~state
  return

copySignal: procedure
  use arg source
  signal = .CameraConditionMetricSignal~new(source~name)
  signal~sampleCount = source~sampleCount
  signal~averageZ = source~averageZ
  signal~maximumAbsoluteZ = source~maximumAbsoluteZ
  signal~firstZ = source~firstZ
  signal~lastZ = source~lastZ
  signal~trendDelta = source~trendDelta
  signal~trendState = source~trendState
  signal~elevated = source~elevated
  signal~baselineContext = source~baselineContext
  return signal

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected: true'
  say '  actual:  ' actual
  exit 1

::requires 'CameraCore.cls'
