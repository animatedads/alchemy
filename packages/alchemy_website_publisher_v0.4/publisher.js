/* Alchemy Website Publisher v0.2
 * Browser-only editorial workbench. No server, token, principal, approval, or deployment authority.
 * Exact Rasen Falcon page inputs; preview derived from its original generated HTML/CSS.
 */
(()=>{'use strict';
const REF=window.RF_REFERENCE;
if(!REF||!REF.pages||!REF.templates) throw Error('Rasen Falcon reference package missing');
const $=s=>document.querySelector(s);
const clone=x=>JSON.parse(JSON.stringify(x));
const KEY='alchemy.website.publisher.rasenfalcon/0.1';
const slugs=[...new Set(['home',...REF.site.navigation,'contact','privacy',...Object.keys(REF.pages)])];
const pretty=slug=>slug==='home'?'Home':(REF.pages[slug]?.nav_label||slug.replace(/-/g,' '));
const initial=()=>({schema:'alchemy.website.publisher.draft/0.1',revision:0,nativeRevision:0,changed_at:null,pages:clone(REF.pages)});
let state=initial(),current='home',tab='content',device='desktop',compare='draft',storageAvailable=true,toastTimer;
try{const raw=localStorage.getItem(KEY); if(raw){const old=JSON.parse(raw);if(isValidStore(old))state=old;}}catch(e){storageAvailable=false;}
function isValidStore(x){return !!x&&x.schema==='alchemy.website.publisher.draft/0.1'&&x.pages&&slugs.every(s=>!!x.pages[s]&&x.pages[s].slug===s&&Array.isArray(x.pages[s].sections))&&Object.keys(x.pages).length===slugs.length;}
function changed(slug){return JSON.stringify(state.pages[slug])!==JSON.stringify(REF.pages[slug]);}
function save(){state.revision++;state.changed_at=new Date().toISOString();try{localStorage.setItem(KEY,JSON.stringify(state));storageAvailable=true;}catch(e){storageAvailable=false;} updateSummaries();const badge=$('#page-status');if(badge)badge.textContent=changed(current)?'EDITED DRAFT':'SOURCE CANDIDATE';}
function toast(s){let el=$('#toast');el.textContent=s;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),3600);}
function escapeHtml(x){return String(x).replace(/[&<>"']/g,a=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[a]));}
function addField(host,label,key,help,opts={}){
 const page=state.pages[current];const block=document.createElement('div');block.className='field-block';
 const h=document.createElement('div');h.className='field-head';const lab=document.createElement('label');lab.className='field-label';lab.textContent=label;
 const tip=document.createElement('span');tip.className='field-tip';tip.textContent=opts.tip||'';h.append(lab,tip);
 const field=document.createElement(opts.multi?'textarea':'input');field.className='field-input';if(opts.multi)field.rows=opts.rows||3;else field.type='text';field.value=page[key]||'';field.id='field-'+key;lab.htmlFor=field.id;field.maxLength=opts.max||5000;
 field.addEventListener('input',()=>{page[key]=field.value;page.status='candidate';save();renderPreview();refreshPageList();});
 block.append(h,field);
 if(help){const d=document.createElement('div');d.className='field-help';d.textContent=help;block.append(d);}
 host.append(block);
}
function addSectionField(host, section, index,key,label,options={}){
 const block=document.createElement('div');block.className='field-block';const lab=document.createElement('label');lab.className='field-label';lab.textContent=label;block.append(lab);
 const input=document.createElement(options.multi?'textarea':'input');input.className='field-input';input.id='section-'+index+'-'+key;lab.htmlFor=input.id;if(!options.multi)input.type='text';else input.rows=options.rows||3;
 input.value=key==='points'?section.points.join('\n'):section[key];
 input.addEventListener('input',()=>{section[key]=key==='points'?input.value.split('\n').map(x=>x.trim()).filter(Boolean):input.value;state.pages[current].status='candidate';save();renderPreview();refreshPageList();});block.append(input);host.append(block);
}
function renderEditor(){const p=state.pages[current];$('#editor-heading').textContent=pretty(current)+' page';$('#editor-subline').textContent=(current==='home'?'/':'/'+current+'/')+' · Editable page content';$('#page-status').textContent=changed(current)?'EDITED DRAFT':'SOURCE CANDIDATE';
 const content=$('#editor-content'),sections=$('#editor-sections'),metadata=$('#editor-metadata');content.replaceChildren();sections.replaceChildren();metadata.replaceChildren();
 const note=document.createElement('div');note.className='editor-note';note.textContent='Write factual, source-supported copy. Editing never retains or grants publication approval.';content.append(note);
 addField(content,'Page headline','headline',null,{tip:'Primary heading',max:240});addField(content,'Introduction','intro','Shown immediately below the headline.',{multi:true,rows:4,max:3000});addField(content,'Opening statement','summary','The introductory body text and search description.',{multi:true,rows:4,max:5000});addField(content,'Small heading','eyebrow',null,{max:180});
 const secNote=document.createElement('div');secNote.className='editor-note';secNote.textContent='Edit the section order, headings, explanatory text and key points. New paragraphs are treated as plain text, never HTML.';sections.append(secNote);
 p.sections.forEach((sec,i)=>{const block=document.createElement('div');block.className='section-card';const hdr=document.createElement('div');hdr.className='section-head';hdr.innerHTML='<span>SECTION '+String(i+1).padStart(2,'0')+'</span><span class="section-number">'+String(i+1).padStart(2,'0')+' / '+String(p.sections.length).padStart(2,'0')+'</span>';block.append(hdr);addSectionField(block,sec,i,'heading','Section heading');addSectionField(block,sec,i,'body','Body text',{multi:true,rows:4});addSectionField(block,sec,i,'points','Key points (one per line)',{multi:true,rows:4});sections.append(block);});
 const add=document.createElement('button');add.className='btn outline';add.textContent='+ Add section';add.onclick=()=>{p.sections.push({heading:'New section',body:'Enter a description of this topic.',points:[]});p.status='candidate';save();renderEditor();renderPreview();};sections.append(add);
 const mNote=document.createElement('div');mNote.className='editor-note';mNote.textContent='Metadata is content too. Search descriptions must not claim capabilities or assurances that have not been verified.';metadata.append(mNote);addField(metadata,'Browser and search title','title','Also used in the page title tag.',{max:180});addField(metadata,'Navigation label','nav_label','The short menu label for this page.',{max:65});
 const rel=document.createElement('div');rel.className='field-block';rel.innerHTML='<span class="field-label">Related page identities</span><p class="field-help">'+escapeHtml(p.related.join(' · '))+'</p>';metadata.append(rel);
 for(const b of document.querySelectorAll('[data-edit-tab]')){const selected=b.dataset.editTab===tab;b.setAttribute('aria-selected',String(selected));$('#editor-'+b.dataset.editTab).hidden=!selected;}
}
function refreshPageList(){const list=$('#page-list');list.replaceChildren();slugs.forEach((slug,i)=>{const btn=document.createElement('button');btn.className='page-btn'+(slug===current?' current':'');btn.dataset.page=slug;btn.setAttribute('aria-current',slug===current?'page':'false');btn.innerHTML='<span class="page-index">'+String(i+1).padStart(2,'0')+'</span><span class="page-caption">'+escapeHtml(pretty(slug))+'</span>'+(changed(slug)?'<span class="changed-mark" title="Edited">●</span>':'');btn.onclick=()=>{current=slug;renderAll();};list.append(btn);});}
function updateSummaries(){const n=slugs.filter(changed).length;$('#draft-summary').textContent=(n?n+' page'+(n!==1?'s':'')+' edited':'No edits')+(state.changed_at?' · saved locally':'');const probs=validateAll();$('#validation-summary').textContent=probs.length?probs.length+' validation issue'+(probs.length>1?'s':''):'9 pages · structurally valid';$('#autosave-note').textContent=storageAvailable?'● Saved on this device · export for backup':'Local storage unavailable · export your work';}
function validatePage(p){const errs=[];for(const key of ['slug','title','nav_label','eyebrow','headline','intro','summary'])if(typeof p[key]!=='string'||!p[key].trim())errs.push('Missing '+key);if(!Array.isArray(p.sections)||p.sections.length<2)errs.push('At least two sections required');else p.sections.forEach((s,i)=>{if(!s.heading?.trim()||!s.body?.trim())errs.push('Section '+(i+1)+' incomplete');if(!Array.isArray(s.points))errs.push('Section '+(i+1)+' points invalid');});if(!Array.isArray(p.related)||p.related.some(k=>!slugs.includes(k)))errs.push('Invalid related page');return errs;}
function validateAll(){return slugs.flatMap(s=>validatePage(state.pages[s]).map(msg=>s+': '+msg));}
function pageUri(s){return s==='home'?'/':'/'+s+'/';}
function pageHref(slug,from){return (from==='home'?'':'../')+(slug==='home'?'':slug+'/')+'index.html';}
function compilePage(slug,page,preview=false){
 const doc=new DOMParser().parseFromString(REF.templates[slug],'text/html');
 const set=(sel,value,root=doc)=>{const e=root.querySelector(sel);if(e)e.textContent=value;};
 set('title',page.title+' — Rasen Falcon');const meta=doc.querySelector('meta[name="description"]');if(meta)meta.setAttribute('content',page.summary);
 const e=doc.querySelector('.hero-copy .eyebrow');if(e){const mark=e.querySelector('.rule-small')?.cloneNode(true);e.replaceChildren(...(mark?[mark]:[]),document.createTextNode(page.eyebrow));}
 set('.hero h1',page.headline);set('.hero-intro',page.intro);set('.editorial-intro p',page.summary);
 const body=doc.querySelector('.page-body');const nodes=Array.from(body.querySelectorAll('section.editorial-section'));const anchor=body.querySelector('.quote-band');const template=nodes[0]?.cloneNode(true);
 nodes.forEach(n=>n.remove());
 page.sections.forEach((s,i)=>{const node=template?.cloneNode(true);if(!node)return;set('.section-number',String(i+1).padStart(2,'0')+' / '+String(page.sections.length).padStart(2,'0'),node);set('.section-content h2',s.heading,node);set('.section-content p',s.body,node);const list=node.querySelector('.point-list');if(list){list.replaceChildren();(s.points||[]).forEach(t=>{const li=doc.createElement('li');li.textContent=t;list.append(li);});}body.insertBefore(node,anchor);});
 const nav=doc.querySelector('.masthead nav');if(nav){const aa=Array.from(nav.querySelectorAll('a'));['home',...REF.site.navigation].forEach((id,i)=>{const a=aa[i];if(a)a.textContent=(state.pages[id]||REF.pages[id])?.nav_label||id;});}
 const robots=doc.querySelector('meta[name="robots"]');if(robots)robots.content='noindex,nofollow';
 if(preview){for(const el of doc.querySelectorAll('link[rel="stylesheet"],script[src],link[rel="icon"]'))el.remove();const style=doc.createElement('style');style.textContent=REF.css;doc.head.append(style);for(const a of doc.querySelectorAll('a[href]'))a.addEventListener?.('click',()=>{});}
 return '<!doctype html>\n'+doc.documentElement.outerHTML;
}
function renderPreview(){const p=compare==='draft'?state.pages[current]:REF.pages[current];const pageHtml=compilePage(current,p,true);const frame=$('#site-frame');frame.srcdoc=pageHtml;$('#preview-path').textContent='rasenfalcon.com '+pageUri(current);$('#browser-address').textContent='https://rasenfalcon.com'+pageUri(current);$('#preview-note').textContent=compare==='draft'?'Rendering device-local candidate. Not deployed.':'Original site-build candidate. Not deployed.';}
function renderAll(){refreshPageList();renderEditor();renderPreview();updateSummaries();const n=$('#native-summary');if(n)n.textContent=state.nativeRevision?'Native record: r'+state.nativeRevision+' (unverified import)':'Native: not loaded';}
function downloadBlob(name,blob){const u=URL.createObjectURL(blob);const a=document.createElement('a');a.href=u;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),2000);}
function downloadText(name,text,type='application/json'){downloadBlob(name,new Blob([text],{type:type+';charset=utf-8'}));}
function sorted(x){if(Array.isArray(x))return x.map(sorted);if(x&&typeof x==='object'){const out={};for(const k of Object.keys(x).sort())out[k]=sorted(x[k]);return out;}return x;}
function canonical(o){return JSON.stringify(sorted(o));}
// Small audited-structure SHA-256 fallback for offline browsers without SubtleCrypto.
// SHA-256 is a content identity here, not a publication signature or approval token.
function sha256Fallback(input){
 const bytes=typeof input==='string'?new TextEncoder().encode(input):input;
 const K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
 const H=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
 const length=Math.ceil((bytes.length+9)/64)*64;const data=new Uint8Array(length);data.set(bytes);data[bytes.length]=0x80;
 const dv=new DataView(data.buffer);const bits=BigInt(bytes.length)*8n;dv.setUint32(length-8,Number((bits>>32n)&0xffffffffn),false);dv.setUint32(length-4,Number(bits&0xffffffffn),false);
 const rotr=(v,n)=>(v>>>n)|(v<<(32-n));const W=new Uint32Array(64);
 for(let start=0;start<length;start+=64){
   for(let i=0;i<16;i++)W[i]=dv.getUint32(start+i*4,false);
   for(let i=16;i<64;i++){const a=W[i-15],b=W[i-2];W[i]=(((W[i-16]+(rotr(a,7)^rotr(a,18)^(a>>>3)))>>>0)+W[i-7]+(rotr(b,17)^rotr(b,19)^(b>>>10)))>>>0;}
   let [a,b,c,d,e,f,g,h]=H;
   for(let i=0;i<64;i++){const t1=(h+(rotr(e,6)^rotr(e,11)^rotr(e,25))+((e&f)^(~e&g))+K[i]+W[i])>>>0;const t2=((rotr(a,2)^rotr(a,13)^rotr(a,22))+((a&b)^(a&c)^(b&c)))>>>0;h=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}
   for(let i=0;i<8;i++)H[i]=(H[i]+[a,b,c,d,e,f,g,h][i])>>>0;
 }
 return H.map(x=>x.toString(16).padStart(8,'0')).join('');
}
async function sha256(x){const data=typeof x==='string'?new TextEncoder().encode(x):x;
 if(typeof crypto!=='undefined'&&crypto.subtle){const bytes=new Uint8Array(await crypto.subtle.digest('SHA-256',data));return Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');}
 return sha256Fallback(data);
}
function crc32(bytes){let crc=0xffffffff;for(const b of bytes){crc^=b;for(let i=0;i<8;i++)crc=(crc&1)?(crc>>>1)^0xedb88320:crc>>>1;}return(crc^0xffffffff)>>>0;}
function zipStore(files){const E=new TextEncoder(),pieces=[],central=[];let offset=0;
 for(const [name,value] of files){const n=E.encode(name),d=typeof value==='string'?E.encode(value):value;const checksum=crc32(d);const local=new Uint8Array(30+n.length),view=new DataView(local.buffer);
 view.setUint32(0,0x04034b50,true);view.setUint16(4,20,true);view.setUint16(6,0x0800,true);view.setUint32(14,checksum,true);view.setUint32(18,d.length,true);view.setUint32(22,d.length,true);view.setUint16(26,n.length,true);local.set(n,30);pieces.push(local,d);
 const cent=new Uint8Array(46+n.length),v=new DataView(cent.buffer);v.setUint32(0,0x02014b50,true);v.setUint16(4,20,true);v.setUint16(6,20,true);v.setUint16(8,0x0800,true);v.setUint32(16,checksum,true);v.setUint32(20,d.length,true);v.setUint32(24,d.length,true);v.setUint16(28,n.length,true);v.setUint32(42,offset,true);cent.set(n,46);central.push(cent);offset+=local.length+d.length;
 }
 const cdOffset=offset,cdLen=central.reduce((n,b)=>n+b.length,0);const end=new Uint8Array(22),v=new DataView(end.buffer);v.setUint32(0,0x06054b50,true);v.setUint16(8,central.length,true);v.setUint16(10,central.length,true);v.setUint32(12,cdLen,true);v.setUint32(16,cdOffset,true);
 return new Blob([...pieces,...central,end],{type:'application/zip'});
}
async function buildPreview(){const errors=validateAll();if(errors.length){toast('Build held: '+errors[0]);return;}const files=[],manifest=[],resources=[];
 for(const slug of slugs){const p=state.pages[slug],filename='site/'+(slug==='home'?'':'/'+slug+'/').replace(/^\//,'')+'index.html';const h=compilePage(slug,p,false),digest=await sha256(h),contentDigest=await sha256(canonical(p));files.push([filename,h]);manifest.push({slug,path:pageUri(slug),file:filename.replace(/^site\//,''),sha256:digest,content_sha256:contentDigest,status:'candidate'});resources.push({proposedResourceId:'RF.PAGE.'+slug.toUpperCase().replace(/-/g,'_'),resourceClass:'STRUCTURED',locale:'en-GB',sourceSha256:contentDigest,publicationStatus:'CANDIDATE_UNPUBLISHED',semanticRole:'PRIMARY_CONTENT',slug});files.push(['content/pages/'+slug+'.json',JSON.stringify(p,null,2)+'\n']);}
 files.push(['content/site.json',JSON.stringify(REF.site,null,2)+'\n']);files.push(['site/assets/site.css',REF.css],['site/assets/site.js',REF.js],['site/assets/favicon.svg',REF.favicon],['site/robots.txt','User-agent: *\nDisallow: /\n']);
 files.push(['site/build-manifest.json',JSON.stringify({schema:'rasenfalcon.build/0.1',mode:'preview',not_a_wire_release:true,not_deployed:true,pages:manifest},null,2)+'\n']);
 files.push(['site/cms-export.json',JSON.stringify({schema:'rasenfalcon.cms-export/0.1',publication_state:'preview',site:REF.site.domain,pages:manifest,candidate_resource_inputs:resources,published_wire_refs:[],authority:'CANDIDATE_ONLY'},null,2)+'\n']);
 files.push(['README.txt','Rasen Falcon candidate website preview built by Alchemy Website Publisher v0.1.\nNOT APPROVED OR DEPLOYED. Preview robots.txt disallows all crawling.\nContent source is in content/pages/*.json; compile with the supplied reference Rasen Falcon builder after review.\nPublic activation requires CMS Brand / institutional approval, Wire Resource Editor identity and ooRexx HTTPS release qualification.\n']);
 downloadBlob('rasenfalcon-preview-candidate.zip',zipStore(files));toast('Preview ZIP prepared: '+manifest.length+' pages · unpublished');
}
async function reviewRequest(){const errors=validateAll();if(errors.length){toast('Review held: '+errors[0]);return;}let pages=[];for(const s of slugs)if(changed(s))pages.push({slug:s,original_sha256:await sha256(canonical(REF.pages[s])),candidate_sha256:await sha256(canonical(state.pages[s]))});if(!pages.length){toast('No edited pages to review');return;}const note=$('#review-note').value.trim();const record={schema:'alchemy.website.publisher.review-request/0.1',status:'PREPARED_NOT_SUBMITTED',publisher_authority:'NONE',app:'Alchemy Website Publisher',site:'rasenfalcon.com',editorial_revision:state.revision,created_at:new Date().toISOString(),changed_pages:pages,note,wire_resource_refs:[],live_deployment:false};downloadText('rasenfalcon-review-request.json',JSON.stringify(record,null,2)+'\n');$('#review-dialog').close();toast('Review record downloaded. Not submitted or approved.');}
function setTab(next){tab=next;for(const b of document.querySelectorAll('[data-edit-tab]')){b.setAttribute('aria-selected',String(b.dataset.editTab===tab));$('#editor-'+b.dataset.editTab).hidden=b.dataset.editTab!==tab;}}
function importContent(text){
 let input=JSON.parse(text), nativeRev=null;
 if(input.schema==='alchemy.website.publisher.native-record/0.2'){
   if(input.provider!=='NoSQLServer'||input.backend!=='SQLITE_NATIVE_READWRITE'||input.authority!=='CANDIDATE_ONLY'||!Number.isSafeInteger(input.revision)||input.revision<1||typeof input.document!=='string')throw Error('Invalid native storage record');
   nativeRev=input.revision;
   input=JSON.parse(input.document);
 }
 if(input.schema==='alchemy.website.publisher.export/0.1'){
   if(input.site!==REF.site.domain||input.authority!=='CANDIDATE_ONLY'||!input.pages||Object.keys(input.pages).length!==slugs.length)throw Error('Content package must contain the same nine-page site');
   for(const s of slugs){if(input.pages[s]?.slug!==s||!Array.isArray(input.pages[s].sections))throw Error('Invalid page '+s);const issues=validatePage(input.pages[s]);if(issues.length)throw Error(issues[0]);}
   state.pages=clone(input.pages);slugs.forEach(s=>state.pages[s].status='candidate');state.nativeRevision=nativeRev??0;save();renderAll();return nativeRev?'Native record '+nativeRev+' imported as unverified candidate':'All page content imported as candidates';
 }
 if(input.slug===current&&Array.isArray(input.sections)){
   for(const key of ['title','nav_label','eyebrow','headline','intro','summary'])if(typeof input[key]!=='string')throw Error('Invalid field '+key);
   const errors=validatePage(input);if(errors.length)throw Error(errors[0]);
   state.pages[current]={...clone(input),slug:current,status:'candidate'};save();renderAll();return pretty(current)+' page imported as candidate';
 }
 throw Error('Import a publisher export, native record, or selected page JSON');
}
function nativeCommand(){return 'rexx native/publisher_store.rex save /private/rasen-publisher.sqlite ./rasenfalcon-native-save.json '+(state.nativeRevision||0);}
function openNativeDialog(){const errors=validateAll();if(errors.length){toast('Save held: '+errors[0]);return;}$('#native-command').textContent=nativeCommand();$('#native-dialog').showModal();}
function nativeDownload(){const document={schema:'alchemy.website.publisher.export/0.1',site:REF.site.domain,authority:'CANDIDATE_ONLY',revision:state.revision,pages:state.pages};downloadText('rasenfalcon-native-save.json',JSON.stringify(document,null,2)+'\n');toast('Candidate exported: NOT YET saved to NoSQLServer');}
$('#native-save-btn').onclick=openNativeDialog;
$('#native-download').onclick=nativeDownload;
$('#native-close').onclick=()=>$('#native-dialog').close();
$('#native-copy-command').onclick=()=>{const cmd=nativeCommand();if(navigator.clipboard?.writeText)navigator.clipboard.writeText(cmd).then(()=>toast('Command copied'),()=>toast('Select and copy the displayed command'));else toast('Select and copy the displayed command');};
$('#reset-btn').onclick=()=>{if(!changed(current)){toast('Already at source edition');return;}if(!confirm('Restore this page from the Rasen Falcon source edition? Your edits to this page will be lost.'))return;state.pages[current]=clone(REF.pages[current]);save();renderAll();toast('Source edition restored');};
// v0.4: governed offline Rasen Falcon stage handoff. UI never invokes a deploy API.
function publisherCandidate(){return {schema:'alchemy.website.publisher.export/0.1',site:REF.site.domain,authority:'CANDIDATE_ONLY',revision:state.revision,pages:state.pages};}
function handoffCommands(){return {
 stage:'python3 tools/site.py stage-publisher ./rasenfalcon-publisher-handoff.json /private/rasen-publisher-stage-001',
 build:'python3 tools/site.py build --mode preview --content-dir /private/rasen-publisher-stage-001/content --output-dir /private/rasen-publisher-preview-001'
};}
async function openHandoff(){const issues=validateAll();if(issues.length){toast('Handoff held: '+issues[0]);return;}
 const record=publisherCandidate(),identity=await sha256(canonical(record));
 $('#handoff-page-count').textContent=slugs.length+' candidate pages';
 $('#handoff-revision').textContent='Local revision: '+state.revision+' (not an approval)';
 $('#handoff-digest').textContent='SHA-256: '+identity+' (content identity only)';
 const commands=handoffCommands();$('#handoff-stage-command').textContent=commands.stage;$('#handoff-build-command').textContent=commands.build;
 $('#handoff-dialog').showModal();
}
function handoffDownload(){const issues=validateAll();if(issues.length){toast('Handoff held: '+issues[0]);return;}
 downloadText('rasenfalcon-publisher-handoff.json',JSON.stringify(publisherCandidate(),null,2)+'\n');
 toast('Candidate exported, not staged, approved or published');
}
function handoffCopy(command){if(navigator.clipboard?.writeText)navigator.clipboard.writeText(command).then(()=>toast('Command copied'),()=>toast('Select and copy the displayed command'));else toast('Select and copy the displayed command');}
$('#handoff-btn').onclick=()=>openHandoff().catch(e=>toast('Handoff error: '+e.message));
$('#handoff-close').onclick=()=>$('#handoff-dialog').close();
$('#handoff-download').onclick=handoffDownload;
$('#handoff-copy-stage').onclick=()=>handoffCopy(handoffCommands().stage);
$('#handoff-copy-build').onclick=()=>handoffCopy(handoffCommands().build);

$('#export-json-btn').onclick=()=>{downloadText('rasenfalcon-editorial-content.json',JSON.stringify({schema:'alchemy.website.publisher.export/0.1',site:REF.site.domain,authority:'CANDIDATE_ONLY',revision:state.revision,pages:state.pages},null,2)+'\n');toast('Structured content exported');};
$('#build-btn').onclick=()=>{buildPreview().catch(e=>toast('Build error: '+e.message));};
$('#import-btn').onclick=()=>$('#import-file').click();$('#import-file').onchange=async e=>{const f=e.target.files?.[0];if(!f)return;if(f.size>3_000_000){toast('Import too large');return;}try{toast(importContent(await f.text()));}catch(err){toast('Import refused: '+err.message);}e.target.value='';};
$('#validate-btn').onclick=()=>{const errors=validatePage(state.pages[current]);toast(errors.length?errors.join('; '):pretty(current)+' page: structure valid (not fact-checked)');};
for(const b of document.querySelectorAll('[data-edit-tab]'))b.onclick=()=>setTab(b.dataset.editTab);
for(const b of document.querySelectorAll('[data-device]'))b.onclick=()=>{device=b.dataset.device;$('#preview-viewport').className='preview-viewport '+device;for(const bb of document.querySelectorAll('[data-device]'))bb.classList.toggle('active',bb===b);};
for(const b of document.querySelectorAll('[data-compare]'))b.onclick=()=>{compare=b.dataset.compare;for(const bb of document.querySelectorAll('[data-compare]'))bb.classList.toggle('active',bb===b);renderPreview();};
$('#open-preview-btn').onclick=()=>{const html=compilePage(current,compare==='draft'?state.pages[current]:REF.pages[current],true);const u=URL.createObjectURL(new Blob([html],{type:'text/html'}));window.open(u,'_blank','noopener');setTimeout(()=>URL.revokeObjectURL(u),15000);};
$('#review-btn').onclick=async()=>{const changedSlugs=slugs.filter(changed);$('#review-details').textContent='Site: rasenfalcon.com · '+changedSlugs.length+' edited page(s) · Editorial revision: '+state.revision+' · No publishing authority';$('#review-dialog').showModal();};
$('#close-dialog').onclick=$('#cancel-dialog').onclick=()=>$('#review-dialog').close();$('#download-review').onclick=()=>{reviewRequest().catch(e=>toast('Review record error: '+e.message));};
renderAll();
window.PUBLISHER_TEST={nativeDownload,nativeCommand,validatePage,validateAll,compilePage,canonical,sha256,zipStore,getPage:()=>clone(state.pages[current]),getState:()=>clone(state),publisherCandidate,handoffCommands,handoffDownload,openHandoff,setPage:s=>{if(slugs.includes(s)){current=s;renderAll();}},importContent,changed,buildPreview};
})();
