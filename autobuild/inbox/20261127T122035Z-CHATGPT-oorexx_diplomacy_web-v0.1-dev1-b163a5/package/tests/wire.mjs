import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const cfg=await (await fetch(process.argv[2]+'/wire-ui/bootstrap')).json();
const api=await import(pathToFileURL(path.join(process.env.WIRE_ESTATE,'alchemy_wire_ui_js_v0.4-dev6/src/index.js')));
const transport=new api.QueueFabricGatewayTransport({url:cfg.gatewayUrl,outboundQueue:cfg.outboundQueue,ownership:cfg.ownership,putResultMode:'required'});
const comms=new api.Comms({transport,source:cfg.ownership.accessPointId,destination:cfg.outboundQueue});
const definitions=new api.DefinitionRegistry(), renderer=new api.MemoryRenderer({definitions});
const profile=new api.RenderProfileController({comms,definitions,renderer,siteId:cfg.siteId,capabilities:{viewportClass:'large',pointer:'fine',features:{dialog:false,resizeObserver:false}}});
const runtime=new api.WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership:cfg.ownership});
const wait=async f=>{for(let i=0;i<200;i++){let v=f();if(v)return v;await new Promise(r=>setTimeout(r,50))}throw Error('Timeout; revision '+runtime.revision)};
let n=0;
const check=(v,m)=>{assert.ok(v,m);n++};
const state=()=>{const r=renderer.getInstance('root');return r?.slots?.state?JSON.parse(r.slots.state):null;};
async function send(action,detail){const previous=runtime.revision;await runtime.sendSemanticAction(action,{instanceId:'root',detail});await wait(()=>runtime.revision>previous);return state();}
await comms.connect(profile.helloPayload({accessPointId:cfg.ownership.accessPointId}));
try{
 await wait(()=>runtime.viewRef&&!runtime.waitingForResync&&!runtime.actionsBlockedByAuthority&&state());
 let p=state();console.log('SNAPSHOT',JSON.stringify(p).slice(0,900));
 check(p.game.role==='LAB_REVIEWER','lab reviewer');
 check(p.game.review.mail.length===3,'delivered press');
 const lab=p.game.id;
 check(p.game.seats.length===7,'seven seats');
 check(!JSON.stringify(p).includes('fixture-only'),'secret handle excluded');
 p=await send('DIP.PROMPT',{power:'AUS',prompt:'Exact <script> literal'});
 check(p.feedback==='PROMPT_SAVED','prompt save');check(p.game.seats[0].prompt==='Exact <script> literal','literal round trip');
 p=await send('DIP.CREDENTIAL.FIXTURE',{provider:'OPENAI',model:'fixture-model',label:'Runner'});
 check(p.credentials.length===3,'add profile');
 p=await send('DIP.REGISTER',{display:'Human tester'});
 check(p.account==='Human tester','register');check(p.game.role==='PUBLIC','non-orchestrator');
 check(p.game.review.mail.length===0,'no opponent private mail');check(!p.game.seats.some(s=>s.prompt),'no opponent instructions');check(!JSON.stringify(p).includes('Fixture strategy hidden from players'),'sealed profile body omitted');check(p.credentials.length===0,'no prior principal credentials');
 p=await send('DIP.PROMPT',{power:'AUS',prompt:'steal',role:'LAB_REVIEWER',principal:'fixture'});check(p.feedback==='DENIED','forged edit denied');
 p=await send('DIP.CREATE',{title:'Human test table',mode:'HUMAN'});
 check(p.game.title==='Human test table','create');
 p=await send('DIP.SEAT',{power:'ENG',kind:'HUMAN'});check(p.game.role==='PLAYER','join');
 p=await send('DIP.SEAT',{power:'FRA',kind:'HUMAN'});check(p.feedback==='ONE_SEAT_PER_PLAYER','second seat refused');
 p=await send('DIP.SELECT',{game:lab});check(p.game.review.mail.length===0,'no private press on selection');check(p.game.seats.every(s=>s.prompt===''),'no private prompt');
 console.log('PASS '+n+' real Wire round-trip checks');
}finally{await comms.close();}
