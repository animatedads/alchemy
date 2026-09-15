suite = .DatabaseSourceConformanceSuite~new

r1 = suite~run(.BadIdentitySource~new)
call assert r1~failed > 0, "bad identity should fail"

r2 = suite~run(.BadDiscoverySource~new)
call assert r2~failed > 0, "bad discovery should fail"

say "DATABASE SOURCE CONFORMANCE FAILURE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class BadIdentitySource public
::method identity
  return .nil
::method capabilities
  return .DatabaseCapabilities~new
::method supports
  use arg capability
  return .false

::class BadDiscoverySource public
::method identity
  return .DatabaseSourceIdentity~new(.DatabaseSourceKind~DATABASE, "mysql", "bad")
::method capabilities
  caps = .DatabaseCapabilities~new
  caps~add(.DatabaseCapability~TABLEDISCOVERY)
  return caps
::method supports
  use arg capability
  return capability = .DatabaseCapability~TABLEDISCOVERY
::method tables
  return "not-an-array"

::requires "database_core.cls"
