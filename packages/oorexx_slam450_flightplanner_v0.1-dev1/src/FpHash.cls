/* FpHash.cls - SLAM 450 Flight Planner v0.1: SHA-512 for evidence lines,
 * through the estate's crypto v0.8.3 with its Foreign Runtime / OpenSSL
 * provider (Tom Dyer, 10 Nov 2026: "you can hash using foreign runtime and
 * crypto. it already does it").
 *
 *   .FpHash~sha512(string)  -> lowercase hex digest
 *   .FpHash~provider        -> 'foreign.openssl.crypto', or 'native' when the
 *                              provider could not be installed
 *
 * The provider is installed once per process, on first use. If that fails
 * (no libcrypto, no Foreign Runtime build) crypto's own pure-ooRexx SHA-512
 * gives the same digest, about 2,000 times slower; crypto also falls back
 * per call if the provider fails or its result does not validate.
 * Measured 10 Nov 2026 in Claude's workspace: 96,600 bytes in 34.8 ms
 * through the provider, 81.6 s pure ooRexx; digest equal to sha512sum.
 *
 * Needs on REXX_PATH: oorexx_crypto_v0.8.3/src, runtime_reference_v0.4/src,
 * oorexx_foreign_runtime_v0.22.6/rexx; on LD_LIBRARY_PATH the Foreign
 * Runtime build and oorexx_crypto_v0.8.3/native (bin/fp_env.sh sets both).
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-10.
 */
::requires 'CryptoForeignRuntimeProvider.cls'

::class FpHash public
::method init class
  expose provider why
  provider = ''; why = ''

::method sha512 class
  expose provider
  use strict arg s
  if provider == '' then self~install
  return .CryptoHash~hashString(s, 'SHA512')

::method provider class
  expose provider
  if provider == '' then self~install
  return provider

/* why the provider is native, '' if it is not */
::method why class
  expose why
  return why

::method install class private
  expose provider why
  signal on syntax name failed
  .CryptoForeignRuntimeInstaller~install
  /* prove it on a known answer before trusting it */
  d = .CryptoHash~hashString('abc', 'SHA512')
  e = .RuntimeImplementationSwitch~broker~lastEvidence
  if d \== 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f' then do
    why = 'known-answer digest differs'
    signal off syntax; .CryptoLibraryBuild~referenceSwitch = .nil
    provider = 'native'; return
  end
  if e~providerId \== 'foreign.openssl.crypto' | e~outcomeCode \== 'COMPLETED' then do
    why = 'provider did not complete (' || e~providerId e~outcomeCode || ')'
    signal off syntax; .CryptoLibraryBuild~referenceSwitch = .nil
    provider = 'native'; return
  end
  provider = 'foreign.openssl.crypto'
  return
failed:
  why = condition('O')~message
  if why == .nil then why = 'install failed'
  .CryptoLibraryBuild~referenceSwitch = .nil
  provider = 'native'
  return
