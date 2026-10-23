"""Browser/storage-contract qualification, NOT an ooRexx runtime qualification."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import json,hashlib,zipfile,re,os
ROOT=Path(__file__).resolve().parents[1]

def main():
    count=0
    def ck(expr,label):
        nonlocal count
        assert expr,label
        count+=1
    with sync_playwright() as sp:
      b=sp.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
      ctx=b.new_context(accept_downloads=True,viewport={'width':1450,'height':900})
      p=ctx.new_page()
      errors=[];p.on('pageerror',lambda e: errors.append(str(e)))
      html=(ROOT/'index.html').read_text()
      for link in ['<link rel="stylesheet" href="publisher.css">','<script src="reference/rasenfalcon.js"></script>','<script src="publisher.js"></script>']:
        html=html.replace(link,'')
      p.set_content(html)
      p.add_style_tag(content=(ROOT/'publisher.css').read_text())
      p.add_script_tag(content=(ROOT/'reference/rasenfalcon.js').read_text())
      p.add_script_tag(content=(ROOT/'publisher.js').read_text())
      p.wait_for_function('window.PUBLISHER_TEST && document.querySelectorAll(".page-btn").length === 9')
      ck(p.locator('#native-save-btn').count()==1,'Native save visible')
      ck(p.locator('#native-summary').inner_text()=='Native: not loaded','Not falsely connected')
      ck(' 0' in p.evaluate('PUBLISHER_TEST.nativeCommand()'),'zero expected revision')
      p.locator('#field-headline').fill('Native-stored editorial story')
      p.locator('#native-save-btn').click()
      ck(p.locator('#native-dialog').is_visible(),'Native guidance visible')
      ck('NoSQLServer' in p.locator('#native-dialog').inner_text(),'Correct storage authority named')
      p.screenshot(path=str(ROOT/'docs'/'native_editor_desktop.png'),full_page=True)
      p.set_viewport_size({'width':390,'height':840});p.screenshot(path=str(ROOT/'docs'/'native_editor_mobile.png'),full_page=True)
      p.set_viewport_size({'width':1450,'height':900})
      with p.expect_download() as d:p.locator('#native-download').click()
      raw=Path(d.value.path()).read_text()
      saved=json.loads(raw)
      ck(saved['schema']=='alchemy.website.publisher.export/0.1','Native import schema')
      ck(saved['pages']['home']['headline']=='Native-stored editorial story','Native export retains current edit')
      ck(saved['authority']=='CANDIDATE_ONLY','No authority granted')
      ck(len(saved['pages'])==9,'Complete snapshot')
      ck(p.locator('#native-summary').inner_text()=='Native: not loaded','Download is not a commit')
      p.locator('#native-close').click()
      native={'schema':'alchemy.website.publisher.native-record/0.2','provider':'NoSQLServer','backend':'SQLITE_NATIVE_READWRITE','authority':'CANDIDATE_ONLY','revision':7,'parent_revision':6,'document':raw}
      ck(p.evaluate('(v)=>PUBLISHER_TEST.importContent(JSON.stringify(v))',native)=='Native record 7 imported as unverified candidate','Native import message')
      ck('r7 (unverified import)' in p.locator('#native-summary').inner_text(),'Native revision labelled as unverified')
      ck(p.locator('#field-headline').input_value()=='Native-stored editorial story','Round trip text')
      ck(p.evaluate('PUBLISHER_TEST.nativeCommand()').endswith(' 7'),'Optimistic expected revision')
      p.locator('#field-headline').fill('After native revision 7')
      ck(p.evaluate('PUBLISHER_TEST.nativeCommand()').endswith(' 7'),'Editing retains base revision')
      ck('NOT GRANTED' in p.locator('.bottom-strip').inner_text(),'No publish permission')
      bad={**native,'backend':'PYTHON_SQLITE3'}
      ck('Invalid native storage record' in p.evaluate('(v)=>{try{PUBLISHER_TEST.importContent(JSON.stringify(v));return "wrong"}catch(e){return e.message}}',bad),'Reject wrong backend')
      bad={**native,'revision':-3}
      ck('Invalid native storage record' in p.evaluate('(v)=>{try{PUBLISHER_TEST.importContent(JSON.stringify(v));return "wrong"}catch(e){return e.message}}',bad),'Reject negative revision')
      bad={**native,'authority':'PUBLISHED'}
      ck('Invalid native storage record' in p.evaluate('(v)=>{try{PUBLISHER_TEST.importContent(JSON.stringify(v));return "wrong"}catch(e){return e.message}}',bad),'Reject forged authority')
      altered=json.loads(raw);altered['pages']['home']['headline']=''
      bad={**native,'document':json.dumps(altered)}
      ck('headline' in p.evaluate('(v)=>{try{PUBLISHER_TEST.importContent(JSON.stringify(v));return "wrong"}catch(e){return e.message}}',bad).lower(),'Reject invalid page content')
      ck(p.locator('#field-headline').input_value()=='After native revision 7','Bad import does not mutate draft')
      ck(not errors,'No JS errors '+str(errors))
      b.close()
    code=(ROOT/'native'/'CmsWebsiteSnapshotStore.cls').read_text()
    runner=(ROOT/'native'/'publisher_store.rex').read_text()
    ck('SQLiteWritableDatabaseEngine~create' in code,'Native backend explicit create')
    ck('SQLiteWritableDatabaseEngine~new' in code,'Native backend explicit open')
    ck("engine~insert('publisher_snapshots', vals)" in code,'Prepared native engine insert')
    ck("expected \\= latestSite" in code,'Native expected-revision check')
    ck('PRIMARY KEY' in code,'Collision guard in schema')
    ck('python' not in code.lower() and 'sqlite3' not in code.lower(),'No direct Python or sqlite3 runtime')
    ck('NO_COMMIT:' in runner,'Failure visible')
    z=os.environ.get('ALCHEMY_NOSQL_V089_ARCHIVE')
    if z:
      with zipfile.ZipFile(z) as zd:
        source=zd.read('nosqlserver_v089_sqlite_rw/src/NoSQLServerSQLiteWritable.cls').decode()
        ck('::class SQLiteWritableDatabaseEngine' in source,'Matched package class')
        ck('::method insert' in source,'Matched insert method')
        ck('::method create class' in source,'Matched explicit create method')
        ck('sqliteApplyBatch' in source,'Matched native prepared write bridge')
    else:
      print('EXTERNAL SOURCE CHECKS SKIPPED: set ALCHEMY_NOSQL_V089_ARCHIVE to qualify v0.89 methods')
    print('PASS',count,'native browser/source handoff assertions (ooRexx execution NOT run)')

if __name__=='__main__':main()
