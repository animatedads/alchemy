import assert from 'node:assert/strict';
import {wire3dProjectionOpenGL,wire3dTransformPoint,wire3dProjectPoint} from '../web/wire3d.js';
const I=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
const T=[1,0,0,0,0,1,0,0,0,0,1,0,3,4,5,1];
assert.deepEqual(wire3dTransformPoint(T,[0,0,0,1]),[3,4,5,1]);
const P=wire3dProjectionOpenGL(60,1,0.1,100);
let near=wire3dTransformPoint(P,[0,0,-0.1,1]);
let far=wire3dTransformPoint(P,[0,0,-100,1]);
assert.ok(Math.abs(near[2]/near[3]+1)<1e-12);
assert.ok(Math.abs(far[2]/far[3]-1)<1e-12);
assert.deepEqual(wire3dProjectPoint(I,I,P,[0,0,1,1]),null);
console.log('PASS test_renderer_math');

// dev21 presentation-navigation qualification: local navigation may alter the view
// presented by the renderer, but must not mutate the Maths-supplied scene matrices.
const {wire3dMultiply,wire3dPresentationNavigation}=await import('../web/wire3d.js');
const ident=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
const nav0=wire3dPresentationNavigation(0,0,0);
assert.deepEqual(nav0.world,ident,'zero navigation world transform is identity');
assert.deepEqual(nav0.eye,ident,'zero navigation eye transform is identity');
const nav=wire3dPresentationNavigation(Math.PI/2,0,2);
assert.equal(nav.eye[14],2,'dolly is presentation-space eye translation');
const combined=wire3dMultiply(nav.eye,wire3dMultiply(ident,nav.world));
assert.equal(combined[14],2,'presentation navigation composes without changing authoritative input view');
console.log('PASS presentation navigation transform');

// dev22 tracking-field determinism is intentionally renderer-owned.
const {Wire3DRenderer}=await import('../web/wire3d.js');
const fake=Object.create(Wire3DRenderer.prototype);
const field={version:'wire3d-tracking/1',seed:'4A91C37D',starCount:64,majorDivisions:8,minorDivisions:32};
const a=fake._trackingVertices(field),b=fake._trackingVertices(field),c=fake._trackingVertices({...field,seed:'4A91C37E'});
assert.deepEqual([...a],[...b],'same field identity reconstructs exactly');
assert.notDeepEqual([...a],[...c],'different seed changes spatial identity');
assert.ok(a.length>64*3,'field contains registration geometry plus stars');
console.log('PASS deterministic tracking field');
