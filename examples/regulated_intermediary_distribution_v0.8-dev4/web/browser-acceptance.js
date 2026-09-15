/* Browser-only acceptance driver. Loaded only when ?acceptance=1. */
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
async function waitFor(check,label,timeout=12000){
  const end=Date.now()+timeout;
  while(Date.now()<end){const value=check(); if(value)return value; await sleep(40);}
  throw new Error(`timeout waiting for ${label}`);
}
function field(live,name){return [...live.nodes.values()].find(node=>node.getAttribute?.('name')===name);}
function mark(name,value){document.documentElement.dataset[name]=String(value);}

(async()=>{
  try{
    const browser=await waitFor(()=>window.RID_BROWSER,'RID runtime');
    const row=await waitFor(()=>browser.renderer.instances.get('CASE-W'),'authoritative case row');
    if(!row.root.textContent.includes('OFFERED')) throw new Error(`provider status not rendered: ${row.root.textContent}`);
    mark('providerStatus','OFFERED');
    row.root.click();

    const detail=await waitFor(()=>{
      const live=browser.renderer.instances.get('case-detail');
      return live && !live.root.hidden && live.root.textContent.includes('OFFERED') ? live : null;
    },'selected case detail');
    mark('selectedCase','CASE-W');
    if(!detail.root.textContent.includes('PRESENT_MORTGAGE_OFFER_AND_SIGN')) throw new Error('concrete signing action not rendered');

    const prepare=await waitFor(()=>{
      const live=browser.renderer.instances.get('sign-prepare');
      return live && !live.root.hidden ? live : null;
    },'signature prepare form');
    field(prepare,'authenticationRef').value='AUTH:PASSKEY:BROWSER';
    field(prepare,'consentRef').value='CONSENT:MORTGAGE_OFFER:BROWSER';
    prepare.root.requestSubmit();

    const signing=await waitFor(()=>{
      const live=browser.renderer.instances.get('signing');
      return live && !live.root.hidden && live.root.textContent.includes('ENV-BROWSER-1') && live.root.textContent.includes('CUSTOMER:W') ? live : null;
    },'server-owned signing challenge');
    mark('challengeBound','ENV-BROWSER-1');

    const submit=await waitFor(()=>{
      const live=browser.renderer.instances.get('sign-submit');
      return live && !live.root.hidden ? live : null;
    },'signature submit form');
    field(submit,'keyId').value='CUSTOMER-W-KEY';
    field(submit,'signatureHex').value='aabb';
    field(submit,'evidenceRef').value='DEVICE:BROWSER:SIG:1';
    submit.root.requestSubmit();

    await waitFor(()=>{
      const live=browser.renderer.instances.get('signing');
      return live && live.root.hidden;
    },'signature completion projection');
    mark('signatureState','COMPLETE');
    document.documentElement.dataset.acceptance='PASS';
    document.getElementById('browser-status').textContent='Acceptance complete · exact signed work completed';
  }catch(error){
    console.error(error);
    document.documentElement.dataset.acceptance='FAIL';
    document.documentElement.dataset.acceptanceError=String(error.message??error);
    const status=document.getElementById('browser-status');
    if(status){status.dataset.state='error';status.textContent=`Acceptance failed: ${error.message??error}`;}
  }
})();
