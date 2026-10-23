import importlib.util
import pathlib
import tempfile
import unittest
from html.parser import HTMLParser
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('rf_site',ROOT/'tools'/'site.py')
rf=importlib.util.module_from_spec(spec);spec.loader.exec_module(rf)
class Links(HTMLParser):
    def __init__(self):super().__init__();self.hrefs=[];self.headers=[];self.meta=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='a' and 'href' in a:self.hrefs.append(a['href'])
        if tag=='h1':self.headers.append('h1')
        if tag=='meta' and a.get('name')=='robots':self.meta.append(a.get('content'))
class TestSite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):rf.build('preview')
    def test_schema(self):self.assertEqual([],rf.validate())
    def test_page_count(self):self.assertEqual(9,len(rf.pages()))
    def test_candidate_production_denied(self):
        with self.assertRaisesRegex(ValueError,'publication gate denied'):
            rf.build('production')
    def test_no_cdn_or_remote_assets(self):
        html=(ROOT/'site'/'index.html').read_text()
        for term in ('https://fonts.','googletagmanager','<iframe','<form','http://cdn.'):
            self.assertNotIn(term,html)
    def test_header_and_preview_noindex(self):
        for p in (ROOT/'site').rglob('index.html'):
            x=Links();x.feed(p.read_text())
            self.assertEqual(1,len(x.headers),str(p));self.assertEqual(['noindex,nofollow'],x.meta)
    def test_all_link_targets_exist(self):
        for p in (ROOT/'site').rglob('index.html'):
            x=Links();x.feed(p.read_text())
            for link in x.hrefs:
                if link.startswith(('#','mailto:','https:')):continue
                target=(p.parent/link).resolve()
                self.assertTrue(target.is_file(),f'{p}: {link}')
    def test_escaped_copy(self):
        site=rf.load(ROOT/'content'/'site.json');pp=rf.pages()
        page=dict(pp['home']);page['headline']='<script>alert(1)</script>'
        output=rf.render(site,pp,'home',page)
        self.assertNotIn('<script>alert(1)</script>',output)
        self.assertIn('&lt;script&gt;',output)
    def test_artifact_digest(self):
        m=rf.load(ROOT/'site'/'build-manifest.json');self.assertTrue(m['not_a_wire_release'])
        for page in m['pages']:
            self.assertEqual(rf.sha((ROOT/'site'/page['file']).read_bytes()),page['sha256'])
    def test_local_files_only(self):
        self.assertTrue((ROOT/'site'/'assets'/'site.css').is_file())
        self.assertTrue((ROOT/'site'/'assets'/'site.js').is_file())
        self.assertTrue((ROOT/'site'/'assets'/'favicon.svg').is_file())
        self.assertIn('Disallow: /',(ROOT/'site'/'robots.txt').read_text())
if __name__=='__main__':unittest.main()
