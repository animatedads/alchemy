export const PROTOCOL_VERSION = 1;

export const MessageKind = Object.freeze({
  HELLO: 'UI_HELLO',
  SUBSCRIPTION_ACTIVATE: 'SUBSCRIPTION_ACTIVATE',
  SUBSCRIPTION_DEACTIVATE: 'SUBSCRIPTION_DEACTIVATE',
  SUBSCRIPTION_STATE: 'SUBSCRIPTION_STATE',
  OBSERVATION_PLAN: 'OBSERVATION_PLAN',
  UI_RENDER_PROFILE: 'UI_RENDER_PROFILE',
  UI_DEFINITION_MANIFEST: 'UI_DEFINITION_MANIFEST',
  UI_JOURNEY_PLAN: 'UI_JOURNEY_PLAN',
  UI_ON_DEMAND_REQUEST: 'UI_ON_DEMAND_REQUEST',
  INTERACTION_PROFILE_OFFER: 'INTERACTION_PROFILE_OFFER',
  INTERACTION_OBSERVATION: 'INTERACTION_OBSERVATION',
  UI_DEFINITION: 'UI_DEFINITION',
  UI_MATERIAL_SET: 'UI_MATERIAL_SET',
  UI_DEFINITION_REQUIRED: 'UI_DEFINITION_REQUIRED',
  UI_VIEW_SNAPSHOT: 'UI_VIEW_SNAPSHOT',
  UI_VIEW_PATCH: 'UI_VIEW_PATCH',
  UI_ACTION: 'UI_ACTION',
  UI_RESYNC_REQUEST: 'UI_RESYNC_REQUEST',
  UI_ACK: 'UI_ACK',
  COMMS_ACK: 'COMMS_ACK'
});

let localCounter = 0;
export function makeMessageId(prefix = 'msg') {
  localCounter += 1;
  const random = globalThis.crypto?.randomUUID?.();
  return random ? `${prefix}:${random}` : `${prefix}:${Date.now().toString(36)}:${localCounter.toString(36)}`;
}

export function makeEnvelope({
  kind,
  payload,
  sequence,
  source,
  destination,
  correlationId = null,
  messageId = makeMessageId(),
  sentAt = new Date().toISOString(),
  protocolVersion = PROTOCOL_VERSION,
  transportMeta = null
}) {
  if (!kind) throw new TypeError('kind is required');
  if (!Number.isSafeInteger(sequence) || sequence < 1) throw new TypeError('positive integer sequence is required');
  return Object.freeze({
    protocolVersion,
    messageId,
    kind,
    sequence,
    source,
    destination,
    correlationId,
    sentAt,
    transportMeta,
    payload
  });
}

export function validateEnvelope(envelope) {
  if (!envelope || typeof envelope !== 'object') throw new TypeError('envelope must be an object');
  if (envelope.protocolVersion !== PROTOCOL_VERSION) throw new Error(`unsupported protocol version ${envelope.protocolVersion}`);
  if (typeof envelope.messageId !== 'string' || !envelope.messageId) throw new TypeError('messageId is required');
  if (typeof envelope.kind !== 'string' || !envelope.kind) throw new TypeError('kind is required');
  if (!Number.isSafeInteger(envelope.sequence) || envelope.sequence < 1) throw new TypeError('sequence must be a positive integer');
  return envelope;
}
