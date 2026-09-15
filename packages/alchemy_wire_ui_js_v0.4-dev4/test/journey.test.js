import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CaptureTransport,
  Comms,
  MessageKind,
  WireUIJourneyController,
  WireUIRuntime,
  DefinitionRegistry,
  MemoryRenderer
} from '../src/index.js';

function makeComms() {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'AP-1', destination: 'SERVER' });
  transport.start((envelope) => comms.receive(envelope));
  comms.connected = true;
  return { comms, transport };
}

test('differential subscription reconciliation sends only the delta', async () => {
  const { comms, transport } = makeComms();

  await comms.reconcileSubscriptions([
    { name: 'UI.SEARCH', revision: 1 },
    { name: 'UI.OFFERS', revision: 3 }
  ]);
  assert.deepEqual(transport.sent.map((m) => [m.kind, m.payload.name]), [
    [MessageKind.SUBSCRIPTION_ACTIVATE, 'UI.SEARCH'],
    [MessageKind.SUBSCRIPTION_ACTIVATE, 'UI.OFFERS']
  ]);

  transport.sent.length = 0;
  await comms.reconcileSubscriptions([
    { name: 'UI.OFFERS', revision: 3 },
    { name: 'UI.BAGS', revision: 1 }
  ]);
  assert.deepEqual(transport.sent.map((m) => [m.kind, m.payload.name]), [
    [MessageKind.SUBSCRIPTION_DEACTIVATE, 'UI.SEARCH'],
    [MessageKind.SUBSCRIPTION_ACTIVATE, 'UI.BAGS']
  ]);
});

test('journey plan activates ACTIVE/PREFETCH but leaves ON_DEMAND dormant', async () => {
  const { comms, transport } = makeComms();
  const journey = new WireUIJourneyController({ comms });

  await journey.installPlan({
    planId: 'PLAN-7',
    revision: 4,
    journeyRef: 'BOOKING-1',
    active: [{ name: 'UI.SEARCH', revision: 2 }],
    prefetch: [{ name: 'UI.OFFERS', revision: 8 }],
    onDemand: [{ capability: 'SEAT_PICKER', name: 'UI.SEATS', revision: 5 }]
  });

  assert.equal(comms.getSubscription('UI.SEARCH').state, 'pending-active');
  assert.equal(comms.getSubscription('UI.OFFERS').state, 'pending-active');
  assert.equal(comms.getSubscription('UI.SEATS'), null);
  assert.equal(journey.listOnDemand()[0].capability, 'SEAT_PICKER');
  assert.equal(transport.sent.filter((m) => m.kind === MessageKind.SUBSCRIPTION_ACTIVATE).length, 2);
});

test('explicit ON_DEMAND request names exactly one offered capability', async () => {
  const { comms, transport } = makeComms();
  const journey = new WireUIJourneyController({ comms });
  await journey.installPlan({
    planId: 'PLAN-8', revision: 1,
    onDemand: [
      { capability: 'SEAT_PICKER', name: 'UI.SEATS', revision: 5 },
      { capability: 'BAG_OPTIONS', name: 'UI.BAGS', revision: 2 }
    ]
  });
  transport.sent.length = 0;

  await journey.requestOnDemand('SEAT_PICKER', { reason: 'customer-selected-seat-choice' });
  assert.equal(transport.sent.length, 1);
  assert.equal(transport.sent[0].kind, MessageKind.UI_ON_DEMAND_REQUEST);
  assert.equal(transport.sent[0].payload.capability, 'SEAT_PICKER');
  assert.equal(transport.sent[0].payload.subscription, 'UI.SEATS');
  await assert.rejects(() => journey.requestOnDemand('NOT_OFFERED'), /not offered/);
});

test('interaction profile selection is explicit UI_ACTION and carries offer evidence', async () => {
  const { comms, transport } = makeComms();
  const definitions = new DefinitionRegistry();
  const renderer = new MemoryRenderer({ definitions });
  const runtime = new WireUIRuntime({
    comms, definitions, renderer,
    ownership: { applicationId: 'APP-1', sessionId: 'S-1', accessPointId: 'AP-1' }
  });
  runtime.viewRef = 'SEARCH';
  runtime.revision = 12;
  const journey = new WireUIJourneyController({ comms, runtime });

  journey.installProfileOffer({
    offerId: 'OFFER-1',
    profiles: ['HUMAN_VISUAL', 'AI_AGENT_OPTIMISED'],
    elementInstance: 'profile-offer',
    viewRef: 'SEARCH',
    revision: 12,
    purpose: 'AUTHORISED_MACHINE_INTERACTION'
  });

  await journey.selectInteractionProfile('OFFER-1', 'AI_AGENT_OPTIMISED', { agentRef: 'AGENT-7' });
  const message = transport.sent.at(-1);
  assert.equal(message.kind, MessageKind.UI_ACTION);
  assert.equal(message.payload.action, 'INTERACTION.PROFILE.SELECT');
  assert.equal(message.payload.renderedRevision, 12);
  assert.equal(message.payload.elementInstance, 'profile-offer');
  assert.equal(message.payload.detail.offerId, 'OFFER-1');
  assert.equal(message.payload.detail.profileId, 'AI_AGENT_OPTIMISED');
  assert.equal(message.payload.detail.agentRef, 'AGENT-7');
});

test('journey plan replacement reconciles subscriptions rather than tear down/rebuild', async () => {
  const { comms, transport } = makeComms();
  const journey = new WireUIJourneyController({ comms });

  await journey.installPlan({
    planId: 'P1', revision: 1,
    active: ['UI.SEARCH'],
    prefetch: ['UI.OFFERS']
  });
  transport.sent.length = 0;

  await journey.installPlan({
    planId: 'P2', revision: 2,
    active: ['UI.OFFERS'],
    prefetch: ['UI.BAGS']
  });

  assert.deepEqual(transport.sent.map((m) => [m.kind, m.payload.name]), [
    [MessageKind.SUBSCRIPTION_DEACTIVATE, 'UI.SEARCH'],
    [MessageKind.SUBSCRIPTION_ACTIVATE, 'UI.BAGS']
  ]);
});
