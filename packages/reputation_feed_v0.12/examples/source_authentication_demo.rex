now=.DateTime~new
source=.ReputationSourceIdentity~new('REG-DEMO','OFFICIAL','Demo Regulator','','','GB','OFFICIAL_NOTICE','demo-endpoint')~seal
env=.ReputationRawEnvelope~new('ENV-DEMO-AUTH',source,now,now,'APPLICATION/JSON','https://reg.demo/notices/1','EN','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
env~addSegment('NOTICE','Synthetic notice for source authentication demo'); env~seal
ring=.CryptoMacKeyRing~new; ring~addKey('demo-key','000102030405060708090a0b0c0d0e0f')
alg=.CryptoLibraryBuild~SIPHASH_ALGORITHM
binding=.ReputationSourceKeyBinding~new('BIND-DEMO','REG-DEMO',alg,'demo-key','',source~endpointId,'https://reg.demo/')~seal
material=.ReputationSourceAuthProof~canonicalMaterial(source~sourceId,binding~bindingId,env~envelopeId,source~endpointId,alg,binding~keyId,now,env~payloadDigest,env~locator)
mac=ring~sign(material)
proof=.ReputationSourceAuthProof~new('PROOF-DEMO',source~sourceId,binding~bindingId,env~envelopeId,source~endpointId,mac~algorithm,mac~keyId,now,env~payloadDigest,env~locator,mac~tag)~seal
auth=.ReputationSourceAuthenticator~new~verify(env,proof,binding,ring,now)
ledger=.ReputationSourceHistoryLedger~new; ledger~recordAuthentication(auth)
view=ledger~snapshotAt(source~sourceId,now)
packet=.ReputationSourceEvidencePacket~new('PACKET-DEMO',env,auth,view)~seal
say 'feed_api=' .ReputationFeedBuild~API_VERSION
say 'source='packet~sourceId 'origin='packet~authenticationState 'verified='packet~authenticatedOrigin
say 'history_events='view~eventCount 'verified_auth='view~verifiedAuthenticationCount 'failed_auth='view~failedAuthenticationCount
say 'truth_decision=NONE (origin authentication is provenance only)'
exit 0
::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
