signal on syntax name expectedMissing
t = .StringTemplate~new("${missing}")
ignore = t~render(.Directory~new)
signal off syntax
say "FAIL strict missing did not raise"
exit 1

expectedMissing:
  say "EXPECTED SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  signal off syntax

signal on syntax name expectedMethod
obj = .Dangerous~new
ctx = .TemplateContext~new~put("object", obj)
t2 = .StringTemplate~new("${object.secret}")
ignore = t2~render(ctx)
signal off syntax
say "FAIL arbitrary object traversal did not raise"
exit 1

expectedMethod:
  say "EXPECTED SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  signal off syntax

signal on syntax name expectedParse
ignore = .StringTemplate~new("${unterminated")
signal off syntax
say "FAIL unterminated expression did not raise"
exit 1

expectedParse:
  say "EXPECTED SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  signal off syntax
  say "PASS test_fail_closed"
  exit 0

::class Dangerous public
::method secret
  return "should never be called without a TemplateObjectView allowlist"

::requires "StringTemplate.cls"
