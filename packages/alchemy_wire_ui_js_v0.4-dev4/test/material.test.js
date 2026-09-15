import test from 'node:test';
import assert from 'node:assert/strict';
import { MaterialController, MessageKind } from '../src/index.js';

class Comms {
  constructor(){this.handlers=new Map();}
  on(kind,handler){this.handlers.set(kind,handler);}
  emit(kind,payload){return this.handlers.get(kind)?.(payload);}
}
class Style {
  constructor(){this.values=new Map();}
  setProperty(name,value){this.values.set(name,String(value));}
  removeProperty(name){this.values.delete(name);}
  getPropertyValue(name){return this.values.get(name)??'';}
}
class Root {
  constructor(){this.style=new Style();this.attrs=new Map();}
  setAttribute(name,value){this.attrs.set(name,String(value));}
}

test('versioned material set becomes CSS custom properties and retains semantic recipes',()=>{
  const comms=new Comms(); const document={documentElement:new Root()};
  const material=new MaterialController({comms,document});
  comms.emit(MessageKind.UI_MATERIAL_SET,{
    materialId:'FLYLO_MATERIAL',version:'1',contentAddress:'sha512-material-1',
    tokens:{'brand.pink':'#ff2d88','space.unit':'8','radius.control':'14'},
    recipes:{'hero.search':'brand.hero/search.card'},siteRelease:{releaseId:'FLYLO_WEB',version:'2026.08.24'}
  });
  assert.equal(document.documentElement.style.getPropertyValue('--wui-brand-pink'),'#ff2d88');
  assert.equal(document.documentElement.style.getPropertyValue('--wui-space-unit'),'8');
  assert.equal(material.recipe('hero.search'),'brand.hero/search.card');
  assert.equal(document.documentElement.attrs.get('data-wire-material-set'),'FLYLO_MATERIAL@1');
});

test('material version replacement removes tokens no longer present',()=>{
  const comms=new Comms(); const document={documentElement:new Root()};
  const material=new MaterialController({comms,document});
  comms.emit(MessageKind.UI_MATERIAL_SET,{materialId:'M',version:'1',contentAddress:'a1',tokens:{old:'x',kept:'1'},recipes:{}});
  comms.emit(MessageKind.UI_MATERIAL_SET,{materialId:'M',version:'2',contentAddress:'a2',tokens:{kept:'2'},recipes:{}});
  assert.equal(document.documentElement.style.getPropertyValue('--wui-old'),'');
  assert.equal(document.documentElement.style.getPropertyValue('--wui-kept'),'2');
});

test('same exact material identity cannot change content address',()=>{
  const comms=new Comms(); const material=new MaterialController({comms,document:{documentElement:new Root()}});
  comms.emit(MessageKind.UI_MATERIAL_SET,{materialId:'M',version:'1',contentAddress:'a1',tokens:{},recipes:{}});
  assert.throws(()=>comms.emit(MessageKind.UI_MATERIAL_SET,{materialId:'M',version:'1',contentAddress:'DIFFERENT',tokens:{},recipes:{}}),/immutable material changed/);
});
