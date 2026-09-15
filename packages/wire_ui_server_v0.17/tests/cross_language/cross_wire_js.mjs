import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const jsSrc = process.env.WIRE_UI_JS_SRC;
if (!jsSrc) throw new Error('WIRE_UI_JS_SRC must point to Alchemy Wire UI JS v0.3.1 package root');
const api = await import(pathToFileURL(path.join(jsSrc, 'src/index.js')).href);
const { CaptureTransport, Comms, WireUIJourneyController, WireUIRuntime, DefinitionRegistry, MemoryRenderer, envelopeToQueuePayload, adaptServerDefinition } = api;

const rex = process.env.REXX || 'rexx';
const serverScript = path.join(path.dirname(new URL(import.meta.url).pathname), 'cross_wire_server.rex');
function runServer(args) {
  const p = spawnSync(rex, [serverScript, ...args], { encoding: 'utf8', env: process.env });
  if (p.status !== 0) throw new Error(`ooRexx cross-wire failed (${p.status}): ${p.stdout}\n${p.stderr}`);
  return p.stdout.trim().split(/\r?\n/).filter(Boolean);
}
function tagged(lines, tag) {
  return lines.filter((l) => l.startsWith(tag + ' ')).map((l) => l.slice(tag.length + 1));
}
function makeComms() {
  const transport = new CaptureTransport();
  const comms = new Comms({ transport, source: 'OLA-AP', destination: 'WIREUI.IN.OLA-AP' });
  transport.start((envelope) => comms.receive(envelope));
  comms.connected = true;
  return { comms, transport };
}

// 1. Real ooRexx objects author the canonical plan and profile offer.
const emitted = runServer(['emit']);
const plan = JSON.parse(tagged(emitted, 'PLAN')[0]);
const offer = JSON.parse(tagged(emitted, 'OFFER')[0]);
assert.equal(plan.type, 'UI_JOURNEY_PLAN');
assert.equal(plan.active[0].name, 'UI.SEARCH');
assert.equal(plan.onDemand[0].capability, 'INSURANCE_TERMS');
assert.equal(offer.profiles[1], 'AI_AGENT_OPTIMISED');

// 2. JS installs ACTIVE/PREFETCH exactly as server planned.
const { comms, transport } = makeComms();
const definitions = new DefinitionRegistry();
const renderer = new MemoryRenderer({ definitions });
const runtime = new WireUIRuntime({
  comms, definitions, renderer,
  ownership: { applicationId: 'OLA-APP', sessionId: 'OLA-SESSION', accessPointId: 'OLA-AP' }
});
const journey = new WireUIJourneyController({ comms, runtime });
await journey.installPlan(plan);
assert.equal(comms.getSubscription('UI.SEARCH').state, 'pending-active');
assert.equal(comms.getSubscription('UI.FLIGHT_OFFERS').state, 'pending-active');
assert.equal(comms.getSubscription('UI.INSURANCE.TERMS'), null);

// 3. JS creates canonical ON_DEMAND request; real ooRexx validates exact mapping.
transport.sent.length = 0;
await journey.requestOnDemand('INSURANCE_TERMS', { reason: 'cross-wire-customer-request' });
const odEnvelope = transport.sent.at(-1);
const od = envelopeToQueuePayload(odEnvelope);
const odResult = runServer(['ondemand', od.planId, String(od.planRevision), od.capability, od.subscription]);
assert.match(odResult.at(-1), /^RESULT ON_DEMAND_ACTIVATED 1$/);

// 4. Real server offer -> JS semantic UI_ACTION -> real server profile transition.
journey.installProfileOffer(offer);
runtime.viewRef = offer.viewRef;
runtime.revision = Number(offer.revision);
transport.sent.length = 0;
await journey.selectInteractionProfile(offer.offerId, 'AI_AGENT_OPTIMISED', { agentRef: 'CROSS-WIRE-AGENT' });
const actionEnvelope = transport.sent.at(-1);
const semantic = envelopeToQueuePayload(actionEnvelope, {
  applicationId: 'OLA-APP', sessionId: 'OLA-SESSION', accessPointId: 'OLA-AP'
});
assert.equal(semantic.detail.profileId, 'AI_AGENT_OPTIMISED');
const profileLines = runServer(['profile', semantic.detail.offerId, semantic.detail.profileId, String(semantic.renderedRevision)]);
assert.ok(profileLines.some((l) => l === 'RESULT AI_AGENT_OPTIMISED AI_SEARCH'));

// 5. Server's machine-semantic definitions really compile in JS v0.3.1.
const defs = tagged(profileLines, 'DEF').map(JSON.parse);
assert.equal(defs.length, 2);
const compiled = defs.map(adaptServerDefinition);
assert.ok(compiled.some((d) => d.semantic.sourcePrimitive === 'SEMANTIC_RECORD'));
assert.ok(compiled.some((d) => d.semantic.sourcePrimitive === 'SEMANTIC_COLLECTION'));
assert.ok(compiled.every((d) => d.definitionKey.endsWith('@1')));
for (const d of compiled) definitions.install(d);
renderer.reset();
renderer.createInstance({ instanceId: 'agent-search-state', definitionId: 'AGENT_SEARCH_STATE', definitionVersion: 1, parentInstanceId: null, slots: { visible: true } });
renderer.createInstance({ instanceId: 'agent-offer-set', definitionId: 'AGENT_OFFER_SET', definitionVersion: 1, parentInstanceId: 'agent-search-state', slots: { visible: true } });
renderer.setRoot('agent-search-state');
assert.equal(renderer.getInstance('agent-offer-set').parentInstanceId, 'agent-search-state');
assert.equal(renderer.getInstance('agent-search-state').slots.visible, true);
console.log('PASS ooRexx <-> configured JS runtime OurLadyAir cross-wire integration');
