signal on syntax name expected
bad = .BrandNarrativeEvidenceReference~new("BAD-1", "LIBRARIAN_V2", "LIBRARIAN_EVENT:9", "VERIFIED", "2026-10-09T17:00:00Z", "DISPATCH")
say "FAIL external evidence authority escalation accepted"
exit 1
expected:
say "SYNTAX RC=" rc "SIGL=" sigl "CONDITION=" condition("C") "DESCRIPTION=" condition("D")
if condition("C") \== "SYNTAX" then do
  say "FAIL unexpected condition" condition("C")
  exit 1
end
say "PASS external evidence cannot acquire dispatch authority"
exit 0
::requires "BrandNarrativeDirective.cls"
