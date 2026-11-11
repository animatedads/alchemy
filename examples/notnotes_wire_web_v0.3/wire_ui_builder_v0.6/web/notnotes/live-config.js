export function parseNotNotesSeed(text){
  const value=JSON.parse(text||'{}');
  if(!value||Array.isArray(value)||typeof value!=='object') throw new Error('notNotes bootstrap seed must be an object');
  return value;
}
export async function loadNotNotesBootstrap(seed){
  if(seed.configUrl){
    const response=await fetch(seed.configUrl,{cache:'no-store',credentials:'same-origin'});
    if(!response.ok) throw new Error(`notNotes bootstrap config ${response.status}`);
    return {...seed,...await response.json()};
  }
  return seed;
}
