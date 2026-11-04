/*
 * NoSQLServer Database Core-compatible provider for DatabaseBackendSelector.
 *
 * This package is loaded only when NOSQLSERVER is selected. It deliberately
 * keeps NoSQLServer's overlapping Database* public classes in this provider
 * package and returns the existing namespaced Database Core compatibility facade.
 */
::class NoSQLDatabaseCoreProvider public

::method open class
  use arg options = .nil
  root = self~option(options, "root", "OOREXX_NOSQL_ROOT")
  if root = "" then root = self~option(options, "databaseRoot", "SSC_DATABASE_ROOT")
  if root = "" then return .NoSQLDatabaseProviderError~new("NoSQLServer provider requires a database root")
  return .FileDatabaseEngine~new(root)~databaseCore

::method openNative class
  use arg options = .nil
  root = self~option(options, "root", "OOREXX_NOSQL_ROOT")
  if root = "" then root = self~option(options, "databaseRoot", "SSC_DATABASE_ROOT")
  if root = "" then return .NoSQLDatabaseProviderError~new("NoSQLServer provider requires a database root")
  return .FileDatabaseEngine~new(root)

::method option class private
  use strict arg options, key, environmentName
  if options \== .nil then do
    if options~hasIndex(key) then return options[key]~string
    upperKey = key~translate
    if options~hasIndex(upperKey) then return options[upperKey]~string
  end
  environmentValue = value(environmentName, , "ENVIRONMENT")
  if environmentValue == .nil then return ""
  return environmentValue~string

::class NoSQLDatabaseProviderError public
::attribute message
::method init
  use strict arg message
  self~message = message
::method string
  return self~message

::requires "NoSQLServer.cls"
