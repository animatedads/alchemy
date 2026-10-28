normAddr=.SocketAddresses~norm('239.255.42.1',47001,'lo','',7,'replication')
normOffers=.NormDev1SocketOfferProvider~new
normOffers~register('replication','norm-local',normAddr,10,'LOCAL')
xtpOffers=.XtpDev10SocketOfferProvider~new
xtpOffers~register('replication','xtp-path',.SocketAddresses~xtp('peer:replication',.false,'replication'),20,'REMOTE')
neg=.SocketNegotiator~new
neg~registerOfferProvider(xtpOffers)
neg~registerOfferProvider(normOffers)
req=.SocketNegotiationRequest~new('replication','SENDER',.false,.false,.true)
sel=neg~negotiate(req)
if \sel~selected then call fail 'no selection'
if sel~address~transport<>.SocketTransportKind~NORM then call fail 'NORM not selected by lower offer priority'
if sel~address~normGroup<>'239.255.42.1' then call fail 'group identity lost'
reqStream=.SocketNegotiationRequest~new('replication','SENDER',.true,.false,.false)
sel2=neg~negotiate(reqStream)
if \sel2~selected then call fail 'stream selection absent'
if sel2~address~transport<>.SocketTransportKind~XTP then call fail 'stream requirement did not exclude NORM/select XTP'
say 'PASS NORM/XTP best-protocol negotiation'
exit 0
fail: procedure
 parse arg why
 say 'FAIL' why
 exit 1
::requires 'SocketProvider.cls'
::requires 'SocketIntentions.cls'
