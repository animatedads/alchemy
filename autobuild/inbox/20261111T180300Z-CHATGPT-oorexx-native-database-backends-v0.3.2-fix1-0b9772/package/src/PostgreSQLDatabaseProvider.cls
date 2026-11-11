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
  -- SSC_DB_* and SSC_POSTGRESQL_BRIDGE are the deployment names already
  -- qualified by the ed209i dev23 selector smoke. Standard libpq variables
  -- remain accepted aliases for non-SSC consumers.
  host = self~optionAlias(options, "host", "SSC_DB_HOST", "PGHOST", "localhost")
  portText = self~optionAlias(options, "port", "SSC_DB_PORT", "PGPORT", "5432")
  databaseName = self~optionAlias(options, "database", "SSC_DB_NAME", "PGDATABASE", "")
  userName = self~optionAlias(options, "user", "SSC_DB_USER", "PGUSER", "")
  password = self~optionAlias(options, "password", "SSC_DB_PASSWORD", "PGPASSWORD", "")
  bridgePath = self~optionAlias(options, "bridge", "SSC_POSTGRESQL_BRIDGE", "OOREXX_POSTGRES_BRIDGE", "libpq.bridge.json")

  credential = .nil
  if password \= "" then credential = .DatabaseCredential~new("password", password)
  connection = .DatabaseConnection~new(host, portText, databaseName, userName, credential, "postgresql")
  backend = .PostgreSQLNativeBackend~new(bridgePath)
  return backend~database(connection)

::method optionAlias class private
  use strict arg options, key, primaryEnvironmentName, fallbackEnvironmentName, defaultValue = ""
  if options \== .nil then do
    if options~hasIndex(key) then return options[key]~string
    upperKey = key~translate
    if options~hasIndex(upperKey) then return options[upperKey]~string
  end
  environmentValue = value(primaryEnvironmentName, , "ENVIRONMENT")
  if environmentValue \== .nil & environmentValue \= "" then return environmentValue~string
  environmentValue = value(fallbackEnvironmentName, , "ENVIRONMENT")
  if environmentValue \== .nil & environmentValue \= "" then return environmentValue~string
  return defaultValue

::requires "PostgreSQLNativeBackend.cls"
