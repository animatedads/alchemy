# Object Queue Fabric engineering sphere v0.3
This is a continuation of v0.2's optional XTP capability architecture and historical dev5/dev6 source evidence. v0.3 records actual XTP dev30 transport hardening, the new standalone QueueXtpReceiptGate candidate1 with local r13196 mock test evidence, and the unfinished authenticated durable network work. Neither XTP ACK/DIAG nor multicast quorum equals Queue Fabric UOW acceptance. The XTP sphere remains a separate source/authority. Runtime Queue Fabric-over-XTP is not qualified.
Search: gopher --profile queue-fabric search xtp --sphere queue-fabric
Tests: sha256sum -c qualification/MANIFEST.sha256; bash tests/check_xtp_contract.sh
