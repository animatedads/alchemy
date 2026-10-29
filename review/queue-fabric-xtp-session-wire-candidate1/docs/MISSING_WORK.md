# Missing work: XTP dev34 / Queue Fabric

- Bind actual queue.transport/2 client/server auth over XtpSession, with LDAP Service Descriptor and Secret Broker key refresh/revocation. Require encrypted session, but do not confuse XTP key ownership with Queue Fabric manager/principal authorization.
- Implement receiver listener that decodes Queue Fabric graph envelope, invokes ACL-checked durable acceptTransfer/UOW and sends authenticated result on same session.
- Supply real cryptographic receipt verifier; sender ACK must follow verified UOW receipt, otherwise RELEASE and reconcile by stable transferId.
- Test remote restart, malformed/replayed results, wrong source manager/channel/queue, and cross-session substitution with r13196.
- Keep existing TCP/TLS SocketSelector channel functional. Multicast interest/repair requires separately qualified group keys and durable per-manager receipts.
- Planner dev5/WLU pre-CLAIM and actual ED209 MI-MU L2/raw36/approved UDP pathways need field qualification.
