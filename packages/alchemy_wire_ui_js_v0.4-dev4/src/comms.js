import { makeEnvelope, MessageKind, validateEnvelope } from './protocol.js';

/**
 * Logical queue communications object.
 *
 * Transport is deliberately abstract. A transport must expose:
 *   start(receive) -> optional Promise
 *   send(envelope) -> optional Promise
 *   close() -> optional Promise
 *
 * Comms serialises inbound dispatch for one logical endpoint. This is the
 * browser-side counterpart of an ordered queue consumer / state owner.
 */
export class Comms {
  constructor({ transport, source, destination, maxReorderBuffer = 128, ackMode = 'none' }) {
    if (!transport) throw new TypeError('transport is required');
    if (!source) throw new TypeError('source is required');
    if (!destination) throw new TypeError('destination is required');

    this.transport = transport;
    this.source = source;
    this.destination = destination;
    this.maxReorderBuffer = maxReorderBuffer;
    this.ackMode = ackMode;

    this.outSequence = 0;
    this.expectedInSequence = 1;
    this.reorderBuffer = new Map();
    this.seenMessageIds = new Set();
    this.handlers = new Map();
    this.anyHandlers = new Set();
    this.stateHandlers = new Set();
    this.inbox = [];
    this.processing = false;
    this.connected = false;
    this.subscriptions = new Map();
  }

  async connect(helloPayload = {}) {
    if (this.connected) return;
    await this.transport.start?.((envelope) => this.receive(envelope));
    this.connected = true;
    this.#emitState({ type: 'connected' });
    await this.send(MessageKind.HELLO, helloPayload, { requiresAck: false });
  }

  async close() {
    this.connected = false;
    await this.transport.close?.();
    this.#emitState({ type: 'closed' });
  }

  on(kind, handler) {
    if (!this.handlers.has(kind)) this.handlers.set(kind, new Set());
    this.handlers.get(kind).add(handler);
    return () => this.handlers.get(kind)?.delete(handler);
  }

  onAny(handler) {
    this.anyHandlers.add(handler);
    return () => this.anyHandlers.delete(handler);
  }

  onState(handler) {
    this.stateHandlers.add(handler);
    return () => this.stateHandlers.delete(handler);
  }

  async send(kind, payload, { correlationId = null, requiresAck = false } = {}) {
    this.outSequence += 1;
    const envelope = makeEnvelope({
      kind,
      payload,
      sequence: this.outSequence,
      source: this.source,
      destination: this.destination,
      correlationId
    });
    await this.transport.send(envelope);
    if (requiresAck) this.#emitState({ type: 'awaiting-ack', messageId: envelope.messageId });
    return envelope;
  }

  async activateSubscription(name, { revision = null, purpose = null } = {}) {
    if (!name) throw new TypeError('subscription name is required');
    const current = this.subscriptions.get(name);
    if (current?.state === 'active' && current.revision === revision) return current;

    const state = { name, revision, purpose, state: 'pending-active' };
    this.subscriptions.set(name, state);
    await this.send(MessageKind.SUBSCRIPTION_ACTIVATE, { name, revision, purpose });
    return state;
  }

  async deactivateSubscription(name) {
    if (!name) throw new TypeError('subscription name is required');
    const current = this.subscriptions.get(name);
    if (current?.state === 'inactive' || current?.state === 'pending-inactive') return current;
    const state = { name, state: 'pending-inactive' };
    this.subscriptions.set(name, state);
    await this.send(MessageKind.SUBSCRIPTION_DEACTIVATE, { name });
    return state;
  }

  /**
   * Differential subscription reconciliation. Only the delta between the
   * currently desired set and the new desired set generates queue traffic.
   */
  async reconcileSubscriptions(desired = []) {
    const wanted = new Map();
    for (const entry of desired) {
      const value = typeof entry === 'string' ? { name: entry } : entry;
      if (!value?.name) throw new TypeError('desired subscription name is required');
      wanted.set(value.name, {
        name: value.name,
        revision: value.revision ?? null,
        purpose: value.purpose ?? null
      });
    }

    const activated = [];
    const deactivated = [];

    for (const [name, current] of this.subscriptions) {
      if (!wanted.has(name) && current.state !== 'inactive' && current.state !== 'pending-inactive') {
        await this.deactivateSubscription(name);
        deactivated.push(name);
      }
    }

    for (const value of wanted.values()) {
      const current = this.subscriptions.get(value.name);
      const sameRevision = (current?.revision ?? null) === value.revision;
      const samePurpose = (current?.purpose ?? null) === value.purpose;
      const alreadyDesired = (current?.state === 'active' || current?.state === 'pending-active') && sameRevision && samePurpose;
      if (!alreadyDesired) {
        await this.activateSubscription(value.name, value);
        activated.push(value.name);
      }
    }

    return { activated, deactivated };
  }

