source = .MinimalSource~new
report = .DatabaseSourceConformanceSuite~new~run(source)

call assert report~failed = 0, "minimal source should not fail"
call assert report~skipped = 1, "table discovery should skip"
call assert report~ok, "minimal source still conforms"

say "DATABASE SOURCE CONFORMANCE SKIP SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class MinimalSource public
::method identity
  return .DatabaseSourceIdentity~new(.DatabaseSourceKind~DATABASE, "generic", "minimal")
::method capabilities
  return .DatabaseCapabilities~new
::method supports
  use arg capability
  return .false

::requires "database_core.cls"
