/* Backend conformance template.
 * External/native adapters replace makeBackend() with their adapter.
 */
backend = makeBackend()
if backend == .nil then do
  say "BACKEND CONFORMANCE: NO BACKEND"
  exit 64
end

call assert backend~isA(.DatabaseBackendContract), "backend contract class"
call assert (backend~name <> ""), "backend name"
call assert backend~supports(.DatabaseCapability~TRANSACTIONS), "transactions"
call assert backend~supports(.DatabaseCapability~TYPEDRESULTS), "typed results"

say "BACKEND CONFORMANCE:" backend~name "OK"
exit 0

makeBackend: procedure
  return .PostgreSQLEngine~new

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