  getSubscription(name) {
    return this.subscriptions.get(name) ?? null;
  }

  receive(envelope) {
    validateEnvelope(envelope);

    if (this.seenMessageIds.has(envelope.messageId)) {
      this.#emitState({ type: 'duplicate', messageId: envelope.messageId, sequence: envelope.sequence });
      return;
    }

    if (envelope.sequence < this.expectedInSequence) {
      this.seenMessageIds.add(envelope.messageId);
      this.#emitState({ type: 'late-duplicate', messageId: envelope.messageId, sequence: envelope.sequence });
      return;
    }

    if (envelope.sequence > this.expectedInSequence) {
      if (this.reorderBuffer.size >= this.maxReorderBuffer) {
        this.#emitState({
          type: 'sequence-overflow',
          expected: this.expectedInSequence,
          received: envelope.sequence
        });
        return;
      }
      this.reorderBuffer.set(envelope.sequence, envelope);
      this.#emitState({ type: 'sequence-gap', expected: this.expectedInSequence, received: envelope.sequence });
      return;
    }

    this.#acceptOrdered(envelope);
    while (this.reorderBuffer.has(this.expectedInSequence)) {
      const next = this.reorderBuffer.get(this.expectedInSequence);
      this.reorderBuffer.delete(this.expectedInSequence);
      this.#acceptOrdered(next);
    }
  }

  #acceptOrdered(envelope) {
    this.seenMessageIds.add(envelope.messageId);
    this.expectedInSequence += 1;
    this.inbox.push(envelope);
    void this.#drainInbox();
  }

  async #drainInbox() {
    if (this.processing) return;
    this.processing = true;
    try {
      while (this.inbox.length) {
        const envelope = this.inbox.shift();
        if (envelope.kind === MessageKind.SUBSCRIPTION_STATE) this.#applySubscriptionState(envelope.payload);

        try {
          const specific = [...(this.handlers.get(envelope.kind) ?? [])];
          for (const handler of specific) await handler(envelope.payload, envelope);
          for (const handler of [...this.anyHandlers]) await handler(envelope.payload, envelope);

          if (this.ackMode === 'message' && envelope.kind !== MessageKind.COMMS_ACK) {
            await this.send(MessageKind.COMMS_ACK, { messageId: envelope.messageId }, { correlationId: envelope.messageId });
          }
          await this.transport.acknowledgeInbound?.(envelope);
        } catch (error) {
          await this.transport.rejectInbound?.(envelope, error);
          this.#emitState({ type: 'inbound-handler-error', messageId: envelope.messageId, sequence: envelope.sequence, error });
        }
      }
    } finally {
      this.processing = false;
    }
  }

  #applySubscriptionState(payload = {}) {
    if (!payload.name) return;
    this.subscriptions.set(payload.name, {
      name: payload.name,
      revision: payload.revision ?? null,
      purpose: payload.purpose ?? null,
      state: payload.active === false ? 'inactive' : 'active'
    });
  }

  #emitState(event) {
    for (const handler of [...this.stateHandlers]) handler(event);
  }
}

/** Minimal test/development transport. */
export class CaptureTransport {
  constructor() {
    this.sent = [];
    this.receiver = null;
  }
  start(receiver) { this.receiver = receiver; }
  async send(envelope) { this.sent.push(envelope); }
  inject(envelope) { this.receiver?.(envelope); }
  close() { this.receiver = null; }
}

/** Browser WebSocket transport. Queue semantics remain in Comms, not here. */
export class WebSocketTransport {
  constructor({ url, protocols = undefined, WebSocketImpl = globalThis.WebSocket }) {
    if (!WebSocketImpl) throw new Error('WebSocket is not available');
    this.url = url;
    this.protocols = protocols;
    this.WebSocketImpl = WebSocketImpl;
    this.socket = null;
  }

  start(receiver) {
    return new Promise((resolve, reject) => {
      const socket = new this.WebSocketImpl(this.url, this.protocols);
      this.socket = socket;
      socket.addEventListener('open', () => resolve(), { once: true });
      socket.addEventListener('error', (event) => reject(event), { once: true });
      socket.addEventListener('message', (event) => {
        const value = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
        receiver(value);
      });
    });
  }

  send(envelope) {
    if (!this.socket || this.socket.readyState !== this.WebSocketImpl.OPEN) throw new Error('WebSocket is not open');
    this.socket.send(JSON.stringify(envelope));
  }

  close() { this.socket?.close(); }
}
