::routine fd_test_install_native_crypto public
  direct=value('FD_TEST_CRYPTO_DIRECT_BRIDGE',,'ENVIRONMENT')
  compat=value('FD_TEST_CRYPTO_COMPAT_BRIDGE',,'ENVIRONMENT')
  if direct='' | compat='' then return .false
  if .CryptoLibraryBuild~referenceSwitch == .nil then ignore=.CryptoForeignRuntimeInstaller~install(direct,.nil,1000,'foreign.openssl.crypto',compat)
  return .true
::requires 'CryptoForeignRuntimeProvider.cls'
