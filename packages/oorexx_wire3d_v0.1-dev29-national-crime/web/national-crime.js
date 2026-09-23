const canvas=document.querySelector("#map"),ctx=canvas.getContext("2d"),tip=document.querySelector("#tip");
const spark=document.querySelector("#spark"),sctx=spark.getContext("2d");
let fc,period="2025-09",selected=null,paths=[],scaleInfo=null;
let category="ALL", categories=[];
let view={zoom:1,panX:0,panY:0}, drag=null;
const q=s=>document.querySelector(s);
function resize(){const d=devicePixelRatio||1,r=canvas.getBoundingClientRect();canvas.width=r.width*d;canvas.height=r.height*d;ctx.setTransform(d,0,0,d,0,0);draw()}
addEventListener("resize",resize);
function rings(g){return g.type==="Polygon"?g.coordinates:g.coordinates.flat()}
function bounds(features){let a=[Infinity,Infinity,-Infinity,-Infinity];for(const f of features)for(const ring of rings(f.geometry))for(const [x,y] of ring){a[0]=Math.min(a[0],x);a[1]=Math.min(a[1],y);a[2]=Math.max(a[2],x);a[3]=Math.max(a[3],y)}return a}
function projection(){const r=canvas.getBoundingClientRect(),b=scaleInfo,pad=38;
 let sx=(r.width-pad*2)/(b[2]-b[0]),sy=(r.height-pad*2)/(b[3]-b[1]),base=Math.min(sx,sy),s=base*view.zoom;
 let worldW=(b[2]-b[0])*s,worldH=(b[3]-b[1])*s;
 let ox=(r.width-worldW)/2+view.panX,oy=(r.height-worldH)/2+view.panY;
 return ([x,y])=>[ox+(x-b[0])*s,r.height-(oy+(y-b[1])*s)]
}
function localPoint(e){const r=canvas.getBoundingClientRect();return {x:e.clientX-r.left,y:e.clientY-r.top}}
function zoomAt(x,y,factor){const old=view.zoom, next=Math.max(1,Math.min(32,old*factor));if(next===old)return;
 const k=next/old;const r=canvas.getBoundingClientRect(),cx=r.width/2,cy=r.height/2;
 view.panX=(view.panX-(x-cx))*k+(x-cx);view.panY=(view.panY+(y-cy))*k-(y-cy);view.zoom=next;draw();updateZoom()}
function updateZoom(){const el=document.querySelector("#zoomValue");if(el)el.textContent=`${view.zoom.toFixed(view.zoom<2?1:0)}×`}

function featureBounds(f){let b=[Infinity,Infinity,-Infinity,-Infinity];for(const ring of rings(f.geometry))for(const [x,y] of ring){b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x);b[3]=Math.max(b[3],y)}return b}
function frameFeature(f){if(!f)return;const r=canvas.getBoundingClientRect(),b=scaleInfo,fb=featureBounds(f),pad=90;
 const base=Math.min((r.width-76)/(b[2]-b[0]),(r.height-76)/(b[3]-b[1]));
 const target=Math.min(32,Math.max(2,Math.min((r.width-pad*2)/Math.max(fb[2]-fb[0],1e-6),(r.height-pad*2)/Math.max(fb[3]-fb[1],1e-6))/base));
 view.zoom=target;
 const cx=(fb[0]+fb[2])/2,cy=(fb[1]+fb[3])/2;
 const fullCx=(b[0]+b[2])/2,fullCy=(b[1]+b[3])/2;
 view.panX=-(cx-fullCx)*base*view.zoom; view.panY=(cy-fullCy)*base*view.zoom;
 draw();updateZoom()
}
function selectFeature(f,frame=false){selected=f;update();if(frame)frameFeature(f);else draw()}
function quant(v,max){if(!v)return 0;let t=Math.log1p(v)/Math.log1p(max);return Math.min(4,Math.floor(t*5))}
const fills=["#17252b","#29434c","#426b77","#6595a1","#a9d2d9"];
function draw(){if(!fc)return;const r=canvas.getBoundingClientRect();ctx.clearRect(0,0,r.width,r.height);let project=projection();let max=Math.max(...fc.features.map(f=>f.properties[period==="2025-09"?"sep":"aug"]));paths=[];
for(const f of fc.features){let p=new Path2D;for(const ring of rings(f.geometry)){ring.forEach((xy,i)=>{let [x,y]=project(xy);i?p.lineTo(x,y):p.moveTo(x,y)});p.closePath()}let v=f.properties[period==="2025-09"?"sep":"aug"];ctx.fillStyle=f===selected?"#d5eef1":fills[quant(v,max)];ctx.fill(p);ctx.strokeStyle=f===selected?"#ffffff":"#36505a";ctx.lineWidth=f===selected?1.5:.28;ctx.stroke(p);paths.push([p,f])}}
function hit(x,y){for(let i=paths.length-1;i>=0;i--)if(ctx.isPointInPath(paths[i][0],x,y))return paths[i][1];return null}
canvas.addEventListener("mousemove",e=>{let p=localPoint(e);
 if(drag){view.panX=drag.panX+(p.x-drag.x);view.panY=drag.panY-(p.y-drag.y);draw();tip.style.display="none";return}
 let f=hit(p.x,p.y);if(!f){tip.style.display="none";return}let v=f.properties[period==="2025-09"?"sep":"aug"];tip.style.display="block";tip.style.left=(p.x+12)+"px";tip.style.top=(p.y+12)+"px";tip.textContent=`${f.properties.areaCode}  ${v} crimes`});
