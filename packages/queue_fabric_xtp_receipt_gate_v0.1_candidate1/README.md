# Queue Fabric XTP durable receipt gate candidate1 (2026-10-27)
This is a self-contained ooRexx compatibility gate with the existing QueueChannelFabric~pump transport~deliver(remoteManager,remoteChannel,envelope,principal) shape. The optional collaborator does NOT implement XTP sending, authentication or durable receiver UOW. A Queue Fabric verified RESULT must be supplied by the explicitly injected receiptVerifier. XTP CNTL, multicast quorum, DIAG and timeout are never application acceptance.

Existing TCP/other approved SocketSelector providers must remain unchanged. The injected resultClass is the exact QueueOperationResult class from the parent Queue Fabric package. Never resolve duplicates through accidental REXX_PATH order.

Candidate tests exercise failure on transport-only ACK, DIAG/refusal, missing verifier evidence, mismatched receipt identity, missing durable fields, and pre-network manager/channel rejection. These use mocks. Local archive of the full 13-assertion variant sha256: 9a33b2df21d436639de3ba5f2ef17c97bd04ddbdf51c8eb7dd735a40281da032. This Git source is its source-review variant, subject to its own Autobuild test.

Missing qualification: queue.transport/2 authenticated session over XTP dev30 with real verifier, transmission-queue ACK vs RELEASE, retained/object graph replay, multicast per-manager durable receipts and repair, Planner dev5 ticket/WLU pre-CLAIM, and directed ED209 L2/raw36/authorized UDP.
