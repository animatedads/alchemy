/* Load the real XTP dev18 ooRexx surface without performing network I/O. */
backend=.XtpSocketBackend~new
ignore=.LdapIdentityTest~assert(backend~hasMethod("MULTICASTSENDER"),"XTP dev18 multicastSender available")
address=.SocketAddresses~xtp("IDENTITY-CLUSTER",.true,"xtp.multicast")
ignore=.LdapIdentityTest~assert(address~multicast,"XTP multicast address truth")
collector=.PeerContractAckCollector~new
channel=.IdentityPeerXtpMulticastChannel~new(backend,address,collector)
ignore=.LdapIdentityTest~equal("IDENTITY-CLUSTER",channel~address~xtpAddress,"XTP group preserved")
say "IDENTITY XTP DEV18 CONTRACT: OK"

::class PeerContractAckCollector
::method collect
  use strict arg request, targetIds
  return .array~new

::requires "tests/TestSupport.cls"
::requires "src/IdentityPeerXtpTransport.cls"
::requires "XtpSocketProvider.cls"
