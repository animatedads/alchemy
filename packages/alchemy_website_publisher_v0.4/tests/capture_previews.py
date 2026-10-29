from pathlib import Path
from playwright.sync_api import sync_playwright
b=Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage'])
    for width,height,path in [(1600,1000,'publisher_desktop.png'),(390,850,'publisher_mobile.png')]:
        context=browser.new_context(viewport={'width':width,'height':height},device_scale_factor=1)
        page=context.new_page()
        html=(b/'index.html').read_text()
        for src in ['<link rel="stylesheet" href="publisher.css">','<script src="reference/rasenfalcon.js"></script>','<script src="publisher.js"></script>']:
            html=html.replace(src,'')
        page.set_content(html)
        page.add_style_tag(content=(b/'publisher.css').read_text())
        page.add_script_tag(content=(b/'reference/rasenfalcon.js').read_text())
        page.add_script_tag(content=(b/'publisher.js').read_text())
        page.frame_locator('#site-frame').locator('h1').wait_for()
        page.locator('[data-compare=baseline]').click()
        page.locator('[data-compare=draft]').click()
        page.frame_locator('#site-frame').locator('h1').scroll_into_view_if_needed()
        page.wait_for_timeout(700)
        page.screenshot(path=str(b/'docs'/path),full_page=True)
        print(path, (b/'docs'/path).stat().st_size)
        context.close()
    browser.close()
