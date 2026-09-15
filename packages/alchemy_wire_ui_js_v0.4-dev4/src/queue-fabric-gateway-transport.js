import { envelopeToQueuePayload, queuePackageToEnvelope } from './oorexx-queue-adapter.js';

/**
 * Browser transport for a Queue Fabric gateway.
 *
 * The gateway owns queue-manager credentials plus PUT / CLAIM / ACK / NACK.
 * The browser receives only an opaque deliveryId for acknowledgement; Queue
 * Fabric claim tokens never cross the browser trust boundary.
 *
 * Outbound:
 *   { type:'QUEUE_PUT', clientPutId, queue, correlationId, payload }
 * Optional result:
 *   { type:'QUEUE_PUT_RESULT', clientPutId, accepted, packageId?, code?, detail? }
 *
 * Inbound:
 *   { type:'QUEUE_DELIVERY', deliveryId?, deliverySequence, package }
 * Browser disposition:
 *   { type:'QUEUE_DELIVERY_ACK', deliveryId, messageId }
 *   { type:'QUEUE_DELIVERY_NACK', deliveryId, messageId, reason }
 *
 * v0.3 gateways that omit deliveryId remain supported; no delivery ACK frame
 * is emitted for those deliveries.
 */
export class QueueFabricGatewayTransport {
  constructor({
    url,
    outboundQueue,
    ownership = {},
    protocols = undefined,
    WebSocketImpl = globalThis.WebSocket,
    putResultMode = 'none',
    putResultTimeoutMs = 10000
  }) {
    if (!url) throw new TypeError('gateway url is required');
    if (!outboundQueue) throw new TypeError('outboundQueue is required');
    if (!WebSocketImpl) throw new Error('WebSocket is not available');
    if (!['none', 'required'].includes(putResultMode)) throw new TypeError('putResultMode must be none or required');
    this.url = url;
    this.outboundQueue = outboundQueue;
    this.ownership = { ...ownership };
    this.protocols = protocols;
    this.WebSocketImpl = WebSocketImpl;
    this.putResultMode = putResultMode;
    this.putResultTimeoutMs = putResultTimeoutMs;
    this.socket = null;
    this.deliveryIds = new Map();
    this.pendingPuts = new Map();
  }

  start(receiver) {
    return new Promise((resolve, reject) => {
      const socket = new this.WebSocketImpl(this.url, this.protocols);
      this.socket = socket;
      socket.addEventListener('open', () => resolve(), { once: true });
      socket.addEventListener('error', (event) => reject(event), { once: true });
      socket.addEventListener('message', (event) => {
        const frame = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
        if (frame?.type === 'QUEUE_DELIVERY' && frame.package) {
          if (!Number.isSafeInteger(frame.deliverySequence) || frame.deliverySequence < 1) {
            throw new Error('QUEUE_DELIVERY requires positive per-access-point deliverySequence');
          }
          const envelope = queuePackageToEnvelope(frame.package, { deliverySequence: frame.deliverySequence });
          if (frame.deliveryId) this.deliveryIds.set(envelope.messageId, String(frame.deliveryId));
          receiver(envelope);
          return;
        }
        if (frame?.type === 'QUEUE_PUT_RESULT' && frame.clientPutId) {
          this.#resolvePut(frame);
        }
      });
    });
  }

  send(envelope) {
    this.#requireOpen();
    const frame = {
      type: 'QUEUE_PUT',
      clientPutId: envelope.messageId,
      queue: this.outboundQueue,
      correlationId: envelope.correlationId,
      payload: envelopeToQueuePayload(envelope, this.ownership)
    };
    if (this.putResultMode !== 'required') {
      this.socket.send(JSON.stringify(frame));
      return undefined;
    }

    const result = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingPuts.delete(envelope.messageId);
        reject(new Error(`Queue Fabric gateway PUT result timeout for ${envelope.messageId}`));
      }, this.putResultTimeoutMs);
      this.pendingPuts.set(envelope.messageId, { resolve, reject, timer });
    });
    // Register the waiter before sending so even a synchronous test gateway
    // cannot race QUEUE_PUT_RESULT ahead of pendingPuts.
    this.socket.send(JSON.stringify(frame));
    return result;
  }

  /** Called by Comms after an inbound semantic message is processed. */
  acknowledgeInbound(envelope) {
    const deliveryId = this.deliveryIds.get(envelope.messageId);
    if (!deliveryId) return false;
    this.deliveryIds.delete(envelope.messageId);
    this.#requireOpen();
    this.socket.send(JSON.stringify({
      type: 'QUEUE_DELIVERY_ACK',
      deliveryId,
      messageId: envelope.messageId
    }));
    return true;
  }

  /** Called by Comms when an inbound semantic handler fails. */
  rejectInbound(envelope, error) {
    const deliveryId = this.deliveryIds.get(envelope.messageId);
    if (!deliveryId) return false;
    this.deliveryIds.delete(envelope.messageId);
    this.#requireOpen();
    this.socket.send(JSON.stringify({
      type: 'QUEUE_DELIVERY_NACK',
      deliveryId,
      messageId: envelope.messageId,
      reason: error?.message ?? String(error ?? 'handler-failed')
    }));
    return true;
  }

  close() {
    for (const pending of this.pendingPuts.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error('Queue Fabric gateway closed before PUT result'));
    }
    this.pendingPuts.clear();
    this.deliveryIds.clear();
    this.socket?.close();
  }

  #resolvePut(frame) {
    const pending = this.pendingPuts.get(frame.clientPutId);
    if (!pending) return;
    this.pendingPuts.delete(frame.clientPutId);
    clearTimeout(pending.timer);
    if (frame.accepted === false) {
      const code = frame.code ? ` ${frame.code}` : '';
      const detail = frame.detail ? `: ${frame.detail}` : '';
      pending.reject(new Error(`Queue Fabric gateway PUT rejected${code}${detail}`));
      return;
    }
    pending.resolve(Object.freeze({
      accepted: true,
      packageId: frame.packageId ?? null,
      code: frame.code ?? 'OK',
      detail: frame.detail ?? null
    }));
  }

  #requireOpen() {
    if (!this.socket || this.socket.readyState !== this.WebSocketImpl.OPEN) {
      throw new Error('Queue Fabric gateway is not open');
    }
  }
}
