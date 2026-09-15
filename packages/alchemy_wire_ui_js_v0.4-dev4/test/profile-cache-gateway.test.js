import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CaptureTransport,
  Comms,
  DefinitionRegistry,
  MemoryDefinitionCache,
  MessageKind,
  QueueFabricGatewayTransport,
  RenderProfileController,
  WireUIRuntime,
  MemoryRenderer,
  makeEnvelope
} from '../src/index.js';

function inbound(kind, payload, sequence, messageId = `server:${sequence}`) {
  return makeEnvelope({ kind, payload, sequence, source: 'server', destination: 'browser', messageId });
}
async function tick() { await new Promise((resolve) => setTimeout(resolve, 10)); }
function makeComms() {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'browser', destination: 'server' });
  transport.start((env) => comms.receive(env));
  comms.connected = true;
  return { comms, transport };
}

const definition = {
  id: 'SITE.OFFER_CARD', version: 3, profileId: 'large-fine', contentAddress: 'sha256:offer-card-v3-large',
  root: 'root', nodes: [{ key: 'root', primitive: 'text' }],
  slots: [{ index: 0, name: 'value', target: 'root', writer: 'text' }], actions: []
};

const capabilities = Object.freeze({
  viewportClass: 'large', pointer: 'fine', reducedMotion: false, colourScheme: 'light',
  features: Object.freeze({ dialog: true, adoptedStyleSheets: true, resizeObserver: true })
});

test('render profile hello advertises capability fingerprint once', () => {
  const { comms } = makeComms();
  const definitions = new DefinitionRegistry();
  const profile = new RenderProfileController({ comms, definitions, siteId: 'OurLadyAir', capabilities });
  const hello = profile.helloPayload({ application: 'booking' });
  assert.equal(hello.application, 'booking');
  assert.equal(hello.capabilityFingerprint, 'large.fine.rm0.light.d1.s1.r1');
  assert.equal(hello.renderCapabilities.viewportClass, 'large');
});

test('profile manifest loads immutable definition from content-addressed cache without network request', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  const cache = new MemoryDefinitionCache();
  await cache.put({ siteId: 'OurLadyAir', profileId: 'large-fine', contentAddress: definition.contentAddress }, definition);
  new RenderProfileController({ comms, definitions, definitionCache: cache, siteId: 'OurLadyAir', capabilities });

  comms.receive(inbound(MessageKind.UI_RENDER_PROFILE, {
    siteId: 'OurLadyAir', profileId: 'large-fine', manifestId: 'm:7',
    definitions: [{ id: definition.id, version: 3, contentAddress: definition.contentAddress }]
  }, 1));
  await tick();

  assert.equal(definitions.has(definition.id, 3), true);
  assert.equal(transport.sent.some((x) => x.kind === MessageKind.UI_DEFINITION_REQUIRED), false);
});

test('profile manifest requests only cache misses', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  const cache = new MemoryDefinitionCache();
  new RenderProfileController({ comms, definitions, definitionCache: cache, siteId: 'OurLadyAir', capabilities });

  comms.receive(inbound(MessageKind.UI_RENDER_PROFILE, {
    siteId: 'OurLadyAir', profileId: 'large-fine', manifestId: 'm:8',
    definitions: [{ id: definition.id, version: 3, contentAddress: definition.contentAddress }]
  }, 1));
  await tick();

  const request = transport.sent.find((x) => x.kind === MessageKind.UI_DEFINITION_REQUIRED);
  assert.ok(request);
  assert.deepEqual(request.payload.definitions, [{ id: definition.id, version: 3, contentAddress: definition.contentAddress }]);
});

