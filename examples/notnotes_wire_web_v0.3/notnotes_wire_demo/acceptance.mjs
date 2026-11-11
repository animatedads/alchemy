/* Browser-only acceptance driver (not part of product/application). */
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
const until=async(fn,limit=10000)=>{const started=Date.now();while(Date.now()-started<limit){const r=fn();if(r)return r;await sleep(40);}throw Error('Timed out waiting for live Wire UI action/result');};
(async()=>{
  try{
    await until(()=>[...document.querySelectorAll('#notnotes-wire-root button')].find(b=>b.textContent.includes('Approve selected document')));
    // PR-1002 is selected authoritatively by MiniNotesApp before this browser joined.
    const approve=[...document.querySelectorAll('#notnotes-wire-root button')].find(b=>b.textContent.includes('Approve selected document'));
    if(!document.querySelector('#notnotes-wire-root').textContent.includes('PR-1002'))throw Error('Initial NotNotes projection missing PR-1002');
    approve.click();
    await until(()=>document.querySelector('#notnotes-wire-root').textContent.includes('APPROVED'));
    document.documentElement.dataset.acceptance='PASS';
    document.documentElement.dataset.proof='NOTNOTES_APPROVED_VIA_WIRE_UI_ACTION';
    document.title='PASS - NotNotes Wire Approval';
  }catch(e){document.documentElement.dataset.acceptance='FAIL';document.documentElement.dataset.error=e.message;document.title='FAIL - '+e.message;}
})();
