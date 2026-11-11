::class DatabaseRow public
::method source
  return "B"

::class BackendProviderB public
::method open
  use arg options = .nil
  return .DatabaseRow~new
