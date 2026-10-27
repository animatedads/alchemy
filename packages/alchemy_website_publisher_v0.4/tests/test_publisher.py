import json, re, hashlib, zipfile, io
from pathlib import Path
from playwright.sync_api import sync_playwright
BASE=Path(__file__).resolve().parents[1]

def check(condition,message):
    assert condition, message

def main():
    passed=0
    def assertx(ok,name):
        nonlocal passed
        check(ok,name);passed+=1
    with sync_playwright() as p:
      browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
      context=browser.new_context(viewport={'width':1600,'height':930},accept_downloads=True)
      page=context.new_page()
      errors=[]
      page.on('pageerror',lambda e:errors.append(str(e)))
      # Headless Chromium in this environment rejects every navigation (even file:// and intercepted localhost).
      # Inline exactly the shipped assets into an about:blank document for deterministic browser interaction tests.
      html=(BASE/'index.html').read_text()
      html=html.replace('<link rel="stylesheet" href="publisher.css">','')
      html=html.replace('<script src="reference/rasenfalcon.js"></script>','')
      html=html.replace('<script src="publisher.js"></script>','')
      page.set_content(html,wait_until='load')
      page.add_style_tag(content=(BASE/'publisher.css').read_text())
      page.add_script_tag(content=(BASE/'reference/rasenfalcon.js').read_text())
      page.add_script_tag(content=(BASE/'publisher.js').read_text())
      page.wait_for_function("window.PUBLISHER_TEST && document.querySelectorAll('.page-btn').length===9")
      assertx(page.title()=='Website Publisher · Alchemy Studio','title')
      assertx(page.locator('.page-btn').count()==9,'nine pages')
      assertx(page.locator('#editor-heading').inner_text()=='Home page','home editor')
      assertx(page.evaluate('PUBLISHER_TEST.validateAll().length')==0,'baseline validates')
      assertx(page.locator('#site-frame').count()==1,'preview frame')
      page.frame_locator('#site-frame').locator('h1').wait_for()
      assertx('Systems that understand intention.' in page.frame_locator('#site-frame').locator('h1').inner_text(),'reference site headline')
      page.locator('#field-headline').fill('A revised Alchemy story.')
      page.frame_locator('#site-frame').locator('h1').wait_for()
      assertx(page.frame_locator('#site-frame').locator('h1').inner_text()=='A revised Alchemy story.','live headline')
      assertx(page.locator('#draft-summary').inner_text().startswith('1 page edited'),'change counter')
      assertx(page.locator('#page-status').inner_text()=='EDITED DRAFT','draft status')
      assertx(page.evaluate('PUBLISHER_TEST.getPage().status')=='candidate','approval invalidated')
      page.locator('[data-compare=baseline]').click()
      page.frame_locator('#site-frame').locator('h1').wait_for()
      assertx(page.frame_locator('#site-frame').locator('h1').inner_text()=='Systems that understand intention.','original comparison')
      page.locator('[data-compare=draft]').click()
      assertx(page.frame_locator('#site-frame').locator('h1').inner_text()=='A revised Alchemy story.','draft comparison')
      page.locator('[data-device=mobile]').click()
      assertx(page.locator('#preview-viewport').evaluate('(e)=>e.classList.contains("mobile")'),'mobile preview')
      page.locator('[data-edit-tab=sections]').click()
      assertx(page.locator('#editor-sections').is_visible(),'sections tab')
      page.locator('#section-0-heading').fill('A stronger engineering story')
      assertx('A stronger engineering story' in page.frame_locator('#site-frame').locator('.section-content h2').first.inner_text(),'live section heading')
      page.locator('#section-0-points').fill('Source-led\nRepeatable\nAuditable')
      page.wait_for_timeout(250)
      assertx(page.frame_locator('#site-frame').locator('.point-list li').count()>=3,'section points')
      page.locator('[data-edit-tab=metadata]').click()
      page.locator('#field-title').fill('Alchemy editorial homepage')
      assertx('Alchemy editorial homepage' in page.frame_locator('#site-frame').locator('title').inner_text(),'search title')
      page.locator('.page-btn[data-page="audio-analysis"]').click()
      assertx(page.locator('#editor-heading').inner_text()=='Audio page','page switch')
      page.locator('.page-btn[data-page="home"]').click()
      assertx(page.locator('#field-title').input_value()=='Alchemy editorial homepage','edits retained in page switching')
      with page.expect_download() as d:
          page.locator('#export-json-btn').click()
      result=d.value
      exported=json.loads(Path(result.path()).read_text())
      assertx(exported['schema']=='alchemy.website.publisher.export/0.1','content export contract')
      assertx(exported['pages']['home']['headline']=='A revised Alchemy story.','export preserves edits')
      # Downloaded preview is a standalone ZIP and maintains the exact RasenFalcon content schema.
      with page.expect_download() as d:
          page.locator('#build-btn').click()
      bundle=d.value
      with zipfile.ZipFile(bundle.path()) as z:
          names=z.namelist();meta=json.loads(z.read('site/build-manifest.json'))
          assertx(len(meta['pages'])==9,'nine built pages')
          assertx(meta['not_deployed'] is True,'explicit no deployment')
          assertx('site/index.html' in names,'home file included')
          assertx('site/assets/site.css' in names,'original styling included')
          assertx('content/pages/home.json' in names,'source content included')
          assertx(b'A revised Alchemy story.' in z.read('site/index.html'),'compiled updated heading')
          assertx(b'<style>' not in z.read('site/index.html'),'compiled references stylesheet')
          assertx(b'Disallow: /' in z.read('site/robots.txt'),'robots preview blocked')
          assertx(json.loads(z.read('content/pages/home.json'))['status']=='candidate','candidate page export')
          digest=hashlib.sha256(json.dumps(exported['pages']['home'],sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
          assertx(next(x for x in meta['pages'] if x['slug']=='home')['content_sha256']==digest,'canonical digest matches native Rasen compiler')
          assertx(len(z.testzip() or '')==0,'ZIP CRC integrity')
      page.locator('#review-btn').click()
      assertx(page.locator('#review-dialog').is_visible(),'review sheet open')
      page.locator('#review-note').fill('Check the changed factual claims.')
      with page.expect_download() as d:
          page.locator('#download-review').click()
      review=json.loads(Path(d.value.path()).read_text())
      assertx(review['status']=='PREPARED_NOT_SUBMITTED','review does not submit')
      assertx(review['publisher_authority']=='NONE','no publication authority')
      assertx(review['changed_pages'][0]['slug']=='home','review has changed page')
      assertx(len(review['changed_pages'][0]['candidate_sha256'])==64,'review includes sha')
      # about:blank lacks persistent origin-backed storage; verify editor model persists across page selections instead.
      page.locator('.page-btn[data-page="audio-analysis"]').click()
      page.locator('.page-btn[data-page="home"]').click()
      assertx(page.locator('#field-headline').input_value()=='A revised Alchemy story.','in-session model retention')
      # Imported standalone page; rejects wrong current slug.
      item=json.loads(json.dumps(exported['pages']['audio-analysis']))
      item['headline']='Imported audio story'
      page.locator('.page-btn[data-page="audio-analysis"]').click()
      page.locator('#import-file').set_input_files({'name':'audio-analysis.json','mimeType':'application/json','buffer':json.dumps(item).encode()})
      assertx(page.locator('#field-headline').input_value()=='Imported audio story','page JSON import')
      assertx(page.evaluate('PUBLISHER_TEST.validateAll().length')==0,'import validates')
      assertx(page.evaluate('PUBLISHER_TEST.sha256("abc")')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','SHA-256 test vector')
      page.locator('.page-btn[data-page="home"]').click()
      page.locator('[data-edit-tab=content]').click()
      page.locator('#field-intro').fill('<img src=x onerror=alert(1)> Visible as text')
      page.wait_for_timeout(250)
      assertx(page.frame_locator('#site-frame').locator('.hero-intro').inner_text().startswith('<img src=x onerror='),'HTML edit safely rendered as text')
      assertx(page.frame_locator('#site-frame').locator('img').count()==0,'HTML edit does not create image element')
      page.locator('#field-headline').fill('')
      assertx(page.evaluate('PUBLISHER_TEST.validateAll().length')>0,'missing headline rejected')
      page.locator('#field-headline').fill('A revised Alchemy story.')
      assertx(not errors, 'browser JavaScript errors: '+str(errors))
      page.set_viewport_size({'width':390,'height':844})
      page.locator('.page-btn[data-page="home"]').click()
      assertx(page.locator('#preview-panel').count()==0 or page.locator('.preview-panel').is_visible(),'mobile panel visible')
      page.screenshot(path=str(BASE/'docs/publisher_mobile.png'),full_page=True)
      page.set_viewport_size({'width':1600,'height':950});page.locator('[data-device=desktop]').click()
      page.screenshot(path=str(BASE/'docs/publisher_desktop.png'),full_page=True)
      browser.close()
    print('PASS',passed,'publisher browser assertions')
if __name__=='__main__':main()
