#!/usr/bin/env python3
"""Cross-package acceptance: real editor candidate -> owned Rasen Falcon v0.2 stage -> preview.
This is an offline development test only; no publication, server or database authority.
"""
import argparse, hashlib, json, os, pathlib, subprocess, tempfile
from playwright.sync_api import sync_playwright
BASE=pathlib.Path(__file__).resolve().parents[1]

def assertx(ok, message):
    if not ok: raise AssertionError(message)
    return 1

def run_site(builder,*args):
    p=subprocess.run(['python3',str(builder/'tools/site.py'),*map(str,args)],cwd=builder,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try: data=json.loads(p.stdout)
    except json.JSONDecodeError as ex: raise AssertionError('site builder did not emit JSON: '+p.stdout+' '+p.stderr) from ex
    return p.returncode,data

def main(builder):
    n=0
    with tempfile.TemporaryDirectory(prefix='website-publisher-crosspackage-') as td:
        work=pathlib.Path(td)
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
            context=browser.new_context(accept_downloads=True,viewport={'width':1510,'height':930})
            page=context.new_page();html=(BASE/'index.html').read_text()
            html=html.replace('<link rel="stylesheet" href="publisher.css">','').replace('<script src="reference/rasenfalcon.js"></script>','').replace('<script src="publisher.js"></script>','')
            page.set_content(html);page.add_style_tag(content=(BASE/'publisher.css').read_text())
            page.add_script_tag(content=(BASE/'reference/rasenfalcon.js').read_text());page.add_script_tag(content=(BASE/'publisher.js').read_text())
            page.wait_for_function('window.PUBLISHER_TEST && document.querySelectorAll(".page-btn").length===9')
            n+=assertx(page.locator('#handoff-btn').is_visible(),'handoff action visible')
            page.locator('#field-headline').fill('Alchemy editorial handoff acceptance')
            page.locator('#handoff-btn').click()
            n+=assertx(page.locator('#handoff-dialog').is_visible(),'handoff dialog visible')
            n+=assertx('9 candidate pages' in page.locator('#handoff-page-count').inner_text(),'nine pages accounted for')
            n+=assertx('Local revision:' in page.locator('#handoff-revision').inner_text(),'local revision disclosed')
            n+=assertx('SHA-256:' in page.locator('#handoff-digest').inner_text(),'content identity disclosed')
            n+=assertx('stage-publisher' in page.locator('#handoff-stage-command').inner_text(),'owned stage command')
            n+=assertx('--mode preview' in page.locator('#handoff-build-command').inner_text(),'preview-only build command')
            with page.expect_download() as dl:page.locator('#handoff-download').click()
            content=dl.value.path().read_text(encoding='utf8') if hasattr(dl.value.path(),'read_text') else pathlib.Path(dl.value.path()).read_text(encoding='utf8')
            candidate=work/'editor.json';candidate.write_text(content,encoding='utf8')
            exported=json.loads(content)
            n+=assertx(dl.value.suggested_filename=='rasenfalcon-publisher-handoff.json','fixed non-executable JSON filename')
            n+=assertx(exported['schema']=='alchemy.website.publisher.export/0.1','contract preserved')
            n+=assertx(exported['authority']=='CANDIDATE_ONLY','no authority claimed')
            n+=assertx(exported['pages']['home']['headline']=='Alchemy editorial handoff acceptance','updated candidate retained')
            n+=assertx(len(exported['pages'])==9,'all page records exported')
            page.locator('#handoff-close').click()
            n+=assertx(not page.locator('#handoff-dialog').is_visible(),'dialog closes')
            browser.close()
        stage=work/'staged'
        rc,data=run_site(builder,'stage-publisher',candidate,stage)
        n+=assertx(rc==0 and data['ok'],'real Rasen Falcon builder accepts editor export')
        report=json.loads((stage/'staging.json').read_text())
        n+=assertx(report['state']=='CANDIDATE_UNREVIEWED' and report['authority']=='NONE','stage has no publication authority')
        n+=assertx(report['native_revision_verified'] is False,'stage refuses native identity proof')
        n+=assertx(not report['production_build_allowed'],'production blocked in staging')
        n+=assertx(report['cms_release_receipts']==[] and report['wire_release_receipts']==[],'no invented receipts')
        n+=assertx(len(report['pages'])==9,'nine staged page identities')
        n+=assertx(report['input_sha256']==hashlib.sha256(candidate.read_bytes()).hexdigest(),'source-byte hash preserved')
        home=json.loads((stage/'content/pages/home.json').read_text())
        n+=assertx(home['headline']=='Alchemy editorial handoff acceptance' and home['status']=='candidate','content preserved, candidate state forced')
        preview=work/'preview'
        rc,data=run_site(builder,'build','--mode','preview','--content-dir',stage/'content','--output-dir',preview)
        n+=assertx(rc==0 and data['ok'],'independent nine-page preview build works')
        n+=assertx((preview/'index.html').is_file(),'preview home output')
        n+=assertx('Alchemy editorial handoff acceptance' in (preview/'index.html').read_text(),'preview renders edited text')
        n+=assertx('noindex,nofollow' in (preview/'index.html').read_text(),'preview cannot claim indexable production')
        n+=assertx('Disallow: /' in (preview/'robots.txt').read_text(),'preview robots denies crawlers')
        n+=assertx(len(list(preview.rglob('index.html')))==9,'all nine pages actually rendered')
        rc,_=run_site(builder,'stage-publisher',candidate,stage)
        n+=assertx(rc!=0 and stage.joinpath('staging.json').read_text()==json.dumps(report,ensure_ascii=False,indent=2,sort_keys=True)+'\n','existing stage denied without change')
        rc,_=run_site(builder,'build','--mode','preview','--content-dir',stage/'content','--output-dir',preview)
        n+=assertx(rc!=0,'preview overwrite denied')
        bad=dict(exported,authority='APPROVED');f=work/'forged.json';f.write_text(json.dumps(bad))
        rc,_=run_site(builder,'stage-publisher',f,work/'forged-stage')
        n+=assertx(rc!=0 and not (work/'forged-stage').exists(),'claimed approval rejected')
        bad=dict(exported,pages={k:v for k,v in exported['pages'].items() if k!='home'});f.write_text(json.dumps(bad))
        rc,_=run_site(builder,'stage-publisher',f,work/'short-stage')
        n+=assertx(rc!=0 and not (work/'short-stage').exists(),'missing page rejected')
        f.write_text(content.replace('"authority": "CANDIDATE_ONLY"','"authority": "CANDIDATE_ONLY", "authority": "CANDIDATE_ONLY"'))
        rc,_=run_site(builder,'stage-publisher',f,work/'duplicate-key-stage')
        n+=assertx(rc!=0 and not (work/'duplicate-key-stage').exists(),'duplicate envelope keys rejected')
        native=work/'native.json';native.write_text(json.dumps({'schema':'alchemy.website.publisher.native-record/0.2','provider':'NoSQLServer','backend':'SQLITE_NATIVE_READWRITE','authority':'CANDIDATE_ONLY','revision':3,'parent_revision':2,'document':content}))
        rc,_=run_site(builder,'stage-publisher',native,work/'native-stage')
        n+=assertx(rc==0,'native-record wrapper correctly accepted as unverified input')
        nr=json.loads((work/'native-stage/staging.json').read_text())
        n+=assertx(nr['native_revision']==3 and nr['native_revision_verified'] is False,'native revision carried without promotion')
        native_doc=json.loads(native.read_text());native_doc['authority']='APPROVED';native.write_text(json.dumps(native_doc))
        rc,_=run_site(builder,'stage-publisher',native,work/'native-forged-stage')
        n+=assertx(rc!=0,'forged native authority rejected')
        rc,data=run_site(builder,'build','--mode','production','--content-dir',stage/'content','--output-dir',work/'production')
        n+=assertx(rc!=0 and not (work/'production').exists(),'production build remains denied')
    print(f'PASS {n} Publisher→Rasen Falcon v0.2 independent staging and preview assertions')

if __name__=='__main__':
    pa=argparse.ArgumentParser();pa.add_argument('--builder',type=pathlib.Path,required=True);ns=pa.parse_args()
    if not (ns.builder/'tools/site.py').is_file():raise SystemExit('Supply extracted rasenfalcon_site_v0.2 folder via --builder')
    main(ns.builder.resolve())
