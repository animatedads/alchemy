import test from 'node:test';
import assert from 'node:assert/strict';
import { parseBootstrapSeed, loadWireUIBootstrap } from '../web/bootstrap-config.js';

test('inline browser-safe bootstrap remains supported', async()=>{
  const seed=parseBootstrapSeed('{"moduleUrl":"/m.js","gatewayUrl":"wss://g/wire-ui","outboundQueue":"WIREUI.IN.AP","ownership":{"applicationId":"A","sessionId":"S","accessPointId":"AP"}}');
  const config=await loadWireUIBootstrap(seed, null);
  assert.equal(config.ownership.sessionId,'S');
  assert.equal(config.outboundQueue,'WIREUI.IN.AP');
});

test('bootstrap URL obtains authoritative VMM binding', async()=>{
  const seed={bootstrapUrl:'/wire-ui/bootstrap?token=t'};
  let called=null;
  const fetchImpl=async(url,options)=>{
    called={url,options};
    return {ok:true,status:200,json:async()=>({
      moduleUrl:'/alchemy-wire-ui-v0.4-dev4/src/index.js',
      gatewayUrl:'wss://vmm.example/wire-ui?token=t',
      outboundQueue:'WIREUI.IN.VMM-AP-42',
      siteId:'VECTOR_MERIDIAN_MARKETS',
      ownership:{applicationId:'VMM-APP',sessionId:'SESSION-42',accessPointId:'VMM-AP-42'}
    })};
  };
  const config=await loadWireUIBootstrap(seed,fetchImpl);
  assert.equal(called.url,seed.bootstrapUrl);
  assert.equal(called.options.cache,'no-store');
  assert.equal(called.options.credentials,'same-origin');
  assert.equal(config.ownership.sessionId,'SESSION-42');
  assert.equal(config.siteId,'VECTOR_MERIDIAN_MARKETS');
  assert.equal('bootstrapUrl' in config,false);
});
