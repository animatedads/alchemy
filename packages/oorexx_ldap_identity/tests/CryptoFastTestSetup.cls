/* Qualification-only acceleration. Production has no dependency on this.
 * Uses Crypto v0.8.3's own Runtime Reference / Foreign Runtime provider seam
 * so semantic SHA-256 identities are still computed by the qualified Crypto
 * API, not by a private test hash implementation.
 */
::class LdapIdentityCryptoFastTestSetup
::method init class
  .CryptoForeignRuntimeInstaller~install
::requires "CryptoForeignRuntimeProvider.cls"
