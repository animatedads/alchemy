import { performance } from 'node:perf_hooks';
import { DefinitionRegistry, MemoryRenderer } from '../src/index.js';

const definition = {
  id: 'BENCH.STATUS', version: 1, profileId: '*', root: 'root',
  nodes: [{ key: 'root', primitive: 'text' }],
  slots: [{ index: 0, name: 'value', target: 'root', writer: 'text' }],
  actions: []
};

const definitions = new DefinitionRegistry();
definitions.install(definition);
const renderer = new MemoryRenderer({ definitions });
renderer.createInstance({ instanceId: 1, definitionId: definition.id, definitionVersion: 1, slots: ['0'] });

const iterations = Number(process.argv[2] ?? 250000);
const start = performance.now();
for (let i = 0; i < iterations; i += 1) renderer.setSlot(1, 0, i);
const elapsed = performance.now() - start;

console.log(JSON.stringify({
  benchmark: 'direct-slot-mutation',
  iterations,
  elapsedMs: Number(elapsed.toFixed(3)),
  mutationsPerSecond: Math.round(iterations / (elapsed / 1000))
}, null, 2));
