#!/usr/bin/env python3
"""Rasen Falcon site publisher: standard-library only, preview-first, JSON CLI."""
import argparse
import hashlib
import html
import json
import pathlib
import re
import shutil
import sys
import tempfile
from pathlib import Path
from datetime import datetime, timezone
from urllib.parse import quote

ROOT=pathlib.Path(__file__).resolve().parents[1]
CONTENT=ROOT/'content'
DIST=ROOT/'site'
SLUG=re.compile(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')

def load(path):
    with path.open(encoding='utf-8') as f: return json.load(f)
def dump(path, value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
def canonical(value): return json.dumps(value,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()
def sha(value): return hashlib.sha256(value if isinstance(value,bytes) else canonical(value)).hexdigest()
def esc(value): return html.escape(str(value),quote=True)
def pages(content_dir=None):
    source=Path(content_dir) if content_dir is not None else CONTENT
    return {p.stem:load(p) for p in sorted((source/'pages').glob('*.json'))}
def validate(content_dir=None):
    source=Path(content_dir) if content_dir is not None else CONTENT
    issues=[]; config=load(source/'site.json'); pp=pages(source)
    if config.get('schema')!='rasenfalcon.site/0.1': issues.append('site schema')
    if 'home' not in pp: issues.append('home page missing')
    for slug,page in pp.items():
        if not SLUG.fullmatch(slug): issues.append(f'invalid slug {slug}')
        if page.get('slug')!=slug: issues.append(f'{slug}: slug mismatch')
        for field in ('title','eyebrow','headline','intro','summary'):
            if not isinstance(page.get(field),str) or not page[field].strip(): issues.append(f'{slug}: {field} missing')
        if page.get('status') not in ('candidate','approved'): issues.append(f'{slug}: invalid status')
        if not isinstance(page.get('sections'),list) or len(page['sections'])<2: issues.append(f'{slug}: at least two sections required')
        for i,s in enumerate(page.get('sections',[])):
            if not s.get('heading') or not s.get('body'): issues.append(f'{slug}: section {i} incomplete')
        for link in page.get('related',[]):
            if link not in pp: issues.append(f'{slug}: unknown related page {link}')
    for slug in config.get('navigation',[]):
        if slug not in pp: issues.append(f'missing nav {slug}')
    return issues

def url(slug,from_slug):
    prefix='' if from_slug=='home' else '../'
    return prefix + ('' if slug=='home' else slug+'/') + 'index.html'

def emblem(size=104):
    # Original abstract botanical mark, deliberately not a Commonwealth coat of arms.
    return f'''<svg width="{size}" height="{size}" viewBox="0 0 120 120" fill="none" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">
      <path d="M28 100C42 80 53 63 72 22M45 79L25 59M51 70L71 84M60 51L40 35M65 40L87 56" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      <g fill="currentColor"><circle cx="73" cy="21" r="5"/><circle cx="63" cy="16" r="4"/><circle cx="83" cy="24" r="4"/><circle cx="87" cy="56" r="5"/><circle cx="95" cy="49" r="3.8"/><circle cx="96" cy="63" r="3.5"/><circle cx="39" cy="35" r="5"/><circle cx="29" cy="32" r="3.8"/><circle cx="44" cy="25" r="3.5"/><circle cx="24" cy="59" r="5"/><circle cx="15" cy="54" r="3.5"/><circle cx="25" cy="70" r="3.5"/><circle cx="71" cy="84" r="4.5"/><circle cx="79" cy="78" r="3.5"/><circle cx="78" cy="91" r="3.5"/></g>
    </svg>'''

def render(config, pp, slug, page, mode='preview'):
    E=esc
    prefix='' if slug=='home' else '../'
    mast=f'''<header class="masthead"><a class="identity" href="{url('home',slug)}" aria-label="Rasen Falcon home"><span class="identity-emblem">{emblem(36)}</span><span>RASEN <span class="divider-dot">·</span> FALCON</span></a><button id="menu-button" class="menu-toggle" aria-expanded="false" aria-controls="primary-navigation">Menu <span aria-hidden="true">☰</span></button><nav id="primary-navigation" aria-label="Primary navigation"><a href="{url('home',slug)}" {'aria-current="page"' if slug=='home' else ''}>Home</a>'''
    for target in config['navigation']:
        p=pp[target]; mast+=f'''<a href="{url(target,slug)}" {'aria-current="page"' if slug==target else ''}>{E(p['nav_label'])}</a>'''
    mast+='</nav></header>'
    hero=f'''<section class="hero {'hero-home' if slug=='home' else 'hero-sub'}"><div class="hero-copy"><p class="eyebrow"><span class="rule-small"></span>{E(page['eyebrow'])}</p><h1>{E(page['headline'])}</h1><p class="hero-intro">{E(page['intro'])}</p><div class="hero-actions"><a class="text-action" href="{url('alchemy' if slug=='home' else 'contact',slug)}">{'Explore Alchemy' if slug=='home' else 'Start a conversation'} <span aria-hidden="true">↗</span></a><span class="edition">FIELD NOTES / {E(config['edition'])}</span></div></div><div class="hero-art"><div class="seal-back"><div class="seal-number">R / F</div><span class="seal-line"></span>{emblem(188)}<span class="seal-caption">EXPERIMENTAL SYSTEMS<br/>OBSERVATION · INTENTION · DESIGN</span></div></div></section>'''
    sections=[]
    for index,s in enumerate(page['sections'],1):
        bullets=''
        if s.get('points'):
            bullets='<ul class="point-list">'+''.join('<li>'+E(v)+'</li>' for v in s['points'])+'</ul>'
        sections.append(f'''<section class="editorial-section"><div class="section-number">{index:02d} / {len(page['sections']):02d}</div><div class="section-content"><h2>{E(s['heading'])}</h2><p>{E(s['body'])}</p>{bullets}</div></section>''')
    related=''.join(f'''<a class="related-card" href="{url(t,slug)}"><span class="card-eyebrow">{E(pp[t]['eyebrow'])}</span><span class="card-title">{E(pp[t]['title'])}</span><span class="card-text">{E(pp[t]['summary'])}</span><span class="card-arrow" aria-hidden="true">↗</span></a>''' for t in page.get('related',[]))
    if related: related=f'<section class="related"><div class="related-heading"><p class="eyebrow">CONTINUE READING</p><h2>Explore the work.</h2></div><div class="related-grid">{related}</div></section>'
    feature=''
    if slug=='home':
        feature='''<section class="quote-band"><div class="quote-decor" aria-hidden="true">“</div><blockquote>Intelligence is more useful when it can explain what it knows, what it intends, and what it is permitted to do.</blockquote><p>THE ALCHEMY APPROACH</p></section>'''
    footer=f'''<footer class="footer"><div class="footer-top"><div><span class="footer-mark">{emblem(58)}</span><p class="footer-name">RASEN FALCON</p><p>The public home of Alchemy.</p></div><div class="footer-links"><a href="{url('alchemy',slug)}">The project</a><a href="{url('contact',slug)}">Enquiries</a><a href="{url('privacy',slug)}">Privacy</a></div></div><div class="footer-baseline"><span>© {datetime.now(timezone.utc).year} Rasen Falcon</span><span>{E(config['footer'])}</span></div></footer>'''
    title=E(page['title']+' — Rasen Falcon')
    meta=E(page['summary'])
    canon=config['sitemap_base']+('/' if slug=='home' else f'/{slug}/')
    pathassets=prefix+'assets/'
    # Preview is never indexable, even when a source page says 'approved'.
    robots='index,follow' if mode=='production' else 'noindex,nofollow'
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="color-scheme" content="light"><meta name="theme-color" content="#f5f1e6"><meta name="description" content="{meta}"><meta name="robots" content="{robots}"><link rel="canonical" href="{E(canon)}"><link rel="icon" type="image/svg+xml" href="{pathassets}favicon.svg"><link rel="stylesheet" href="{pathassets}site.css"><title>{title}</title></head>
<body><a class="skip-link" href="#main">Skip to content</a><div class="site-shell">{mast}<main id="main">{hero}<div class="page-body"><div class="editorial-intro"><span class="display-label">01 / THE SUBJECT</span><p>{E(page['summary'])}</p></div>{''.join(sections)}{feature}</div>{related}<section class="outro"><div><p class="eyebrow">RASEN FALCON / ENQUIRIES</p><h2>There is more to make.</h2></div><a class="outlined-action" href="{url('contact',slug)}">Get in touch <span aria-hidden="true">↗</span></a></section></main>{footer}</div><script src="{pathassets}site.js" defer></script></body></html>'''

def build(mode='preview', content_dir=None, output_dir=None):
    if mode not in ('preview','production'):
        raise ValueError('unsupported build mode')
    source=Path(content_dir) if content_dir is not None else CONTENT
    out=Path(output_dir) if output_dir is not None else DIST
    issues=validate(source);pp=pages(source);config=load(source/'site.json')
    if issues: raise ValueError('; '.join(issues))
    if mode=='production':
        # Editorial labels and locally supplied approvals are not trusted CMS/Wire
        # publication authority. A real external release receipt verifier is pending.
        raise ValueError('publication gate denied: authenticated CMS, Brand and Wire release receipts not integrated')
    if output_dir is not None:
        if out.exists(): raise ValueError('preview output already exists; overwrite denied')
        if out.resolve() in (ROOT.resolve(), source.resolve()) or out.resolve() in source.resolve().parents:
            raise ValueError('unsafe output path')
    elif DIST.exists():
        shutil.rmtree(DIST)  # Original managed preview location only.
    (out/'assets').mkdir(parents=True)
    for asset in ('site.css','site.js','favicon.svg'):
        shutil.copy2(ROOT/'assets'/asset,out/'assets'/asset)
    manifest=[];resources=[]
    for slug,page in pp.items():
        d=out if slug=='home' else out/slug
        d.mkdir(parents=True,exist_ok=True)
        b=render(config,pp,slug,page,mode=mode).encode('utf-8')
        (d/'index.html').write_bytes(b)
        uri='/' if slug=='home' else '/'+slug+'/'
        manifest.append({'slug':slug,'path':uri,'file':str((d/'index.html').relative_to(out)),'sha256':sha(b),'content_sha256':sha(page),'status':page['status']})
        resources.append({'proposedResourceId':'RF.PAGE.'+slug.upper().replace('-','_'),'resourceClass':'STRUCTURED','locale':'en-GB','sourceSha256':sha(page),'publicationStatus':'CANDIDATE_UNPUBLISHED','semanticRole':'PRIMARY_CONTENT','slug':slug})
    (out/'robots.txt').write_text('User-agent: *\nDisallow: /\n' if mode=='preview' else 'User-agent: *\nAllow: /\nSitemap: https://rasenfalcon.com/sitemap.xml\n',encoding='utf-8')
    if mode=='production':
        import xml.sax.saxutils as sx
        sitemap=''.join('<url><loc>'+sx.escape(config['sitemap_base']+m['path'])+'</loc></url>' for m in manifest)
        (out/'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+sitemap+'</urlset>',encoding='utf-8')
    cms={'schema':'rasenfalcon.cms-export/0.1','publication_state':mode,'site':config['domain'],'brand_policy':config['identity'],'pages':manifest,'candidate_resource_inputs':resources,'published_wire_refs':[],'authority':'editorial source candidate; CMS Brand Builder import and Wire Resource Editor publication not asserted'}
    dump(out/'cms-export.json',cms)
    digest=sha({m['file']:m['sha256'] for m in manifest})
    dump(out/'build-manifest.json',{'schema':'rasenfalcon.build/0.1','mode':mode,'site_digest':digest,'pages':manifest,'source':'content/pages/*.json','wire_builder_target':'WIRE-UI-DESIGN/0.7','runtime_target':'WIRE-UI/0.1','not_a_wire_release':True})
    return {'ok':True,'mode':mode,'pages':len(pp),'site_digest':digest,'output':str(out)}


# Deliberately offline: there is no browser or untrusted JSON path to CMS or
# Wire release authority. This adapter imports only a complete nine-page
# candidate, with source lineage, into a separate immutable staging directory.
def _unique_pairs(pairs):
    result={}
    for k,v in pairs:
        if k in result: raise ValueError('duplicate JSON key: '+k)
        result[k]=v
    return result

def _json_candidate(blob):
    return json.loads(blob,object_pairs_hook=_unique_pairs)

def _nonneg_int(value):
    return type(value) is int and 0<=value<=9007199254740991

def _editorial_page(slug, value, expected):
    if not isinstance(value,dict) or value.get('slug')!=slug:
        raise ValueError('page identity mismatch: '+slug)
    allowed={'slug','title','nav_label','eyebrow','headline','intro','summary','sections','related','status'}
    if set(value)-allowed: raise ValueError('unrecognised editorial field: '+slug)
    page={k:value[k] for k in allowed if k in value}
    for field in ('title','nav_label','eyebrow','headline','intro','summary'):
        if not isinstance(page.get(field),str) or not page[field].strip():
            raise ValueError('invalid '+slug+' field: '+field)
    sections=page.get('sections')
    if not isinstance(sections,list) or len(sections)<2 or len(sections)>64:
        raise ValueError('invalid section count: '+slug)
    for item in sections:
        if not isinstance(item,dict) or set(item)-{'heading','body','points'}:
            raise ValueError('invalid section structure: '+slug)
        if any(not isinstance(item.get(k),str) or not item[k].strip() for k in ('heading','body')):
            raise ValueError('incomplete section: '+slug)
        if 'points' in item and (not isinstance(item['points'],list) or
            len(item['points'])>100 or any(not isinstance(pt,str) for pt in item['points'])):
            raise ValueError('invalid section points: '+slug)
    related=page.get('related',[])
    if not isinstance(related,list) or any(not isinstance(r,str) or r not in expected for r in related):
        raise ValueError('invalid related page: '+slug)
    if page.get('status') not in ('candidate','approved'):
        raise ValueError('invalid status: '+slug)
    # Editorial status is untrusted. No status or claimed approval may be
    # promoted across this boundary; production stays independently blocked.
    page['status']='candidate'
    return page

def stage_publisher(source_file, dest):
    inp=Path(source_file)
    if inp.stat().st_size>3000000:
        raise ValueError('publisher export exceeds 3 MB limit')
    raw=inp.read_bytes()
    record=_json_candidate(raw)
    if not isinstance(record,dict): raise ValueError('invalid publisher envelope')
    native_revision=None
    if record.get('schema')=='alchemy.website.publisher.native-record/0.2':
        if (record.get('provider')!='NoSQLServer' or
            record.get('backend')!='SQLITE_NATIVE_READWRITE' or
            record.get('authority')!='CANDIDATE_ONLY' or
            not _nonneg_int(record.get('revision')) or record['revision']<1 or
            not isinstance(record.get('document'),str)):
            raise ValueError('untrusted native record')
        native_revision=record['revision']
        record=_json_candidate(record['document'])
    if not isinstance(record,dict) or record.get('schema')!='alchemy.website.publisher.export/0.1':
        raise ValueError('unsupported publisher export schema')
    config=load(CONTENT/'site.json')
    expected=pages()
    if record.get('site')!=config['domain'] or record.get('authority')!='CANDIDATE_ONLY':
        raise ValueError('wrong site or claimed publication authority')
    if not _nonneg_int(record.get('revision')):
        raise ValueError('invalid editorial revision')
    imported=record.get('pages')
    if not isinstance(imported,dict) or set(imported)!=set(expected):
        raise ValueError('publisher export must contain exactly the configured pages')
    candidate={slug:_editorial_page(slug,imported[slug],expected) for slug in sorted(expected)}
    target=Path(dest).absolute()
    if target.exists(): raise ValueError('staging target already exists; overwrite denied')
    if target.resolve()==ROOT.resolve() or target.resolve() in ROOT.resolve().parents:
        raise ValueError('unsafe staging target')
    target.parent.mkdir(parents=True,exist_ok=True)
    work=Path(tempfile.mkdtemp(prefix='.rasenfalcon-stage-',dir=target.parent))
    try:
        stage=work/'content';(stage/'pages').mkdir(parents=True)
        dump(stage/'site.json',config)
        for slug,page in candidate.items(): dump(stage/'pages'/(slug+'.json'),page)
        report={
          'schema':'rasenfalcon.publisher-stage/0.1',
          'state':'CANDIDATE_UNREVIEWED',
          'authority':'NONE',
          'site':config['domain'],
          'origin_schema':'alchemy.website.publisher.export/0.1',
          'input_sha256':sha(raw),
          'publisher_revision':record['revision'],
          'native_revision':native_revision,
          'native_revision_verified':False,
          'pages':[{'slug':slug,'content_sha256':sha(candidate[slug])} for slug in candidate],
          'cms_release_receipts':[], 'wire_release_receipts':[],
          'production_build_allowed':False,
        }
        dump(work/'staging.json',report)
        # A fully validated snapshot is atomically presented to reviewers.
        work.rename(target)
    except BaseException:
        shutil.rmtree(work,ignore_errors=True)
        raise
    return {'ok':True,'staging':str(target),'page_count':len(candidate),
            'state':'CANDIDATE_UNREVIEWED','input_sha256':sha(raw),
            'native_revision_verified':False}

def main():
    parser=argparse.ArgumentParser(description='Rasen Falcon editorial site compiler')
    sub=parser.add_subparsers(dest='command',required=True)
    b=sub.add_parser('build');b.add_argument('--mode',choices=['preview','production'],default='preview');b.add_argument('--content-dir');b.add_argument('--output-dir')
    st=sub.add_parser('stage-publisher');st.add_argument('source');st.add_argument('destination')
    sub.add_parser('validate');sub.add_parser('status')
    s=sub.add_parser('set');s.add_argument('slug');s.add_argument('field',choices=['title','headline','intro','summary','eyebrow']);s.add_argument('value');s.add_argument('--expect-sha256')
    ss=sub.add_parser('set-section');ss.add_argument('slug');ss.add_argument('index',type=int,help='zero-based section index');ss.add_argument('field',choices=['heading','body']);ss.add_argument('value');ss.add_argument('--expect-sha256')
    sh=sub.add_parser('show');sh.add_argument('slug')
    args=parser.parse_args()
    try:
        if args.command=='build':result=build(args.mode,args.content_dir,args.output_dir)
        elif args.command=='stage-publisher':result=stage_publisher(args.source,args.destination)
        elif args.command=='validate':
            issues=validate();result={'ok':not issues,'issues':issues,'page_count':len(pages())}
        elif args.command=='status':
            result={'ok':True,'pages':[{'slug':k,'title':v['title'],'status':v['status'],'content_sha256':sha(v)} for k,v in pages().items()],'identity_status':load(CONTENT/'site.json')['identity']['decision_status']}
        else:
            if not SLUG.fullmatch(args.slug): raise ValueError('invalid slug')
            path=CONTENT/'pages'/f'{args.slug}.json'
            if not path.is_file(): raise ValueError('unknown slug')
            page=load(path)
            if args.command=='show':
                result={'ok':True,'slug':args.slug,'content_sha256':sha(page),'page':page}
            else:
                old_digest=sha(page)
                if args.expect_sha256 and args.expect_sha256!=old_digest: raise ValueError('stale source: expected SHA-256 does not match')
                if args.command=='set':page[args.field]=args.value
                elif args.command=='set-section':
                    if args.index<0 or args.index>=len(page['sections']): raise ValueError('section index outside range')
                    page['sections'][args.index][args.field]=args.value
                page['status']='candidate';dump(path,page)
                result={'ok':True,'slug':args.slug,'field':args.field,'status':'candidate','previous_sha256':old_digest,'content_sha256':sha(page)}
    except Exception as ex:result={'ok':False,'error':str(ex)}
    print(json.dumps(result,sort_keys=True,ensure_ascii=False))
    return 0 if result['ok'] else 2
if __name__=='__main__':sys.exit(main())
