'use strict';
const OMITTED = Symbol('ooRexx.omitted');
class RexxCondition extends Error { constructor(condition){ super(condition && condition.message || 'Rexx condition'); this.name='RexxCondition'; this.condition=condition; } }
class BidirectionalRegistry {
 constructor(){this.jsToHandle=new WeakMap();this.handleToJs=new Map();this.rexxToProxy=new WeakMap();this.proxyToRexx=new WeakMap();this.next=1;}
 toRexx(v){
  if(v===null||v===undefined||typeof v!=='object'&&typeof v!=='function') return v;
  if(this.proxyToRexx.has(v)) return this.proxyToRexx.get(v);
  let h=this.jsToHandle.get(v); if(!h){h=this.next++;this.jsToHandle.set(v,h);this.handleToJs.set(h,v);}
  return Object.freeze({__alchemyJsHandle:h});
 }
 toJS(v){
  if(v&&typeof v==='object'&&Object.prototype.hasOwnProperty.call(v,'__alchemyJsHandle')) return this.handleToJs.get(v.__alchemyJsHandle);
  if(v===null||v===undefined||typeof v!=='object'&&typeof v!=='function') return v;
  if(this.rexxToProxy.has(v)) return this.rexxToProxy.get(v);
  const self=this;
  const p=new Proxy(function(){},{
   get(_t,k){ if(k==='__alchemyRexxAuthority') return v; const x=v[k]; if(typeof x==='function') return (...a)=>{try{return self.toJS(x.apply(v,a.map(z=>self.toRexx(z))))}catch(e){throw new RexxCondition(e)}}; return self.toJS(x); },
   set(_t,k,x){v[k]=self.toRexx(x);return true;},
   apply(_t,_this,a){try{return self.toJS(v.apply(v,a.map(z=>self.toRexx(z))))}catch(e){throw new RexxCondition(e)}}
  });
  this.rexxToProxy.set(v,p);this.proxyToRexx.set(p,v);return p;
 }
}
module.exports={BidirectionalRegistry,RexxCondition,OMITTED};
