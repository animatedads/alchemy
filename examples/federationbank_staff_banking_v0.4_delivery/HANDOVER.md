# Handover — Staff Banking v0.4

Current continuation point: v0.3 backend + early Staff Wire UI v0.1.

The UI is a presentation/intent surface only. Preserve the separation among
Authentication, Access Control, exact Method Permission, Staff Authority and
Core Banking. A renderer role, visible field or enabled button is not authority.

Recommended next work is checker UI over durable `APPROVAL_REQUIRED` work. Give
the checker its own exact invocation permission and Staff Authority decision and
prove a maker cannot self-approve by manipulating browser state. Then add a
dedicated live Staff browser/WebSocket/Queue Fabric/Web Gateway acceptance test.
