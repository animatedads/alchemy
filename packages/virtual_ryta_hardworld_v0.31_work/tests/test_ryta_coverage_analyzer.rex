say 'RYTA COVERAGE ANALYZER START'

analyzer = .RYTACoverageAnalyzer~new
report = analyzer~analyzeCoreStateMatrix(.RYTAStateRules~new)

call assertEqual 'vectors', 64, report~totalVectors
call assertEqual 'holes', 0, report~holes
call assertEqual 'ambiguous winners', 0, report~ambiguousWinners
call assertEqual 'unreachable rules', 0, report~unreachableRules~items
call assertEqual 'shadowed rules', 0, report~shadowedRules~items
call assertEqual 'expected mismatches', 0, report~expectedMismatches
call assertEqual 'action disposition holes', 0, report~dispositionHoles
call assertEqual 'language issues', 0, report~invalidLanguageElements
call assertEqual 'coverage issues', 0, report~issues~items
call assertEqual 'relational lines header + 64 rows', 65, report~relationLines~items
call assertTrue 'raw overlaps are visible', report~overlapVectors > 0

say '  ' report~renderSummary
say 'RYTA COVERAGE ANALYZER: OK'
exit 0

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
  say '  actual:' actual
  exit 1

::requires '../RYTACoverage.cls'
