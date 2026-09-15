::class BundleCapability subclass BundleBase public

::method runtimeSelfTest
  return self~version <> ""

::method value
  use arg requestId
  return self~version || ":" || requestId

::requires "BundleBase.cls"
