import path from 'node:path';
import {spawn} from 'node:child_process';

const root=path.resolve(process.env.WUIB_BUILDER_ROOT??path.join(import.meta.dirname,'..'));
const rollup=need('WUIB_TEST_ROLLUP');
const serverZip=need('WUIB_TEST_SERVER_ZIP');
const oorexxDeb=need('WUIB_TEST_OOREXX_DEB');
function need(name){const value=process.env[name];if(!value)throw new Error(`${name} required`);return path.resolve(value);}
function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms));}
async function stop(child){if(!child||child.exitCode!==null)return;child.kill('SIGTERM');await Promise.race([new Promise(resolve=>child.once('exit',resolve)),sleep(2000)]);if(child.exitCode===null)child.kill('SIGKILL');}
function lines(stream,onLine){let buf='';stream.setEncoding('utf8');stream.on('data',chunk=>{buf+=chunk;for(;;){const at=buf.indexOf('\n');if(at<0)break;const line=buf.slice(0,at).replace(/\r$/,'');buf=buf.slice(at+1);onLine(line);}});}

let child=null;
try{
  child=spawn(path.join(root,'run_builder_studio.sh'),['--rollup',rollup,'--server-zip',serverZip,'--oorexx-deb',oorexxDeb,'--port','0','--json'],{cwd:root,stdio:['ignore','pipe','pipe']});
  const stderr=[];let ready=null;
  lines(child.stdout,line=>{try{const value=JSON.parse(line);if(value?.event==='builder-live-ready')ready=value;}catch{}});
  lines(child.stderr,line=>stderr.push(line));
  const deadline=Date.now()+30000;
  while(!ready&&child.exitCode===null&&Date.now()<deadline)await sleep(25);
  if(!ready)throw new Error(`cold launcher did not become ready: ${stderr.join(' | ')||`exit=${child.exitCode}`}`);
  const response=await fetch(ready.healthUrl,{cache:'no-store'});if(!response.ok)throw new Error(`health ${response.status}`);
  const health=await response.json();
  if(health.ok!==true||health.runtime!=='ooRexx/WireUIServer/QueueFabric'||health.targetProjectId!=='VISUAL_WORKSPACE')throw new Error(`unexpected health ${JSON.stringify(health)}`);
  console.log(`PASS test_live_studio_launcher cold ZIP/deb resolution; ${health.runtime}; ${health.targetProjectId}`);
}catch(error){console.error(`FAIL test_live_studio_launcher: ${error.stack||error}`);process.exitCode=1;}
finally{await stop(child);}