canvas.addEventListener("mousedown",e=>{let p=localPoint(e);drag={x:p.x,y:p.y,panX:view.panX,panY:view.panY,moved:false}});
addEventListener("mouseup",e=>{if(!drag)return;let p=localPoint(e),m=Math.hypot(p.x-drag.x,p.y-drag.y);if(m<5){selectFeature(hit(p.x,p.y),false)}drag=null});
canvas.addEventListener("wheel",e=>{e.preventDefault();let p=localPoint(e);zoomAt(p.x,p.y,e.deltaY<0?1.35:1/1.35)},{passive:false});
document.querySelectorAll("[data-period]").forEach(b=>b.onclick=()=>{period=b.dataset.period;document.querySelectorAll("[data-period]").forEach(x=>x.classList.toggle("active",x===b));update();draw()});
function update(){if(!selected)return;let p=selected.properties,cur=period==="2025-09"?p.sep:p.aug,prev=period==="2025-09"?p.aug:p.sep;q("#areaCode").textContent=p.areaCode;q("#areaName").textContent=p.name;q("#current").textContent=cur.toLocaleString();q("#previous").textContent=prev.toLocaleString();let d=cur-prev;q("#change").textContent=(d>0?"+":"")+d.toLocaleString();drawSpark(p.aug,p.sep)}
function drawSpark(a,b){let r=spark.getBoundingClientRect(),d=devicePixelRatio||1;spark.width=r.width*d;spark.height=r.height*d;sctx.setTransform(d,0,0,d,0,0);sctx.clearRect(0,0,r.width,r.height);let max=Math.max(a,b,1),ys=v=>r.height-18-(v/max)*(r.height-35);sctx.strokeStyle="#6f9eab";sctx.lineWidth=2;sctx.beginPath();sctx.moveTo(20,ys(a));sctx.lineTo(r.width-20,ys(b));sctx.stroke();sctx.fillStyle="#d3ebef";for(const [x,v] of [[20,a],[r.width-20,b]]){sctx.beginPath();sctx.arc(x,ys(v),4,0,Math.PI*2);sctx.fill()}sctx.fillStyle="#77939d";sctx.font="10px ui-monospace";sctx.fillText("AUG",8,r.height-3);sctx.fillText("SEP",r.width-38,r.height-3)}

function norm(x){return (x||"").toLowerCase().trim()}
function showGeoResults(qv){
 const box=q("#geoResults"),n=norm(qv);if(!n){box.style.display="none";box.innerHTML="";return}
 const exact=[],prefix=[],contains=[];
 for(const f of fc.features){let p=f.properties,c=norm(p.areaCode),name=norm(p.name);if(c===n||name===n)exact.push(f);else if(c.startsWith(n)||name.startsWith(n))prefix.push(f);else if(c.includes(n)||name.includes(n))contains.push(f)}
 const found=[...exact,...prefix,...contains].slice(0,20);box.innerHTML=found.length?"":'<div class="empty">No matching geography</div>';for(const f of found){let d=document.createElement("div");d.className="result";d.innerHTML=`<b>${f.properties.areaCode}</b><span>${f.properties.name}</span>`;d.onclick=()=>{selectFeature(f,true);q("#geoSearch").value=`${f.properties.areaCode} — ${f.properties.name}`;box.style.display="none"};box.appendChild(d)}box.style.display="block"
}
function showCrimeResults(qv){
 const box=q("#crimeResults"),n=norm(qv);if(!n){box.style.display="none";return}
 const found=categories.filter(c=>norm(c).includes(n)).slice(0,20);box.innerHTML=found.length?"":'<div class="empty">No matching category</div>';for(const c of found){let d=document.createElement("div");d.className="result";d.innerHTML=`<b>${c}</b>`;d.onclick=()=>{category=c;q("#crimeCategory").textContent=c.toUpperCase();q("#crimeSearch").value=c;box.style.display="none"};box.appendChild(d)}box.style.display="block"
}
q("#geoSearch").addEventListener("input",e=>showGeoResults(e.target.value));
q("#geoSearch").addEventListener("keydown",e=>{if(e.key==="Enter"){let first=q("#geoResults .result");if(first)first.click()}});
q("#geoFind").onclick=()=>{let first=q("#geoResults .result");if(first)first.click();else showGeoResults(q("#geoSearch").value)};
q("#crimeSearch").addEventListener("input",e=>showCrimeResults(e.target.value));
q("#crimeSearch").addEventListener("keydown",e=>{if(e.key==="Enter"){let first=q("#crimeResults .result");if(first)first.click()}});
Promise.all([fetch("./national-crime.geojson").then(r=>r.json()),fetch("./national-crime-summary.json").then(r=>r.json())]).then(([g,s])=>{fc=g;categories=s.categories||[];scaleInfo=bounds(fc.features);q("#headerStat").textContent=`${s.areaCount.toLocaleString()} AREAS / ${s.totals["2025-09"].toLocaleString()} SEP STREET CRIMES / COMPACT`;resize()});

q("#zoomIn").onclick=()=>{const r=canvas.getBoundingClientRect();zoomAt(r.width/2,r.height/2,1.5)};
q("#zoomOut").onclick=()=>{const r=canvas.getBoundingClientRect();zoomAt(r.width/2,r.height/2,1/1.5)};
q("#zoomReset").onclick=()=>{view={zoom:1,panX:0,panY:0};draw();updateZoom()};

q("#frameSelection").onclick=()=>frameFeature(selected);
