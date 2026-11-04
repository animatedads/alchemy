# Wire Deployment Candidate 4: General Deployment dev4 live evidence gate

This native ooRexx code reuses General ooRexx Deployment v0.1-dev4 HostedModuleEvidence and Candidate 3's WireDeploymentAdmissionJournal. It does **not** create another installer, Queue Fabric manager, HTTPS stack or LDAP authority. The gate returns PROBED_ACTIVE only after admitted request/digest/target, module id, generation, mount, complete hosted lifecycle and independently authenticated live probe evidence all match.

The production host must inject a trusted verifier with verifyLiveProbe(receipt,admissionTuple). It must independently verify authenticated HTTPS/TLS, Wire WebSocket semantic action and observation, applicable LDAP access control and content-addressed Storage Fabric evidence binding. The included stub used for local tests is **not** a production authority. Raw journal complete() remains privileged and should never be exposed to browsers or app handlers.

Qualified locally with user-supplied ooRexx r13196: two native test scripts PASS, one source compile PASS, and original Candidate3 re-run eight native tests and seven compile checks PASS. No real TLS/WSS/LDAP network traffic, signed .wapp retrieval, cross-host fencing or production cutover is qualified.

Version pins: oorexx_deployment_v0.1-dev4.zip SHA256 c6f04ddc6bcb80963161d3312b773cbc4c58fdbd2f99907662aa4a0d6ad23ce2; wire_application_deployment_v0.1_candidate3.zip SHA256 8aa156951a6f2326ef7c8df944a04a3afcb9929ce1f89d5ce347ba4fed87dbe9; Queue Fabric v0.9-dev6, Alchemy Objects v0.8, Crypto v0.8.3; ooRexx 5.3.0 r13196.

Downloadable full ZIP SHA256 8b70d45d74cc3aefa91de1efa53f3dd9092e62e6842097ba74a38781d1699865 includes full tests and an explicit environment runner. Autobuilder is not used.
