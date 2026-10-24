/*
 * PostgreSQL provider for DatabaseBackendSelector.
 *
 * This provider package may load Database Core because it is loaded only when
 * POSTGRESQL is selected. The neutral selector package never imports these
 * classes into its own package namespace.
 */
::class PostgreSQLDatabaseProvider public

::method open class
  use arg options = .nil
  host = self~option(options, "host", "PGHOST", "localhost")
  portText = self~option(options, "port", "PGPORT", "5432")
  databaseName = self~option(options, "database", "PGDATABASE", "")
  userName = self~option(options, "user", "PGUSER", "")
  password = self~option(options, "password", "PGPASSWORD", "")
  bridgePath = self~option(options, "bridge", "OOREXX_POSTGRES_BRIDGE", "libpq.bridge.json")

  credential = .nil
  if password \= "" then credential = .DatabaseCredential~new("password", password)
  connection = .DatabaseConnection~new(host, portText, databaseName, userName, credential, "postgresql")
  backend = .PostgreSQLNativeBackend~new(bridgePath)
  return backend~database(connection)

::method option class private
  use strict arg options, key, environmentName, defaultValue = ""
  if options \== .nil then do
    if options~hasIndex(key) then return options[key]~string
    upperKey = key~translate
    if options~hasIndex(upperKey) then return options[upperKey]~string
  end
  environmentValue = value(environmentName, , "ENVIRONMENT")
  if environmentValue == .nil | environmentValue = "" then return defaultValue
  return environmentValue~string

::requires "PostgreSQLNativeBackend.cls"
