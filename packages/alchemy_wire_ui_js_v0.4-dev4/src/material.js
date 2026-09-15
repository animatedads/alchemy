import { MessageKind } from './protocol.js';

function cssTokenName(name) {
  const token=String(name??'').trim().toLowerCase().replace(/[^a-z0-9_-]+/g,'-').replace(/^-+|-+$/g,'');
  if(!token) throw new TypeError('material token name is required');
  return `--wui-${token}`;
}

/**
 * Applies versioned Builder material tokens to browser CSS custom properties.
 * Recipe strings remain semantic recipe identifiers; this controller does not
 * execute arbitrary CSS supplied by the server.
 */
export class MaterialController {
  constructor({ comms, document = globalThis.document }) {
    if(!comms) throw new TypeError('comms is required');
    this.comms=comms;
    this.document=document??null;
    this.current=null;
    this.seen=new Map();
    this.appliedProperties=new Set();
    comms.on(MessageKind.UI_MATERIAL_SET,(payload)=>this.apply(payload));
  }

  apply(payload={}) {
    const materialId=String(payload.materialId??'').trim();
    const version=String(payload.version??'').trim();
    const contentAddress=String(payload.contentAddress??'').trim();
    if(!materialId||!version||!contentAddress) throw new TypeError('materialId, version and contentAddress are required');
    const tokens=payload.tokens && typeof payload.tokens==='object' && !Array.isArray(payload.tokens) ? { ...payload.tokens } : {};
    const recipes=payload.recipes && typeof payload.recipes==='object' && !Array.isArray(payload.recipes) ? { ...payload.recipes } : {};
    const key=`${materialId}@${version}`;
    const priorAddress=this.seen.get(key);
    if(priorAddress && priorAddress!==contentAddress) throw new Error(`immutable material changed: ${key}`);
    this.seen.set(key,contentAddress);

    const style=this.document?.documentElement?.style;
    if(style?.removeProperty) for(const property of this.appliedProperties) style.removeProperty(property);
    this.appliedProperties.clear();
    if(style?.setProperty) {
      for(const [name,value] of Object.entries(tokens)) {
        const property=cssTokenName(name);
        style.setProperty(property,String(value));
        this.appliedProperties.add(property);
      }
    }
    this.document?.documentElement?.setAttribute?.('data-wire-material-set',key);
    this.document?.documentElement?.setAttribute?.('data-wire-material-address',contentAddress);
    this.current=Object.freeze({materialId,version,contentAddress,tokens:Object.freeze(tokens),recipes:Object.freeze(recipes),siteRelease:payload.siteRelease??null});
    return this.current;
  }

  token(name) { return this.current?.tokens?.[name] ?? null; }
  recipe(role) { return this.current?.recipes?.[role] ?? null; }
}

export { cssTokenName };
