import test from 'node:test';
import assert from 'node:assert/strict';
import {
  Comms,
  CaptureTransport,
  DefinitionRegistry,
  MemoryRenderer,
  MessageKind,
  ObservationPlan,
  WireUIRuntime,
  makeEnvelope
} from '../src/index.js';

function inbound(kind, payload, sequence, messageId = `server:${sequence}`) {
  return makeEnvelope({
    kind,
    payload,
    sequence,
    source: 'server',
    destination: 'browser',
    messageId
  });
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
  id: 'SITE.CANCEL_BUTTON',
  version: 1,
  profileId: '*',
  root: 'root',
  nodes: [{ key: 'root', primitive: 'button' }],
  slots: [
    { index: 0, target: 'root', writer: 'text' },
    { index: 1, target: 'root', writer: 'enabled' }
  ],
  actions: [{ target: 'root', event: 'click', action: 'SERVICE.CANCEL.BEGIN' }]
};

test('Comms serialises inbound queue handling and reorders bounded gaps', async () => {
  const { comms } = makeComms();
  const seen = [];
  comms.on('X', async (payload) => {
    seen.push(`start${payload.n}`);
    await new Promise((resolve) => setTimeout(resolve, payload.n === 1 ? 10 : 0));
    seen.push(`end${payload.n}`);
  });

  comms.receive(inbound('X', { n: 2 }, 2));
  comms.receive(inbound('X', { n: 1 }, 1));
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.deepEqual(seen, ['start1', 'end1', 'start2', 'end2']);
});

test('subscriptions are direct queue control messages', async () => {
  const { comms, transport } = makeComms();
  await comms.activateSubscription('UI.ACCOUNT', { revision: 7, purpose: 'render-account' });
  assert.equal(transport.sent.at(-1).kind, MessageKind.SUBSCRIPTION_ACTIVATE);
  assert.deepEqual(transport.sent.at(-1).payload, { name: 'UI.ACCOUNT', revision: 7, purpose: 'render-account' });

  await comms.deactivateSubscription('UI.ACCOUNT');
  assert.equal(transport.sent.at(-1).kind, MessageKind.SUBSCRIPTION_DEACTIVATE);
});

test('disabled observation does not construct payload or send anything', async () => {
  const { comms, transport } = makeComms();
  const observations = new ObservationPlan({ comms });
  let called = false;
  const result = await observations.observe('UI.CART.HOVER', () => { called = true; return { x: 1 }; });
  assert.equal(result, false);
  assert.equal(called, false);
  assert.equal(transport.sent.length, 0);
});

test('enabled observation projects only registered fields', async () => {
  const { comms, transport } = makeComms();
  const observations = new ObservationPlan({ comms });
  observations.install({
    subscription: 'SERVICE.CONTEXT',
    revision: 3,
    points: [{ id: 'UI.ORDER.FAILURE', allowedFields: ['orderRef', 'failureClass'], purpose: 'SERVICE_RECOVERY' }]
  });
  await observations.observe('UI.ORDER.FAILURE', { orderRef: 'o:7', failureClass: 'payment', cardNumber: 'nope' });
  const event = transport.sent.at(-1);
  assert.equal(event.kind, MessageKind.INTERACTION_OBSERVATION);
  assert.deepEqual(event.payload.observation, { orderRef: 'o:7', failureClass: 'payment' });
});

test('snapshot installs live instances and patch performs direct slot mutation', async () => {
  const { comms } = makeComms();
  const definitions = new DefinitionRegistry();
  definitions.install(definition);
  const renderer = new MemoryRenderer({ definitions });
  const runtime = new WireUIRuntime({ comms, definitions, renderer });
  void runtime;

  comms.receive(inbound(MessageKind.UI_VIEW_SNAPSHOT, {
    viewRef: 'CustomerPanel', revision: 10, rootInstanceId: 1,
    instances: [{ instanceId: 1, definitionId: definition.id, definitionVersion: 1, slots: ['Cancel service', true] }]
  }, 1));
  await tick();
  assert.equal(renderer.getInstance(1).slots[0], 'Cancel service');

  comms.receive(inbound(MessageKind.UI_VIEW_PATCH, {
    viewRef: 'CustomerPanel', previousRevision: 10, newRevision: 11,
    operations: [{ op: 'SET_SLOT', instanceId: 1, slot: 1, value: false }]
  }, 2));
  await tick();
  assert.equal(renderer.getInstance(1).slots[1], false);
  assert.equal(runtime.revision, 11);
});

