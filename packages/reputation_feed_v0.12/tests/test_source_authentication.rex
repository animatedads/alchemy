now = .DateTime~new

source = .ReputationSourceIdentity~new('REG-EXAMPLE','OFFICIAL','Example Regulator','','','GB','OFFICIAL_NOTICE','regulator-feed')
source~seal
envelope = .ReputationRawEnvelope~new('ENV-AUTH-1',source,now,now,'APPLICATION/JSON','https://reg.example/notices/42','EN','0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef')
envelope~addSegment('NOTICE','Synthetic regulator notice used only for authentication testing')
envelope~seal

ring = .CryptoMacKeyRing~new
ring~addKey('reg-key-1','000102030405060708090a0b0c0d0e0f')
algorithm = .CryptoLibraryBuild~SIPHASH_ALGORITHM
binding = .ReputationSourceKeyBinding~new('BIND-REG-1','REG-EXAMPLE',algorithm,'reg-key-1','',source~endpointId,'https://reg.example/',now - .TimeSpan~new(1),now + .TimeSpan~new(1))
binding~seal
material = .ReputationSourceAuthProof~canonicalMaterial(source~sourceId,binding~bindingId,envelope~envelopeId,source~endpointId,algorithm,binding~keyId,now,envelope~payloadDigest,envelope~locator)
signed = ring~sign(material)
proof = .ReputationSourceAuthProof~new('PROOF-1',source~sourceId,binding~bindingId,envelope~envelopeId,source~endpointId,signed~algorithm,signed~keyId,now,envelope~payloadDigest,envelope~locator,signed~tag)
proof~seal

auth = .ReputationSourceAuthenticator~new
verified = auth~verify(envelope,proof,binding,ring)
call assertTrue verified~verified, 'source origin verifies'
call assertEqual 'VERIFIED', verified~state, 'verified state'
call assertEqual 'ORIGIN_VERIFIED', verified~reasonCode, 'verified reason'
call assertFalse verified~hasMethod('TRUSTSCORE'), 'authentication result has no trust score surface'

badLast = right(signed~tag,1)
if badLast = '0' then replacement = '1'; else replacement = '0'
badTag = left(signed~tag,length(signed~tag)-1) || replacement
badProof = .ReputationSourceAuthProof~new('PROOF-BAD',source~sourceId,binding~bindingId,envelope~envelopeId,source~endpointId,signed~algorithm,signed~keyId,now,envelope~payloadDigest,envelope~locator,badTag)
badProof~seal
bad = auth~verify(envelope,badProof,binding,ring)
call assertFalse bad~verified, 'bad source proof rejected'
call assertEqual 'PROOF_INVALID', bad~reasonCode, 'bad proof reason retained'

missing = auth~verify(envelope,.nil,binding,ring)
call assertEqual 'UNVERIFIED', missing~state, 'missing proof remains unverified rather than false truth claim'
call assertEqual 'PROOF_MISSING', missing~reasonCode, 'missing proof reason'

outside = .ReputationRawEnvelope~new('ENV-OUTSIDE',source,now,now,'APPLICATION/JSON','https://mirror.example/notices/42','EN',envelope~payloadDigest)
outside~addSegment('NOTICE','Same bytes delivered through an unbound locator')
outside~seal
outsideMaterial = .ReputationSourceAuthProof~canonicalMaterial(source~sourceId,binding~bindingId,outside~envelopeId,source~endpointId,algorithm,binding~keyId,now,outside~payloadDigest,outside~locator)
outsideSigned = ring~sign(outsideMaterial)
outsideProof = .ReputationSourceAuthProof~new('PROOF-OUTSIDE',source~sourceId,binding~bindingId,outside~envelopeId,source~endpointId,outsideSigned~algorithm,outsideSigned~keyId,now,outside~payloadDigest,outside~locator,outsideSigned~tag)
outsideProof~seal
outsideResult = auth~verify(outside,outsideProof,binding,ring)
call assertEqual 'LOCATOR_OUTSIDE_BINDING', outsideResult~reasonCode, 'valid proof outside bound endpoint range is not accepted'

/* Public-key source bindings are supported without storing a private key in
   Reputation Feed.  The expensive RFC 8032 arithmetic is tested in
   oorexx_crypto; Feed has a separate optional slow integration probe. */
edBinding = .ReputationSourceKeyBinding~new('BIND-ED','REG-EXAMPLE','ED25519','ed-key-1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',source~endpointId,'https://reg.example/')
edBinding~seal
call assertEqual 'ED25519',edBinding~algorithm,'public-key source binding retained'

adoption = .AlchemyAdoptionVerifier~verify(binding,'STANDARD')
call assertTrue adoption~ok, 'source binding satisfies AlchemyObject v0.8 STANDARD adoption'
call assertEqual '0.8', adoption~evidence['base_version'], 'v0.8 adoption evidence'

say 'PASS test_source_authentication api=' || .ReputationFeedBuild~API_VERSION
exit 0

assertTrue: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
::requires 'AlchemyAdoption.cls'
