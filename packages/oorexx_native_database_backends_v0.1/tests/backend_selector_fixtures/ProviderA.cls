::class DatabaseRow public
::method source
  return "A"

::class BackendProviderA public
::method open class
  use arg options = .nil
  return .DatabaseRow~new
