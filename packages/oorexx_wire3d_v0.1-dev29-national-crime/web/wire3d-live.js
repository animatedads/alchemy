/*
 * Live Wire3D semantic client.
 *
 * Transport remains owned by Alchemy Wire UI JS / Queue Fabric Web Gateway.
 * Wire3D owns semantic validation, ordered scene application and revision fences.
 */
export class Wire3DLiveClient {
  constructor({ renderer, transport }) {
    if (!renderer) throw new TypeError('renderer is required');
    if (!transport) throw new TypeError('QueueFabricGatewayTransport is required');
    this.renderer = renderer;
    this.transport = transport;
    this.connected = false;
    this.sceneId = null;
    this.lastDeliverySequence = 0;
    // Queue Fabric may call the receiver again before an asynchronous render
    // finishes. Keep semantic application strictly ordered in the browser.
    this.receiveTail = Promise.resolve();
  }

  async connect() {
    if (this.connected) return;
    await this.transport.start((envelope) => {
      this.receiveTail = this.receiveTail.then(() => this.#receive(envelope));
      // #receive owns rejection -> NACK, so keep the chain usable after a bad
      // delivery instead of poisoning every later delivery.
      this.receiveTail = this.receiveTail.catch(() => undefined);
    });
    this.connected = true;
  }

  async drain() { await this.receiveTail; }

  async close() {
    await this.drain();
    this.connected = false;
    await this.transport.close?.();
  }

  #validateSequence(envelope) {
    const seq = envelope.deliverySequence;
    if (seq === undefined || seq === null) return; // legacy/fake transports
    if (!Number.isSafeInteger(seq) || seq < 1) throw new Error('invalid delivery sequence');
    if (seq <= this.lastDeliverySequence) throw new Error(`non-monotonic delivery sequence ${seq}`);
  }

  #validateScene(sceneId) {
    if (!sceneId) throw new Error('Wire3D delivery requires sceneId');
    if (this.sceneId !== null && sceneId !== this.sceneId) {
      throw new Error(`scene mismatch: active ${this.sceneId}, delivery ${sceneId}`);
    }
  }

  async #receive(envelope) {
    try {
      this.#validateSequence(envelope);
      if (envelope.kind === 'WIRE3D_SNAPSHOT') {
        const snapshot = envelope.payload?.snapshot;
        if (!snapshot || snapshot.protocol !== 'WIRE-3D/0.1') throw new Error('invalid Wire3D snapshot delivery');
        if (!snapshot.sceneId) throw new Error('Wire3D snapshot requires sceneId');
        // A snapshot is the explicit resynchronisation boundary and may switch
        // the active scene. Deltas never may.
        this.renderer.setScene(snapshot);
        this.sceneId = snapshot.sceneId;
      } else if (envelope.kind === 'WIRE3D_DELTA') {
        const delta = envelope.payload?.delta;
        if (!delta || delta.protocol !== 'WIRE-3D-DELTA/0.1') throw new Error('invalid Wire3D delta delivery');
        this.#validateScene(delta.sceneId);
        this.renderer.applyDelta(delta);
      } else {
        throw new Error(`unsupported Wire3D delivery ${envelope.kind}`);
      }
      if (envelope.deliverySequence !== undefined && envelope.deliverySequence !== null) {
        this.lastDeliverySequence = envelope.deliverySequence;
      }
      await this.transport.acknowledgeInbound?.(envelope);
    } catch (error) {
      await this.transport.rejectInbound?.(envelope, error);
    }
  }
}

/* Deployment supplies the already-qualified Alchemy Wire UI JS module. */
export async function connectWire3DThroughExistingGateway({
  renderer, moduleUrl, gatewayUrl, outboundQueue, ownership = {}, WebSocketImpl = globalThis.WebSocket
}) {
  if (!moduleUrl) throw new TypeError('Alchemy Wire UI JS module URL is required');
  const api = await import(moduleUrl);
  const transport = new api.QueueFabricGatewayTransport({
    url: gatewayUrl,
    outboundQueue,
    ownership,
    WebSocketImpl,
    putResultMode: 'none'
  });
  const client = new Wire3DLiveClient({ renderer, transport });
  await client.connect();
  return client;
}
