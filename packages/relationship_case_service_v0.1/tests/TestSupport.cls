::class RelationshipCaseServiceTestSupport public
::method assertTrue class
  use arg condition, detail = "assertTrue"
  if \condition then do; say "FAIL:" detail; exit 1; end
  return .true
::method assertEqual class
  use arg expected, actual, detail = "assertEqual"
  if expected <> actual then do; say "FAIL:" detail "expected=" expected "actual=" actual; exit 1; end
  return .true
