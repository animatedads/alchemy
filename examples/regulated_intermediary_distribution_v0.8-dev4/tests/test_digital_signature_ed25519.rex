port=value("CRYPTO_REFERENCE_TEST_PORT",,"ENVIRONMENT")
if port="" then raise syntax 88.900 array("CRYPTO_REFERENCE_TEST_PORT is required for accelerated Ed25519 qualification")
broker=.RuntimeImplementationBroker~new
provider=.RuntimeTcpJsonProvider~new("python.crypto.reference","127.0.0.1",port+0,2,1048576,"")
do operation over .array~of("crypto.ed25519.keypair/1","crypto.ed25519.sign/1","crypto.ed25519.verify/1")
  broker~register(operation,.RuntimeImplementationReference~new(provider,100,.true,1,1))
end
.RuntimeImplementationSwitch~installBroker(broker)
.CryptoLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch

/* End-to-end business signature proof using the supplied oorexx_crypto v0.3. */
seed="9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
pair=.Ed25519~keypair(seed)
now=.DateTime~new
before=now-.TimeSpan~new(0,0,0,0,60)
registry=.RIDSigningKeyRegistry~new
providerSigner="ALL_JAPAN_INSURANCE_CO_LTD|ALL_JAPAN_POLICY_ADMIN"
.RIDTestSupport~ok(registry~register(.RIDSigningKey~new("AJI-EVENT-KEY",providerSigner,"ED25519",pair["public"],"PROVIDER_EVENT",before,.nil,"KEY:EVIDENCE:AJI")))
.RIDTestSupport~ok(registry~register(.RIDSigningKey~new("CUSTOMER-SIGN-KEY","CUSTOMER:SIG","ED25519",pair["public"],"DOCUMENT_SIGNATURE",before,.nil,"KEY:EVIDENCE:CUSTOMER")))
verifier=.RIDEd25519SignatureVerifier~new
service=.RIDDigitalSignatureService~new(registry,verifier)

status=.RIDProviderStatusEvidence~new("AJI-STATUS-100","ALL_JAPAN_INSURANCE_CO_LTD","ALL_JAPAN_POLICY_ADMIN","AJI:CASE:100","AJI-HOME|2026.08|SEM",100,"APPROVED",now,"AJI:EVENT:100")
unsigned=.RIDSignedProviderStatusEvent~new(status,providerSigner,"AJI-EVENT-KEY","00",now,"AJI:MTLS:SESSION:1")
sig=verifier~signForTest(unsigned~canonicalMessage,seed)
signed=.RIDSignedProviderStatusEvent~new(status,providerSigner,"AJI-EVENT-KEY",sig,now,"AJI:MTLS:SESSION:1")
.RIDTestSupport~ok(service~verifyProviderStatus(signed),"provider event signature must verify")

contentDigest=.SHA512~new("exact mortgage/insurance document bytes for test")~digest
envelope=.RIDSignatureEnvelope~new("SIGENV-1","CASE-SIG","APPLICATION_DECLARATION","DOC:SEM:1","1","SHA-512",contentDigest,"OBJECT:SIGNED:DOC:1","DURABLE:MEDIUM:1",now)
req=.RIDSignatureRequirement~new("CUSTOMER-1","CUSTOMER:SIG","CUSTOMER","ACCEPT_AND_SUBMIT",.true)
.RIDTestSupport~ok(envelope~addRequirement(req))
.RIDTestSupport~ok(envelope~seal)
message=envelope~canonicalSigningMessage(req~requirementId,req~signerRef,req~signerRole,req~purpose,now,"AUTH:MFA:1","CONSENT:1")
docSig=verifier~signForTest(message,seed)
evidence=.RIDSignatureEvidence~new("SIGNATURE-1",envelope~envelopeId,req~requirementId,req~signerRef,req~signerRole,"CUSTOMER-SIGN-KEY",docSig,now,"AUTH:MFA:1","CONSENT:1","EVIDENCE:SIGNATURE:1")
.RIDTestSupport~ok(service~submitDocumentSignature(envelope,evidence),"document signature must verify")
.RIDTestSupport~assertEq("COMPLETE",envelope~state,"required verified signature completes envelope")
.RIDTestSupport~assertEq(contentDigest,envelope~contentDigest,"signed envelope remains bound to exact document digest")
.CryptoLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say "PASS Ed25519 provider event and digital document signatures via Runtime Reference"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDDigitalSigning.cls"
::requires "RIDEd25519SignatureBridge.cls"
::requires "TestSupport.cls"
::requires "crypto.cls"
::requires "RuntimeTcpJsonProvider.cls"
