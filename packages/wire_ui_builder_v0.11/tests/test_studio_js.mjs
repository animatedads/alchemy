import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const jsSrc=process.env.WIRE_UI_JS_SRC;
if(!jsSrc) throw new Error('WIRE_UI_JS_SRC required');
const studioPath=process.env.WIRE_UI_BUILDER_STUDIO_JSON ?? path.resolve('../studio/wire_ui_builder_studio_v0.11.json');
const {adaptServerDefinition}=await import(pathToFileURL(path.join(jsSrc,'server-semantic-adapter.js')).href);
const pkg=JSON.parse(fs.readFileSync(studioPath,'utf8'));
if(!pkg.releaseRef?.contentAddress) throw new Error('Studio release is not sealed');
if(pkg.definitions.length!==23) throw new Error(`expected 23 Studio definitions, got ${pkg.definitions.length}`);
const defs=new Map(pkg.definitions.map(d=>[d.definitionKey,adaptServerDefinition(d)]));
for(const key of ['WUIB_COMPONENT_EDITOR@1','WUIB_ELEMENT_EDITOR@1','WUIB_PROJECTION_EDITOR@1','WUIB_MATERIAL_EDITOR@1','WUIB_JOURNEY_EDITOR@1','WUIB_EXPERIMENT_EDITOR@1','WUIB_PUBLISH@1']){
  if(!defs.has(key)) throw new Error(`missing ${key}`);
  const def=defs.get(key);
  if(!def.nodes.some(n=>n.primitive==='form')) throw new Error(`${key} is not renderable as a form`);
  if(def.actions.length!==1) throw new Error(`${key} missing semantic action`);
}
if(defs.get('WUIB_COMPONENT_EDITOR@1').actions[0].action!=='DESIGN.COMPONENT.DRAFT') throw new Error('component editor action mismatch');
for(const key of ['WUIB_SOURCE_FILES@1','WUIB_SOURCE_WINDOW_CONTROL@1','WUIB_SOURCE_ROW@1']) if(!defs.has(key)) throw new Error(`source workspace definition missing ${key}`);
if(defs.get('WUIB_SOURCE_WINDOW_CONTROL@1').actions[0]?.action!=='SOURCE.WINDOW') throw new Error('source window action mismatch');
if(defs.get('WUIB_SOURCE_ROW@1').actions[0]?.action!=='SOURCE.OPEN') throw new Error('source row action mismatch');
const sourceDetailRaw=pkg.definitions.find(d=>d.definitionKey==='WUIB_SOURCE_DETAIL@1');
for(const field of ['attributes','constants','requires','packageOptions','queryRevision','scopeRevision','selectionRevision']){
  if(sourceDetailRaw?.bindings?.[field]!==field) throw new Error(`source detail missing ${field} binding`);
}
if((pkg.compositions??[]).length!==6) throw new Error('expected six Studio compositions');
for(const key of ['WUIB_COMPOSITION_EDITOR@1','WUIB_PREVIEW_CONTROL@1']){ const def=defs.get(key); if(!def?.nodes.some(n=>n.primitive==='form')) throw new Error(`${key} is not a form`); }
const canvas=defs.get('WUIB_COMPOSITION_CANVAS@1'); if(!canvas) throw new Error('composition canvas definition missing');
if(canvas.actions[0]?.action!=='COMPOSITION.SELECT') throw new Error('composition canvas action mismatch');
const rawCanvas=pkg.definitions.find(d=>d.definitionKey==='WUIB_COMPOSITION_CANVAS@1');
if(!Array.isArray(rawCanvas?.metadata?.compositionHints)||rawCanvas.metadata.compositionHints.length!==1) throw new Error('canvas lacks compiled composition hint');
for(const key of ['WUIB_TOOL_NAV@1','WUIB_ARTIFACT_LIBRARY@1','WUIB_SELECTION_INSPECTOR@1','WUIB_FLOW_MAP@1']) if(!defs.has(key)) throw new Error(`Studio visual definition missing ${key}`);
if(!defs.has('WUIB_TOOL_NAV@1')) throw new Error('tool navigation definition missing');
if(defs.get('WUIB_TOOL_NAV@1').actions[0]?.action!=='STUDIO.NAVIGATE') throw new Error('tool navigation action mismatch');
console.log('PASS test_studio_js 23/23 definitions renderable + 6 contextual compositions');
