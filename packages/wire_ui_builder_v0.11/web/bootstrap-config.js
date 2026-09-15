export function parseBootstrapSeed(text) {
  const value=JSON.parse(text||'{}');
  if(!value||typeof value!=='object'||Array.isArray(value)) throw new TypeError('Wire UI Builder bootstrap seed must be an object');
  return value;
}
export async function loadWireUIBootstrap(seed,fetchImpl=globalThis.fetch){
  if(!seed||typeof seed!=='object'||Array.isArray(seed)) throw new TypeError('Wire UI Builder bootstrap seed must be an object');
  if(!seed.bootstrapUrl) return Object.freeze({...seed});
  if(typeof fetchImpl!=='function') throw new Error('fetch is required for Builder bootstrap URL');
  const response=await fetchImpl(String(seed.bootstrapUrl),{method:'GET',credentials:'same-origin',cache:'no-store',headers:{accept:'application/json'}});
  if(!response?.ok) throw new Error(`Wire UI Builder bootstrap request failed (${response?.status??'network'})`);
  const value=await response.json();
  if(!value||typeof value!=='object'||Array.isArray(value)) throw new Error('Wire UI Builder bootstrap response must be an object');
  return Object.freeze({...value});
}
