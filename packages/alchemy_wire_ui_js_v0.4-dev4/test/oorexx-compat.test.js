import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CaptureTransport,
  Comms,
  DefinitionRegistry,
  MemoryRenderer,
  MessageKind,
  WireUIRuntime,
  adaptServerDefinition,
  adaptServerSnapshot,
  envelopeToQueuePayload,
  queuePackageToEnvelope
} from '../src/index.js';

async function tick() { await new Promise((resolve) => setTimeout(resolve, 10)); }

const serverButton = {
  definitionId: 'CANCEL_SERVICE_ACTION',
  version: '1',
  primitive: 'ACTION_BUTTON',
  action: 'SERVICE.CANCEL.BEGIN',
  label: 'Cancel service',
  styleRole: 'secondary_destructive',
  contentAddress: 'wui01-abc'
};

test('QueueWorkPackage metadata becomes the Comms direct envelope', () => {
  const env = queuePackageToEnvelope({
    packageId: 'pkg-7', sequence: 41, correlationId: 'c-9', createdAt: '2026-08-24T10:00:00Z',
    sourceQueue: 'SERVER', currentQueue: 'WIREUI.OUT.AP-1',
    payload: { type: 'UI_VIEW_PATCH', protocolVersion: 'WIRE-UI/0.1', viewRef: 'v', previousRevision: 1, newRevision: 2, operations: [] }
  });
  assert.equal(env.messageId, 'pkg-7');
  assert.equal(env.sequence, 41);
  assert.equal(env.kind, MessageKind.UI_VIEW_PATCH);
  assert.equal(env.payload.viewRef, 'v');
});

test('browser envelope flattens to WireUIApplication semantic action shape', async () => {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'browser', destination: 'server' });
  transport.start((e) => comms.receive(e));
  comms.connected = true;
  const env = await comms.send(MessageKind.UI_ACTION, { viewRef: 'CustomerPanel', renderedRevision: 3, elementInstance: 'cancel', action: 'SERVICE.CANCEL.BEGIN' });
  const semantic = envelopeToQueuePayload(env, { applicationId: 'APP-1', sessionId: 'SESSION-1', accessPointId: 'AP-1' });
  assert.equal(semantic.type, 'UI_ACTION');
  assert.equal(semantic.messageId, env.messageId);
  assert.equal(semantic.applicationId, 'APP-1');
  assert.equal(semantic.elementInstance, 'cancel');
});

test('current ooRexx simple element definition precompiles into browser definition', () => {
  const d = adaptServerDefinition(serverButton);
  assert.equal(d.id, 'CANCEL_SERVICE_ACTION');
  assert.equal(d.nodes[0].primitive, 'button');
  assert.equal(d.actions[0].action, 'SERVICE.CANCEL.BEGIN');
  assert.ok(d.slots.some((s) => s.name === 'enabled'));
});

test('ooRexx semantic snapshot uses named slots without losing direct writer path', async () => {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'browser', destination: 'server' });
  transport.start((e) => comms.receive(e));
  comms.connected = true;
  const definitions = new DefinitionRegistry();
  definitions.install(adaptServerDefinition(serverButton));
  const renderer = new MemoryRenderer({ definitions });
  const runtime = new WireUIRuntime({
    comms, definitions, renderer, serverSemantic: true,
    ownership: { applicationId: 'APP-1', sessionId: 'SESSION-1', accessPointId: 'AP-1' }
  });
  void runtime;

  const snap = adaptServerSnapshot({
    viewRef: 'CustomerPanel', revision: 0, rootInstance: 'cancel',
    elementInstances: [{ instanceId: 'cancel', definitionId: 'CANCEL_SERVICE_ACTION', parentId: '', slots: { action: 'SERVICE.CANCEL.BEGIN', enabled: true } }]
  });
  await runtime['dummy']; // no-op; keeps test intention explicit
  assert.equal(snap.instances[0].slots.action, undefined);
  assert.equal(snap.instances[0].slots.enabled, true);
});

test('end-to-end current ooRexx semantic definition/snapshot/patch/action contract', async () => {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'AP-1', destination: 'WIREUI.IN.AP-1' });
  transport.start((e) => comms.receive(e));
  comms.connected = true;
  const definitions = new DefinitionRegistry();
  const renderer = new MemoryRenderer({ definitions });
  new WireUIRuntime({
    comms, definitions, renderer, serverSemantic: true,
    ownership: { applicationId: 'APP-1', sessionId: 'SESSION-1', accessPointId: 'AP-1' }
  });

  comms.receive({
    protocolVersion: 1, messageId: 'pkg:def', kind: MessageKind.UI_DEFINITION, sequence: 1,
    source: 'WIREUI.DEF.AP-1', destination: 'AP-1', correlationId: null, sentAt: new Date().toISOString(),
    payload: serverButton
  });
  await tick();
  assert.ok(definitions.has('CANCEL_SERVICE_ACTION', 1));

  comms.receive({
    protocolVersion: 1, messageId: 'pkg:snap', kind: MessageKind.UI_VIEW_SNAPSHOT, sequence: 2,
    source: 'WIREUI.OUT.AP-1', destination: 'AP-1', correlationId: null, sentAt: new Date().toISOString(),
    payload: {
      viewRef: 'CustomerPanel', revision: 0, rootInstance: 'cancel',
      elementInstances: [{
        instanceId: 'cancel', definitionId: 'CANCEL_SERVICE_ACTION', parentId: '',
        slots: { action: 'SERVICE.CANCEL.BEGIN', enabled: true }
      }]
    }
  });
  await tick();
  assert.equal(renderer.getInstance('cancel').slots.enabled, true);

  comms.receive({
    protocolVersion: 1, messageId: 'pkg:patch', kind: MessageKind.UI_VIEW_PATCH, sequence: 3,
    source: 'WIREUI.OUT.AP-1', destination: 'AP-1', correlationId: null, sentAt: new Date().toISOString(),
    payload: {
      viewRef: 'CustomerPanel', previousRevision: 0, newRevision: 1,
      operations: [{ op: 'SET_SLOT', instanceId: 'cancel', slot: 'enabled', value: false }]
    }
  });
  await tick();
  assert.equal(renderer.getInstance('cancel').slots.enabled, false);

  renderer.emitAction('cancel', 'SERVICE.CANCEL.BEGIN');
  await tick();
  const actionEnvelope = transport.sent.at(-1);
  assert.equal(actionEnvelope.kind, MessageKind.UI_ACTION);
  assert.equal(actionEnvelope.payload.applicationId, 'APP-1');
  assert.equal(actionEnvelope.payload.sessionId, 'SESSION-1');
  assert.equal(actionEnvelope.payload.accessPointId, 'AP-1');
  assert.equal(actionEnvelope.payload.renderedRevision, 1);

  const semantic = envelopeToQueuePayload(actionEnvelope);
  assert.equal(semantic.type, 'UI_ACTION');
  assert.equal(semantic.applicationId, 'APP-1');
  assert.equal(semantic.viewRef, 'CustomerPanel');
  assert.equal(semantic.elementInstance, 'cancel');
});
