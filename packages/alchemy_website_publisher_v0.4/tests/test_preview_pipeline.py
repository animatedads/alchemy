#!/usr/bin/env python3
"""Live cross-package acceptance of one-command candidate preview compilation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'tools/preview_pipeline.py'

def invoke(builder,candidate,output):
    p=subprocess.run([sys.executable,str(RUN),'--builder',str(builder),'--candidate',str(candidate),'--output',str(output)],capture_output=True,text=True)
    return p.returncode,json.loads(p.stdout)

def main(builder):
    passed=0
    def ck(value,label):
        nonlocal passed
        if not value:raise AssertionError(label)
        passed+=1
    with tempfile.TemporaryDirectory(prefix='website-publisher-pipeline-') as td:
        tmp=Path(td)
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
            context=browser.new_context(accept_downloads=True)
            page=context.new_page()
            html=(ROOT/'index.html').read_text()
            html=html.replace('<link rel="stylesheet" href="publisher.css">','').replace('<script src="reference/rasenfalcon.js"></script>','').replace('<script src="publisher.js"></script>','')
            page.set_content(html)
            page.add_style_tag(content=(ROOT/'publisher.css').read_text())
            page.add_script_tag(content=(ROOT/'reference/rasenfalcon.js').read_text())
            page.add_script_tag(content=(ROOT/'publisher.js').read_text())
            page.wait_for_function('window.PUBLISHER_TEST && document.querySelectorAll(".page-btn").length===9')
            page.locator('#field-headline').fill('Native-safe private preview operator workflow')
            with page.expect_download() as dl:page.locator('#handoff-btn').click();page.locator('#handoff-download').click()
            candidate=tmp/'editor.json';candidate.write_bytes(Path(dl.value.path()).read_bytes())
            browser.close()
        dest=tmp/'preview-candidate-001'
        rc,reply=invoke(builder,candidate,dest)
        ck(rc==0 and reply['ok'],'pipeline passes complete editor candidate')
        receipt=json.loads((dest/'publisher-preview-receipt.json').read_text())
        ck(receipt['schema']=='alchemy.website.publisher.preview-bundle/0.1','receipt schema')
        ck(receipt['state']=='CANDIDATE_PREVIEW_BUILT' and receipt['authority']=='NONE','candidate only')
        ck(receipt['deployment']=='NOT_PERFORMED' and receipt['publication_authority']=='NONE','no deployment rights')
        ck(not receipt['native_revision_verified'],'unverified native identity')
        ck(receipt['page_count']==9,'9 pages compiled')
        ck(receipt['input_sha256']==hashlib.sha256(candidate.read_bytes()).hexdigest(),'candidate exact byte digest')
        ck(receipt['stage_report_sha256']==hashlib.sha256((dest/'staged/staging.json').read_bytes()).hexdigest(),'stage hash')
        ck(receipt['build_manifest_sha256']==hashlib.sha256((dest/'preview/build-manifest.json').read_bytes()).hexdigest(),'preview hash')
        ck(len(list((dest/'preview').rglob('index.html')))==9,'rendered 9 html pages')
        ck(all('noindex,nofollow' in f.read_text() for f in (dest/'preview').rglob('index.html')),'all pages noindex')
        ck('Disallow: /' in (dest/'preview/robots.txt').read_text(),'robots deny indexing')
        ck('Native-safe private preview operator workflow' in (dest/'preview/index.html').read_text(),'edited text delivered')
        rc,_=invoke(builder,candidate,dest)
        ck(rc==2 and receipt==json.loads((dest/'publisher-preview-receipt.json').read_text()),'refuses output overwrite')
        bad=tmp/'forged.json';bad.write_text(candidate.read_text().replace('"CANDIDATE_ONLY"','"APPROVED"',1))
        rc,_=invoke(builder,bad,tmp/'forged-preview')
        ck(rc==2 and not (tmp/'forged-preview').exists(),'forged approval fails without artifact')
        bad.write_text(candidate.read_text().replace('"home"', '"broken"',1))
        rc,_=invoke(builder,bad,tmp/'broken-preview')
        ck(rc==2 and not (tmp/'broken-preview').exists(),'invalid page fails without artifact')
        symlink=tmp/'candidate-symlink.json';symlink.symlink_to(candidate)
        rc,_=invoke(builder,symlink,tmp/'link-preview')
        ck(rc==2 and not (tmp/'link-preview').exists(),'candidate symlink rejected')
        outlink=tmp/'output-link';outlink.symlink_to(dest)
        rc,_=invoke(builder,candidate,outlink)
        ck(rc==2,'output symlink rejected')
        record={'schema':'alchemy.website.publisher.native-record/0.2','provider':'NoSQLServer','backend':'SQLITE_NATIVE_READWRITE','authority':'CANDIDATE_ONLY','revision':5,'parent_revision':4,'document':candidate.read_text()}
        native=tmp/'native.json';native.write_text(json.dumps(record))
        rc,_=invoke(builder,native,tmp/'native-preview')
        ck(rc==0 and not json.loads((tmp/'native-preview/staged/staging.json').read_text())['native_revision_verified'],'native wrapper never becomes authority')
    print('PASS',passed,'candidate preview pipeline assertions')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--builder',type=Path,required=True);args=p.parse_args();main(args.builder)
