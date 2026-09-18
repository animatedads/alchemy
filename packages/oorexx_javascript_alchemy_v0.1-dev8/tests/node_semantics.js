'use strict';
const assert = require('assert');
const {Animal, Dog, makeFixture} = require('../javascript/semantic_fixture');
(async () => {
  const f = makeFixture();
  assert.strictEqual(f.dog.self(), f.dog);
  assert.strictEqual(f.dog instanceof Dog, true);
  assert.strictEqual(f.dog instanceof Animal, true);
  assert.strictEqual(Object.getPrototypeOf(Dog.prototype), Animal.prototype);
  assert.strictEqual(f.dog.greet(), 'hello Ada');
  assert.strictEqual(f.dog.greet('hi'), 'hi Ada');
  assert.strictEqual(f.collection[3], null);
  assert.strictEqual(f.collection[4], undefined);
  assert.strictEqual(f.callback(f.dog, x => x.self()), f.dog);
  assert.strictEqual(await f.promiseValue(), f.dog);
  let e; try { f.thrower(); } catch (x) { e = x; }
  assert(e instanceof TypeError); assert.strictEqual(e.message, 'fixture-boom');
  console.log('PASS identity');
  console.log('PASS prototype-authority');
  console.log('PASS omitted-null-undefined-semantics');
  console.log('PASS callback-reentry-shape');
  console.log('PASS promise-identity');
  console.log('PASS exception-authority');
})();