test('missing definition is requested before snapshot is applied', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  const renderer = new MemoryRenderer({ definitions });
  new WireUIRuntime({ comms, definitions, renderer });

  comms.receive(inbound(MessageKind.UI_VIEW_SNAPSHOT, {
    viewRef: 'CustomerPanel', revision: 1, rootInstanceId: 1,
    instances: [{ instanceId: 1, definitionId: definition.id, definitionVersion: 1, slots: [] }]
  }, 1));
  await tick();
  assert.equal(transport.sent.at(-1).kind, MessageKind.UI_DEFINITION_REQUIRED);
  assert.equal(renderer.getInstance(1), null);

  comms.receive(inbound(MessageKind.UI_DEFINITION, { definition }, 2));
  await tick();
  assert.ok(renderer.getInstance(1));
});


test('CREATE_INSTANCE waits for its exact definition without forcing resync', async()=>{
  const transport=new CaptureTransport(); const comms=new Comms({transport,source:'browser',destination:'server'});
  const definitions=new DefinitionRegistry(); definitions.install({id:'ROOT',version:1,profileId:'*',nodes:[{key:'root',primitive:'container'}],slots:[],actions:[]});
  const renderer=new MemoryRenderer({definitions}); const runtime=new WireUIRuntime({comms,definitions,renderer});
  await comms.connect();
  transport.inject(makeEnvelope({kind:MessageKind.UI_VIEW_SNAPSHOT,payload:{viewRef:'V',revision:1,rootInstanceId:'root',instances:[{instanceId:'root',definitionId:'ROOT',definitionVersion:1,slots:{}}]},sequence:1,source:'server',destination:'browser'}));
  await new Promise(r=>setTimeout(r,10));
  transport.inject(makeEnvelope({kind:MessageKind.UI_VIEW_PATCH,payload:{viewRef:'V',previousRevision:1,newRevision:2,operations:[{op:'CREATE_INSTANCE',instance:{instanceId:'child',definitionId:'CHILD',definitionVersion:1,parentInstanceId:'root',slots:{value:'hello'}}}]},sequence:2,source:'server',destination:'browser'}));
  transport.inject(makeEnvelope({kind:MessageKind.UI_VIEW_PATCH,payload:{viewRef:'V',previousRevision:2,newRevision:3,operations:[{op:'SET_SLOT',instanceId:'child',slot:'value',value:'updated'}]},sequence:3,source:'server',destination:'browser'}));
  await new Promise(r=>setTimeout(r,10));
  assert.equal(runtime.revision,1);
  assert.equal(transport.sent.some(e=>e.kind===MessageKind.UI_RESYNC_REQUEST),false);
  assert.equal(transport.sent.some(e=>e.kind===MessageKind.UI_DEFINITION_REQUIRED),true);
  transport.inject(makeEnvelope({kind:MessageKind.UI_DEFINITION,payload:{id:'CHILD',version:1,profileId:'*',nodes:[{key:'root',primitive:'text'}],slots:[{index:0,name:'value',target:'root',writer:'text'}],actions:[]},sequence:4,source:'server',destination:'browser'}));
  await new Promise(r=>setTimeout(r,20));
  assert.equal(runtime.revision,3);
  assert.equal(renderer.getInstance('child').slots.value,'updated');
});

test('revision gap requests resync and does not mutate view', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  definitions.install(definition);
  const renderer = new MemoryRenderer({ definitions });
  const runtime = new WireUIRuntime({ comms, definitions, renderer });

  comms.receive(inbound(MessageKind.UI_VIEW_SNAPSHOT, {
    viewRef: 'v', revision: 5, rootInstanceId: 1,
    instances: [{ instanceId: 1, definitionId: definition.id, slots: ['Before', true] }]
  }, 1));
  await tick();

  comms.receive(inbound(MessageKind.UI_VIEW_PATCH, {
    viewRef: 'v', previousRevision: 6, newRevision: 7,
    operations: [{ op: 'SET_SLOT', instanceId: 1, slot: 0, value: 'Wrong' }]
  }, 2));
  await tick();

  assert.equal(renderer.getInstance(1).slots[0], 'Before');
  assert.equal(runtime.waitingForResync, true);
  assert.equal(transport.sent.at(-1).kind, MessageKind.UI_RESYNC_REQUEST);
  assert.equal(transport.sent.at(-1).payload.haveRevision, 5);
});

