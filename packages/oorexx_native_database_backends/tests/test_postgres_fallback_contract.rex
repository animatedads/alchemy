b=.PostgreSQLProcessFallbackBackend~new
call assert b~implementationKind=.NativeDatabaseImplementationKind~PROCESS_BRIDGE, "fallback kind"
call assert b~supports("TRANSACTIONS"), "fallback transactions"
call assert \b~supports("COPY_STREAMING"), "fallback COPY limitation"
call assert b~commandExecutor~isA(.DatabaseProcessCommandExecutor), "uses existing Database Core process executor"
say "POSTGRESQL PROCESS FALLBACK CONTRACT: PASS available=" b~available
exit 0
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "PostgreSQLProcessFallbackBackend.cls"
