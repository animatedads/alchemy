import importlib.util
import pathlib
import json
from unittest.mock import patch
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
    def test_approved_source_still_noindexed_in_preview(self):
        cfg=rf.load(ROOT/'content'/'site.json')
        pp=rf.pages()
        approved=dict(pp['home']);approved['status']='approved'
        markup=rf.render(cfg, pp, 'home', approved, mode='preview')
        self.assertIn('name="robots" content="noindex,nofollow"', markup)
        self.assertNotIn('name="robots" content="index,follow"', markup)
    def test_forged_editorial_approval_cannot_authorise_release(self):
        page=rf.pages()['home']
        with tempfile.TemporaryDirectory() as temporary:
            tmp=pathlib.Path(temporary)
            (tmp/'pages').mkdir()
            # Even a self-declared approved page plus fake name/time cannot publish.
            for slug, value in rf.pages().items():
                candidate=dict(value);candidate['status']='approved'
                (tmp/'pages'/f'{slug}.json').write_text(json.dumps(candidate))
            (tmp/'site.json').write_text((ROOT/'content'/'site.json').read_text())
            (tmp/'approvals.json').write_text(json.dumps({slug:{'approved_by':'anyone','approved_at':'2026-10-24','content_sha256':rf.sha(dict(value,status='approved'))} for slug,value in rf.pages().items()}))
            with patch.object(rf,'CONTENT',tmp):
                with self.assertRaisesRegex(ValueError,'authenticated CMS, Brand and Wire'):
                    rf.build('production')
    def test_unsupported_build_mode_denied(self):
        with self.assertRaisesRegex(ValueError,'unsupported build mode'):
            rf.build('unexpected')
    def _export(self,**changes):
        record={'schema':'alchemy.website.publisher.export/0.1',
                'site':'rasenfalcon.com','authority':'CANDIDATE_ONLY',
                'revision':4,'pages':rf.pages()}
        record.update(changes)
        return record
    def _write_export(self,root,value):
        source=pathlib.Path(root)/'export.json'
        source.write_text(json.dumps(value,ensure_ascii=False),encoding='utf-8')
        return source
    def test_publisher_handoff_and_isolated_preview(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            export=self._export()
            export['pages']['home']['headline']='Revised candidate (not approved)'
            export['pages']['home']['status']='approved'
            source=self._write_export(root,export)
            previous=rf.sha((ROOT/'content'/'pages'/'home.json').read_bytes())
            staged=rf.stage_publisher(source,root/'staged')
            self.assertTrue(staged['ok'])
            self.assertEqual(9,staged['page_count'])
            self.assertFalse(staged['native_revision_verified'])
            self.assertEqual(previous,rf.sha((ROOT/'content'/'pages'/'home.json').read_bytes()))
            candidate=json.loads((root/'staged'/'content'/'pages'/'home.json').read_text())
            self.assertEqual('candidate',candidate['status'])
            self.assertEqual('Revised candidate (not approved)',candidate['headline'])
            meta=json.loads((root/'staged'/'staging.json').read_text())
            self.assertFalse(meta['production_build_allowed'])
            self.assertEqual([],meta['cms_release_receipts'])
            self.assertEqual([],meta['wire_release_receipts'])
            self.assertEqual(4,meta['publisher_revision'])
            self.assertIsNone(meta['native_revision'])
            preview=rf.build('preview',content_dir=root/'staged'/'content',output_dir=root/'preview')
            self.assertEqual(9,preview['pages'])
            self.assertIn('Revised candidate (not approved)',(root/'preview'/'index.html').read_text())
            self.assertIn('noindex,nofollow',(root/'preview'/'index.html').read_text())
            with self.assertRaisesRegex(ValueError,'already exists'):
                rf.build('preview',content_dir=root/'staged'/'content',output_dir=root/'preview')
            with self.assertRaisesRegex(ValueError,'already exists'):
                rf.stage_publisher(source,root/'staged')
            with self.assertRaisesRegex(ValueError,'authenticated CMS'):
                rf.build('production',content_dir=root/'staged'/'content',output_dir=root/'production')
            self.assertFalse((root/'production').exists())
    def test_native_record_candidate_handoff(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            native={'schema':'alchemy.website.publisher.native-record/0.2',
                    'provider':'NoSQLServer','backend':'SQLITE_NATIVE_READWRITE',
                    'authority':'CANDIDATE_ONLY','revision':12,
                    'document':json.dumps(self._export())}
            source=self._write_export(root,native)
            rf.stage_publisher(source,root/'staged')
            staged=json.loads((root/'staged'/'staging.json').read_text())
            self.assertEqual(12,staged['native_revision'])
            self.assertFalse(staged['native_revision_verified'])
            native['authority']='PUBLISHED'
            source=self._write_export(root,native)
            with self.assertRaisesRegex(ValueError,'untrusted native'):
                rf.stage_publisher(source,root/'refused')
            self.assertFalse((root/'refused').exists())
    def test_publisher_stage_refuses_wrong_site_and_page_set(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            source=self._write_export(root,self._export(site='other.example'))
            with self.assertRaisesRegex(ValueError,'wrong site'):
                rf.stage_publisher(source,root/'bad-site')
            ps=rf.pages(); ps.pop('home')
            source=self._write_export(root,self._export(pages=ps))
            with self.assertRaisesRegex(ValueError,'exactly'):
                rf.stage_publisher(source,root/'missing-page')
            ps=rf.pages(); ps['../escape']=ps['home'].copy()
            source=self._write_export(root,self._export(pages=ps))
            with self.assertRaisesRegex(ValueError,'exactly'):
                rf.stage_publisher(source,root/'traversal')
            self.assertFalse((root/'traversal').exists())
    def test_publisher_stage_strips_claimed_approval_and_rejects_bad_fields(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            pages=rf.pages()
            pages['home']['approved_by']='someone'
            source=self._write_export(root,self._export(pages=pages))
            with self.assertRaisesRegex(ValueError,'unrecognised editorial field'):
                rf.stage_publisher(source,root/'claimed')
            pages=rf.pages(); pages['home']['sections']=[None,{}]
            source=self._write_export(root,self._export(pages=pages))
            with self.assertRaisesRegex(ValueError,'invalid section'):
                rf.stage_publisher(source,root/'badsections')
            source.write_text('{"schema":"x","schema":"y"}')
            with self.assertRaisesRegex(ValueError,'duplicate JSON'):
                rf.stage_publisher(source,root/'duplicate')
    def test_publisher_stage_refuses_size_and_revision_spoof(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            source=self._write_export(root,self._export(revision=True))
            with self.assertRaisesRegex(ValueError,'invalid editorial revision'):
                rf.stage_publisher(source,root/'bool')
            source.write_bytes(b' '*(3000001))
            with self.assertRaisesRegex(ValueError,'3 MB'):
                rf.stage_publisher(source,root/'large')
    def test_unknown_explicit_preview_target_does_not_destroy_source(self):
        with tempfile.TemporaryDirectory() as td:
            root=pathlib.Path(td)
            marker=root/'marker'; marker.mkdir();(marker/'precious').write_text('PRESERVE')
            with self.assertRaisesRegex(ValueError,'already exists'):
                rf.build('preview',output_dir=marker)
            self.assertEqual('PRESERVE',(marker/'precious').read_text())
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