test('semantic browser action carries the rendered revision', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  definitions.install(definition);
  const renderer = new MemoryRenderer({ definitions });
  new WireUIRuntime({ comms, definitions, renderer });

  comms.receive(inbound(MessageKind.UI_VIEW_SNAPSHOT, {
    viewRef: 'v', revision: 12, rootInstanceId: 1,
    instances: [{ instanceId: 1, definitionId: definition.id, slots: ['Cancel', true] }]
  }, 1));
  await tick();
  renderer.emitAction(1, 'SERVICE.CANCEL.BEGIN');
  await tick();

  const action = transport.sent.at(-1);
  assert.equal(action.kind, MessageKind.UI_ACTION);
  assert.deepEqual(action.payload, {
    viewRef: 'v', renderedRevision: 12, elementInstance: 1,
    action: 'SERVICE.CANCEL.BEGIN', detail: {}
  });
});

test('published definitions are immutable', () => {
  const definitions = new DefinitionRegistry();
  definitions.install(definition);
  assert.throws(() => definitions.install({ ...definition, nodes: [{ key: 'root', primitive: 'text' }] }), /immutable definition conflict/);
});

class FakeNode {
  constructor(tag) {
    this.tagName = tag.toUpperCase();
    this.children = [];
    this.attributes = new Map();
    this.listeners = new Map();
    this.textContent = '';
    this.hidden = false;
    this.disabled = false;
    this.value = '';
    this.className = '';
    this.parent = null;
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  removeAttribute(name) { this.attributes.delete(name); }
  addEventListener(name, handler) { this.listeners.set(name, handler); }
  appendChild(child) { child.remove(); child.parent = this; this.children.push(child); }
  insertBefore(child, before) {
    child.remove(); child.parent = this;
    const i = this.children.indexOf(before);
    if (i < 0) this.children.push(child); else this.children.splice(i, 0, child);
  }
  replaceChildren(...children) {
    for (const child of this.children) child.parent = null;
    this.children = [];
    for (const child of children) this.appendChild(child);
  }
  remove() {
    if (!this.parent) return;
    this.parent.children = this.parent.children.filter((child) => child !== this);
    this.parent = null;
  }
  fire(name) { this.listeners.get(name)?.({ currentTarget: this }); }
}

class FakeDocument {
  createElement(tag) { return new FakeNode(tag); }
}

// BrowserRenderer is imported lazily so the primary runtime tests remain renderer-neutral.
test('browser renderer precompiles subscribed definition before live snapshot and uses direct writers', async () => {
  const { BrowserRenderer } = await import('../src/index.js');
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  const document = new FakeDocument();
  const mount = new FakeNode('mount');
  const renderer = new BrowserRenderer({ definitions, mount, document });
  new WireUIRuntime({ comms, definitions, renderer });

  comms.receive(inbound(MessageKind.UI_DEFINITION, { definition, subscription: 'UI.ACCOUNT' }, 1));
  await tick();
  assert.equal(renderer.compiled.has(`${definition.id}@1`), true);

  comms.receive(inbound(MessageKind.UI_VIEW_SNAPSHOT, {
    viewRef: 'v', revision: 1, rootInstanceId: 7,
    instances: [{ instanceId: 7, definitionId: definition.id, slots: ['Cancel service', true] }]
  }, 2));
  await tick();

  const live = renderer.instances.get(7);
  assert.equal(live.root.textContent, 'Cancel service');
  assert.equal(live.root.disabled, false);

  comms.receive(inbound(MessageKind.UI_VIEW_PATCH, {
    viewRef: 'v', previousRevision: 1, newRevision: 2,
    operations: [{ op: 'SET_SLOT', instanceId: 7, slot: 1, value: false }]
  }, 3));
  await tick();
  assert.equal(live.root.disabled, true);

  live.root.fire('click');
  await tick();
  assert.equal(transport.sent.at(-1).kind, MessageKind.UI_ACTION);
  assert.equal(transport.sent.at(-1).payload.renderedRevision, 2);
});
