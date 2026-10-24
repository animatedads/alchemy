/*
 * DatabaseBackendSelector.cls - runtime provider package selection.
 *
 * This package deliberately requires neither NoSQLServer.cls nor database_core.cls.
 * It loads only the configured provider package and does not import that package's
 * public classes into the caller package.  This is the class-name isolation boundary
 * required when providers publish overlapping names such as DatabaseRow/DatabaseResult.
 *
 * Provider contract:
 *   provider class (or provider instance) implements open(options)
 *
 * Selection options (Directory keys; upper-case aliases are accepted):
 *   provider - logical provider id
 *   package  - package path/name to load
 *   class    - public provider class in that package
 *
 * Environment fallbacks:
 *   OOREXX_DATABASE_PROVIDER
 *   OOREXX_DATABASE_PROVIDER_PACKAGE
 *   OOREXX_DATABASE_PROVIDER_CLASS
 *
 * Built-in provider defaults:
 *   NOSQLSERVER -> NoSQLDatabaseCoreProvider.cls / NoSQLDatabaseCoreProvider
 *   POSTGRESQL  -> PostgreSQLDatabaseProvider.cls / PostgreSQLDatabaseProvider
 */
::class DatabaseBackendSelectionError public
::attribute message
::method init
  use strict arg message
  self~message = message
::method string
  return self~message

::class DatabaseBackendSelector public
::attribute selectedProvider
::attribute selectedPackage
::attribute selectedClass

::method init
  self~selectedProvider = ""
  self~selectedPackage = .nil
  self~selectedClass = .nil

::method open
  use arg options = .nil
  providerClass = self~providerClass(options)
  if providerClass~isA(.DatabaseBackendSelectionError) then return providerClass

  if providerClass~hasMethod("OPEN") then
    return providerClass~open(options)

  signal on syntax name instantiateFailed
  provider = providerClass~new
  signal off syntax
  if \provider~hasMethod("OPEN") then
    return .DatabaseBackendSelectionError~new("Selected database provider does not implement open(options)")
  return provider~open(options)

instantiateFailed:
  conditionObj = condition("O")
  message = "Unable to instantiate selected database provider"
  if conditionObj \== .nil then do
    description = conditionObj["DESCRIPTION"]
    if description \== .nil then message ||= ": " || description
  end
  return .DatabaseBackendSelectionError~new(message)

::method providerClass
  use arg options = .nil
  spec = self~resolve(options)
  if spec~isA(.DatabaseBackendSelectionError) then return spec

  packageName = spec["package"]
  className = spec["class"]
  providerName = spec["provider"]

  signal on syntax name loadFailed
  loadedPackage = .context~package~loadPackage(packageName)
  signal off syntax

  providerClass = loadedPackage~findPublicClass(className)
  if providerClass == .nil then
    return .DatabaseBackendSelectionError~new("Selected database provider class '" || className || "' is not public in package '" || packageName || "'")

  self~selectedProvider = providerName
  self~selectedPackage = loadedPackage
  self~selectedClass = providerClass
  return providerClass

loadFailed:
  conditionObj = condition("O")
  message = "Unable to load selected database provider package '" || packageName || "'"
  if conditionObj \== .nil then do
    description = conditionObj["DESCRIPTION"]
    if description \== .nil then message ||= ": " || description
  end
  return .DatabaseBackendSelectionError~new(message)

::method resolve
  use arg options = .nil
  if options == .nil then options = .directory~new

  providerName = self~option(options, "provider", "OOREXX_DATABASE_PROVIDER")~strip
  packageName = self~option(options, "package", "OOREXX_DATABASE_PROVIDER_PACKAGE")~strip
  className = self~option(options, "class", "OOREXX_DATABASE_PROVIDER_CLASS")~strip

  if providerName = "" then providerName = "NOSQLSERVER"
  providerKey = providerName~translate

  select
    when providerKey = "NOSQL" | providerKey = "NOSQLSERVER" then do
      providerName = "NOSQLSERVER"
      if packageName = "" then packageName = "NoSQLDatabaseCoreProvider.cls"
      if className = "" then className = "NoSQLDatabaseCoreProvider"
    end
    when providerKey = "POSTGRES" | providerKey = "POSTGRESQL" then do
      providerName = "POSTGRESQL"
      if packageName = "" then packageName = "PostgreSQLDatabaseProvider.cls"
      if className = "" then className = "PostgreSQLDatabaseProvider"
    end
    otherwise do
      if packageName = "" then
        return .DatabaseBackendSelectionError~new("Database provider '" || providerName || "' requires package configuration")
      if className = "" then
        return .DatabaseBackendSelectionError~new("Database provider '" || providerName || "' requires class configuration")
    end
  end

  spec = .directory~new
  spec["provider"] = providerName
  spec["package"] = packageName
  spec["class"] = className
  return spec

::method option private
  use strict arg options, key, environmentName
  if options \== .nil then do
    if options~hasIndex(key) then return options[key]~string
    upperKey = key~translate
    if options~hasIndex(upperKey) then return options[upperKey]~string
  end
  environmentValue = value(environmentName, , "ENVIRONMENT")
  if environmentValue == .nil then return ""
  return environmentValue~string