test('received definition is persisted for a subsequent warm session', async () => {
  const cache = new MemoryDefinitionCache();
  const first = makeComms();
  const definitions = new DefinitionRegistry({ profileId: 'large-fine' });
  const profile = new RenderProfileController({ comms: first.comms, definitions, definitionCache: cache, siteId: 'OurLadyAir', capabilities });
  const renderer = new MemoryRenderer({ definitions });
  new WireUIRuntime({ comms: first.comms, definitions, renderer, renderProfile: profile });

  first.comms.receive(inbound(MessageKind.UI_DEFINITION, { definition }, 1));
  await tick();
  assert.equal(await cache.has({ siteId: 'OurLadyAir', profileId: 'large-fine', contentAddress: definition.contentAddress }), true);

  const second = makeComms();
  const secondDefinitions = new DefinitionRegistry();
  new RenderProfileController({ comms: second.comms, definitions: secondDefinitions, definitionCache: cache, siteId: 'OurLadyAir', capabilities });
  second.comms.receive(inbound(MessageKind.UI_RENDER_PROFILE, {
    siteId: 'OurLadyAir', profileId: 'large-fine', manifestId: 'm:9',
    definitions: [{ id: definition.id, version: 3, contentAddress: definition.contentAddress }]
  }, 1));
  await tick();
  assert.equal(secondDefinitions.has(definition.id, 3), true);
  assert.equal(second.transport.sent.some((x) => x.kind === MessageKind.UI_DEFINITION_REQUIRED), false);
});

class FakeWebSocket {
  static OPEN = 1;
  constructor() { this.readyState = FakeWebSocket.OPEN; this.handlers = new Map(); this.sent = []; queueMicrotask(() => this.#emit('open', {})); FakeWebSocket.last = this; }
  addEventListener(name, fn) { if (!this.handlers.has(name)) this.handlers.set(name, []); this.handlers.get(name).push(fn); }
  #emit(name, event) { for (const fn of this.handlers.get(name) ?? []) fn(event); }
  send(text) { this.sent.push(text); }
  inject(frame) { this.#emit('message', { data: JSON.stringify(frame) }); }
  close() { this.readyState = 3; }
}

test('Queue Fabric gateway transport frames outbound PUT and adapts inbound delivery', async () => {
  const gateway = new QueueFabricGatewayTransport({
    url: 'ws://gateway', outboundQueue: 'WIRE.UI.SERVER', ownership: { sessionId: 's:1' }, WebSocketImpl: FakeWebSocket
  });
  let received = null;
  await gateway.start((value) => { received = value; });

  const outbound = makeEnvelope({
    kind: MessageKind.UI_ACTION, payload: { action: 'ORDER.RETRY' }, sequence: 1,
    source: 'browser', destination: 'server', messageId: 'browser:1'
  });
  gateway.send(outbound);
  const frame = JSON.parse(FakeWebSocket.last.sent[0]);
  assert.equal(frame.type, 'QUEUE_PUT');
  assert.equal(frame.queue, 'WIRE.UI.SERVER');
  assert.equal(frame.payload.type, MessageKind.UI_ACTION);
  assert.equal(frame.payload.sessionId, 's:1');
  assert.equal(frame.payload.action, 'ORDER.RETRY');

  FakeWebSocket.last.inject({
    type: 'QUEUE_DELIVERY', deliverySequence: 1,
    package: {
      packageId: 'pkg:7', sequence: 991, sourceQueue: 'WIRE.UI.SERVER', currentQueue: 'WEB.SESSION.1',
      createdAt: '2026-08-24T12:00:00Z', correlationId: 'c:1',
      payload: { type: MessageKind.UI_ACK, accepted: true }
    }
  });
  assert.equal(received.kind, MessageKind.UI_ACK);
  assert.equal(received.messageId, 'pkg:7');
  assert.equal(received.sequence, 1);
  assert.equal(received.transportMeta.queueFabricPackageSequence, 991);
  assert.deepEqual(received.payload, { accepted: true });
});

test('cryptographic definition content address detects mutation', async () => {
  const { definitionContentAddress, verifyDefinitionContentAddress } = await import('../src/index.js');
  const base = { ...definition, contentAddress: null };
  const address = await definitionContentAddress(base);
  const addressed = { ...base, contentAddress: address };
  assert.equal(await verifyDefinitionContentAddress(addressed), true);
  await assert.rejects(() => verifyDefinitionContentAddress({ ...addressed, nodes: [{ key: 'root', primitive: 'button' }] }), /content-address mismatch/);
});
