import test from 'node:test';
import assert from 'node:assert/strict';
import {
  Comms,
  MessageKind,
  QueueFabricGatewayTransport,
  makeEnvelope
} from '../src/index.js';

class FakeWebSocket {
  static OPEN = 1;
  constructor() {
    this.readyState = FakeWebSocket.OPEN;
    this.handlers = new Map();
    this.sent = [];
    FakeWebSocket.last = this;
    queueMicrotask(() => this.#emit('open', {}));
  }
  addEventListener(name, fn) {
    if (!this.handlers.has(name)) this.handlers.set(name, []);
    this.handlers.get(name).push(fn);
  }
  #emit(name, event) { for (const fn of this.handlers.get(name) ?? []) fn(event); }
  send(text) { this.sent.push(text); }
  inject(frame) { this.#emit('message', { data: JSON.stringify(frame) }); }
  close() { this.readyState = 3; }
}

function delivery({ deliveryId = 'delivery:1', deliverySequence = 1, packageId = 'pkg:1', kind = MessageKind.UI_ACK, payload = {} } = {}) {
  return {
    type: 'QUEUE_DELIVERY',
    deliveryId,
    deliverySequence,
    package: {
      packageId,
      sequence: 500 + deliverySequence,
      currentQueue: 'WIREUI.AP.OUT',
      createdAt: '2026-08-24T13:00:00Z',
      correlationId: null,
      payload: { type: kind, ...payload }
    }
  };
}

async function tick() { await new Promise((resolve) => setTimeout(resolve, 10)); }

async function makeGatewayComms(options = {}) {
  const transport = new QueueFabricGatewayTransport({
    url: 'ws://gateway',
    outboundQueue: 'WIREUI.AP.IN',
    WebSocketImpl: FakeWebSocket,
    ...options
  });
  const comms = new Comms({ transport, source: 'AP', destination: 'WIREUI.AP.IN' });
  await transport.start((env) => comms.receive(env));
  comms.connected = true;
  return { transport, comms, socket: FakeWebSocket.last };
}

test('gateway delivery is ACKed only after semantic handler completes', async () => {
  const { comms, socket } = await makeGatewayComms();
  const order = [];
  comms.on(MessageKind.UI_ACK, async () => {
    await new Promise((resolve) => setTimeout(resolve, 5));
    order.push('handled');
  });

  socket.inject(delivery({ deliveryId: 'delivery:77' }));
  await tick();

  const frames = socket.sent.map(JSON.parse);
  const ack = frames.find((x) => x.type === 'QUEUE_DELIVERY_ACK');
  assert.deepEqual(order, ['handled']);
  assert.equal(ack.deliveryId, 'delivery:77');
  assert.equal(ack.messageId, 'pkg:1');
});

test('semantic handler failure NACKs opaque delivery without exposing claim token', async () => {
  const { comms, socket } = await makeGatewayComms();
  let state = null;
  comms.onState((event) => { if (event.type === 'inbound-handler-error') state = event; });
  comms.on(MessageKind.UI_ACK, () => { throw new Error('semantic failure'); });

  socket.inject(delivery({ deliveryId: 'delivery:88' }));
  await tick();

  const frames = socket.sent.map(JSON.parse);
  const nack = frames.find((x) => x.type === 'QUEUE_DELIVERY_NACK');
  assert.equal(nack.deliveryId, 'delivery:88');
  assert.equal(nack.messageId, 'pkg:1');
  assert.equal(nack.reason, 'semantic failure');
  assert.equal('claimToken' in nack, false);
  assert.equal(state.messageId, 'pkg:1');
});

test('legacy gateway delivery without deliveryId remains compatible and emits no delivery ACK', async () => {
  const { comms, socket } = await makeGatewayComms();
  let handled = false;
  comms.on(MessageKind.UI_ACK, () => { handled = true; });
  const frame = delivery();
  delete frame.deliveryId;
  socket.inject(frame);
  await tick();
  assert.equal(handled, true);
  assert.equal(socket.sent.map(JSON.parse).some((x) => x.type === 'QUEUE_DELIVERY_ACK'), false);
});

test('required QUEUE_PUT result resolves with gateway package identity', async () => {
  const { transport, socket } = await makeGatewayComms({ putResultMode: 'required', putResultTimeoutMs: 1000 });
  const envelope = makeEnvelope({
    kind: MessageKind.UI_ACTION,
    payload: { action: 'ORDER.RETRY' },
    sequence: 1,
    source: 'AP', destination: 'WIREUI.AP.IN', messageId: 'browser:put:1'
  });

  const resultPromise = transport.send(envelope);
  const put = socket.sent.map(JSON.parse).find((x) => x.type === 'QUEUE_PUT');
  assert.equal(put.clientPutId, 'browser:put:1');
  socket.inject({ type: 'QUEUE_PUT_RESULT', clientPutId: 'browser:put:1', accepted: true, packageId: 'pkg:900' });
  const result = await resultPromise;
  assert.equal(result.accepted, true);
  assert.equal(result.packageId, 'pkg:900');
});

test('required QUEUE_PUT rejection propagates to sender', async () => {
  const { transport, socket } = await makeGatewayComms({ putResultMode: 'required', putResultTimeoutMs: 1000 });
  const envelope = makeEnvelope({
    kind: MessageKind.UI_ACTION,
    payload: { action: 'ORDER.RETRY' },
    sequence: 1,
    source: 'AP', destination: 'WIREUI.AP.IN', messageId: 'browser:put:2'
  });

  const resultPromise = transport.send(envelope);
  socket.inject({
    type: 'QUEUE_PUT_RESULT', clientPutId: 'browser:put:2', accepted: false,
    code: 'QUEUE_ACCESS_DENIED', detail: 'principal may not PUT'
  });
  await assert.rejects(resultPromise, /QUEUE_ACCESS_DENIED: principal may not PUT/);
});
