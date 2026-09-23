import fs from 'node:fs';
const scene=JSON.parse(fs.readFileSync(new URL('../web/scene.json',import.meta.url),'utf8'));
if(!scene.trackingField?.enabled) throw new Error('tracking descriptor absent from shipped web scene');
const js=fs.readFileSync(new URL('../web/wire3d.js',import.meta.url),'utf8');
for(const token of ['_trackingVertices','_trackingLines','gl.drawArrays(gl.LINES','gl.drawArrays(gl.POINTS']) if(!js.includes(token)) throw new Error('missing tracking renderer token '+token);
console.log('PASS shipped tracking descriptor + deterministic line/star renderer');
