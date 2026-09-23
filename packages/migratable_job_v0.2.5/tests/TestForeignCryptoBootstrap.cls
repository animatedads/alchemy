::routine mj_test_install_native_crypto public
  direct=value("MIGRATABLE_JOB_CRYPTO_DIRECT_BRIDGE",,"ENVIRONMENT")
  compat=value("MIGRATABLE_JOB_CRYPTO_COMPAT_BRIDGE",,"ENVIRONMENT")
  if direct="" | compat="" then raise syntax 88.900 array("Foreign Runtime Crypto bridge paths required for Migratable Job qualification")
  if .CryptoLibraryBuild~referenceSwitch == .nil then
    ignore=.CryptoForeignRuntimeInstaller~install(direct,.nil,1000,"foreign.openssl.crypto",compat)
  return .true
::requires "CryptoForeignRuntimeProvider.cls"
