import test from 'node:test';
import assert from 'node:assert/strict';
import {
  adaptServerDefinition,
  adaptServerInstance,
  envelopeToQueuePayload,
  makeEnvelope,
  MessageKind
} from '../src/index.js';

const v03Primitives = [
  ['PANEL', 'container'],
  ['FORM', 'form'],
  ['MODE_SWITCH_OFFER', 'button'],
  ['OFFER_LIST', 'list'],
  ['OFFER_SELECTOR', 'list'],
  ['DOCUMENT', 'document'],
  ['SEMANTIC_RECORD', 'semantic-record'],
  ['SEMANTIC_COLLECTION', 'list']
];

test('Wire UI Server v0.3 primitive vocabulary is precompilable', () => {
  for (const [serverPrimitive, browserPrimitive] of v03Primitives) {
    const definition = adaptServerDefinition({
      definitionId: `D_${serverPrimitive}`,
      version: '1',
      primitive: serverPrimitive,
      action: serverPrimitive === 'FORM' ? 'FLIGHT.SEARCH.SUBMIT' : ''
    });
    assert.equal(definition.nodes[0].primitive, browserPrimitive, serverPrimitive);
  }
});

test('FORM semantic action compiles as submit rather than click', () => {
  const definition = adaptServerDefinition({
    definitionId: 'OLA_SEARCH_FORM', version: '1', primitive: 'FORM', action: 'FLIGHT.SEARCH.SUBMIT'
  });
  assert.equal(definition.actions.length, 1);
  assert.equal(definition.actions[0].event, 'submit');
  assert.equal(definition.actions[0].preventDefault, true);
});

test('Builder exact definitionVersion/definitionKey survives compatibility adaptation', () => {
  const definition = adaptServerDefinition({
    definitionId: 'OLA_SEARCH_FORM', definitionVersion: 2, definitionKey: 'OLA_SEARCH_FORM@2',
    primitive: 'FORM', profile: 'HUMAN_VISUAL', contentAddress: 'builder-token-2',
    semanticElementRef: { kind: 'ELEMENT', id: 'FLIGHT_SEARCH', version: 1 },
    projectionRef: { kind: 'PROJECTION', id: 'SEARCH_FORM', version: 2 },
    componentRef: { kind: 'COMPONENT', id: 'FORM', version: 1 },
    bindings: { origin: 'origin' }
  });
  assert.equal(definition.id, 'OLA_SEARCH_FORM');
  assert.equal(definition.version, 2);
  assert.equal(definition.definitionKey, 'OLA_SEARCH_FORM@2');
  assert.equal(definition.profileId, 'HUMAN_VISUAL');
  assert.equal(definition.semantic.projectionRef.id, 'SEARCH_FORM');
  assert.deepEqual(definition.semantic.bindings, { origin: 'origin' });

  const instance = adaptServerInstance({
    instanceId: 'search', definitionKey: 'OLA_SEARCH_FORM@2', parentId: '', slots: { visible: true }
  });
  assert.equal(instance.definitionId, 'OLA_SEARCH_FORM');
  assert.equal(instance.definitionVersion, 2);
  assert.equal(instance.definitionKey, 'OLA_SEARCH_FORM@2');
});

test('AI profile selection projects profileId to Wire UI Server v0.3 top-level profile field', () => {
  const envelope = makeEnvelope({
    kind: MessageKind.UI_ACTION,
    sequence: 1,
    source: 'AP-1', destination: 'WIREUI.IN.AP-1', messageId: 'agent-select-1',
    payload: {
      applicationId: 'OLA-APP', sessionId: 'OLA-SESSION', accessPointId: 'OLA-AP',
      viewRef: 'OurLadyAir.Booking', renderedRevision: 7,
      elementInstance: 'agentOffer', action: 'INTERACTION.PROFILE.SELECT',
      detail: { offerId: 'agent-offer', profileId: 'AI_AGENT_OPTIMISED', agentRef: 'AGENT-7' }
    }
  });
  const semantic = envelopeToQueuePayload(envelope);
  assert.equal(semantic.profile, 'AI_AGENT_OPTIMISED');
  assert.equal(semantic.detail.offerId, 'agent-offer');
  assert.equal(semantic.detail.agentRef, 'AGENT-7');
});
