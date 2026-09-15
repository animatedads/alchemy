/* Test-only plugin proving hard dispositions cannot be outweighed by scores. */
::class RYTATestExtremeScoringPlugin public
::attribute actionCode
::attribute amount

::method init
  use arg actionCode, amount
  self~actionCode = actionCode
  self~amount = amount

::method pluginVersion
  return '0.2'

::method pluginKind
  return 'SCORE'

::method pluginId
  return 'TEST_EXTREME_SCORING'

::method canonicalConfiguration
  return 'TEST_EXTREME_SCORING|version=' || self~pluginVersion || '|action=' || self~actionCode || '|amount=' || self~amount

::method score
  use arg world, actionCode
  if actionCode == self~actionCode then return self~amount
  return 0
