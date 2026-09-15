import { makeEnvelope } from './protocol.js';

/**
 * Convert an ooRexx QueueWorkPackage-shaped object carrying a WireUIProtocol
 * semantic message into the browser Comms envelope.
 *
 * The Queue Fabric package remains the delivery authority for message id,
 * sequence, correlation and observed queue ordering.  The semantic payload
 * remains the application message.
 */
export function queuePackageToEnvelope(pkg, {
  source = 'oorexx',
  destination = pkg?.currentQueue ?? 'browser',
  deliverySequence = pkg?.deliverySequence ?? null
} = {}) {
  if (!pkg || typeof pkg !== 'object') throw new TypeError('queue package is required');
  const semantic = pkg.payload;
  if (!semantic || typeof semantic !== 'object') throw new TypeError('queue package payload is required');
  const kind = semantic.type ?? semantic.kind;
  if (!kind) throw new TypeError('semantic message type is required');

  const payload = { ...semantic };
  delete payload.type;
  delete payload.kind;
  delete payload.protocolVersion;

  const sequence = deliverySequence == null ? Number(pkg.sequence) : Number(deliverySequence);
  if (!Number.isSafeInteger(sequence) || sequence < 1) throw new TypeError('positive per-access-point deliverySequence is required');

  return makeEnvelope({
    kind,
    payload,
    sequence,
    source,
    destination,
    correlationId: pkg.correlationId || null,
    messageId: String(pkg.packageId),
    sentAt: pkg.createdAt || new Date().toISOString(),
    transportMeta: {
      queueFabricPackageSequence: Number(pkg.sequence),
      requestedQueue: pkg.requestedQueue ?? null,
      currentQueue: pkg.currentQueue ?? null
    }
  });
}

/**
 * Convert a browser Comms envelope to the semantic table shape accepted by
 * WireUIApplication/WireUIServer.  Queue Fabric supplies its own package id
 * and queue sequence when this object is PUT.
 */
export function envelopeToQueuePayload(envelope, ownership = {}) {
  if (!envelope || typeof envelope !== 'object') throw new TypeError('envelope is required');
  const payload = envelope.payload && typeof envelope.payload === 'object'
    ? { ...envelope.payload }
    : { value: envelope.payload };

  const semantic = {
    type: envelope.kind,
    protocolVersion: 'WIRE-UI/0.1',
    messageId: envelope.messageId,
    commsSequence: envelope.sequence,
    ...ownership,
    ...payload
  };

  // Wire UI Server v0.3 validates the selected interaction profile as a
  // top-level semantic action field. The JS controller keeps offer evidence
  // grouped in detail, so the Queue Fabric boundary projects only this
  // protocol-defined value rather than flattening arbitrary detail fields.
  if (semantic.type === 'UI_ACTION' && semantic.action === 'INTERACTION.PROFILE.SELECT' && !semantic.profile) {
    const selected = payload?.detail?.profileId ?? payload?.detail?.profile ?? null;
    if (selected) semantic.profile = selected;
  }

  return semantic;
}
