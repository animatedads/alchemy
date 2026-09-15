engines = .array~of(.PostgreSQLEngine~new, .MySQLEngine~new)
required = .array~of( -
  .DatabaseCapability~TRANSACTIONS, -
  .DatabaseCapability~SAVEPOINTS, -
  .DatabaseCapability~PREPAREDSTATEMENTS, -
  .DatabaseCapability~PREPAREDBATCH, -
  .DatabaseCapability~TYPEDRESULTS, -
  .DatabaseCapability~RESULTMETADATA, -
  .DatabaseCapability~RESULTSCHEMA, -
  .DatabaseCapability~MUTATIONRESULTS, -
  .DatabaseCapability~PREPAREDMUTATIONRESULTS, -
  .DatabaseCapability~TRANSACTIONRETRY, -
  .DatabaseCapability~TRANSACTIONREADONLY, -
  .DatabaseCapability~TRANSACTIONISOLATION, -
  .DatabaseCapability~TRANSACTIONTIMEOUT)

do engine over engines
  do capability over required
    call assert engine~supports(capability), engine~name || " missing " || capability
  end
end

say "DATABASE BACKEND CAPABILITY MATRIX SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
