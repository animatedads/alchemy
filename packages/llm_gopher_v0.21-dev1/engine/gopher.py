#!/usr/bin/env python3
import argparse, json, os, re, shutil, subprocess, hashlib, zipfile, io, fnmatch, shlex, ast, tempfile, difflib, tokenize, socketserver, urllib.request, urllib.parse, urllib.error
from pathlib import Path

SCHEMA='llm-gopher/0.21'
TOOL_CLASSES={'OK':0,'INVALID_REQUEST':2,'UNAVAILABLE':3,'TEMPORARY_FAILURE':4,'PERMISSION_DENIED':5,'IMPLEMENTATION_FAILURE':6,'DEPENDENCY_FAILURE':7,'TIMEOUT':8}

OPERATION_SUCCESS_CLASSES={
    'OK','FOUND','EXISTS','MATCH','VALID','LISTED','MERGED','OPENED','EXAMINED',
    'PLANNED','UPDATED','READY','STAGED','RECORDED','CREATED','SUBMITTED','ACTIVATED','SAFE','CAUTION','AVAILABLE','MATERIALIZATION_REQUIRED','RECOVERABLE','CLEAN','WARNINGS','PACKAGED'
}

def env(tool_status='OK', operation_status='OK', result=None, **extra):
    operation_rc=0 if operation_status in OPERATION_SUCCESS_CLASSES else (2 if operation_status=='INVALID_ARGUMENT' else 1)
    d={'schema':SCHEMA,'tool_status':{'rc':TOOL_CLASSES.get(tool_status,6),'class':tool_status},
       'operation_status':{'rc':operation_rc,'class':operation_status},
       'result':result}
    d.update(extra); return d

def load_json(p):
    with open(p,encoding='utf-8') as f:return json.load(f)

def canonical(obj): return json.dumps(obj,sort_keys=True,separators=(',',':'))
def digest(obj): return hashlib.sha256(canonical(obj).encode()).hexdigest()

def pack_files(path):
    p=Path(path)
    if p.is_file(): return [p]
    return sorted(p.rglob('*.json'))

def load_pack(path):
    docs=[]
    for f in pack_files(path):
        o=load_json(f)
        if o.get('kind') in ('sphere','article','page-handler','tool','access-policy','capability','service','corpus','language-rule','language-module'): docs.append((str(f),o))
    return docs

def merge_packs(paths):
    # Stable identity is kind:id. Same identity+same body dedups; different bodies conflict.
    merged={}; provenance={}
    for path in paths:
        for src,o in load_pack(path):
            key=(o['kind'],o['id'])
            if key in merged:
                if canonical(merged[key]) != canonical(o):
                    return env('OK','CONFLICT',{'key':list(key),'existing_sources':provenance[key],'incoming_source':src})
                provenance[key].append(src)
            else:
                merged[key]=o; provenance[key]=[src]
    out=[]
    for k in sorted(merged):
        o=dict(merged[k]); o['_provenance']=provenance[k]; out.append(o)
    return env('OK','MERGED',{'documents':out,'count':len(out),'digest':digest(out)})

def build_index(paths):
    m=merge_packs(paths)
    if m['operation_status']['class']!='MERGED': return m
    docs=m['result']['documents']; idx={}
    for o in docs: idx[(o['kind'],o['id'])]=o
    return env('OK','OK',{'index':idx,'digest':m['result']['digest']})

def allowed(policy, role, action, resource):
    if not policy: return True
    for rule in policy.get('rules',[]):
        if role in rule.get('roles',[]) and (action in rule.get('actions',[]) or '*' in rule.get('actions',[])):
            pat=rule.get('resource','*')
            if pat=='*' or resource==pat or (pat.endswith('*') and resource.startswith(pat[:-1])):
                return rule.get('effect')=='allow'
    return False

def find_policy(idx,sphere):
    sid=sphere.get('access_policy')
    return idx.get(('access-policy',sid)) if sid else None

def open_article(idx, article_id, role):
    a=idx.get(('article',article_id))
    if not a: return env('OK','NOT_FOUND',{'article':article_id})
    sphere=idx.get(('sphere',a.get('sphere')))
    if not sphere: return env('IMPLEMENTATION_FAILURE','UNKNOWN',None,diagnostics=['article references missing sphere'])
    if not allowed(find_policy(idx,sphere),role,'read','article:'+article_id):
        return env('OK','DENIED',{'article':article_id})
    sels=[]
    for s in a.get('selectors',[]):
        action=s.get('action','read'); res=s.get('resource','selector:'+s.get('id',''))
        if allowed(find_policy(idx,sphere),role,action,res): sels.append(s)
    result={k:v for k,v in a.items() if not k.startswith('_') and k!='selectors'}
    result['selectors']=sels
    return env('OK','OPENED',result, evidence={'article_digest':digest(a),'sphere':sphere['id']})

def which(name): return shutil.which(name)

def run_cmd(argv, timeout=15):
    try:
        p=subprocess.run(argv,text=True,capture_output=True,timeout=timeout)
        return p
    except subprocess.TimeoutExpired:
        return None

def tool_locate(args):
    name=args.get('name')
    if not name:return env('INVALID_REQUEST','UNKNOWN',None)
    p=which(name)
    return env('OK','FOUND' if p else 'NOT_FOUND',{'name':name,'path':p})

def tool_sha256(args):
    p=Path(args.get('path',''))
    if not p.is_file(): return env('OK','NOT_FOUND',{'path':str(p)})
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    got=h.hexdigest(); expected=args.get('expected')
    st='MATCH' if expected and got.lower()==expected.lower() else ('MISMATCH' if expected else 'OK')
    return env('OK',st,{'path':str(p),'sha256':got,'expected':expected})

def zip_py_list(args):
    p=Path(args.get('path',''))
    if not p.is_file():return env('OK','NOT_FOUND',{'path':str(p)})
    try:
        with zipfile.ZipFile(p) as z:n=z.namelist()
        return env('OK','LISTED',{'path':str(p),'entries':n,'count':len(n),'route':'python.zipfile'})
    except zipfile.BadZipFile:return env('OK','INVALID_ARCHIVE',{'path':str(p),'route':'python.zipfile'})

def zip_unzip_list(args):
    if not which('unzip'):return env('UNAVAILABLE','UNKNOWN',None)
    p=Path(args.get('path',''))
    if not p.is_file():return env('OK','NOT_FOUND',{'path':str(p)})
    q=run_cmd(['unzip','-Z1',str(p)])
    if q is None:return env('TIMEOUT','UNKNOWN',None)
    if q.returncode:return env('OK','INVALID_ARCHIVE',{'stderr':q.stderr,'route':'shell.unzip'})
    n=q.stdout.splitlines();return env('OK','LISTED',{'entries':n,'count':len(n),'route':'shell.unzip'})

MAX_ARCHIVE_MEMBER_BYTES=64*1024*1024
TEXT_EXTENSIONS={'.rex','.cls','.rxj','.txt','.md','.json','.xml','.html','.htm','.css','.js','.ts','.py','.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx','.java','.sh','.bash','.ini','.cfg','.conf','.yaml','.yml','.toml','.sql','.csv','.properties','.mf','.cmake'}

def _open_zip_chain(path, nested=None):
    """Open a zip and optional ! separated nested zip members without extracting to disk."""
    p=Path(path)
    if not p.is_file(): return None, [], env('OK','NOT_FOUND',{'path':str(p)})
    opened=[]
    try:
        z=zipfile.ZipFile(p)
        opened.append(z)
        chain=[]
        if nested:
            chain=[x for x in str(nested).split('!') if x]
        for member in chain:
            try:
                info=z.getinfo(member)
            except KeyError:
                for q in reversed(opened): q.close()
                return None, [], env('OK','NOT_FOUND',{'path':str(p),'nested':nested,'missing_member':member})
            if info.file_size > MAX_ARCHIVE_MEMBER_BYTES:
                for q in reversed(opened): q.close()
                return None, [], env('OK','TOO_LARGE',{'member':member,'size':info.file_size,'limit':MAX_ARCHIVE_MEMBER_BYTES})
            data=z.read(member)
            try:
                z=zipfile.ZipFile(io.BytesIO(data))
            except zipfile.BadZipFile:
                for q in reversed(opened): q.close()
                return None, [], env('OK','INVALID_ARCHIVE',{'member':member})
            opened.append(z)
        return z, opened, None
    except zipfile.BadZipFile:
        for q in reversed(opened): q.close()
        return None, [], env('OK','INVALID_ARCHIVE',{'path':str(p)})

def _close_zips(opened):
    for z in reversed(opened):
        try:z.close()
        except Exception:pass

def _kind_for_name(name):
    low=name.lower(); ext=Path(low).suffix
    if low.endswith('/') : return 'directory'
    if ext in ('.zip','.jar','.war','.ear','.whl'): return 'archive'
    if ext in ('.rex','.cls','.rxj'): return 'oorexx-source'
    if ext in ('.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx'): return 'cpp-source'
    if ext=='.java': return 'java-source'
    if ext in TEXT_EXTENSIONS: return 'text'
    return 'binary-or-unknown'

def zip_examine(args):
    z,opened,err=_open_zip_chain(args.get('path',''),args.get('nested'))
    if err:return err
    try:
        prefix=args.get('prefix') or ''
        rows=[]
        for i in z.infolist():
            if prefix and not i.filename.startswith(prefix):continue
            rows.append({'name':i.filename,'kind':_kind_for_name(i.filename),'size':i.file_size,'compressed_size':i.compress_size,'crc32':f'{i.CRC:08x}','directory':i.is_dir()})
        kinds={}
        for r in rows:kinds[r['kind']]=kinds.get(r['kind'],0)+1
        return env('OK','EXAMINED',{'path':args.get('path'),'nested':args.get('nested'),'entries':rows,'count':len(rows),'kinds':kinds,'route':'python.zipfile-stream'})
    finally:_close_zips(opened)

def zip_member_find(args):
    z,opened,err=_open_zip_chain(args.get('path',''),args.get('nested'))
    if err:return err
    try:
        pattern=args.get('pattern') or args.get('name')
        if not pattern:return env('INVALID_REQUEST','UNKNOWN',None)
        mode=args.get('mode','contains')
        matches=[]
        for n in z.namelist():
            ok = (pattern in n) if mode=='contains' else (fnmatch.fnmatch(n,pattern) if mode=='glob' else bool(re.search(pattern,n)))
            if ok:matches.append(n)
        return env('OK','FOUND' if matches else 'NOT_FOUND',{'pattern':pattern,'mode':mode,'matches':matches,'count':len(matches),'nested':args.get('nested')})
    except re.error as e:return env('INVALID_REQUEST','UNKNOWN',None,diagnostics=[str(e)])
    finally:_close_zips(opened)

def zip_member_read(args):
    z,opened,err=_open_zip_chain(args.get('path',''),args.get('nested'))
    if err:return err
    member=args.get('member')
    if not member:
        _close_zips(opened); return env('INVALID_REQUEST','UNKNOWN',None)
    try:
        try:i=z.getinfo(member)
        except KeyError:return env('OK','NOT_FOUND',{'member':member})
        max_bytes=int(args.get('max_bytes',1024*1024))
        if i.file_size>max_bytes:return env('OK','TOO_LARGE',{'member':member,'size':i.file_size,'limit':max_bytes})
        data=z.read(member)
        try:text=data.decode(args.get('encoding','utf-8'),errors='replace')
        except LookupError:return env('INVALID_REQUEST','UNKNOWN',None,diagnostics=['unknown encoding'])
        lines=text.splitlines()
        start=max(1,int(args.get('start_line',1))); count=max(1,min(int(args.get('max_lines',200)),2000))
        part=lines[start-1:start-1+count]
        return env('OK','FOUND',{'member':member,'kind':_kind_for_name(member),'size':i.file_size,'start_line':start,'returned_lines':len(part),'total_lines':len(lines),'lines':[{'line':start+j,'text':v} for j,v in enumerate(part)]})
    finally:_close_zips(opened)

def zip_text_search(args):
    z,opened,err=_open_zip_chain(args.get('path',''),args.get('nested'))
    if err:return err
    query=args.get('query')
    if query is None:
        _close_zips(opened);return env('INVALID_REQUEST','UNKNOWN',None)
    glob=args.get('glob','*'); max_matches=max(1,min(int(args.get('max_matches',100)),1000)); case_sensitive=str(args.get('case_sensitive','false')).lower() in ('1','true','yes')
    needle=query if case_sensitive else query.lower(); hits=[]; examined=0; skipped_large=0; skipped_binary=0
    try:
        for i in z.infolist():
            if i.is_dir() or not fnmatch.fnmatch(i.filename,glob):continue
            kind=_kind_for_name(i.filename)
            if kind not in ('oorexx-source','cpp-source','java-source','text'): skipped_binary+=1; continue
            if i.file_size>MAX_ARCHIVE_MEMBER_BYTES: skipped_large+=1; continue
            examined+=1
            raw=z.read(i)
            if b'\x00' in raw[:4096]: skipped_binary+=1; continue
            txt=raw.decode('utf-8',errors='replace')
            for no,line in enumerate(txt.splitlines(),1):
                hay=line if case_sensitive else line.lower()
                if needle in hay:
                    hits.append({'member':i.filename,'line':no,'text':line[:1000]})
                    if len(hits)>=max_matches:
                        return env('OK','FOUND',{'query':query,'glob':glob,'hits':hits,'count':len(hits),'truncated':True,'members_examined':examined,'skipped_large':skipped_large,'skipped_binary':skipped_binary})
        return env('OK','FOUND' if hits else 'NOT_FOUND',{'query':query,'glob':glob,'hits':hits,'count':len(hits),'truncated':False,'members_examined':examined,'skipped_large':skipped_large,'skipped_binary':skipped_binary})
    finally:_close_zips(opened)

def zip_find(args):
    r=invoke_capability('archive.zip.list',args)
    if r['tool_status']['class']!='OK' or r['operation_status']['class']!='LISTED':return r
    needle=args.get('name') or args.get('pattern')
    if not needle:return env('INVALID_REQUEST','UNKNOWN',None)
    ms=[x for x in r['result']['entries'] if needle in x]
    return env('OK','FOUND' if ms else 'NOT_FOUND',{'matches':ms,'count':len(ms),'list_route':r['result'].get('route')})

def _read_text_object(args):
    member=args.get('member')
    if member:
        z,opened,err=_open_zip_chain(args.get('path',''),args.get('nested'))
        if err:return None,None,err
        try:
            try:i=z.getinfo(member)
            except KeyError:return None,None,env('OK','NOT_FOUND',{'member':member})
            if i.file_size>MAX_ARCHIVE_MEMBER_BYTES:return None,None,env('OK','TOO_LARGE',{'member':member,'size':i.file_size,'limit':MAX_ARCHIVE_MEMBER_BYTES})
            raw=z.read(member)
            txt=raw.decode(args.get('encoding','utf-8'),errors='replace')
            identity=str(args.get('path'))+'!'+((str(args.get('nested'))+'!') if args.get('nested') else '')+member
            return txt,identity,None
        finally:_close_zips(opened)
    p=Path(args.get('path',''))
    if not p.is_file():return None,None,env('OK','NOT_FOUND',{'path':str(p)})
    return p.read_text(errors='replace'),str(p),None

def rex_methods(args):
    txt,identity,err=_read_text_object(args)
    if err:return err
    classes=re.findall(r'(?im)^\s*::class\s+([\w.]+)(?:\s+subclass\s+([\w.]+))?',txt)
    methods=re.findall(r'(?im)^\s*::method\s+([\w.]+)([^\r\n]*)',txt)
    attrs=re.findall(r'(?im)^\s*::attribute\s+([\w.]+)([^\r\n]*)',txt)
    return env('OK','OK',{'path':identity,'classes':[{'name':a,'super':b or None} for a,b in classes],
                          'methods':[{'name':a,'declaration':b.strip()} for a,b in methods],
                          'attributes':[{'name':a,'declaration':b.strip()} for a,b in attrs]})

def cpp_methods(args):
    txt,identity,err=_read_text_object(args)
    if err:return err
    classes=re.findall(r'\b(?:class|struct)\s+(\w+)',txt)
    funcs=re.findall(r'(?m)^\s*(?:[\w:<>,*&~]+\s+)+([~\w]+)\s*\(([^;{}]*)\)\s*(?:const\s*)?[;{]',txt)
    return env('OK','OK',{'path':identity,'classes':classes,'functions':[{'name':n,'args':a.strip()} for n,a in funcs]})


def python_examine(args):
    txt,identity,err=_read_text_object(args)
    if err:return err
    try:
        tree=ast.parse(txt,filename=identity)
    except SyntaxError as e:
        return env('OK','INVALID_SOURCE',{'path':identity,'line':e.lineno,'offset':e.offset,'message':e.msg})
    classes=[]; functions=[]; imports=[]
    for node in tree.body:
        if isinstance(node,(ast.Import,ast.ImportFrom)):
            imports.append({'line':getattr(node,'lineno',None),'text':ast.get_source_segment(txt,node) or ''})
        elif isinstance(node,ast.ClassDef):
            classes.append({'name':node.name,'line':node.lineno,'bases':[ast.unparse(x) for x in node.bases],
                            'methods':[x.name for x in node.body if isinstance(x,(ast.FunctionDef,ast.AsyncFunctionDef))]})
        elif isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef)):
            functions.append({'name':node.name,'line':node.lineno,'async':isinstance(node,ast.AsyncFunctionDef)})
    return env('OK','OK',{'path':identity,'classes':classes,'functions':functions,'imports':imports})

def java_examine(args):
    txt,identity,err=_read_text_object(args)
    if err:return err
    package=None
    m=re.search(r'(?m)^\s*package\s+([A-Za-z_][\w.]*)\s*;',txt)
    if m: package=m.group(1)
    imports=[]
    for m in re.finditer(r'(?m)^\s*import\s+(static\s+)?([A-Za-z_][\w.*]*)\s*;',txt):
        imports.append({'name':m.group(2),'static':bool(m.group(1)),'line':txt.count('\n',0,m.start())+1})
    types=[]
    type_rx=re.compile(
        r'(?m)^\s*(?P<mods>(?:(?:public|protected|private|abstract|final|static|sealed|non-sealed|strictfp)\s+)*)'
        r'(?P<kind>class|interface|enum|record)\s+(?P<name>[A-Za-z_]\w*)'
        r'(?P<tail>[^\n{]*)'
    )
    for m in type_rx.finditer(txt):
        tail=m.group('tail').strip()
        types.append({'name':m.group('name'),'kind':m.group('kind'),'modifiers':m.group('mods').split(),
                      'declaration':tail,'line':txt.count('\n',0,m.start())+1})
    methods=[]
    # Deliberately lexical: compile validation remains authoritative.
    method_rx=re.compile(
        r'(?m)^\s*(?P<mods>(?:(?:public|protected|private|static|final|synchronized|abstract|native|strictfp|default)\s+)*)'
        r'(?:(?P<rtype>[A-Za-z_$][\w$<>,.?\[\] @]*)\s+)?'
        r'(?P<name>[A-Za-z_$][\w$]*)\s*\((?P<args>[^;{}()]*)\)\s*'
        r'(?:throws\s+(?P<throws>[^{;]+))?\s*(?P<end>\{|;)'
    )
    control={'if','for','while','switch','catch','synchronized','try'}
    for m in method_rx.finditer(txt):
        name=m.group('name')
        if name in control: continue
        methods.append({'name':name,'return_type':(m.group('rtype') or '').strip() or None,
                        'arguments':m.group('args').strip(),'throws':(m.group('throws') or '').strip() or None,
                        'modifiers':m.group('mods').split(),'line':txt.count('\n',0,m.start())+1})
    return env('OK','OK',{'path':identity,'package':package,'imports':imports,'types':types,'methods':methods})

def java_compile(args):
    path=str(args.get('path') or '')
    if not path:return env('OK','INVALID_ARGUMENT',{'missing':['path']})
    p=Path(path)
    if not p.is_file():return env('OK','NOT_FOUND',{'path':path})
    javac=shutil.which(str(args.get('javac') or 'javac'))
    if not javac:return env('UNAVAILABLE','UNKNOWN',None,diagnostics=['javac unavailable'])
    argv=[javac,'-proc:none']
    release=args.get('release')
    if release not in (None,''):
        argv += ['--release',str(release)]
    if bool(args.get('lint',True)):
        argv += ['-Xlint:all']
    cp=args.get('classpath')
    if cp: argv += ['-classpath',str(cp)]
    sourcepath=args.get('sourcepath')
    if sourcepath: argv += ['-sourcepath',str(sourcepath)]
    with tempfile.TemporaryDirectory(prefix='llm-gopher-javac-') as out:
        argv += ['-d',out,str(p)]
        q=run_cmd(argv,timeout=int(args.get('timeout',30)))
        if q is None:return env('TIMEOUT','UNKNOWN',None)
        v=run_cmd([javac,'-version'],timeout=5)
        return env('OK','VALID' if q.returncode==0 else 'INVALID_SOURCE',{
            'path':str(p),'validator':javac,'validator_version':(v.stderr or v.stdout).strip() if v else None,
            'release':int(release) if release not in (None,'') else None,
            'lint':bool(args.get('lint',True)),'classpath_supplied':bool(cp),'sourcepath_supplied':bool(sourcepath),
            'rc':q.returncode,'stdout':q.stdout[-12000:],'stderr':q.stderr[-12000:],
            'classes_retained':False})

def man_subset(args):
    if not which('man'):return env('UNAVAILABLE','UNKNOWN',None)
    name=args.get('name'); section=args.get('section')
    if not name:return env('INVALID_REQUEST','UNKNOWN',None)
    argv=['man']+([str(section)] if section else [])+[name]
    p=run_cmd(argv)
    if p is None:return env('TIMEOUT','UNKNOWN',None)
    if p.returncode:return env('OK','NOT_FOUND',{'name':name,'stderr':p.stderr})
    lines=p.stdout.splitlines(); wanted=args.get('contains')
    if wanted:
        lines=[x for x in lines if wanted.lower() in x.lower()]
    return env('OK','FOUND',{'name':name,'lines':lines[:200]})



def _sha_bytes(data):
    return hashlib.sha256(data).hexdigest()

def _read_source_bytes(path):
    p=Path(path)
    if not p.is_file(): return None, env('OK','NOT_FOUND',{'path':str(p)})
    return p.read_bytes(), None

def _read_replacement(path):
    p=Path(path)
    if not p.is_file(): return None, env('OK','NOT_FOUND',{'replacement_path':str(p)})
    b=p.read_bytes()
    if not b.strip(): return None, env('OK','INVALID_ARGUMENT',{'invalid':[{'field':'replacement_path','reason':'empty replacement'}]})
    return b, None

def _atomic_commit(path, data):
    p=Path(path); mode=p.stat().st_mode
    fd,tmp=tempfile.mkstemp(prefix=p.name+'.gopher.', dir=str(p.parent))
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(data); f.flush(); os.fsync(f.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp,p)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise

def _diff_text(before, after, path, max_lines=400):
    a=before.decode('utf-8',errors='replace').splitlines()
    b=after.decode('utf-8',errors='replace').splitlines()
    d=list(difflib.unified_diff(a,b,fromfile=path+' (before)',tofile=path+' (after)',lineterm=''))
    return {'lines':d[:max_lines],'line_count':len(d),'truncated':len(d)>max_lines}

def _rexxc_path(args):
    explicit=args.get('rexxc')
    if explicit and Path(explicit).is_file(): return explicit
    p=which('rexxc')
    if p:return p
    packaged='/mnt/data/oorexx_runtime_530/usr/local/bin/rexxc'
    return packaged if Path(packaged).is_file() else None

def _validate_oorexx_bytes(data, args):
    rexxc=_rexxc_path(args)
    if not rexxc:return env('UNAVAILABLE','UNKNOWN',None,diagnostics=['rexxc unavailable'])
    fd,tmp=tempfile.mkstemp(suffix='.cls')
    os.close(fd)
    out=tmp+'.out'
    try:
        Path(tmp).write_bytes(data)
        q=run_cmd([rexxc,tmp,out],timeout=30)
        if q is None:return env('TIMEOUT','UNKNOWN',None)
        return env('OK','VALID' if q.returncode==0 else 'INVALID_SOURCE',{'validator':rexxc,'rc':q.returncode,'stdout':q.stdout[-8000:],'stderr':q.stderr[-8000:]})
    finally:
        for x in (tmp,out):
            try: os.unlink(x)
            except OSError: pass

def _rexx_directives(lines):
    out=[]
    rx=re.compile(r'^\s*::([A-Za-z]+)\b(.*)$',re.I)
    for i,line in enumerate(lines):
        m=rx.match(line)
        if m: out.append((i,m.group(1).lower(),m.group(2).strip()))
    return out

def source_oorexx_method_edit(args):
    path=args['path']; cls=args['class']; method=args['method']; op=args['operation'].upper()
    before,err=_read_source_bytes(path)
    if err:return err
    expected=args.get('expected_sha256')
    before_sha=_sha_bytes(before)
    if expected and expected.lower()!=before_sha.lower():return env('OK','STALE_SOURCE',{'path':path,'expected_sha256':expected,'actual_sha256':before_sha})
    repl,err=_read_replacement(args['replacement_path'])
    if err:return err
    try:text=before.decode('utf-8')
    except UnicodeDecodeError:return env('OK','UNSUPPORTED_ENCODING',{'path':path,'expected':'utf-8'})
    rtext=repl.decode('utf-8',errors='strict')
    mm=re.match(r'(?im)^\s*::method\s+([\w.]+)\b',rtext)
    if not mm or mm.group(1).lower()!=method.lower():return env('OK','INVALID_ARGUMENT',{'invalid':[{'field':'replacement_path','reason':'must begin with ::method '+method}]})
    lines=text.splitlines(keepends=True); dirs=_rexx_directives(lines)
    classes=[(i,rest.split()[0] if rest.split() else '') for i,k,rest in dirs if k=='class']
    hits=[x for x in classes if x[1].lower()==cls.lower()]
    if not hits:return env('OK','NOT_FOUND',{'class':cls})
    if len(hits)>1:return env('OK','AMBIGUOUS',{'class':cls,'matches':[i+1 for i,_ in hits]})
    cstart=hits[0][0]
    later=[i for i,k,rest in dirs if i>cstart and k in ('class','routine')]; cend=min(later) if later else len(lines)
    methods=[]
    for pos,(i,k,rest) in enumerate(dirs):
        if k=='method' and cstart<i<cend:
            name=(rest.split()[0] if rest.split() else '')
            if name.lower()==method.lower():
                nxt=min([j for j,kk,rr in dirs if j>i] or [len(lines)])
                end=min(nxt,cend)
                while end>i+1 and not lines[end-1].strip(): end-=1
                methods.append((i,end))
    if op=='ADD' and methods:return env('OK','ALREADY_EXISTS',{'class':cls,'method':method,'line':methods[0][0]+1})
    if op=='REPLACE' and not methods:return env('OK','NOT_FOUND',{'class':cls,'method':method})
    if len(methods)>1:return env('OK','AMBIGUOUS',{'class':cls,'method':method,'matches':[a+1 for a,b in methods]})
    # Preserve replacement bytes exactly, adding one newline only when needed for directive separation.
    newline=b'\r\n' if b'\r\n' in before else b'\n'
    if not repl.endswith((b'\n',b'\r')):repl += newline
    offsets=[0]
    for line in before.splitlines(keepends=True):offsets.append(offsets[-1]+len(line))
    if op=='REPLACE': a,b=methods[0]; start,end=offsets[a],offsets[b]
    else: start=end=offsets[cend]
    after=before[:start]+repl+before[end:]
    rules=_evaluate_rules_bytes(after,'oorexx','.cls')
    if rules['result'].get('blockers',0):
        return env('OK','RULE_BREACH',{'path':path,'class':cls,'method':method,'language_rules':rules['result'],'committed':False,'before_sha256':before_sha})
    validation=_validate_oorexx_bytes(after,args)
    if validation['tool_status']['class']!='OK' or validation['operation_status']['class']!='VALID':
        return env(validation['tool_status']['class'],'VALIDATION_FAILED',{'path':path,'class':cls,'method':method,'validation':validation,'language_rules':rules['result'],'committed':False,'before_sha256':before_sha})
    _atomic_commit(path,after)
    return env('OK','UPDATED',{'path':path,'language':'oorexx','class':cls,'method':method,'operation':op,'changed_range':{'start_line':(methods[0][0]+1 if methods else cend+1),'end_line_before':(methods[0][1] if methods else cend)},'before_sha256':before_sha,'after_sha256':_sha_bytes(after),'diff':_diff_text(before,after,path),'validation':validation['result'],'language_rules':rules['result'],'committed':True})

def _python_decode(data):
    bio=io.BytesIO(data)
    enc,_=tokenize.detect_encoding(bio.readline)
    return data.decode(enc),enc

def source_python_method_edit(args):
    path=args['path']; cls=args['class']; method=args['method']; op=args['operation'].upper()
    before,err=_read_source_bytes(path)
    if err:return err
    expected=args.get('expected_sha256'); before_sha=_sha_bytes(before)
    if expected and expected.lower()!=before_sha.lower():return env('OK','STALE_SOURCE',{'path':path,'expected_sha256':expected,'actual_sha256':before_sha})
    repl,err=_read_replacement(args['replacement_path'])
    if err:return err
    try:text,enc=_python_decode(before); rtext,_=_python_decode(repl)
    except Exception as e:return env('OK','UNSUPPORTED_ENCODING',{'path':path,'error':str(e)})
    try:tree=ast.parse(text,filename=path)
    except SyntaxError as e:return env('OK','INVALID_SOURCE',{'path':path,'line':e.lineno,'message':e.msg})
    classes=[n for n in ast.walk(tree) if isinstance(n,ast.ClassDef) and n.name==cls]
    if not classes:return env('OK','NOT_FOUND',{'class':cls})
    if len(classes)>1:return env('OK','AMBIGUOUS',{'class':cls,'count':len(classes)})
    c=classes[0]; methods=[n for n in c.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name==method]
    if op=='ADD' and methods:return env('OK','ALREADY_EXISTS',{'class':cls,'method':method,'line':methods[0].lineno})
    if op=='REPLACE' and not methods:return env('OK','NOT_FOUND',{'class':cls,'method':method})
    if len(methods)>1:return env('OK','AMBIGUOUS',{'class':cls,'method':method,'count':len(methods)})
    # Validate replacement as a class member, then normalize only its indentation to the target class body.
    stripped=rtext.strip('\r\n')
    try:
        rt=ast.parse('class __GopherReplacement__:\n'+''.join('    '+ln+'\n' for ln in stripped.splitlines()))
        rn=rt.body[0].body[0]
    except Exception as e:return env('OK','INVALID_ARGUMENT',{'invalid':[{'field':'replacement_path','reason':'replacement must be one complete Python method: '+str(e)}]})
    if not isinstance(rn,(ast.FunctionDef,ast.AsyncFunctionDef)) or rn.name!=method:return env('OK','INVALID_ARGUMENT',{'invalid':[{'field':'replacement_path','reason':'replacement method name must be '+method}]})
    src_lines=before.splitlines(keepends=True); newline=b'\r\n' if b'\r\n' in before else b'\n'
    offsets=[0]
    for line in src_lines:offsets.append(offsets[-1]+len(line))
    if methods:
        n=methods[0]; start,end=offsets[n.lineno-1],offsets[n.end_lineno]
        indent=re.match(rb'[ \t]*',src_lines[n.lineno-1]).group(0)
    else:
        # Insert at the end of the class, before the first following top-level construct.
        endline=c.end_lineno; start=end=offsets[endline]
        first_member_line=min([getattr(n,'lineno',10**9) for n in c.body] or [c.lineno+1])
        indent=(re.match(rb'[ \t]*',src_lines[first_member_line-1]).group(0) if first_member_line<=len(src_lines) else b'    ')
    raw_lines=repl.splitlines()
    # Strip common leading whitespace from supplied fragment, then apply class-member indentation.
    nonblank=[re.match(rb'[ \t]*',x).group(0) for x in raw_lines if x.strip()]
    common=min((len(x) for x in nonblank),default=0)
    rep=b''.join(indent+x[common:]+newline for x in raw_lines)
    after=before[:start]+rep+before[end:]
    rules=_evaluate_rules_bytes(after,'python','.py')
    if rules['result'].get('blockers',0):
        return env('OK','RULE_BREACH',{'path':path,'class':cls,'method':method,'language_rules':rules['result'],'committed':False,'before_sha256':before_sha})
    try:_python_decode(after); ast.parse(_python_decode(after)[0],filename=path)
    except SyntaxError as e:return env('OK','VALIDATION_FAILED',{'path':path,'class':cls,'method':method,'validation':{'class':'INVALID_SOURCE','line':e.lineno,'message':e.msg},'language_rules':rules['result'],'committed':False,'before_sha256':before_sha})
    _atomic_commit(path,after)
    return env('OK','UPDATED',{'path':path,'language':'python','class':cls,'method':method,'operation':op,'changed_range':{'start_line':(methods[0].lineno if methods else c.end_lineno+1),'end_line_before':(methods[0].end_lineno if methods else c.end_lineno)},'before_sha256':before_sha,'after_sha256':_sha_bytes(after),'diff':_diff_text(before,after,path),'validation':{'class':'VALID','validator':'python.ast'},'language_rules':rules['result'],'committed':True})

def _evaluate_rules_bytes(data, language, suffix):
    fd,tmp=tempfile.mkstemp(suffix=suffix); os.close(fd)
    try:
        Path(tmp).write_bytes(data)
        return language_rules_evaluate({'path':tmp,'language':language})
    finally:
        try:os.unlink(tmp)
        except OSError:pass

def _rule_fix(kind, text, replacement=None):
    d={'class':kind,'correct':text}
    if replacement is not None:d['replacement']=replacement
    return d

def _breach(rule_id, language, severity, where, caused_by, observed, fix, details=None):
    return {'rule':rule_id,'language':language,'status':'BREACHED','severity':severity,'where':where,
            'caused_by':caused_by,'observed':observed,'fix':fix,
            'details':details or ('rule://'+language+'/'+rule_id.lower()),
            'actions':[x for x in [
                {'label':'APPLY suggested fix','action':'APPLY'} if fix.get('class')=='AUTOMATIC' else None,
                {'label':'EDIT fix','action':'EDIT'}, {'label':'IGNORE with justification','action':'IGNORE'},
                {'label':'SHOW rule details','action':'SHOW_DETAILS'}] if x]}

def _oorexx_rule_breaches(text, path):
    lines=text.splitlines(); breaches=[]
    req={}
    classes=[]; current=None; methods={}
    for n,line in enumerate(lines,1):
        m=re.match(r'^\s*::requires\s+["\']?([^"\'\s]+)',line,re.I)
        if m:
            key=m.group(1).lower(); req.setdefault(key,[]).append((n,line))
        m=re.match(r'^\s*::class\s+([^\s]+)',line,re.I)
        if m:
            current=m.group(1); classes.append((current.lower(),current,n,line)); methods.setdefault(current.lower(),{})
            continue
        m=re.match(r'^\s*::method\s+([^\s]+)',line,re.I)
        if m and current:
            methods[current.lower()].setdefault(m.group(1).lower(),[]).append((n,line,m.group(1)))
    byclass={}
    for key,name,n,line in classes:byclass.setdefault(key,[]).append((n,line,name))
    for key,hits in byclass.items():
        if len(hits)>1:
            breaches.append(_breach('OOREXX.DIRECTIVE.DUPLICATE_CLASS','oorexx','BLOCKER',{'path':path,'lines':[x[0] for x in hits]},
                'the same ::class name is declared more than once', [x[1] for x in hits],
                _rule_fix('MANUAL','Keep one intended class definition or rename the distinct class.')))
    for cls,mm in methods.items():
        for mn,hits in mm.items():
            if len(hits)>1:
                breaches.append(_breach('OOREXX.DIRECTIVE.DUPLICATE_METHOD','oorexx','BLOCKER',{'path':path,'class':cls,'lines':[x[0] for x in hits]},
                    'the same ::method name is declared more than once in one class', [x[1] for x in hits],
                    _rule_fix('MANUAL','Keep, rename, or deliberately replace exactly one method definition.')))
    for key,hits in req.items():
        if len(hits)>1:
            breaches.append(_breach('OOREXX.REQUIRES.DUPLICATE','oorexx','ADVISORY',{'path':path,'lines':[x[0] for x in hits]},
                'the same ::requires target is present more than once', [x[1] for x in hits],
                _rule_fix('AUTOMATIC','Keep one canonical ::requires directive and remove the duplicate occurrences.')))
    return breaches,3

def _python_rule_breaches(text, path):
    breaches=[]
    try: tree=ast.parse(text,filename=path)
    except SyntaxError as e:
        return [_breach('PYTHON.SYNTAX.INVALID','python','BLOCKER',{'path':path,'line':e.lineno,'column':e.offset},
            'Python parser rejected the source', e.text.rstrip() if e.text else e.msg,
            _rule_fix('MANUAL','Correct the syntax reported by the parser before continuing.'))],4
    checked=4
    for c in [n for n in ast.walk(tree) if isinstance(n,ast.ClassDef)]:
        seen={}
        for n in c.body:
            if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)):
                seen.setdefault(n.name,[]).append(n)
        for name,hits in seen.items():
            if len(hits)>1:
                breaches.append(_breach('PYTHON.CLASS.DUPLICATE_METHOD','python','BLOCKER',{'path':path,'class':c.name,'lines':[x.lineno for x in hits]},
                    'multiple methods with the same name occur in one class; later definitions replace earlier ones',
                    [{'line':x.lineno,'name':name} for x in hits],_rule_fix('MANUAL','Keep, rename, or deliberately replace exactly one method definition.')))
    for n in ast.walk(tree):
        if isinstance(n,ast.ImportFrom) and any(a.name=='*' for a in n.names):
            breaches.append(_breach('PYTHON.IMPORT.WILDCARD','python','ADVISORY',{'path':path,'line':n.lineno},
                'a wildcard import obscures the names introduced into this module', {'module':n.module,'line':n.lineno},
                _rule_fix('SUGGESTED','Import the specific names that this module actually uses.')))
        if isinstance(n,ast.ExceptHandler) and n.type is None:
            breaches.append(_breach('PYTHON.EXCEPT.BARE','python','ADVISORY',{'path':path,'line':n.lineno},
                'a bare except catches exceptions beyond the intended operational failure class', {'line':n.lineno},
                _rule_fix('SUGGESTED','Catch the narrowest exception type appropriate to the operation.')))
    return breaches,checked


def _java_mask_noncode(text):
    # Preserve offsets/newlines while removing comments and string/char contents.
    out=list(text); i=0; n=len(text); state='code'
    while i<n:
        c=text[i]; d=text[i+1] if i+1<n else ''
        if state=='code':
            if c=='/' and d=='/':
                out[i]=out[i+1]=' '; i+=2; state='line'; continue
            if c=='/' and d=='*':
                out[i]=out[i+1]=' '; i+=2; state='block'; continue
            if c=='"':
                out[i]=' '; i+=1; state='string'; continue
            if c=="'":
                out[i]=' '; i+=1; state='char'; continue
        elif state=='line':
            if c=='\n': state='code'
            else: out[i]=' '
            i+=1; continue
        elif state=='block':
            if c=='*' and d=='/':
                out[i]=out[i+1]=' '; i+=2; state='code'; continue
            if c!='\n': out[i]=' '
            i+=1; continue
        elif state in ('string','char'):
            quote='"' if state=='string' else "'"
            if c=='\\':
                out[i]=' '
                if i+1<n:
                    if text[i+1]!='\n': out[i+1]=' '
                    i+=2; continue
            if c==quote:
                out[i]=' '; i+=1; state='code'; continue
            if c!='\n': out[i]=' '
            i+=1; continue
        i+=1
    return ''.join(out)

def _java_rule_breaches(text,path):
    breaches=[];checked=2
    basename=Path(path).stem
    masked=_java_mask_noncode(text)
    public_rx=re.compile(r'^\s*public\s+(?:abstract\s+|final\s+|sealed\s+|non-sealed\s+|strictfp\s+)*(class|interface|enum|record)\s+([A-Za-z_]\w*)')
    depth=0; offset=0
    for original,code in zip(text.splitlines(True),masked.splitlines(True)):
        if depth==0:
            m=public_rx.match(code)
            if m:
                kind,name=m.group(1),m.group(2)
                line=text.count('\n',0,offset)+1
                if name!=basename:
                    breaches.append({'rule':'JAVA.SOURCE.PUBLIC_TYPE_FILENAME','status':'BREACHED','severity':'BLOCKER',
                        'where':{'path':path,'line':line},
                        'caused_by':f'public top-level {kind} {name} does not match source filename {basename}.java',
                        'observed':{'public_type':name,'filename':Path(path).name},
                        'correct':'> CORRECT: put the public top-level type in '+name+'.java or rename the type intentionally.',
                        'fix':{'class':'MANUAL'},'details':'rule://java/source/public-type-filename'})
        depth += code.count('{')-code.count('}')
        if depth<0: depth=0
        offset += len(original)
    # Empty catch blocks are syntactically valid, so advisory only.
    empty_rx=re.compile(r'catch\s*\([^)]*\)\s*\{\s*\}',re.S)
    for m in empty_rx.finditer(masked):
        line=text.count('\n',0,m.start())+1
        breaches.append({'rule':'JAVA.EXCEPT.EMPTY_CATCH','status':'BREACHED','severity':'ADVISORY',
            'where':{'path':path,'line':line},'caused_by':'catch block discards the exception with no visible handling',
            'correct':'> CORRECT: handle, translate, log with context, or document a deliberate suppression at the narrow boundary.',
            'fix':{'class':'SUGGESTED'},'details':'rule://java/exceptions/empty-catch'})
    return breaches,checked

def language_rules_evaluate(args):
    path=args.get('path'); lang=(args.get('language') or 'auto').lower()
    if not path:return env('OK','INVALID_ARGUMENT',{'missing':['path']})
    p=Path(path)
    if not p.is_file():return env('OK','NOT_FOUND',{'path':path})
    if lang=='auto':
        lang='python' if p.suffix.lower()=='.py' else ('java' if p.suffix.lower()=='.java' else ('oorexx' if p.suffix.lower() in ('.cls','.rex','.rxj') else 'unknown'))
    if lang not in ('oorexx','python','java'):return env('OK','UNSUPPORTED',{'language':lang,'supported':['oorexx','python','java']})
    try:text=p.read_text(encoding='utf-8')
    except UnicodeDecodeError:return env('OK','UNSUPPORTED_ENCODING',{'path':path,'expected':'utf-8'})
    breaches,checked=(_oorexx_rule_breaches(text,path) if lang=='oorexx' else (_python_rule_breaches(text,path) if lang=='python' else _java_rule_breaches(text,path)))
    blockers=sum(1 for b in breaches if b['severity']=='BLOCKER'); advisories=len(breaches)-blockers
    cycle='cycle://language-rules/'+hashlib.sha256((lang+'\0'+str(p.resolve())+'\0'+_sha_bytes(p.read_bytes())).encode()).hexdigest()[:16]
    return env('OK','BREACHED' if breaches else 'CORRECT',{'language':lang,'path':path,'rules_checked':checked,'breaches':breaches,'breach_count':len(breaches),'blockers':blockers,'advisories':advisories,'cycle':cycle,'resume':cycle})

def rule_page(idx, rule_id, language=None, return_to=None):
    matches=[]
    for (k,i),r in idx.items():
        if k=='language-rule' and i.lower()==rule_id.lower() and (not language or r.get('language')==language):matches.append(r)
    if not matches:return env('OK','NOT_FOUND',{'rule':rule_id,'language':language})
    if len(matches)>1:return env('OK','AMBIGUOUS',{'rule':rule_id,'languages':[x.get('language') for x in matches]})
    r=dict(matches[0]);r.pop('_provenance',None)
    r['page_type']='LanguageRulePage'; r['return_to']=return_to
    if return_to:r['selectors']=[{'label':'RETURN TO cycle','selector':return_to,'action':'RETURN'}]
    return env('OK','OPENED',r)


# Machine-readable capability contracts. One source drives validation, describe,
# context hints, and higher-level composite planning.
CAPABILITY_SCHEMAS={
 'executable.locate':{
   'summary':'Locate an executable in the current execution environment.',
   'parameters':{'name':{'type':'string','required':True,'description':'Executable name.'}},
   'examples':['exec executable.locate name=rexx'],
   'result':{'name':'string','path':'string|null'},'supports':['host']},
 'crypto.sha256':{
   'summary':'Calculate or verify SHA-256 for a filesystem file.',
   'parameters':{'path':{'type':'string','required':True},'expected':{'type':'string','required':False}},
   'examples':['exec crypto.sha256 path=artifact.zip','exec crypto.sha256 path=artifact.zip expected=<sha256>'],
   'result':{'path':'string','sha256':'hex','expected':'string|null'},'supports':['file']},
 'archive.zip.list':{
   'summary':'List members of a ZIP archive using the best available service route.',
   'parameters':{'path':{'type':'string','required':True}},
   'examples':['exec archive.zip.list path=artifact.zip'],'result':{'entries':'string[]','count':'integer'},'supports':['zip']},
 'archive.zip.find':{
   'summary':'Find archive members by contained name text.',
   'parameters':{'path':{'type':'string','required':True},'name':{'type':'string','required':False},'pattern':{'type':'string','required':False}},
   'one_of':[['name','pattern']], 'examples':['exec archive.zip.find path=artifact.zip name=Maths.cls'],
   'result':{'matches':'string[]','count':'integer'},'supports':['zip']},
 'archive.zip.examine':{
   'summary':'Examine and classify ZIP members without extraction, including nested ZIPs.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False,'description':'! separated nested ZIP member chain.'},'prefix':{'type':'string','required':False}},
   'examples':['exec archive.zip.examine path=library.zip','exec archive.zip.examine path=library.zip nested=current/component.zip'],
   'result':{'entries':'member[]','count':'integer','kinds':'object'},'supports':['zip','nested-zip']},
 'archive.zip.member.find':{
   'summary':'Find member names inside a ZIP or nested ZIP without extraction.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'pattern':{'type':'string','required':False},'name':{'type':'string','required':False},'mode':{'type':'string','required':False,'default':'contains','enum':['contains','glob','regex']}},
   'one_of':[['pattern','name']],
   'examples':["exec archive.zip.member.find path=library.zip nested=current/component.zip pattern='*Maths.cls' mode=glob"],
   'result':{'matches':'string[]','count':'integer'},'supports':['zip','nested-zip']},
 'archive.zip.member.read':{
   'summary':'Read a bounded, line-numbered text slice from a ZIP member without extraction.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'member':{'type':'string','required':True},'start_line':{'type':'integer','required':False,'default':1,'minimum':1},'max_lines':{'type':'integer','required':False,'default':200,'minimum':1,'maximum':2000},'max_bytes':{'type':'integer','required':False,'default':1048576,'minimum':1},'encoding':{'type':'string','required':False,'default':'utf-8'}},
   'examples':['exec archive.zip.member.read path=library.zip nested=current/component.zip member=src/Maths.cls start_line=775 max_lines=5'],
   'result':{'member':'string','lines':'line[]','total_lines':'integer','returned_lines':'integer'},'supports':['zip','nested-zip','text']},
 'archive.zip.text.search':{
   'summary':'Search text members of a ZIP or nested ZIP and return bounded line-numbered hits.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'query':{'type':'string','required':True},'glob':{'type':'string','required':False,'default':'*'},'max_matches':{'type':'integer','required':False,'default':100,'minimum':1,'maximum':1000},'case_sensitive':{'type':'boolean','required':False,'default':False}},
   'examples':["exec archive.zip.text.search path=library.zip nested=current/component.zip glob='*Maths.cls' query='::class MathInteger'"],
   'result':{'hits':'hit[]','count':'integer','truncated':'boolean'},'supports':['zip','nested-zip','text']},
 'source.oorexx.examine':{
   'summary':'Examine ooRexx source and return classes, attributes, and methods. Source may be a file or ZIP member.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'member':{'type':'string','required':False},'encoding':{'type':'string','required':False,'default':'utf-8'}},
   'examples':['exec source.oorexx.examine path=Maths.cls','exec source.oorexx.examine path=library.zip nested=current/component.zip member=src/Maths.cls'],
   'result':{'classes':'class[]','attributes':'attribute[]','methods':'method[]'},'supports':['file','zip-member','nested-zip-member','oorexx-source']},
 'source.python.examine':{
   'summary':'Examine Python source with the AST and return top-level classes, functions, and imports.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'member':{'type':'string','required':False},'encoding':{'type':'string','required':False,'default':'utf-8'}},
   'examples':['exec source.python.examine path=sample.py'],'result':{'classes':'class[]','functions':'function[]','imports':'import[]'},'supports':['file','zip-member','nested-zip-member','python-source']},
 'source.java.examine':{
   'summary':'Lexically examine Java source and return package, imports, declared types, and method signatures; use source.java.compile for authoritative syntax/type validation.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'member':{'type':'string','required':False},'encoding':{'type':'string','required':False,'default':'utf-8'}},
   'examples':['exec source.java.examine path=Sample.java','exec source.java.examine path=app.zip member=project/src/main/java/p/Sample.java'],
   'result':{'package':'string|null','imports':'import[]','types':'type[]','methods':'method[]'},'supports':['file','zip-member','nested-zip-member','java-source']},
 'source.java.compile':{
   'summary':'Compile-check one Java source file with the installed javac in an isolated output directory; returns compiler identity and diagnostics without retaining class files.',
   'parameters':{
      'path':{'type':'string','required':True},'release':{'type':'integer','required':False,'minimum':8,'maximum':30},
      'classpath':{'type':'string','required':False},'sourcepath':{'type':'string','required':False},
      'lint':{'type':'boolean','required':False,'default':True},'javac':{'type':'string','required':False},
      'timeout':{'type':'integer','required':False,'default':30,'minimum':1,'maximum':120}},
   'examples':['exec source.java.compile path=Sample.java release=17','exec source.java.compile path=JmsClient.java release=17 classpath=/path/jms-api.jar'],
   'result':{'validator':'path','validator_version':'string','release':'integer|null','rc':'integer','stderr':'string','classes_retained':'false'},
   'supports':['file','java-source','compile-only','isolated-output']},
 'source.cpp.examine':{
   'summary':'Examine C/C++ source and return discovered classes and functions. Source may be a file or ZIP member.',
   'parameters':{'path':{'type':'string','required':True},'nested':{'type':'string','required':False},'member':{'type':'string','required':False},'encoding':{'type':'string','required':False,'default':'utf-8'}},
   'examples':['exec source.cpp.examine path=sample.hpp'],'result':{'classes':'string[]','functions':'function[]'},'supports':['file','zip-member','nested-zip-member','cpp-source']},
 'source.language.rules.evaluate':{
   'summary':'Evaluate all deterministic language rules for a source version and return every known breach as one grouped diagnostic set.',
   'parameters':{'path':{'type':'string','required':True},'language':{'type':'string','required':False,'default':'auto','enum':['auto','oorexx','python','java']}},
   'examples':['exec source.language.rules.evaluate path=Foo.cls language=oorexx'],
   'result':{'rules_checked':'integer','breaches':'RuleBreach[]','cycle':'selector'},'supports':['file','oorexx-source','python-source','java-source','grouped-diagnostics']},
 'source.oorexx.method.edit':{
   'summary':'Surgically add or replace one ooRexx method while preserving unrelated source bytes; validate before atomic commit.',
   'parameters':{'path':{'type':'string','required':True},'class':{'type':'string','required':True},'method':{'type':'string','required':True},'operation':{'type':'string','required':True,'enum':['ADD','REPLACE']},'replacement_path':{'type':'string','required':True},'expected_sha256':{'type':'string','required':False},'rexxc':{'type':'string','required':False}},
   'examples':['exec source.oorexx.method.edit path=Foo.cls class=Foo method=bar operation=REPLACE replacement_path=/tmp/bar.rex'],
   'result':{'before_sha256':'hex','after_sha256':'hex','diff':'object','validation':'object','committed':'boolean'},'supports':['file','oorexx-source','bounded-edit']},
 'source.python.method.edit':{
   'summary':'Surgically add or replace one Python class method using AST source spans; preserve unrelated source bytes and validate before atomic commit.',
   'parameters':{'path':{'type':'string','required':True},'class':{'type':'string','required':True},'method':{'type':'string','required':True},'operation':{'type':'string','required':True,'enum':['ADD','REPLACE']},'replacement_path':{'type':'string','required':True},'expected_sha256':{'type':'string','required':False}},
   'examples':['exec source.python.method.edit path=foo.py class=Foo method=bar operation=REPLACE replacement_path=/tmp/bar.py'],
   'result':{'before_sha256':'hex','after_sha256':'hex','diff':'object','validation':'object','committed':'boolean'},'supports':['file','python-source','bounded-edit']},
 'source.symbol.lookup':{
   'summary':'Locate an exact language declaration for a class/symbol. Exact declaration is preferred; text fallback occurs only when explicitly requested.',
   'parameters':{
      'path':{'type':'string','required':True},
      'member':{'type':'string','required':False},
      'nested':{'type':'string','required':False},
      'symbol':{'type':'string','required':True},
      'language':{'type':'string','required':False,'default':'auto','enum':['auto','oorexx','python','java','cpp','text']},
      'fallback':{'type':'boolean','required':False,'default':False}},
   'examples':['exec source.symbol.lookup path=Foo.cls symbol=Foo language=oorexx','exec source.symbol.lookup path=lib.zip member=project/src/Foo.cls symbol=Foo language=oorexx'],
   'result':{'match_kind':'EXACT_DECLARATION|TEXT_FALLBACK|NONE','hits':'line[]','fallback_used':'boolean'},
   'supports':['filesystem','zip-member','nested-zip','exact-declaration','ambiguity']},
 'corpus.record.lookup':{
   'summary':'Look up corpus records by exact typed field/value first, with bounded text fallback only when no exact field match exists.',
   'parameters':{
      'field':{'type':'string','required':True},
      'value':{'type':'string','required':True},
      'corpus':{'type':'string','required':False},
      'fallback':{'type':'boolean','required':False,'default':True},
      'max_matches':{'type':'integer','required':False,'default':50,'minimum':1,'maximum':500}},
   'examples':['exec corpus.record.lookup field=opcode value=5D','exec corpus.record.lookup field=topic value=precision corpus=maths.continuity'],
   'result':{'match_kind':'EXACT_FIELD|TEXT_FALLBACK|NONE','hits':'record[]','fallback_used':'boolean'},
   'supports':['typed-corpus','exact-field','bounded-fallback']},
 'dogfood.escape.record':{
   'summary':'Record a task where Gopher lacked a sufficient article/capability and a fallback was required.',
   'parameters':{'task':{'type':'string','required':True},'reason':{'type':'string','required':True},'fallback':{'type':'string','required':False},'outcome':{'type':'string','required':False},'failure_class':{'type':'string','required':False}},
   'examples':['exec dogfood.escape.record task="find applicable tests" reason="no test-impact capability" fallback="manual inspection"'],
   'result':{'failure_class':'string','correct':'string'},'supports':['dogfood','operations-guide']},
 'test.impact.discover':{
   'summary':'Advisory discovery of tests that reference a changed component or concept.',
   'parameters':{'path':{'type':'string','required':True},'changed':{'type':'string','required':True}},
   'examples':['exec test.impact.discover path=. changed="package staging"'],
   'result':{'tests':'object[]','basis':'string'},'supports':['source-tree','test-discovery','advisory']},
 'sphere.editor.import.legacy':{
   'summary':'Import one pre-kind legacy sphere ZIP/directory into canonical editor layout without parsing free-form evidence notes into provenance.',
   'parameters':{'source':{'type':'string','required':True},'out':{'type':'string','required':True}},
   'examples':['exec sphere.editor.import.legacy source=legacy_sphere.zip out=/tmp/canonical-sphere'],
   'result':{'sphere':'string','version':'string','articles':'integer','rule':'string'},
   'supports':['sphere-authoring','legacy-migration','FISH-safe']},
 'sphere.editor.template':{
   'summary':'Return or write a canonical template for one sphere object kind so authors fill semantics rather than inventing structure.',
   'parameters':{'kind':{'type':'string','required':True,'enum':['article','corpus','language-rule','service','language-module','sphere','access-policy']},'sphere':{'type':'string','required':False},'id':{'type':'string','required':False},'title':{'type':'string','required':False},'version':{'type':'string','required':False,'default':'0.1'},'out':{'type':'string','required':False}},
   'examples':['exec sphere.editor.template kind=article sphere=x id=ops.x title="Do X" out=/tmp/article.json'],'result':{'template':'object','out':'string|null'},'supports':['sphere-authoring','canonical-shape']},
 'sphere.editor.corpus.record.put':{
   'summary':'Create or replace exactly one corpus record by a caller-selected stable key/value, with stale-source fencing.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True},'corpus':{'type':'string','required':True},'from':{'type':'string','required':True},'key':{'type':'string','required':False,'default':'id'},'value':{'type':'string','required':True},'expected_sha256':{'type':'string','required':False}},
   'examples':['exec sphere.editor.corpus.record.put path=/tmp/s sphere=x corpus=x.lessons from=/tmp/record.json key=topic value=FISH'],'result':{'record_index':'integer','before_sha256':'hex','after_sha256':'hex'},'supports':['sphere-authoring','bounded-edit','corpus']},
 'sphere.editor.changelog.add':{
   'summary':'Add one deduplicated changelog item under an existing/new version heading.',
   'parameters':{'path':{'type':'string','required':True},'version':{'type':'string','required':True},'text':{'type':'string','required':True}},'examples':['exec sphere.editor.changelog.add path=/tmp/s version=0.2 text="Corrected rule classification"'],'result':{'before_sha256':'hex|null','after_sha256':'hex'},'supports':['sphere-authoring','bounded-edit','changelog']},
 'sphere.editor.create':{
   'summary':'Create a canonical sphere work tree with sphere/access-policy/profile/changelog/tests/qualification scaffold.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True},'version':{'type':'string','required':False,'default':'0.1'},'title':{'type':'string','required':True},'purpose':{'type':'string','required':False}},
   'examples':['exec sphere.editor.create path=/tmp/java-lessons sphere=java-lessons title="Java lessons"'],'result':{'path':'string','profile':'string','next':'string[]'},'supports':['sphere-authoring','canonical-layout']},
 'sphere.editor.put':{
   'summary':'Create or replace exactly one sphere object from a JSON file using its canonical kind/id path and optional stale-source SHA fence.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True},'kind':{'type':'string','required':True,'enum':['article','corpus','language-rule','service','language-module','sphere','access-policy']},'from':{'type':'string','required':True},'expected_sha256':{'type':'string','required':False}},
   'examples':['exec sphere.editor.put path=/tmp/s sphere=my-sphere kind=article from=/tmp/article.json'],'result':{'before_sha256':'hex|null','after_sha256':'hex','changed':'boolean'},'supports':['bounded-edit','sphere-authoring','stale-source-fence']},
 'sphere.editor.evidence.attach':{
   'summary':'Attach one canonical machine-resolvable provenance object to an exact sphere object; prose note remains opaque and is never parsed for authority.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True},'kind':{'type':'string','required':True},'id':{'type':'string','required':True},'artifact':{'type':'string','required':True},'sha256':{'type':'string','required':True},'member':{'type':'string','required':True},'line_start':{'type':'integer','required':False},'line_end':{'type':'integer','required':False},'claim':{'type':'string','required':False},'note':{'type':'string','required':False},'expected_sha256':{'type':'string','required':False}},
   'examples':['exec sphere.editor.evidence.attach path=/tmp/s sphere=x kind=article id=ops.x artifact=a.zip sha256=<64hex> member=README.md line_start=38 line_end=45 note="la la la ... oh I mean line"'],'result':{'provenance':'object','after_sha256':'hex'},'supports':['provenance','bounded-edit','PROVENANCE_PANIC']},
 'sphere.editor.validate':{
   'summary':'Validate JSON parseability, unique kind/id identity, required kind fields, sphere/profile consistency and canonical provenance structure.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True}},'examples':['exec sphere.editor.validate path=/tmp/s sphere=x'],'result':{'problems':'object[]','problem_count':'integer'},'supports':['sphere-authoring','cross-object-validation']},
 'sphere.editor.lint':{
   'summary':'Advisory sphere lint for missing start/purpose/provenance, weak rule metadata, risky automatic fixes, absent tests/qualification and legacy source shapes.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True}},'examples':['exec sphere.editor.lint path=/tmp/s sphere=x'],'result':{'warnings':'object[]','warning_count':'integer'},'supports':['sphere-authoring','advisory']},
 'sphere.editor.package':{
   'summary':'Validate then package a sphere work tree with a SHA-256 manifest; optionally require clean lint.',
   'parameters':{'path':{'type':'string','required':True},'sphere':{'type':'string','required':True},'out':{'type':'string','required':True},'require_clean_lint':{'type':'boolean','required':False,'default':False}},'examples':['exec sphere.editor.package path=/tmp/s sphere=x out=/tmp/x-sphere.zip'],'result':{'out':'string','sha256':'hex','manifest':'string'},'supports':['sphere-authoring','package']},
 'reference.document.locate':{'summary':'Locate an approximate printed PDF page or HTML section.','parameters':{'source':{'type':'string','required':True},'kind':{'type':'string','required':False,'default':'auto','enum':['auto','pdf','html']},'reference_page':{'type':'integer','required':False,'minimum':1},'approx_page':{'type':'integer','required':False,'minimum':1},'reference':{'type':'string','required':False},'query':{'type':'string','required':False},'window':{'type':'integer','required':False,'default':12,'minimum':0,'maximum':100},'max_download_bytes':{'type':'integer','required':False,'default':67108864},'timeout':{'type':'integer','required':False,'default':20}},'examples':['exec reference.document.locate source=manual.pdf reference_page=47 approx_page=61'],'supports':['file','http','https','pdf','html']},
 'reference.document.page.read':{'summary':'Read one bounded PDF page or HTML section and return navigation.','parameters':{'source':{'type':'string','required':True},'kind':{'type':'string','required':False,'default':'auto','enum':['auto','pdf','html']},'page':{'type':'integer','required':False,'default':1,'minimum':1},'section':{'type':'integer','required':False,'minimum':1},'reference_page':{'type':'integer','required':False,'minimum':1},'step':{'type':'integer','required':False,'default':5},'max_chars':{'type':'integer','required':False,'default':24000},'html_chunk_chars':{'type':'integer','required':False,'default':12000},'max_download_bytes':{'type':'integer','required':False,'default':67108864},'timeout':{'type':'integer','required':False,'default':20}},'examples':['exec reference.document.page.read source=manual.pdf page=61'],'supports':['file','http','https','pdf','html']},
 'reference.document.find':{'summary':'Find a string in PDF/HTML and return bounded page/section hits with excerpts.','parameters':{'source':{'type':'string','required':True},'query':{'type':'string','required':True},'kind':{'type':'string','required':False,'default':'auto','enum':['auto','pdf','html']},'case_sensitive':{'type':'boolean','required':False,'default':False},'max_hits':{'type':'integer','required':False,'default':50},'context_chars':{'type':'integer','required':False,'default':240},'start_page':{'type':'integer','required':False,'default':1},'end_page':{'type':'integer','required':False},'html_chunk_chars':{'type':'integer','required':False,'default':12000},'max_download_bytes':{'type':'integer','required':False,'default':67108864},'timeout':{'type':'integer','required':False,'default':20}},'examples':['exec reference.document.find source=manual.pdf query="USE STRICT ARG"'],'supports':['file','http','https','pdf','html','bounded-search']},
 'reference.document.navigate':{'summary':'Move relative to a PDF page or HTML section.','parameters':{'source':{'type':'string','required':True},'kind':{'type':'string','required':False,'default':'auto','enum':['auto','pdf','html']},'page':{'type':'integer','required':False},'section':{'type':'integer','required':False},'delta':{'type':'integer','required':False,'default':1},'step':{'type':'integer','required':False,'default':5},'max_chars':{'type':'integer','required':False,'default':24000},'html_chunk_chars':{'type':'integer','required':False,'default':12000},'max_download_bytes':{'type':'integer','required':False,'default':67108864},'timeout':{'type':'integer','required':False,'default':20}},'examples':['exec reference.document.navigate source=manual.pdf page=61 delta=1'],'supports':['file','http','https','pdf','html']},
 'workspace.inspect':{
   'summary':'Inspect workspace filesystem byte/inode headroom and bounded top-level allocated usage before materialisation, extraction or large tests.',
   'parameters':{'path':{'type':'string','required':False},'paths':{'type':'string','required':False},'top_path':{'type':'string','required':False,'default':'/mnt/data'},'max_top':{'type':'integer','required':False,'default':20}},
   'examples':['exec workspace.inspect paths=/mnt/data,/tmp,/ top_path=/mnt/data'],'result':{'filesystems':'filesystem[]','usage':'object','top':'object[]'},'supports':['workspace','capacity','inodes']},
 'workspace.archive.preflight':{
   'summary':'Read ZIP central-directory metadata without extraction and decide whether materialise/extract fits byte, inode, traversal and expansion-ratio policy.',
   'parameters':{
      'path':{'type':'string','required':True},'destination':{'type':'string','required':False,'default':'/mnt/data'},
      'materialize_bytes':{'type':'integer','required':False,'default':0},'working_copies':{'type':'integer','required':False,'default':1},
      'reserve_bytes':{'type':'integer','required':False,'default':67108864},'reserve_percent':{'type':'number','required':False,'default':10},
      'max_expansion_ratio':{'type':'number','required':False,'default':100},'workspace_root':{'type':'string','required':False},'workspace_limit_bytes':{'type':'integer','required':False},'workspace_limit_inodes':{'type':'integer','required':False}},
   'examples':['exec workspace.archive.preflight path=large.zip destination=/mnt/data','exec workspace.archive.preflight path=large.zip destination=/mnt/data materialize_bytes=31457280'],
   'result':{'archive':'object','destination':'filesystem','estimate':'object','findings':'finding[]','advice':'object'},'supports':['zip','preflight','capacity','zip-bomb','handover-advice']},
 'workspace.materialization.check':{
   'summary':'Check whether an expected file is already available to the execution workspace and whether an expected materialisation can fit safely.',
   'parameters':{'path':{'type':'string','required':False},'expected_bytes':{'type':'integer','required':False,'default':0},'destination':{'type':'string','required':False,'default':'/mnt/data'},'reserve_bytes':{'type':'integer','required':False,'default':67108864},'workspace_root':{'type':'string','required':False},'workspace_limit_bytes':{'type':'integer','required':False}},
   'examples':['exec workspace.materialization.check path=/mnt/data/input.zip expected_bytes=31457280'],'result':{'materialization_required':'boolean','advice':'object'},'supports':['workspace','materialization','handover-advice']},
 'workspace.handover.frame':{
   'summary':'Build a read-only structured handover frame from the current environment, active spheres and optional exact artifact identity. It does not save or transmit anything.',
   'parameters':{'task':{'type':'string','required':False},'next_action':{'type':'string','required':False},'artifact':{'type':'string','required':False},'env':{'type':'string','required':False}},
   'examples':['exec workspace.handover.frame task="continue Java sphere" next_action="run v0.18 tests" artifact=/mnt/data/candidate.zip'],
   'result':{'artifact':'object|null','active_spheres':'object','capture':'string[]','missing':'string[]','ready_to_save':'boolean'},'supports':['workspace','handover','continuity','read-only']},
 'workspace.context.recoverability':{
   'summary':'Check the minimum local continuity artifacts needed to recover Gopher work after session loss and advise handover when they are absent.',
   'parameters':{'env':{'type':'string','required':False},'qualification':{'type':'string','required':False,'default':'qualification'},'changelog':{'type':'string','required':False,'default':'CHANGELOG.md'}},
   'examples':['exec workspace.context.recoverability'],'result':{'checks':'check[]','missing':'check[]','advice':'object'},'supports':['workspace','continuity','handover-advice']},
 'package.stage.check':{
   'summary':'Examine a package staging tree in one pass and return every packaging breach, discovered tests, and test environment references.',
   'parameters':{'path':{'type':'string','required':True},'version':{'type':'string','required':False}},
   'examples':['exec package.stage.check path=. version=v0.21-dev1'],
   'result':{'breaches':'PackageBreach[]','tests':'string[]','environment':'EnvironmentReference[]'},'supports':['directory','package-stage','grouped-diagnostics']},
 'package.stage.create':{
   'summary':'Create a clean staging tree while excluding VCS/cache/generated material and prior root delivery ZIPs.',
   'parameters':{'path':{'type':'string','required':True},'stage':{'type':'string','required':True}},
   'examples':['exec package.stage.create path=. stage=/tmp/package-stage'],
   'result':{'files':'integer','excluded':'object[]','manifest_digest':'hex'},'supports':['directory','package-stage']},
 'manual.man.subset':{
   'summary':'Return a bounded subset of an installed man page.',
   'parameters':{'name':{'type':'string','required':True},'section':{'type':'string','required':False},'contains':{'type':'string','required':False}},
   'examples':['exec manual.man.subset name=unzip contains=-Z'],'result':{'name':'string','lines':'string[]'},'supports':['host-manual']}
}

def dogfood_escape_record(args):
    task=str(args.get('task','')).strip(); reason=str(args.get('reason','')).strip()
    fallback=str(args.get('fallback','')).strip(); outcome=str(args.get('outcome','')).strip()
    if not task or not reason:
        return env('OK','INVALID_ARGUMENT',{'missing':[x for x,v in [('task',task),('reason',reason)] if not v]})
    failure=str(args.get('failure_class') or 'DOGFOOD.CAPABILITY_GAP')
    rec={'task':task,'reason':reason,'failure_class':failure,
         'fallback':fallback or None,'outcome':outcome or None,
         'correct':'> CORRECT: add or improve a Gopher article/capability so this task no longer requires the fallback'}
    return env('OK','RECORDED',rec)

def test_impact_discover(args):
    root=Path(str(args.get('path',''))); changed=str(args.get('changed','')).strip()
    if not root.is_dir(): return env('OK','NOT_FOUND',{'path':str(root)})
    if not changed: return env('OK','INVALID_ARGUMENT',{'missing':['changed']})
    terms={x.lower() for x in re.split(r'[^A-Za-z0-9_]+',changed) if len(x)>=3}
    tests=[]
    for q in sorted((root/'tests').glob('*')) if (root/'tests').is_dir() else []:
        if not q.is_file(): continue
        txt=q.read_text(errors='replace').lower()
        score=sum(1 for t in terms if t in txt or t in q.name.lower())
        if score: tests.append({'path':q.relative_to(root).as_posix(),'score':score})
    tests.sort(key=lambda x:(-x['score'],x['path']))
    return env('OK','FOUND' if tests else 'NOT_FOUND',{'changed':changed,'tests':tests,
        'basis':'lexical references in test names/content; advisory discovery, not authoritative dependency analysis'})


def _fs_snapshot(path):
    p=Path(path)
    probe=p
    while not probe.exists() and probe != probe.parent:
        probe=probe.parent
    st=os.statvfs(str(probe))
    frsize=st.f_frsize or st.f_bsize
    total=st.f_blocks*frsize
    free=st.f_bavail*frsize
    used=max(0,total-free)
    inode_total=st.f_files
    inode_free=st.f_favail if st.f_favail >= 0 else st.f_ffree
    return {
        'requested_path':str(p),
        'probe_path':str(probe.resolve()),
        'bytes':{'total':total,'used':used,'free':free,'free_percent':round((free/total*100.0),2) if total else None},
        'inodes':{'total':inode_total,'free':inode_free,'used':max(0,inode_total-inode_free) if inode_total>=0 and inode_free>=0 else None,
                  'free_percent':round((inode_free/inode_total*100.0),2) if inode_total else None}
    }

def _walk_allocated_bytes(path, max_entries=200000):
    root=Path(path)
    total=0; files=0; dirs=0; truncated=False
    if not root.exists():
        return {'bytes':0,'files':0,'directories':0,'truncated':False}
    try:
        for q in root.rglob('*'):
            if files+dirs >= max_entries:
                truncated=True; break
            try:
                if q.is_symlink():
                    files+=1
                    total+=q.lstat().st_blocks*512
                elif q.is_file():
                    files+=1
                    total+=q.stat().st_blocks*512
                elif q.is_dir():
                    dirs+=1
            except OSError:
                continue
    except OSError:
        truncated=True
    return {'bytes':total,'files':files,'directories':dirs,'truncated':truncated}

def workspace_inspect(args):
    paths=args.get('paths') or args.get('path') or ['/mnt/data','/tmp','/']
    if isinstance(paths,str):
        paths=[x for x in paths.split(',') if x]
    top_path=str(args.get('top_path') or '/mnt/data')
    max_top=int(args.get('max_top',20))
    result={'filesystems':[],'usage':None,'top':[]}
    seen=set()
    for path in paths:
        try:
            snap=_fs_snapshot(path)
        except OSError as e:
            snap={'requested_path':str(path),'error':str(e)}
        key=(snap.get('probe_path'),json.dumps(snap.get('bytes',{}),sort_keys=True))
        if key not in seen:
            result['filesystems'].append(snap);seen.add(key)
    result['usage']=dict({'path':top_path},**_walk_allocated_bytes(top_path))
    tp=Path(top_path)
    if tp.is_dir():
        rows=[]
        for child in tp.iterdir():
            try:
                info=_walk_allocated_bytes(child,max_entries=50000)
                if child.is_file():
                    info['bytes']=child.stat().st_blocks*512
                    info['files']=1
                rows.append({'path':str(child),'bytes':info['bytes'],'files':info['files'],'directories':info['directories'],'truncated':info['truncated']})
            except OSError:
                continue
        rows.sort(key=lambda x:(x['bytes'],x['path']),reverse=True)
        result['top']=rows[:max_top]
    return env('OK','OPENED',result)

def _zip_preflight(path):
    p=Path(path)
    if not p.is_file():
        return None,env('OK','NOT_FOUND',{'path':str(p)})
    try:
        compressed=p.stat().st_size
        with zipfile.ZipFile(p) as z:
            infos=z.infolist()
            total=0; files=0; dirs=0; max_member=0; max_name=None; unsafe=[]; encrypted=0
            compressed_members=0
            for info in infos:
                name=info.filename
                normalized=name.replace('\\','/')
                q=Path(normalized)
                if q.is_absolute() or '..' in q.parts or re.match(r'^[A-Za-z]:/',normalized) or normalized.startswith('//'):
                    unsafe.append(name)
                if info.flag_bits & 0x1:
                    encrypted+=1
                compressed_members+=info.compress_size
                total+=info.file_size
                if name.endswith('/'):
                    dirs+=1
                else:
                    files+=1
                if info.file_size>max_member:
                    max_member=info.file_size; max_name=name
            ratio=(total/max(1,compressed_members)) if total else 0.0
            return {
                'path':str(p.resolve()),'archive_bytes':compressed,'members':len(infos),'files':files,'directories':dirs,
                'uncompressed_bytes':total,'compressed_member_bytes':compressed_members,'expansion_ratio':round(ratio,3),
                'largest_member':{'name':max_name,'bytes':max_member},
                'unsafe_paths':unsafe[:50],'unsafe_path_count':len(unsafe),'encrypted_members':encrypted
            },None
    except zipfile.BadZipFile:
        return None,env('OK','INVALID_ARCHIVE',{'path':str(p),'reason':'bad ZIP central directory'})

def workspace_archive_preflight(args):
    path=str(args.get('path') or '')
    if not path:return env('OK','INVALID_ARGUMENT',{'missing':['path']})
    destination=str(args.get('destination') or args.get('dest') or '/mnt/data')
    reserve_bytes=int(args.get('reserve_bytes',64*1024*1024))
    reserve_percent=float(args.get('reserve_percent',10.0))
    working_copies=max(1,int(args.get('working_copies',1)))
    materialize_bytes=max(0,int(args.get('materialize_bytes',0)))
    max_ratio=float(args.get('max_expansion_ratio',100.0))
    meta,err=_zip_preflight(path)
    if err:return err
    fs=_fs_snapshot(destination)
    physical_free=fs['bytes']['free']; physical_inode_free=fs['inodes']['free']
    workspace_root=str(args.get('workspace_root') or destination)
    usage=_walk_allocated_bytes(workspace_root)
    declared_limit=args.get('workspace_limit_bytes')
    if declared_limit in (None,''):
        declared_limit=os.environ.get('LLM_GOPHER_WORKSPACE_LIMIT_BYTES')
    declared_inode_limit=args.get('workspace_limit_inodes')
    if declared_inode_limit in (None,''):
        declared_inode_limit=os.environ.get('LLM_GOPHER_WORKSPACE_LIMIT_INODES')
    quota_free=None
    if declared_limit not in (None,''):
        quota_free=max(0,int(declared_limit)-int(usage['bytes']))
    quota_inode_free=None
    if declared_inode_limit not in (None,''):
        quota_inode_free=max(0,int(declared_inode_limit)-(int(usage['files'])+int(usage['directories'])))
    free=min(physical_free,quota_free) if quota_free is not None else physical_free
    inode_free=min(physical_inode_free,quota_inode_free) if quota_inode_free is not None and physical_inode_free is not None else (quota_inode_free if quota_inode_free is not None else physical_inode_free)
    extraction=meta['uncompressed_bytes']
    required=materialize_bytes + extraction*working_copies
    if declared_limit not in (None,''):
        quota_target=max(8*1024*1024,int(declared_limit)*(int(reserve_percent*1000))//100000)
        policy_reserve=min(reserve_bytes,quota_target)
    else:
        policy_reserve=max(reserve_bytes,int(fs['bytes']['total']*(reserve_percent/100.0)))
    required_with_reserve=required+policy_reserve
    required_inodes=meta['files']+meta['directories']+16
    findings=[]
    if meta['unsafe_path_count']:
        findings.append({'class':'ARCHIVE_TRAVERSAL','severity':'BLOCKER','detail':f"{meta['unsafe_path_count']} unsafe archive paths"})
    if meta['encrypted_members']:
        findings.append({'class':'ENCRYPTED_MEMBERS','severity':'BLOCKER','detail':f"{meta['encrypted_members']} encrypted members cannot be safely prevalidated/extracted by this route"})
    if meta['expansion_ratio']>max_ratio:
        findings.append({'class':'EXPANSION_RATIO','severity':'BLOCKER','detail':f"expansion ratio {meta['expansion_ratio']} exceeds policy {max_ratio}"})
    if required>free:
        findings.append({'class':'INSUFFICIENT_BYTES','severity':'BLOCKER','detail':f"operation requires at least {required} bytes but destination has {free} free"})
    elif required_with_reserve>free:
        findings.append({'class':'LOW_HEADROOM','severity':'WARNING','detail':f"operation fits only by consuming the safety reserve; required with reserve {required_with_reserve}, free {free}"})
    if inode_free is not None and inode_free>=0 and required_inodes>inode_free:
        findings.append({'class':'INSUFFICIENT_INODES','severity':'BLOCKER','detail':f"archive needs about {required_inodes} inodes but destination has {inode_free} free"})
    blockers=[x for x in findings if x['severity']=='BLOCKER']
    warnings=[x for x in findings if x['severity']=='WARNING']
    if blockers:
        status='HANDOVER_ADVISED'
        advice={
            'action':'PREPARE_HANDOVER',
            'reason':'workspace cannot safely complete the materialize/extract operation under current limits',
            'do_not_extract':True,
            'suggestions':['preserve exact archive identity and intended operation','record current Gopher context/result selectors','move to a workspace with sufficient byte/inode headroom','do not partially extract and hope to continue']
        }
    elif warnings:
        status='CAUTION'
        advice={'action':'CONSIDER_HANDOVER','reason':'operation fits but leaves less than configured safety headroom','do_not_extract':False}
    else:
        status='SAFE'
        advice={'action':'PROCEED','reason':'archive fits byte/inode/reserve policy and no traversal/ratio/encryption blocker was found','do_not_extract':False}
    return env('OK',status,{
        'archive':meta,'destination':fs,
        'workspace_quota':{
            'root':workspace_root,'usage':usage,
            'limit_bytes':int(declared_limit) if declared_limit not in (None,'') else None,
            'quota_free_bytes':quota_free,'effective_free_bytes':free,
            'limit_inodes':int(declared_inode_limit) if declared_inode_limit not in (None,'') else None,
            'quota_free_inodes':quota_inode_free,'effective_free_inodes':inode_free
        },
        'estimate':{
            'materialize_bytes':materialize_bytes,'extraction_bytes':extraction,'working_copies':working_copies,
            'required_operation_bytes':required,'safety_reserve_bytes':policy_reserve,
            'required_with_reserve_bytes':required_with_reserve,'required_inodes':required_inodes
        },
        'findings':findings,'blocker_count':len(blockers),'warning_count':len(warnings),
        'advice':advice
    })

def workspace_materialization_check(args):
    expected_path=str(args.get('path') or '')
    expected_bytes=max(0,int(args.get('expected_bytes',0)))
    destination=str(args.get('destination') or '/mnt/data')
    if expected_path and Path(expected_path).exists():
        p=Path(expected_path)
        return env('OK','AVAILABLE',{'path':str(p.resolve()),'bytes':p.stat().st_size if p.is_file() else None,
                                     'materialization_required':False})
    fs=_fs_snapshot(destination)
    workspace_root=str(args.get('workspace_root') or destination)
    usage=_walk_allocated_bytes(workspace_root)
    declared_limit=args.get('workspace_limit_bytes')
    if declared_limit in (None,''):
        declared_limit=os.environ.get('LLM_GOPHER_WORKSPACE_LIMIT_BYTES')
    quota_free=max(0,int(declared_limit)-int(usage['bytes'])) if declared_limit not in (None,'') else None
    effective_free=min(fs['bytes']['free'],quota_free) if quota_free is not None else fs['bytes']['free']
    reserve=max(int(args.get('reserve_bytes',64*1024*1024)),int(fs['bytes']['total']*0.10))
    if declared_limit not in (None,''):
        reserve=min(reserve,max(8*1024*1024,int(declared_limit)*10//100))
    need=expected_bytes+reserve
    if expected_bytes and need>effective_free:
        return env('OK','HANDOVER_ADVISED',{
            'path':expected_path or None,'expected_bytes':expected_bytes,'destination':fs,
            'workspace_quota':{'root':workspace_root,'usage':usage,'limit_bytes':int(declared_limit) if declared_limit not in (None,'') else None,'quota_free_bytes':quota_free,'effective_free_bytes':effective_free},
            'materialization_required':True,
            'advice':{'action':'PREPARE_HANDOVER','reason':'expected materialization plus safety reserve does not fit this workspace','required_host_capability':'files.materialize','next':'handover to a workspace with sufficient quota, then materialise the exact file reference through the host and rerun preflight'}
        })
    return env('OK','MATERIALIZATION_REQUIRED',{
        'path':expected_path or None,'expected_bytes':expected_bytes or None,'destination':fs,
        'workspace_quota':{'root':workspace_root,'usage':usage,'limit_bytes':int(declared_limit) if declared_limit not in (None,'') else None,'quota_free_bytes':quota_free,'effective_free_bytes':effective_free},
        'materialization_required':True,
        'advice':{'action':'MATERIALIZE_THROUGH_HOST_TOOL','reason':'file is not present in the execution workspace; Gopher cannot fabricate or infer a mounted path','required_host_capability':'files.materialize','next':'materialise the exact file reference through the host, then rerun this check/preflight using the returned path'}
    })

def workspace_handover_frame(args):
    env_root=Path(str(args.get('env') or os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user')))))
    artifact=str(args.get('artifact') or '').strip()
    task=str(args.get('task') or '').strip()
    next_action=str(args.get('next_action') or '').strip()
    frame={
        'schema':'llm-gopher/handover-frame/1',
        'task':task or None,'next_action':next_action or None,
        'cwd':str(Path.cwd()),'environment':str(env_root),
        'setup_manifest':None,'active_spheres':{},'artifact':None,
        'capture':['current baseline/artifact identity','exact SHA-256','active sphere provenance','completed tests/evidence','known blocker or capacity condition','next action','required environment/materialisation inputs']
    }
    setup=env_root/'state'/'setup.json'
    if setup.is_file():
        try: frame['setup_manifest']=json.loads(setup.read_text(encoding='utf-8'))
        except Exception: frame['setup_manifest']={'path':str(setup),'unreadable':True}
    frame['active_spheres']=_load_sphere_registry(env_root)
    if artifact:
        ap=Path(artifact)
        if ap.is_file():
            h=hashlib.sha256()
            with ap.open('rb') as f:
                for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
            frame['artifact']={'path':str(ap.resolve()),'bytes':ap.stat().st_size,'sha256':h.hexdigest()}
        else:
            frame['artifact']={'path':artifact,'available':False,'note':'do not infer a mounted path from a display name'}
    missing=[]
    if not task: missing.append('task')
    if not next_action: missing.append('next_action')
    if artifact and not (frame['artifact'] or {}).get('sha256'): missing.append('materialized_artifact_identity')
    frame['missing']=missing
    frame['ready_to_save']=not bool(missing)
    return env('OK','OPENED',frame)

def workspace_context_recoverability(args):
    env_root=Path(str(args.get('env') or os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user')))))
    checks=[]
    setup=env_root/'state'/'setup.json'
    spheres=env_root/'state'/'spheres.json'
    checks.append({'item':'setup_manifest','path':str(setup),'present':setup.is_file()})
    checks.append({'item':'sphere_registry','path':str(spheres),'present':spheres.is_file()})
    qual=Path(str(args.get('qualification') or 'qualification'))
    checks.append({'item':'qualification','path':str(qual),'present':qual.exists()})
    changelog=Path(str(args.get('changelog') or 'CHANGELOG.md'))
    checks.append({'item':'changelog','path':str(changelog),'present':changelog.is_file()})
    missing=[x for x in checks if not x['present']]
    if missing:
        return env('OK','HANDOVER_ADVISED',{'checks':checks,'missing':missing,
            'advice':{'action':'PREPARE_HANDOVER','reason':'one or more continuity artifacts are absent; capture current baseline, exact digests, active spheres, pending task and test evidence before session loss'}})
    return env('OK','RECOVERABLE','CLEAN','WARNINGS','PACKAGED',{'checks':checks,'missing':[],
        'advice':{'action':'CONTINUE','reason':'minimum setup/sphere/qualification/changelog continuity artifacts are present'}})


SPHERE_CANONICAL_LAYOUT={
    'sphere':'00-sphere.json',
    'access-policy':'01-access-policy.json',
    'article':'articles/{id}.json',
    'corpus':'corpora/{id}.json',
    'language-rule':'rules/{id}.json',
    'service':'services/{id}.json',
    'language-module':'languages/{id}.json',
}

SPHERE_KIND_REQUIRED={
    'sphere':['kind','id','version','title'],
    'access-policy':['kind','id','version','rules'],
    'article':['kind','id','version','sphere','title','summary'],
    'corpus':['kind','id','sphere','title','records'],
    'language-rule':['kind','id','version','language','title'],
    'service':['kind','id','version','capabilities','implementation'],
    'language-module':['kind','id','version','extensions','source_kind'],
}

def _safe_component(x,label='id'):
    x=str(x or '').strip()
    if not x or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*',x):
        raise ValueError(label+' must match [A-Za-z0-9][A-Za-z0-9._-]*')
    return x

def _sha_file(path):
    p=Path(path)
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None

def _sphere_root(path):
    p=Path(path).resolve()
    return p

def _sphere_pack(root,sphere):
    return Path(root)/'packs'/sphere

def _sphere_object_path(root,sphere,kind,oid):
    if kind not in SPHERE_CANONICAL_LAYOUT:
        raise ValueError('unsupported sphere object kind: '+str(kind))
    rel=SPHERE_CANONICAL_LAYOUT[kind].format(id=oid)
    return _sphere_pack(root,sphere)/rel

def _atomic_json_write(path,obj):
    p=Path(path); p.parent.mkdir(parents=True,exist_ok=True)
    tmp=p.with_suffix(p.suffix+'.tmp')
    tmp.write_text(json.dumps(obj,indent=2,ensure_ascii=False,sort_keys=False)+'\n',encoding='utf-8')
    os.replace(tmp,p)

def _sphere_scan(root,sphere=None):
    root=Path(root)
    objects=[]; errors=[]
    packs=(root/'packs'/sphere) if sphere else (root/'packs')
    if not packs.is_dir():return objects,[{'class':'MISSING_PACKS','path':str(packs)}]
    for f in sorted(packs.rglob('*.json')):
        try:o=json.loads(f.read_text(encoding='utf-8'))
        except Exception as e:
            errors.append({'class':'INVALID_JSON','path':str(f),'error':str(e)});continue
        if isinstance(o,dict) and o.get('kind') and o.get('id'):
            objects.append((f,o))
    return objects,errors

def _validate_provenance_entry(item,where):
    problems=[]
    if not isinstance(item,dict):
        return [{'class':'PROVENANCE_NOT_OBJECT','where':where}]
    for k in ('artifact','sha256','member'):
        if not item.get(k):
            problems.append({'class':'PROVENANCE_MISSING_FIELD','where':where,'field':k})
    sha=item.get('sha256')
    if sha and not re.fullmatch(r'[0-9a-fA-F]{64}',str(sha)):
        problems.append({'class':'PROVENANCE_BAD_SHA256','where':where,'value':sha})
    a=item.get('line_start');b=item.get('line_end')
    if a is not None:
        try:
            if int(a)<1:raise ValueError()
        except:problems.append({'class':'PROVENANCE_BAD_LINE','where':where,'field':'line_start','value':a})
    if b is not None:
        try:
            if int(b)<1:raise ValueError()
        except:problems.append({'class':'PROVENANCE_BAD_LINE','where':where,'field':'line_end','value':b})
    if a is not None and b is not None:
        try:
            if int(b)<int(a):problems.append({'class':'PROVENANCE_REVERSED_RANGE','where':where,'line_start':a,'line_end':b})
        except:pass
    # `note` is intentionally opaque prose. Never parse it to reconstruct authority.
    return problems

def sphere_editor_create(args):
    try:
        sphere=_safe_component(args.get('sphere'),'sphere')
        version=str(args.get('version') or '0.1').strip()
        title=str(args.get('title') or sphere).strip()
    except ValueError as e:return env('OK','INVALID_ARGUMENT',{'reason':str(e)})
    root=_sphere_root(args.get('path') or (sphere+'_sphere_work'))
    if root.exists() and any(root.iterdir()):
        return env('OK','CONFLICT',{'path':str(root),'reason':'destination is not empty'})
    pack=_sphere_pack(root,sphere); pack.mkdir(parents=True,exist_ok=True)
    sphere_obj={'kind':'sphere','id':sphere,'version':version,'title':title,
                'access_policy':sphere+'-access',
                'purpose':str(args.get('purpose') or 'Describe this sphere purpose before qualification.'),
                'start_here':[]}
    policy={'kind':'access-policy','id':sphere+'-access','version':version,
            'rules':[{'effect':'allow','roles':['llm','developer','operator','admin'],'actions':['read'],'resource':'*'}]}
    profile={'id':sphere,'version':version,'packs':['packs/core','packs/'+sphere]}
    _atomic_json_write(_sphere_object_path(root,sphere,'sphere',sphere),sphere_obj)
    _atomic_json_write(_sphere_object_path(root,sphere,'access-policy',policy['id']),policy)
    _atomic_json_write(root/'profiles'/(sphere+'.json'),profile)
    (root/'tests').mkdir(parents=True,exist_ok=True)
    (root/'qualification').mkdir(parents=True,exist_ok=True)
    (root/'CHANGELOG.md').write_text('# Changelog\n\n## '+version+'\n- Initial sphere scaffold.\n',encoding='utf-8')
    (root/'README.md').write_text('# '+title+'\n\nUse `gopher --profile '+sphere+' context '+sphere+'` after installing/loading this sphere.\n',encoding='utf-8')
    return env('OK','CREATED',{'path':str(root),'sphere':sphere,'version':version,
        'profile':str(root/'profiles'/(sphere+'.json')),
        'next':['add articles/corpora/rules/services with sphere edit put','attach structured provenance','sphere edit validate','sphere edit lint','add tests/qualification','sphere edit package']})



def sphere_editor_import_legacy(args):
    source=Path(str(args.get('source') or args.get('path') or '')).resolve()
    out=Path(str(args.get('out') or '')).resolve()
    if not source.exists() or not out:
        return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('source',str(source) if source else ''),('out',str(out) if out else '')] if not v]})
    temp=None
    try:
        if source.is_file():
            if source.suffix.lower()!='.zip':return env('OK','INVALID_ARGUMENT',{'source':str(source),'reason':'legacy import currently accepts a directory or ZIP'})
            temp=Path(tempfile.mkdtemp(prefix='llm-gopher-legacy-sphere-'))
            with zipfile.ZipFile(source) as z:
                for info in z.infolist():
                    q=Path(info.filename)
                    if q.is_absolute() or '..' in q.parts:
                        return env('OK','INVALID_ARCHIVE',{'source':str(source),'member':info.filename,'reason':'unsafe archive path'})
                z.extractall(temp)
            candidates=[p.parent for p in temp.rglob('00-manifest.json')]
            if len(candidates)!=1:return env('OK','AMBIGUOUS' if candidates else 'NOT_FOUND',{'source':str(source),'legacy_roots':[str(x) for x in candidates]})
            legacy=candidates[0]
        else:
            candidates=[source] if (source/'00-manifest.json').is_file() else [p.parent for p in source.rglob('00-manifest.json')]
            if len(candidates)!=1:return env('OK','AMBIGUOUS' if candidates else 'NOT_FOUND',{'source':str(source),'legacy_roots':[str(x) for x in candidates]})
            legacy=candidates[0]
        manifest=json.loads((legacy/'00-manifest.json').read_text(encoding='utf-8'))
        sphere=_safe_component(manifest.get('id'),'sphere')
        version=str(manifest.get('version') or '0.1')
        title=str(manifest.get('name') or sphere)
        if out.exists() and any(out.iterdir()):return env('OK','CONFLICT',{'out':str(out),'reason':'destination is not empty'})
        pack=_sphere_pack(out,sphere);pack.mkdir(parents=True,exist_ok=True)
        sphere_obj={'kind':'sphere','id':sphere,'version':version,'title':title,
            'access_policy':sphere+'-policy','purpose':manifest.get('description',''),
            'start_here':[], 'legacy_import':{'source':str(source),'manifest':manifest}}
        policy_path=legacy/'01-access-policy.json'
        if policy_path.is_file():
            legacy_pol=json.loads(policy_path.read_text(encoding='utf-8'))
            policy_id=str(legacy_pol.get('id') or sphere+'-policy')
            current_rules=legacy_pol.get('rules') or []
            if current_rules and all(isinstance(x,dict) and 'effect' in x for x in current_rules):
                pol=dict(legacy_pol);pol['kind']='access-policy';pol['version']=str(pol.get('version') or version)
            else:
                allow_all=(str(legacy_pol.get('default_action','')).upper()=='ALLOW' or any(
                    isinstance(x,dict) and str(x.get('action','')).upper()=='ALLOW' and '*' in x.get('subjects',[]) and '*' in x.get('resources',[])
                    for x in current_rules))
                if not allow_all:
                    return env('OK','UNSUPPORTED',{'source':str(source),'policy':legacy_pol,'reason':'legacy access policy cannot be safely mapped automatically'})
                pol={'kind':'access-policy','id':policy_id,'version':version,
                     'legacy_policy':legacy_pol,
                     'rules':[{'effect':'allow','roles':['llm','developer','operator','admin'],'actions':['read','exec'],'resource':'*'}]}
            pol['id']=policy_id;sphere_obj['access_policy']=policy_id
        else:
            pol={'kind':'access-policy','id':sphere+'-policy','version':version,
                 'rules':[{'effect':'allow','roles':['llm','developer','operator','admin'],'actions':['read'],'resource':'*'}]}
        _atomic_json_write(_sphere_object_path(out,sphere,'sphere',sphere),sphere_obj)
        _atomic_json_write(_sphere_object_path(out,sphere,'access-policy',pol['id']),pol)
        article_ids=[]
        artdir=legacy/'articles'
        if artdir.is_dir():
            for f in sorted(artdir.glob('*.json')):
                o=json.loads(f.read_text(encoding='utf-8'))
                oid=_safe_component(o.get('id'),'article id')
                o['kind']='article';o['version']=str(o.get('version') or version);o['sphere']=sphere
                o.setdefault('summary','');o.setdefault('title',oid)
                o.setdefault('authority',manifest.get('authority') or o.get('grounding') or 'legacy-grounding')
                if o.get('evidence_note'):
                    o['legacy_evidence_note']=o.pop('evidence_note')
                _atomic_json_write(_sphere_object_path(out,sphere,'article',oid),o);article_ids.append(oid)
        corpdir=legacy/'corpus'
        if corpdir.is_dir():
            for f in sorted(corpdir.glob('*.json')):
                raw=json.loads(f.read_text(encoding='utf-8'))
                cid=sphere+'.'+f.stem if f.stem!='core' else sphere+'.core'
                if isinstance(raw,list):
                    co={'kind':'corpus','id':cid,'version':version,'sphere':sphere,'title':title+' corpus','records':raw,
                        'authority':manifest.get('authority') or 'legacy-grounding'}
                elif isinstance(raw,dict):
                    co=dict(raw);co.update({'kind':'corpus','id':str(raw.get('id') or cid),'version':str(raw.get('version') or version),'sphere':sphere})
                    co.setdefault('title',title+' corpus');co.setdefault('records',[])
                else:return env('OK','INVALID_SOURCE',{'path':str(f),'reason':'legacy corpus must be array/object'})
                _atomic_json_write(_sphere_object_path(out,sphere,'corpus',co['id']),co)
        sphere_obj['start_here']=article_ids[:3]
        _atomic_json_write(_sphere_object_path(out,sphere,'sphere',sphere),sphere_obj)
        profile={'id':sphere,'version':version,'packs':['packs/core','packs/'+sphere]}
        _atomic_json_write(out/'profiles'/(sphere+'.json'),profile)
        (out/'tests').mkdir(parents=True,exist_ok=True);(out/'qualification').mkdir(parents=True,exist_ok=True)
        # Preserve legacy qualification/tests as evidence without pretending they use the new layout.
        for dirname in ('tests','qualification'):
            srcd=legacy/dirname
            if srcd.is_dir():
                for f in srcd.rglob('*'):
                    if f.is_file():
                        rel=f.relative_to(srcd);dst=out/dirname/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dst)
        (out/'README.md').write_text('# '+title+'\n\nCanonical import of legacy sphere '+sphere+' '+version+'.\n',encoding='utf-8')
        (out/'CHANGELOG.md').write_text('# Changelog\n\n## '+version+'-canonical\n- Imported legacy sphere structure without interpreting free-form evidence prose as machine provenance.\n',encoding='utf-8')
        return env('OK','CREATED',{'source':str(source),'legacy_root':str(legacy),'out':str(out),'sphere':sphere,'version':version,
            'articles':len(article_ids),'rule':'legacy evidence_note preserved as opaque legacy_evidence_note; never parsed into provenance'})
    except (ValueError,json.JSONDecodeError,OSError,zipfile.BadZipFile) as e:
        return env('OK','INVALID_SOURCE',{'source':str(source),'reason':str(e)})
    finally:
        if temp is not None:shutil.rmtree(temp,ignore_errors=True)

def sphere_editor_template(args):
    kind=str(args.get('kind') or '').strip()
    sphere=str(args.get('sphere') or '').strip()
    oid=str(args.get('id') or '').strip()
    title=str(args.get('title') or oid or '').strip()
    version=str(args.get('version') or '0.1').strip()
    if kind not in SPHERE_CANONICAL_LAYOUT:
        return env('OK','INVALID_ARGUMENT',{'kind':kind,'supported':sorted(SPHERE_CANONICAL_LAYOUT)})
    try:
        if sphere:_safe_component(sphere,'sphere')
        if oid:_safe_component(oid,'id')
    except ValueError as e:return env('OK','INVALID_ARGUMENT',{'reason':str(e)})
    if kind=='article':
        obj={'kind':'article','id':oid,'version':version,'sphere':sphere,'title':title,'summary':'',
             'authority':'','invariants':[],'procedure':[],'provenance':[]}
    elif kind=='corpus':
        obj={'kind':'corpus','id':oid,'sphere':sphere,'title':title,'records':[]}
    elif kind=='language-rule':
        obj={'kind':'language-rule','id':oid,'version':version,'language':'','title':title,
             'classification':'','detection':'','severity':'ADVISORY','trigger':'','correct':'> CORRECT: ','fix':{'class':'SUGGESTED'},'provenance':[]}
    elif kind=='service':
        obj={'kind':'service','id':oid,'version':version,'rank':10,'capabilities':[],
             'implementation':'','implementation_class':'','operations':['exec'],'spheres':[sphere] if sphere else [],
             'effect_class':'','reversible':None,'authority_class':''}
    elif kind=='language-module':
        obj={'kind':'language-module','id':oid,'version':version,'title':title,'extensions':[],
             'source_kind':'','examiner_capability':'','symbol_language':oid}
    elif kind=='sphere':
        obj={'kind':'sphere','id':sphere or oid,'version':version,'title':title,
             'access_policy':(sphere or oid)+'-access' if (sphere or oid) else '',
             'purpose':'','start_here':[]}
    else:
        obj={'kind':'access-policy','id':oid or ((sphere+'-access') if sphere else ''),'version':version,
             'rules':[{'effect':'allow','roles':['llm'],'actions':['read'],'resource':'*'}]}
    out=args.get('out')
    if out:
        _atomic_json_write(out,obj)
    return env('OK','OPENED',{'kind':kind,'sphere':sphere or None,'id':oid or obj.get('id'),'template':obj,'out':str(Path(out).resolve()) if out else None})

def sphere_editor_corpus_record_put(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or ''); corpus=str(args.get('corpus') or '')
    source=str(args.get('from') or args.get('source') or '')
    key=str(args.get('key') or 'id'); value=str(args.get('value') or '')
    if not all((sphere,corpus,source,key,value)):
        return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('sphere',sphere),('corpus',corpus),('from',source),('key',key),('value',value)] if not v]})
    hits,errs=_find_sphere_object(root,sphere,'corpus',corpus)
    if errs:return env('OK','INVALID_SOURCE',{'errors':errs})
    if not hits:return env('OK','NOT_FOUND',{'sphere':sphere,'corpus':corpus})
    if len(hits)>1:return env('OK','AMBIGUOUS',{'sphere':sphere,'corpus':corpus,'paths':[str(x[0]) for x in hits]})
    try:
        record=json.loads(Path(source).read_text(encoding='utf-8'))
        if not isinstance(record,dict):raise ValueError('record JSON must be an object')
    except Exception as e:return env('OK','INVALID_ARGUMENT',{'reason':str(e),'source':source})
    if str(record.get(key,''))!=value:
        return env('OK','INVALID_ARGUMENT',{'reason':'record key/value mismatch','key':key,'expected':value,'actual':record.get(key)})
    f,obj=hits[0]; before=_sha_file(f)
    expected=args.get('expected_sha256')
    if expected and before!=expected:return env('OK','STALE_SOURCE',{'path':str(f),'expected_sha256':expected,'actual_sha256':before})
    records=obj.setdefault('records',[])
    matches=[i for i,r in enumerate(records) if isinstance(r,dict) and str(r.get(key,''))==value]
    if len(matches)>1:return env('OK','AMBIGUOUS',{'corpus':corpus,'key':key,'value':value,'record_indexes':matches})
    op='CREATED'
    if matches:
        records[matches[0]]=record;op='UPDATED'
    else:
        records.append(record)
    _atomic_json_write(f,obj);after=_sha_file(f)
    return env('OK',op,{'sphere':sphere,'corpus':corpus,'path':str(f),'key':key,'value':value,
        'record_index':matches[0] if matches else len(records)-1,'before_sha256':before,'after_sha256':after})

def sphere_editor_changelog_add(args):
    root=_sphere_root(args.get('path') or '.')
    version=str(args.get('version') or '').strip(); text=str(args.get('text') or '').strip()
    if not version or not text:return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('version',version),('text',text)] if not v]})
    p=root/'CHANGELOG.md'
    before=_sha_file(p)
    current=p.read_text(encoding='utf-8') if p.is_file() else '# Changelog\n'
    heading='## '+version
    lines=current.splitlines()
    if heading in lines:
        pos=lines.index(heading)+1
        item='- '+text
        if item in lines:return env('OK','EXISTS',{'path':str(p),'version':version,'text':text,'sha256':before})
        lines.insert(pos,item)
        new='\n'.join(lines).rstrip()+'\n'
    else:
        body=current
        if body.startswith('# Changelog'):
            rest=body[len('# Changelog'):].lstrip('\n')
            new='# Changelog\n\n'+heading+'\n- '+text+'\n\n'+rest
        else:
            new='# Changelog\n\n'+heading+'\n- '+text+'\n\n'+body
    p.write_text(new,encoding='utf-8')
    return env('OK','UPDATED' if before else 'CREATED',{'path':str(p),'version':version,'text':text,
        'before_sha256':before,'after_sha256':_sha_file(p)})

def sphere_editor_put(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or '').strip()
    kind=str(args.get('kind') or '').strip()
    source=str(args.get('from') or args.get('source') or '').strip()
    if not sphere or not kind or not source:
        return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('sphere',sphere),('kind',kind),('from',source)] if not v]})
    try:
        _safe_component(sphere,'sphere')
        src=Path(source)
        obj=json.loads(src.read_text(encoding='utf-8'))
        if not isinstance(obj,dict):raise ValueError('source JSON must contain one object')
        if obj.get('kind')!=kind:raise ValueError('object kind '+repr(obj.get('kind'))+' does not match requested '+repr(kind))
        oid=_safe_component(obj.get('id'),'object id')
        if kind in ('article','corpus') and obj.get('sphere')!=sphere:
            raise ValueError(kind+' sphere must be '+sphere)
        target=_sphere_object_path(root,sphere,kind,oid)
    except Exception as e:return env('OK','INVALID_ARGUMENT',{'reason':str(e),'source':source})
    before=_sha_file(target)
    expected=args.get('expected_sha256')
    if expected and before!=expected:
        return env('OK','STALE_SOURCE',{'path':str(target),'expected_sha256':expected,'actual_sha256':before})
    required=SPHERE_KIND_REQUIRED.get(kind,[])
    missing=[x for x in required if x not in obj or obj.get(x) in (None,'')]
    if missing:return env('OK','INVALID_ARGUMENT',{'object':{'kind':kind,'id':oid},'missing':missing})
    _atomic_json_write(target,obj)
    after=_sha_file(target)
    return env('OK','UPDATED' if before else 'CREATED',{'sphere':sphere,'kind':kind,'id':oid,'path':str(target),
        'before_sha256':before,'after_sha256':after,'changed':before!=after})

def _find_sphere_object(root,sphere,kind,oid):
    objects,errs=_sphere_scan(root,sphere)
    hits=[(f,o) for f,o in objects if o.get('kind')==kind and o.get('id')==oid and
          (kind not in ('article','corpus') or o.get('sphere')==sphere)]
    return hits,errs

def sphere_editor_evidence_attach(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or '');kind=str(args.get('kind') or '');oid=str(args.get('id') or '')
    artifact=str(args.get('artifact') or '');sha=str(args.get('sha256') or '');member=str(args.get('member') or '')
    if not all((sphere,kind,oid,artifact,sha,member)):
        return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('sphere',sphere),('kind',kind),('id',oid),('artifact',artifact),('sha256',sha),('member',member)] if not v]})
    hits,errs=_find_sphere_object(root,sphere,kind,oid)
    if errs:return env('OK','INVALID_SOURCE',{'errors':errs})
    if not hits:return env('OK','NOT_FOUND',{'sphere':sphere,'kind':kind,'id':oid})
    if len(hits)>1:return env('OK','AMBIGUOUS',{'sphere':sphere,'kind':kind,'id':oid,'paths':[str(x[0]) for x in hits]})
    f,obj=hits[0];before=_sha_file(f)
    expected=args.get('expected_sha256')
    if expected and before!=expected:return env('OK','STALE_SOURCE',{'path':str(f),'expected_sha256':expected,'actual_sha256':before})
    ev={'artifact':artifact,'sha256':sha.lower(),'member':member}
    if args.get('line_start') not in (None,''):ev['line_start']=int(args['line_start'])
    if args.get('line_end') not in (None,''):ev['line_end']=int(args['line_end'])
    if args.get('claim'):ev['claim']=str(args['claim'])
    if args.get('note'):ev['note']=str(args['note'])
    problems=_validate_provenance_entry(ev,kind+':'+oid)
    if problems:return env('OK','INVALID_ARGUMENT',{'provenance':ev,'problems':problems})
    prov=obj.setdefault('provenance',[])
    identity=(ev['artifact'],ev['sha256'],ev['member'],ev.get('line_start'),ev.get('line_end'),ev.get('claim'))
    for old in prov:
        oldid=(old.get('artifact'),old.get('sha256'),old.get('member'),old.get('line_start'),old.get('line_end'),old.get('claim'))
        if oldid==identity:return env('OK','EXISTS',{'sphere':sphere,'kind':kind,'id':oid,'path':str(f),'provenance':ev})
    prov.append(ev);_atomic_json_write(f,obj);after=_sha_file(f)
    return env('OK','UPDATED',{'sphere':sphere,'kind':kind,'id':oid,'path':str(f),'before_sha256':before,'after_sha256':after,'provenance':ev})

def sphere_editor_validate(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or '').strip()
    objects,parse_errors=_sphere_scan(root,sphere or None)
    problems=list(parse_errors);warnings=[]
    seen={}
    for f,o in objects:
        key=(o.get('kind'),o.get('id'))
        if key in seen:
            problems.append({'class':'DUPLICATE_IDENTITY','identity':list(key),'paths':[seen[key],str(f)]})
        else:seen[key]=str(f)
        kind=o.get('kind')
        for field in SPHERE_KIND_REQUIRED.get(kind,[]):
            if field not in o or o.get(field) in (None,''):
                problems.append({'class':'MISSING_REQUIRED_FIELD','path':str(f),'kind':kind,'id':o.get('id'),'field':field})
        if kind in ('article','corpus') and sphere and o.get('sphere')!=sphere:
            problems.append({'class':'SPHERE_MISMATCH','path':str(f),'expected':sphere,'actual':o.get('sphere')})
        prov=o.get('provenance',[])
        if prov is not None and not isinstance(prov,list):
            problems.append({'class':'PROVENANCE_NOT_LIST','path':str(f)})
        elif isinstance(prov,list):
            for n,item in enumerate(prov):
                problems.extend(_validate_provenance_entry(item,str(f)+'#provenance['+str(n)+']'))
    if sphere:
        spheres=[o for _,o in objects if o.get('kind')=='sphere' and o.get('id')==sphere]
        if len(spheres)!=1:problems.append({'class':'SPHERE_IDENTITY_COUNT','sphere':sphere,'count':len(spheres)})
        pf=root/'profiles'/(sphere+'.json')
        if not pf.is_file():problems.append({'class':'PROFILE_MISSING','path':str(pf)})
        else:
            try:
                prof=json.loads(pf.read_text(encoding='utf-8'))
                if prof.get('id')!=sphere:problems.append({'class':'PROFILE_ID_MISMATCH','path':str(pf),'actual':prof.get('id'),'expected':sphere})
                rels=prof.get('packs',[])
                if 'packs/'+sphere not in rels and sphere not in prof.get('spheres',[]):
                    problems.append({'class':'PROFILE_DOES_NOT_LOAD_SPHERE','path':str(pf),'sphere':sphere})
            except Exception as e:problems.append({'class':'PROFILE_INVALID_JSON','path':str(pf),'error':str(e)})
        if not (root/'CHANGELOG.md').is_file():problems.append({'class':'CHANGELOG_MISSING'})
        if not (root/'tests').is_dir():problems.append({'class':'TEST_DIRECTORY_MISSING'})
        if not (root/'qualification').is_dir():problems.append({'class':'QUALIFICATION_DIRECTORY_MISSING'})
    return env('OK','VALID' if not problems else 'BREACHED',{'path':str(root),'sphere':sphere or None,
        'object_count':len(objects),'problems':problems,'problem_count':len(problems),'warnings':warnings})

def sphere_editor_lint(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or '').strip()
    objects,parse_errors=_sphere_scan(root,sphere or None)
    warnings=[]
    if parse_errors:
        warnings.extend({'class':'PARSE_ERROR_BLOCKS_LINT','detail':x} for x in parse_errors)
    for f,o in objects:
        kind=o.get('kind');oid=o.get('id')
        if kind=='sphere':
            if not o.get('purpose'):warnings.append({'class':'SPHERE_PURPOSE_MISSING','path':str(f),'id':oid})
            if not o.get('start_here'):warnings.append({'class':'START_HERE_EMPTY','path':str(f),'id':oid})
        if kind=='article':
            if len(str(o.get('summary','')))>1200:warnings.append({'class':'ARTICLE_SUMMARY_LARGE','path':str(f),'id':oid})
            if not o.get('provenance') and not o.get('authoritative_sources') and not o.get('authority'):
                warnings.append({'class':'ARTICLE_NO_PROVENANCE_OR_AUTHORITY','path':str(f),'id':oid})
        if kind=='language-rule':
            for field in ('classification','detection','severity'):
                if not o.get(field):warnings.append({'class':'RULE_METADATA_MISSING','path':str(f),'id':oid,'field':field})
            fix=o.get('fix') or {}
            if str(fix.get('class','')).upper() in ('AUTOMATIC','AUTOMATIC_SAFE') and str(o.get('detection','')).lower() not in ('deterministic','exact'):
                warnings.append({'class':'AUTOMATIC_FIX_WEAK_DETECTION','path':str(f),'id':oid})
        if 'authoritative_sources' in o and 'provenance' not in o:
            warnings.append({'class':'LEGACY_SOURCE_SHAPE','path':str(f),'id':oid,'correct':'> CORRECT: migrate machine-resolvable citations to provenance[]; keep narrative source notes separately.'})
    tests=list((root/'tests').glob('*')) if (root/'tests').is_dir() else []
    if not any(x.is_file() for x in tests):warnings.append({'class':'NO_TEST_FILE'})
    quals=list((root/'qualification').glob('*')) if (root/'qualification').is_dir() else []
    if not any(x.is_file() for x in quals):warnings.append({'class':'NO_QUALIFICATION_FILE'})
    return env('OK','CLEAN' if not warnings else 'WARNINGS',{'path':str(root),'sphere':sphere or None,'warnings':warnings,'warning_count':len(warnings)})

def sphere_editor_package(args):
    root=_sphere_root(args.get('path') or '.')
    sphere=str(args.get('sphere') or '').strip()
    out=Path(str(args.get('out') or (str(root)+'.zip'))).resolve()
    valid=sphere_editor_validate({'path':str(root),'sphere':sphere})
    if valid['operation_status']['class']!='VALID':
        return env('OK','BREACHED',{'reason':'sphere validation failed','validation':valid['result']})
    lint=sphere_editor_lint({'path':str(root),'sphere':sphere})
    if bool(args.get('require_clean_lint',False)) and lint['operation_status']['class']!='CLEAN':
        return env('OK','BREACHED',{'reason':'sphere lint is not clean','lint':lint['result']})
    out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists():out.unlink()
    manifest=[]
    # manifest is calculated from the pre-package tree and inserted in qualification/
    for f in sorted(root.rglob('*')):
        if f.is_file() and not any(x in f.parts for x in ('.git','__pycache__')):
            rel=f.relative_to(root).as_posix()
            manifest.append((hashlib.sha256(f.read_bytes()).hexdigest(),rel))
    mpath=root/'qualification'/'MANIFEST.sha256'
    mpath.parent.mkdir(parents=True,exist_ok=True)
    mpath.write_text(''.join(sha+'  '+rel+'\n' for sha,rel in manifest),encoding='utf-8')
    top=root.name
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted(root.rglob('*')):
            if not f.is_file():continue
            rel=f.relative_to(root)
            if any(x in rel.parts for x in ('.git','__pycache__')) or f.suffix in ('.pyc','.pyo'):continue
            z.write(f,Path(top)/rel)
    with zipfile.ZipFile(out) as z:
        bad=z.testzip()
    if bad:return env('IMPLEMENTATION_FAILURE','UNKNOWN',{'out':str(out),'bad_member':bad})
    return env('OK','PACKAGED',{'sphere':sphere,'source':str(root),'out':str(out),
        'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bytes':out.stat().st_size,
        'manifest':str(mpath),'lint':lint['result']})


MAX_REFERENCE_DOWNLOAD_BYTES=64*1024*1024

def _ref_fetch(source,max_bytes=MAX_REFERENCE_DOWNLOAD_BYTES,timeout=20):
    source=str(source or '').strip()
    if not source:return None,None,env('OK','INVALID_ARGUMENT',{'missing':['source']})
    u=urllib.parse.urlparse(source)
    if u.scheme in ('http','https'):
        req=urllib.request.Request(source,headers={'User-Agent':'LLM-Gopher/0.21','Accept':'application/pdf,text/html,*/*;q=0.1'})
        try:
            with urllib.request.urlopen(req,timeout=timeout) as r:
                out=bytearray()
                while True:
                    b=r.read(min(1024*1024,max_bytes+1-len(out)))
                    if not b:break
                    out.extend(b)
                    if len(out)>max_bytes:return None,None,env('OK','TOO_LARGE',{'source':source,'limit':max_bytes})
                return bytes(out),{'source':source,'resolved_source':r.geturl(),'source_class':'url','content_type':r.headers.get('Content-Type','').split(';')[0].lower(),'bytes':len(out)},None
        except urllib.error.HTTPError as e:return None,None,env('OK','NOT_FOUND' if e.code==404 else 'FETCH_FAILED',{'source':source,'http_status':e.code})
        except Exception as e:return None,None,env('TEMPORARY_FAILURE','UNKNOWN',{'source':source,'reason':str(e)})
    q=Path(source)
    if not q.is_file():return None,None,env('OK','NOT_FOUND',{'source':source})
    if q.stat().st_size>max_bytes:return None,None,env('OK','TOO_LARGE',{'source':source,'limit':max_bytes})
    ext=q.suffix.lower()
    return q.read_bytes(),{'source':source,'resolved_source':str(q.resolve()),'source_class':'file','content_type':'application/pdf' if ext=='.pdf' else ('text/html' if ext in ('.html','.htm') else ''),'bytes':q.stat().st_size},None

def _ref_kind(data,meta,kind='auto'):
    if kind in ('pdf','html'):return kind
    if meta.get('content_type')=='application/pdf' or data[:5]==b'%PDF-':return 'pdf'
    h=data[:4096].decode('utf-8','ignore').lower()
    if 'html' in meta.get('content_type','') or '<html' in h or '<!doctype html' in h:return 'html'
    return 'unknown'

def _pdf_count(data):
    try:
        from pypdf import PdfReader
        return len(PdfReader(io.BytesIO(data)))
    except Exception:
        pass
    if which('pdfinfo'):
        try:
            with tempfile.NamedTemporaryFile(suffix='.pdf') as f:
                f.write(data); f.flush()
                q=run_cmd(['pdfinfo',f.name],timeout=15)
                if q is not None and q.returncode==0:
                    m=re.search(r'(?mi)^Pages:\s*(\d+)\s*$',q.stdout)
                    if m:return int(m.group(1))
        except Exception:
            pass
    return None

def _pdf_text(data,page):
    if which('pdftotext'):
        with tempfile.NamedTemporaryFile(suffix='.pdf') as f:
            f.write(data);f.flush()
            q=run_cmd(['pdftotext','-f',str(page),'-l',str(page),'-layout','-nopgbrk',f.name,'-'],timeout=25)
            if q and q.returncode==0:return q.stdout,'pdftotext'
    try:
        from pypdf import PdfReader
        r=PdfReader(io.BytesIO(data))
        if page<1 or page>len(r.pages):return None,'pypdf'
        return r.pages[page-1].extract_text() or '','pypdf'
    except Exception:return None,'unavailable'

def _html_text(data):
    txt=data.decode('utf-8',errors='replace')
    txt=re.sub(r'(?is)<(script|style|noscript|svg).*?</\1>',' ',txt)
    txt=re.sub(r'(?i)</?(?:p|div|section|article|li|ul|ol|table|tr|td|th|pre|blockquote|br|hr|h[1-6])\b[^>]*>','\n',txt)
    txt=re.sub(r'(?s)<[^>]+>',' ',txt)
    import html as _html
    txt=_html.unescape(txt)
    lines=[' '.join(x.split()) for x in txt.splitlines()]
    return '\n'.join(x for x in lines if x).strip()

def _chunks(text,n=12000):
    return [text[i:i+n] for i in range(0,max(1,len(text)),n)] or ['']

def reference_document_read(args):
    data,meta,err=_ref_fetch(args.get('source'),int(args.get('max_download_bytes',MAX_REFERENCE_DOWNLOAD_BYTES)),int(args.get('timeout',20)))
    if err:return err
    kind=_ref_kind(data,meta,args.get('kind','auto'));step=int(args.get('step',5));mx=int(args.get('max_chars',24000))
    if kind=='pdf':
        total=_pdf_count(data);page=int(args.get('page',1))
        if total and page>total:return env('OK','NOT_FOUND',{'page':page,'pages':total})
        text,route=_pdf_text(data,page)
        if text is None:return env('DEPENDENCY_FAILURE','UNKNOWN',{'page':page})
        shown=text[:mx]
        nav={'previous':page-1 if page>1 else None,'next':page+1 if not total or page<total else None,'minus_n':max(1,page-step),'plus_n':min(total,page+step) if total else page+step}
        return env('OK','OPENED',{'document':{**meta,'kind':'pdf','sha256':hashlib.sha256(data).hexdigest(),'pages':total},'location':{'physical_page':page,'reference_page_hint':args.get('reference_page'),'approximate_reference':args.get('reference_page') is not None},'text':shown,'text_bounds':{'characters_total':len(text),'characters_returned':len(shown),'truncated':len(shown)<len(text)},'navigation':nav,'extractor':route})
    if kind=='html':
        cs=_chunks(_html_text(data),int(args.get('html_chunk_chars',12000)));sec=int(args.get('section') or args.get('page') or 1)
        if sec<1 or sec>len(cs):return env('OK','NOT_FOUND',{'section':sec,'sections':len(cs)})
        text=cs[sec-1];shown=text[:mx]
        nav={'previous':sec-1 if sec>1 else None,'next':sec+1 if sec<len(cs) else None,'minus_n':max(1,sec-step),'plus_n':min(len(cs),sec+step)}
        return env('OK','OPENED',{'document':{**meta,'kind':'html','sha256':hashlib.sha256(data).hexdigest(),'sections':len(cs)},'location':{'section':sec},'text':shown,'text_bounds':{'characters_total':len(text),'characters_returned':len(shown),'truncated':len(shown)<len(text)},'navigation':nav})
    return env('OK','UNSUPPORTED',{'source':args.get('source')})

def reference_document_find(args):
    query=str(args.get('query') or '')
    if not query:return env('OK','INVALID_ARGUMENT',{'missing':['query']})
    data,meta,err=_ref_fetch(args.get('source'),int(args.get('max_download_bytes',MAX_REFERENCE_DOWNLOAD_BYTES)),int(args.get('timeout',20)))
    if err:return err
    kind=_ref_kind(data,meta,args.get('kind','auto'));case=bool(args.get('case_sensitive',False));needle=query if case else query.casefold()
    max_hits=max(1,min(int(args.get('max_hits',50)),500));ctx=max(40,min(int(args.get('context_chars',240)),4000));hits=[];truncated=False
    if kind=='pdf':
        total=_pdf_count(data)
        if not total:return env('DEPENDENCY_FAILURE','UNKNOWN',{'reason':'cannot determine PDF pages'})
        start=max(1,int(args.get('start_page',1)));end=min(total,int(args.get('end_page') or total))
        for page in range(start,end+1):
            text,route=_pdf_text(data,page)
            if text is None:continue
            hay=text if case else text.casefold();pos=0
            while True:
                at=hay.find(needle,pos)
                if at<0:break
                hits.append({'physical_page':page,'excerpt':' '.join(text[max(0,at-ctx):min(len(text),at+len(query)+ctx)].split()),'open':{'source':meta['resolved_source'],'page':page}})
                if len(hits)>=max_hits:truncated=True;break
                pos=at+max(1,len(query))
            if truncated:break
        return env('OK','FOUND' if hits else 'NOT_FOUND',{'document':{**meta,'kind':'pdf','sha256':hashlib.sha256(data).hexdigest(),'pages':total},'query':query,'hits':hits,'count':len(hits),'truncated':truncated})
    if kind=='html':
        cs=_chunks(_html_text(data),int(args.get('html_chunk_chars',12000)))
        for sec,text in enumerate(cs,1):
            hay=text if case else text.casefold();pos=0
            while True:
                at=hay.find(needle,pos)
                if at<0:break
                hits.append({'section':sec,'excerpt':' '.join(text[max(0,at-ctx):min(len(text),at+len(query)+ctx)].split()),'open':{'source':meta['resolved_source'],'section':sec}})
                if len(hits)>=max_hits:truncated=True;break
                pos=at+max(1,len(query))
            if truncated:break
        return env('OK','FOUND' if hits else 'NOT_FOUND',{'document':{**meta,'kind':'html','sha256':hashlib.sha256(data).hexdigest(),'sections':len(cs)},'query':query,'hits':hits,'count':len(hits),'truncated':truncated})
    return env('OK','UNSUPPORTED',{'source':args.get('source')})

def reference_document_locate(args):
    data,meta,err=_ref_fetch(args.get('source'),int(args.get('max_download_bytes',MAX_REFERENCE_DOWNLOAD_BYTES)),int(args.get('timeout',20)))
    if err:return err
    kind=_ref_kind(data,meta,args.get('kind','auto'))
    if kind=='html':
        q=str(args.get('query') or args.get('reference') or '')
        if q:
            r=reference_document_find({**args,'query':q,'max_hits':20})
            if r.get('result',{}).get('hits'):
                r['result']['next']=r['result']['hits'][0]['open']
            return r
        return env('OK','OPENED',{'document':{**meta,'kind':'html','sha256':hashlib.sha256(data).hexdigest()},'next':{'source':meta['resolved_source'],'section':1}})
    if kind=='pdf':
        total=_pdf_count(data);ref=args.get('reference_page');center=max(1,int(args.get('approx_page') or ref or 1));window=max(0,min(int(args.get('window',12)),100));hits=[]
        if ref is None:return env('OK','OPENED',{'document':{**meta,'kind':'pdf','sha256':hashlib.sha256(data).hexdigest(),'pages':total},'next':{'source':meta['resolved_source'],'page':center}})
        target=str(ref)
        for page in range(max(1,center-window),min(total,center+window)+1 if total else center+window+1):
            text,route=_pdf_text(data,page)
            if text is None:continue
            lines=[x.strip() for x in text.splitlines() if x.strip()]
            edge=lines[:12]+lines[-12:]
            if any(x==target or re.fullmatch(r'(?:page|p\.?)\s*'+re.escape(target),x,re.I) for x in edge):
                hits.append({'physical_page':page,'score':100,'open':{'source':meta['resolved_source'],'page':page}})
        return env('OK','FOUND' if hits else 'NOT_FOUND',{'document':{**meta,'kind':'pdf','sha256':hashlib.sha256(data).hexdigest(),'pages':total},'reference_page':ref,'approx_page':center,'hits':hits,'count':len(hits),'next':hits[0]['open'] if hits else {'source':meta['resolved_source'],'page':center}})
    return env('OK','UNSUPPORTED',{'source':args.get('source')})

def reference_document_navigate(args):
    a=dict(args);delta=int(a.pop('delta',1))
    if a.get('section') is not None:
        a['section']=max(1,int(a['section'])+delta);a.pop('page',None)
    else:a['page']=max(1,int(a.get('page') or 1)+delta)
    return reference_document_read(a)

def _stage_excluded(rel):
    parts=Path(rel).parts
    if any(x in ('.git','.hg','.svn','__pycache__','.pytest_cache','.mypy_cache') for x in parts): return 'generated-or-vcs'
    name=Path(rel).name
    if name.endswith(('.pyc','.pyo','.swp','~')) or name in ('.DS_Store','Thumbs.db'): return 'generated'
    return None

def package_stage_check(args):
    root=Path(str(args.get('path','')))
    if not root.exists() or not root.is_dir(): return env('OK','NOT_FOUND',{'path':str(root)})
    package_version=str(args.get('version') or '').strip()
    breaches=[]; files=[]; excluded=[]; tests=[]
    for q in sorted(root.rglob('*')):
        rel=q.relative_to(root).as_posix()
        reason=_stage_excluded(rel)
        if reason:
            excluded.append({'path':rel,'reason':reason})
            continue
        if q.is_file():
            files.append(rel)
            if rel.startswith('tests/') and (q.name.startswith('run') or q.suffix in ('.py','.rex','.sh')):
                tests.append(rel)
    # VCS/generated material is a breach only if already present in an explicit staging tree.
    for q in sorted(root.rglob('*')):
        rel=q.relative_to(root).as_posix()
        reason=_stage_excluded(rel)
        if reason:
            breaches.append({'rule':'PACKAGE.CONTENT.EXCLUDED','status':'BREACHED','severity':'BLOCKER',
                'where':{'path':rel},'caused_by':'generated/cache/VCS material is present in the candidate staging tree',
                'correct':'> CORRECT: exclude this path from the staged package','fix':{'class':'AUTOMATIC'}})
    # Dependencies at package root are forbidden unless explicitly requested.
    dep_names=('dependencies','dependency','vendor','venv','.venv','node_modules')
    for q in root.iterdir():
        if q.name.lower() in dep_names:
            breaches.append({'rule':'PACKAGE.DEPENDENCY.ROOT','status':'BREACHED','severity':'BLOCKER',
                'where':{'path':q.name},'caused_by':'dependency material is present at the primary package root',
                'correct':'> CORRECT: keep dependencies external unless the package manifest explicitly requests embedding',
                'fix':{'class':'MANUAL'}})
    changelog=next((x for x in ('CHANGELOG.md','CHANGELOG','CHANGES.md') if (root/x).is_file()),None)
    if not changelog:
        breaches.append({'rule':'PACKAGE.CHANGELOG.REQUIRED','status':'BREACHED','severity':'BLOCKER',
            'where':{'path':str(root)},'caused_by':'no changelog is present',
            'correct':'> CORRECT: add/update CHANGELOG.md before sealing','fix':{'class':'SUGGESTED'}})
    elif package_version and package_version not in (root/changelog).read_text(errors='replace'):
        breaches.append({'rule':'PACKAGE.CHANGELOG.VERSION','status':'BREACHED','severity':'BLOCKER',
            'where':{'path':changelog},'caused_by':'changelog has no entry for '+package_version,
            'correct':'> CORRECT: add a '+package_version+' changelog entry before sealing','fix':{'class':'SUGGESTED'}})
    if not tests:
        breaches.append({'rule':'PACKAGE.TEST.REQUIRED','status':'BREACHED','severity':'BLOCKER',
            'where':{'path':'tests/'},'caused_by':'no executable/discoverable test was found',
            'correct':'> CORRECT: provide at least one package test before sealing','fix':{'class':'MANUAL'}})
    envs={}
    env_re=re.compile(r'\b(?:os\.environ\.get|os\.getenv)\(\s*[\'"]([A-Z][A-Z0-9_]*)[\'"]|(?:\$\{|^\s*)([A-Z][A-Z0-9_]*)')
    for rel in tests:
        try: txt=(root/rel).read_text(errors='replace')
        except: continue
        names=set()
        for m in env_re.finditer(txt):
            names.add(next(x for x in m.groups() if x))
        for name in re.findall(r'\$\{([A-Z][A-Z0-9_]*)',txt): names.add(name)
        for name in re.findall(r'\b([A-Z][A-Z0-9_]*)=\$\{',txt): names.add(name)
        # Variables assigned by the test itself are local harness state, not external environment inputs.
        assigned=set(re.findall(r'(?m)(?:^|[;&]\s*)([A-Z][A-Z0-9_]*)=',txt))
        self_default=set(re.findall(r'(?m)([A-Z][A-Z0-9_]*)=.?\$\{\1[:-]',txt))
        for name in (names-assigned)|self_default: envs.setdefault(name,[]).append(rel)
    blockers=sum(1 for b in breaches if b['severity']=='BLOCKER')
    return env('OK','BREACHED' if breaches else 'READY',{
        'path':str(root),'version':package_version or None,'files_considered':len(files),
        'tests':tests,'test_count':len(tests),
        'environment':[{'name':k,'referenced_by':sorted(v)} for k,v in sorted(envs.items())],
        'breaches':breaches,'breach_count':len(breaches),'blockers':blockers,
        'excluded_candidates':excluded,
        'rules_checked':['PACKAGE.CONTENT.EXCLUDED','PACKAGE.DEPENDENCY.ROOT','PACKAGE.CHANGELOG.REQUIRED',
                         'PACKAGE.CHANGELOG.VERSION','PACKAGE.TEST.REQUIRED']})

def package_stage_create(args):
    src=Path(str(args.get('path',''))); out=Path(str(args.get('stage','')))
    if not src.is_dir(): return env('OK','NOT_FOUND',{'path':str(src)})
    if not str(out): return env('OK','INVALID_ARGUMENT',{'missing':['stage']})
    if out.exists(): shutil.rmtree(out)
    out.mkdir(parents=True)
    copied=[]; excluded=[]
    for q in sorted(src.rglob('*')):
        rel=q.relative_to(src)
        reason=_stage_excluded(rel.as_posix())
        if reason:
            excluded.append({'path':rel.as_posix(),'reason':reason}); continue
        if q.is_dir(): continue
        # never carry old delivery ZIPs into a new stage
        if q.suffix.lower()=='.zip' and q.parent==src:
            excluded.append({'path':rel.as_posix(),'reason':'prior-artifact'}); continue
        target=out/rel; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(q,target); copied.append(rel.as_posix())
    digest=hashlib.sha256('\n'.join(copied).encode()).hexdigest()
    return env('OK','STAGED',{'source':str(src),'stage':str(out),'files':len(copied),'excluded':excluded,'manifest_digest':digest})

def capability_schema(capability):
    s=CAPABILITY_SCHEMAS.get(capability)
    if not s:return None
    return {'kind':'capability-schema','id':capability,**s}

def _bool_value(v):
    if isinstance(v,bool):return v
    x=str(v).strip().lower()
    if x in ('1','true','yes','on'):return True
    if x in ('0','false','no','off'):return False
    raise ValueError('expected boolean')

def validate_capability_args(capability,args):
    schema=CAPABILITY_SCHEMAS.get(capability)
    if not schema:return None
    params=schema.get('parameters',{}); missing=[]; invalid=[]; normalized=dict(args)
    for name,spec in params.items():
        if spec.get('required') and (name not in args or args.get(name) in (None,'')):missing.append(name)
    for group in schema.get('one_of',[]):
        if not any(args.get(n) not in (None,'') for n in group):
            invalid.append({'fields':group,'reason':'one_of_required'})
    for name,val in list(args.items()):
        spec=params.get(name)
        if spec is None:
            invalid.append({'field':name,'reason':'unknown_argument'});continue
        if val in (None,'') and not spec.get('required'):
            normalized.pop(name,None)
            continue
        try:
            typ=spec.get('type','string')
            if typ=='integer':v=int(val)
            elif typ=='boolean':v=_bool_value(val)
            else:v=str(val)
            if 'enum' in spec and v not in spec['enum']:raise ValueError('expected one of '+','.join(spec['enum']))
            if 'minimum' in spec and v<spec['minimum']:raise ValueError('below minimum')
            if 'maximum' in spec and v>spec['maximum']:raise ValueError('above maximum')
            normalized[name]=v
        except Exception as e:invalid.append({'field':name,'value':val,'reason':str(e)})
    if missing or invalid:
        return env('OK','INVALID_ARGUMENT',{'capability':capability,'missing':missing,'invalid':invalid,'schema':capability_schema(capability)})
    for name,spec in params.items():
        if name not in normalized and 'default' in spec:normalized[name]=spec['default']
    return normalized

# Aglets-inspired service layer: callers request capabilities; Finder returns an
# authorised ServiceProxy. Implementations remain private to the engine.
IMPLEMENTATIONS={
    'builtin.executable.locate':tool_locate,
    'builtin.crypto.sha256':tool_sha256,
    'builtin.archive.zip.list.python':zip_py_list,
    'builtin.archive.zip.list.unzip':zip_unzip_list,
    'builtin.archive.zip.find':zip_find,
    'builtin.archive.zip.examine':zip_examine,
    'builtin.archive.zip.member.find':zip_member_find,
    'builtin.archive.zip.member.read':zip_member_read,
    'builtin.archive.zip.text.search':zip_text_search,
    'builtin.source.oorexx.examine':rex_methods,
    'builtin.source.python.examine':python_examine,
    'builtin.source.java.examine':java_examine,
    'builtin.source.java.compile':java_compile,
    'builtin.source.cpp.examine':cpp_methods,
    'builtin.manual.man.subset':man_subset,
    'builtin.source.oorexx.method.edit':source_oorexx_method_edit,
    'builtin.source.python.method.edit':source_python_method_edit,
    'builtin.language.rules.evaluate':language_rules_evaluate,
    'builtin.source.symbol.lookup':lambda args: source_symbol_lookup(None,args),
    'builtin.dogfood.escape.record':dogfood_escape_record,
    'builtin.test.impact.discover':test_impact_discover,
    'builtin.sphere.editor.import.legacy':sphere_editor_import_legacy,
    'builtin.sphere.editor.template':sphere_editor_template,
    'builtin.sphere.editor.corpus.record.put':sphere_editor_corpus_record_put,
    'builtin.sphere.editor.changelog.add':sphere_editor_changelog_add,
    'builtin.sphere.editor.create':sphere_editor_create,
    'builtin.sphere.editor.put':sphere_editor_put,
    'builtin.sphere.editor.evidence.attach':sphere_editor_evidence_attach,
    'builtin.sphere.editor.validate':sphere_editor_validate,
    'builtin.sphere.editor.lint':sphere_editor_lint,
    'builtin.sphere.editor.package':sphere_editor_package,
    'builtin.reference.document.locate':reference_document_locate,
    'builtin.reference.document.page.read':reference_document_read,
    'builtin.reference.document.find':reference_document_find,
    'builtin.reference.document.navigate':reference_document_navigate,
    'builtin.workspace.inspect':workspace_inspect,
    'builtin.workspace.archive.preflight':workspace_archive_preflight,
    'builtin.workspace.materialization.check':workspace_materialization_check,
    'builtin.workspace.handover.frame':workspace_handover_frame,
    'builtin.workspace.context.recoverability':workspace_context_recoverability,
    'builtin.package.stage.check':package_stage_check,
    'builtin.package.stage.create':package_stage_create,
}


def inherited_service_spheres(idx, sphere):
    # Explicit, destination-controlled service inheritance. This is not pack-global
    # leakage: only spheres named by the destination sphere are admissible.
    if not sphere:return set()
    seen=set(); todo=[sphere]
    while todo:
        sid=todo.pop(0)
        if sid in seen:continue
        seen.add(sid)
        sp=idx.get(('sphere',sid))
        if not sp:continue
        for parent in sp.get('inherits_services_from',[]):
            if parent not in seen:todo.append(parent)
    return seen

def service_allowed(idx, sphere, role, service, capability):
    sp=idx.get(('sphere',sphere)) if sphere else None
    policy=find_policy(idx,sp) if sp else None
    scopes=service.get('spheres',[])
    inherited=inherited_service_spheres(idx,sphere)
    if scopes and '*' not in scopes and not any(scope in inherited for scope in scopes):return False
    # Authorization is always evaluated in the destination sphere. Inheritance
    # changes service visibility; it never carries source-sphere authority.
    if policy and not allowed(policy,role,'exec','capability:'+capability):return False
    if policy and not allowed(policy,role,'exec','service:'+service['id']):return False
    return True

def find_services(idx, capability, role='llm', sphere=None):
    out=[]
    for (kind,_),svc in idx.items():
        if kind!='service' or capability not in svc.get('capabilities',[]):continue
        if not service_allowed(idx,sphere,role,svc,capability):continue
        out.append(svc)
    out.sort(key=lambda x:(int(x.get('rank',1000)),x['id']))
    return out

def service_proxy(svc, capability):
    return {'kind':'service-proxy','service':svc['id'],'capability':capability,
            'operations':svc.get('operations',['exec']),'rank':svc.get('rank',1000)}

def finder(idx, capability, role='llm', sphere=None):
    svcs=find_services(idx,capability,role,sphere)
    return env('OK','FOUND' if svcs else 'NOT_FOUND',
               {'capability':capability,'sphere':sphere,'proxies':[service_proxy(s,capability) for s in svcs]})

def invoke_via_finder(idx, capability, args, role='llm', sphere=None):
    checked=validate_capability_args(capability,args)
    if isinstance(checked,dict) and checked.get('operation_status',{}).get('class')=='INVALID_ARGUMENT':return checked
    if checked is not None:args=checked
    svcs=find_services(idx,capability,role,sphere); attempts=[]
    if not svcs:return env('OK','NOT_FOUND',{'capability':capability,'sphere':sphere,'reason':'no authorised service'})
    last=None
    for depth,svc in enumerate(svcs):
        impl=svc.get('implementation')
        f=IMPLEMENTATIONS.get(impl)
        cf=CONTEXTUAL_IMPLEMENTATIONS.get(impl)
        if f is None and cf is None:
            r=env('UNAVAILABLE','UNKNOWN',None,diagnostics=['implementation not installed: '+str(impl)])
        elif cf is not None:
            r=cf(idx,args,role,sphere)
        else:
            r=f(args)
        attempts.append({'service':svc['id'],'implementation':impl,'tool_status':r['tool_status']['class']})
        last=r
        if r['tool_status']['class']=='OK' or r['tool_status']['class'] not in ('UNAVAILABLE','TEMPORARY_FAILURE','DEPENDENCY_FAILURE'):
            r['service_proxy']=service_proxy(svc,capability)
            r['route']={'requested_capability':capability,'service':svc['id'],'implementation':impl,
                        'fallback_depth':depth,'attempts':attempts}
            return r
    last['route']={'requested_capability':capability,'service':None,'implementation':None,
                   'fallback_depth':len(svcs),'attempts':attempts}
    return last

def corpus_search(idx,args,role='llm',sphere=None):
    query=(args.get('query') or '').strip().lower()
    if not query:return env('INVALID_REQUEST','UNKNOWN',None)
    requested=args.get('corpus')
    hits=[]
    for (kind,cid),c in idx.items():
        if kind!='corpus' or (requested and cid!=requested):continue
        if sphere and c.get('sphere') not in (None,sphere):continue
        sp=idx.get(('sphere',c.get('sphere'))) if c.get('sphere') else None
        if sp and not allowed(find_policy(idx,sp),role,'read','corpus:'+cid):continue
        for n,rec in enumerate(c.get('records',[])):
            hay=canonical(rec).lower()
            if query in hay:
                hits.append({'corpus':cid,'record':n,'data':rec})
    return env('OK','FOUND' if hits else 'NOT_FOUND',{'query':query,'hits':hits,'count':len(hits)})

def _field_value(record, field):
    cur=record
    for part in str(field).split('.'):
        if not isinstance(cur,dict) or part not in cur:return None
        cur=cur[part]
    return cur

def _exact_value_match(actual, expected):
    if isinstance(actual,list):
        return any(_exact_value_match(x,expected) for x in actual)
    if isinstance(actual,bool):
        return str(actual).lower()==str(expected).lower()
    if actual is None:return False
    return str(actual).casefold()==str(expected).casefold()

def corpus_record_lookup(idx,args,role='llm',sphere=None):
    field=str(args.get('field') or '').strip()
    value=str(args.get('value') or '').strip()
    requested=args.get('corpus')
    fallback=bool(args.get('fallback',True))
    max_matches=int(args.get('max_matches',50))
    if not field or not value:
        return env('OK','INVALID_ARGUMENT',{'missing':[x for x,v in [('field',field),('value',value)] if not v]})
    exact=[]; fallback_hits=[]
    for (kind,cid),c in idx.items():
        if kind!='corpus' or (requested and cid!=requested):continue
        if sphere and c.get('sphere') not in (None,sphere):continue
        sp=idx.get(('sphere',c.get('sphere'))) if c.get('sphere') else None
        if sp and not allowed(find_policy(idx,sp),role,'read','corpus:'+cid):continue
        for n,rec in enumerate(c.get('records',[])):
            actual=_field_value(rec,field)
            if _exact_value_match(actual,value):
                exact.append({'corpus':cid,'record':n,'field':field,'value':actual,'match_kind':'EXACT_FIELD','data':rec})
                if len(exact)>=max_matches:break
        if len(exact)>=max_matches:break
    if exact:
        return env('OK','FOUND',{'field':field,'value':value,'match_kind':'EXACT_FIELD','hits':exact,'count':len(exact),'fallback_used':False})
    if fallback:
        needle=value.casefold()
        for (kind,cid),c in idx.items():
            if kind!='corpus' or (requested and cid!=requested):continue
            if sphere and c.get('sphere') not in (None,sphere):continue
            sp=idx.get(('sphere',c.get('sphere'))) if c.get('sphere') else None
            if sp and not allowed(find_policy(idx,sp),role,'read','corpus:'+cid):continue
            for n,rec in enumerate(c.get('records',[])):
                if needle in canonical(rec).casefold():
                    fallback_hits.append({'corpus':cid,'record':n,'field':field,'value':_field_value(rec,field),'match_kind':'TEXT_FALLBACK','data':rec})
                    if len(fallback_hits)>=max_matches:break
            if len(fallback_hits)>=max_matches:break
    return env('OK','FOUND' if fallback_hits else 'NOT_FOUND',
               {'field':field,'value':value,'match_kind':'TEXT_FALLBACK' if fallback_hits else 'NONE',
                'hits':fallback_hits,'count':len(fallback_hits),'fallback_used':bool(fallback_hits)})


CONTEXTUAL_IMPLEMENTATIONS={
    'builtin.corpus.record.lookup':corpus_record_lookup,
}

def describe_capability(idx,capability,role='llm',sphere=None):
    schema=capability_schema(capability)
    if not schema:return env('OK','NOT_FOUND',{'capability':capability})
    svcs=find_services(idx,capability,role,sphere)
    result=dict(schema)
    result['available']=bool(svcs)
    result['services']=[service_proxy(s,capability) for s in svcs]
    result['invocation']={'low_level':'gopher exec '+capability+' key=value ...'}
    return env('OK','OPENED',result)

def context_view(idx,sphere,role,full=False):
    sp=idx.get(('sphere',sphere))
    if not sp:return env('OK','NOT_FOUND',{'sphere':sphere})
    if not allowed(find_policy(idx,sp),role,'read','sphere:'+sphere):return env('OK','DENIED',{'sphere':sphere})
    arts=[]
    for (k,i),a in idx.items():
        if k=='article' and a.get('sphere')==sphere and allowed(find_policy(idx,sp),role,'read','article:'+i):
            arts.append({'id':i,'title':a.get('title'),'section':a.get('section'),'topics':a.get('topics',[])})
    caps=[]
    capids=sorted({cap for (k,_),svc in idx.items() if k=='service' for cap in svc.get('capabilities',[])})
    for cap in capids:
        ps=find_services(idx,cap,role,sphere)
        if not ps:continue
        sch=CAPABILITY_SCHEMAS.get(cap,{})
        required=[n for n,v in sch.get('parameters',{}).items() if v.get('required')]
        item={'id':cap,'summary':sch.get('summary'),'required':required,'supports':sch.get('supports',[]),'describe':'gopher describe '+cap+' --sphere '+sphere}
        if full:item['services']=[service_proxy(x,cap) for x in ps];item['parameters']=sch.get('parameters',{});item['examples']=sch.get('examples',[])
        caps.append(item)
    corp=[]
    for (k,cid),c in idx.items():
        if k=='corpus' and c.get('sphere') in (None,sphere) and allowed(find_policy(idx,sp),role,'read','corpus:'+cid):
            corp.append({'id':cid,'title':c.get('title'),'records':len(c.get('records',[]))})
    arts_sorted=sorted(arts,key=lambda x:((x.get('section') or ''),x['id']))
    sections={}
    for a in arts_sorted:
        sec=a.get('section') or 'unsectioned'
        sections.setdefault(sec,[]).append({'id':a['id'],'title':a.get('title'),'topics':a.get('topics',[])})
    return env('OK','OPENED',{'kind':'context','sphere':sphere,'role':role,'articles':arts_sorted,'sections':sections,
                              'capabilities':caps,'corpora':sorted(corp,key=lambda x:x['id']),
                              'language_modules':[language_module_describe(idx,lid).get('result') for lid in sp.get('language_modules',[]) if language_module_describe(idx,lid).get('operation_status',{}).get('class')=='OPENED'],
                              'inherits_services_from':sorted(inherited_service_spheres(idx,sphere)-{sphere}),
                              'hints':['Use describe <capability> for the full schema.','Use examine source for composite source examination.']})

TOOLS={'executable.locate':tool_locate,'crypto.sha256':tool_sha256,'archive.zip.list.python':zip_py_list,
       'archive.zip.list.unzip':zip_unzip_list,'archive.zip.find':zip_find,
       'archive.zip.examine':zip_examine,'archive.zip.member.find':zip_member_find,'archive.zip.member.read':zip_member_read,'archive.zip.text.search':zip_text_search,'source.oorexx.examine':rex_methods,
       'source.cpp.examine':cpp_methods,'manual.man.subset':man_subset}
CAPS={'archive.zip.list':['archive.zip.list.unzip','archive.zip.list.python']}

def invoke_tool(name,args):
    f=TOOLS.get(name)
    if not f:return env('UNAVAILABLE','UNKNOWN',None,diagnostics=['tool not installed: '+name])
    r=f(args); r['tool']={'id':name}; return r

def invoke_capability(cap,args):
    routes=CAPS.get(cap,[cap]); attempts=[]
    for depth,name in enumerate(routes):
        r=invoke_tool(name,args); attempts.append({'tool':name,'tool_status':r['tool_status']['class']})
        if r['tool_status']['class']=='OK':
            r['route']={'requested_capability':cap,'implementation':name,'fallback_depth':depth,'attempts':attempts};return r
        if r['tool_status']['class'] not in ('UNAVAILABLE','TEMPORARY_FAILURE','DEPENDENCY_FAILURE'):
            r['route']={'requested_capability':cap,'implementation':name,'fallback_depth':depth,'attempts':attempts};return r
    r['route']={'requested_capability':cap,'implementation':None,'fallback_depth':len(routes),'attempts':attempts};return r


def page_rexx_class(idx, article, bindings, role):
    path=bindings.get('path')
    if not path:return env('INVALID_REQUEST','UNKNOWN',None)
    r=invoke_via_finder(idx,'source.oorexx.examine',{k:v for k,v in {'path':path,'nested':bindings.get('nested'),'member':bindings.get('member')}.items() if v},role,article.get('sphere'))
    if r['tool_status']['class']!='OK' or r['operation_status']['class']!='OK':return r
    x=r['result']
    return env('OK','OPENED',{'page_type':'RexxClassPage','title':article.get('title'),
        'object':{k:v for k,v in {'path':path,'nested':bindings.get('nested'),'member':bindings.get('member')}.items() if v},'sections':{'classes':x.get('classes',[]),'attributes':x.get('attributes',[]),'methods':x.get('methods',[])},
        'selectors':open_article(idx,article['id'],role)['result'].get('selectors',[])}, evidence={'examiner_route':r.get('route'),'source_path':path})

def page_cpp_class(idx, article, bindings, role):
    path=bindings.get('path')
    if not path:return env('INVALID_REQUEST','UNKNOWN',None)
    r=invoke_via_finder(idx,'source.cpp.examine',{k:v for k,v in {'path':path,'nested':bindings.get('nested'),'member':bindings.get('member')}.items() if v},role,article.get('sphere'))
    if r['tool_status']['class']!='OK' or r['operation_status']['class']!='OK':return r
    x=r['result']
    return env('OK','OPENED',{'page_type':'CppClassPage','title':article.get('title'),'object':{k:v for k,v in {'path':path,'nested':bindings.get('nested'),'member':bindings.get('member')}.items() if v},
        'sections':{'classes':x.get('classes',[]),'functions':x.get('functions',[])},
        'selectors':open_article(idx,article['id'],role)['result'].get('selectors',[])}, evidence={'examiner_route':r.get('route'),'source_path':path})

def page_man(idx, article, bindings, role):
    args={'name':bindings.get('name'),'section':bindings.get('section'),'contains':bindings.get('contains')}
    r=invoke_via_finder(idx,'manual.man.subset',{k:v for k,v in args.items() if v},role,article.get('sphere'))
    if r['tool_status']['class']!='OK' or r['operation_status']['class'] not in ('FOUND','OK'):return r
    return env('OK','OPENED',{'page_type':'ManPage','title':article.get('title'),'object':{'name':args.get('name')},
        'sections':{'manual_excerpt':r['result'].get('lines',[])},'selectors':open_article(idx,article['id'],role)['result'].get('selectors',[])}, evidence={'route':r.get('route')})

def page_archive(idx, article, bindings, role):
    path=bindings.get('path')
    if not path:return env('INVALID_REQUEST','UNKNOWN',None)
    args={k:v for k,v in {'path':path,'nested':bindings.get('nested'),'prefix':bindings.get('prefix')}.items() if v}
    r=invoke_via_finder(idx,'archive.zip.examine',args,role,article.get('sphere'))
    if r['tool_status']['class']!='OK' or r['operation_status']['class']!='EXAMINED':return r
    x=r['result']
    return env('OK','OPENED',{'page_type':'ArchivePage','title':article.get('title'),
        'object':{k:v for k,v in {'path':path,'nested':bindings.get('nested')}.items() if v},
        'sections':{'summary':{'count':x.get('count',0),'kinds':x.get('kinds',{})},'entries':x.get('entries',[])},
        'selectors':open_article(idx,article['id'],role)['result'].get('selectors',[])}, evidence={'examiner_route':r.get('route')})

PAGE_HANDLERS={'RexxClassPage':page_rexx_class,'CppClassPage':page_cpp_class,'ManPage':page_man,'ArchivePage':page_archive}

def render_page(idx, article_id, bindings, role='llm'):
    a=idx.get(('article',article_id))
    if not a:return env('OK','NOT_FOUND',{'article':article_id})
    opened=open_article(idx,article_id,role)
    if opened['operation_status']['class']!='OPENED':return opened
    h=a.get('handler','ArticlePage')
    if h=='ArticlePage':return opened
    f=PAGE_HANDLERS.get(h)
    if not f:return env('UNAVAILABLE','UNKNOWN',None,diagnostics=['page handler not installed: '+h])
    return f(idx,a,bindings,role)

def new_page_instance(idx, article_id, bindings, role='llm'):
    page=render_page(idx,article_id,bindings,role)
    if page['tool_status']['class']!='OK' or page['operation_status']['class']!='OPENED':return page
    a=idx.get(('article',article_id)); steps=[]
    for st in a.get('checklist',[]):
        steps.append({'id':st['id'],'label':st.get('label',st['id']),'complete':False,'evidence':None,'selector':st.get('selector'),
                      'success':st.get('success',['OK'])})
    inst={'kind':'page-instance','article':article_id,'article_digest':digest(a),'bindings':bindings,'role':role,'steps':steps,'page':page['result']}
    inst['instance_digest']=digest(inst)
    return env('OK','OPENED',inst)

def run_page_step(idx, instance, step_id, role='llm'):
    steps=instance.get('steps',[]); step=next((x for x in steps if x.get('id')==step_id),None)
    if not step:return env('OK','NOT_FOUND',{'step':step_id})
    a=idx.get(('article',instance.get('article'))); sels={s.get('id'):s for s in a.get('selectors',[])} if a else {}
    sel=sels.get(step.get('selector'))
    if not sel:return env('IMPLEMENTATION_FAILURE','UNKNOWN',None,diagnostics=['checklist selector missing'])
    args=dict(instance.get('bindings',{})); cap=sel.get('capability')
    r=invoke_via_finder(idx,cap,args,role,a.get('sphere'))
    op=r['operation_status']['class']
    if r['tool_status']['class']=='OK' and op in step.get('success',['OK']):
        step['complete']=True; step['evidence']={'capability':cap,'operation_status':op,'result_digest':digest(r.get('result')),'route':r.get('route')}
    instance['instance_digest']=digest({k:v for k,v in instance.items() if k!='instance_digest'})
    return env(r['tool_status']['class'],op,{'instance':instance,'step':step_id,'execution_result':r})


def _source_member_priority(name):
    parts=[p.casefold() for p in Path(name).parts[:-1]]
    if 'src' in parts:return (0,len(parts),name.casefold())
    if 'source' in parts:return (1,len(parts),name.casefold())
    if 'rexx' in parts:return (2,len(parts),name.casefold())
    return (3,len(parts),name.casefold())


def language_module_resolve(idx, source):
    ext=Path(str(source)).suffix.lower()
    matches=[]
    for (kind,lid),mod in idx.items():
        if kind!='language-module':continue
        if ext in [str(x).lower() for x in mod.get('extensions',[])]:
            item=dict(mod); item.pop('_provenance',None); matches.append(item)
    if not matches:return env('OK','NOT_FOUND',{'source':str(source),'extension':ext})
    if len(matches)>1:return env('OK','AMBIGUOUS',{'source':str(source),'extension':ext,'languages':[x['id'] for x in matches]})
    return env('OK','FOUND',{'source':str(source),'extension':ext,'module':matches[0]})

def language_module_describe(idx, language):
    mod=idx.get(('language-module',language))
    if not mod:return env('OK','NOT_FOUND',{'language':language})
    out=dict(mod);out.pop('_provenance',None)
    return env('OK','OPENED',out)

def source_symbol_lookup(idx,args,role='llm',sphere=None):
    path=str(args.get('path') or '')
    member=args.get('member')
    nested=args.get('nested')
    symbol=str(args.get('symbol') or '').strip()
    language=str(args.get('language') or 'auto').lower()
    fallback=bool(args.get('fallback',False))
    if not path or not symbol:
        return env('OK','INVALID_ARGUMENT',{'missing':[k for k,v in [('path',path),('symbol',symbol)] if not v]})
    read_args={'path':path}
    if member:read_args['member']=member
    if nested:read_args['nested']=nested
    txt,identity,err=_read_text_object(read_args)
    if err:return err
    if language=='auto':
        ext=Path(member or path).suffix.lower()
        language='oorexx' if ext in ('.cls','.rex','.rxj') else ('python' if ext=='.py' else ('java' if ext=='.java' else ('cpp' if ext in ('.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx') else 'text')))
    lines=txt.splitlines()
    exact=[]
    if language=='oorexx':
        patterns=[
            ('class',re.compile(r'^\s*::class\s+'+re.escape(symbol)+r'(?=\s|$)',re.I)),
            ('method',re.compile(r'^\s*::method\s+'+re.escape(symbol)+r'(?=\s|$)',re.I)),
            ('routine',re.compile(r'^\s*::routine\s+'+re.escape(symbol)+r'(?=\s|$)',re.I)),
            ('attribute',re.compile(r'^\s*::attribute\s+'+re.escape(symbol)+r'(?=\s|$)',re.I)),
        ]
        exact=[]
        for n,line in enumerate(lines,1):
            for kind,rx in patterns:
                if rx.search(line):
                    exact.append({'line':n,'text':line[:1000],'declaration':kind})
    elif language=='python':
        patterns=[
            ('class',re.compile(r'^\s*class\s+'+re.escape(symbol)+r'(?=\s*[:(])')),
            ('function',re.compile(r'^\s*(?:async\s+)?def\s+'+re.escape(symbol)+r'(?=\s*\()')),
        ]
        exact=[]
        for n,line in enumerate(lines,1):
            for kind,rx in patterns:
                if rx.search(line): exact.append({'line':n,'text':line[:1000],'declaration':kind})
    elif language=='java':
        type_rx=re.compile(r'^\s*(?:(?:public|protected|private|abstract|final|static|sealed|non-sealed|strictfp)\s+)*(class|interface|enum|record)\s+'+re.escape(symbol)+r'(?=\s|[:<{])')
        declared_types=set()
        any_type_rx=re.compile(r'^\s*(?:(?:public|protected|private|abstract|final|static|sealed|non-sealed|strictfp)\s+)*(?:class|interface|enum|record)\s+([A-Za-z_$][\w$]*)')
        for line in lines:
            mt=any_type_rx.search(line)
            if mt: declared_types.add(mt.group(1))
        # Methods require an explicit return type. Constructor form is accepted
        # only when the symbol is also a declared type in this source.
        method_rx=re.compile(
            r'^\s*(?:(?:public|protected|private|static|final|synchronized|abstract|native|strictfp|default)\s+)*'
            r'[A-Za-z_$][\w$<>,.?\[\] @]*\s+'+re.escape(symbol)+
            r'\s*\([^;{}]*\)\s*(?:throws\s+[^;{]+\s*)?[{;]'
        )
        ctor_rx=re.compile(
            r'^\s*(?:(?:public|protected|private)\s+)*'+re.escape(symbol)+
            r'\s*\([^;{}]*\)\s*(?:throws\s+[^;{]+\s*)?\{'
        ) if symbol in declared_types else None
        type_hits=[]
        member_hits=[]
        for n,line in enumerate(lines,1):
            mt=type_rx.search(line)
            if mt:
                type_hits.append({'line':n,'text':line[:1000],'declaration':mt.group(1)})
            elif method_rx.search(line):
                member_hits.append({'line':n,'text':line[:1000],'declaration':'method'})
            elif ctor_rx is not None and ctor_rx.search(line):
                member_hits.append({'line':n,'text':line[:1000],'declaration':'constructor'})
        exact=type_hits if type_hits else member_hits
    elif language=='cpp':
        rx=re.compile(r'^\s*(?:class|struct)\s+'+re.escape(symbol)+r'(?=\s|[:{;])')
        exact=[{'line':n,'text':line[:1000],'declaration':'class'} for n,line in enumerate(lines,1) if rx.search(line)]
    if len(exact)>1:
        return env('OK','AMBIGUOUS',{'source':identity,'symbol':symbol,'language':language,
                                     'match_kind':'EXACT_DECLARATION','candidates':exact})
    if len(exact)==1:
        return env('OK','FOUND',{'source':identity,'symbol':symbol,'language':language,
                                 'match_kind':'EXACT_DECLARATION','fallback_used':False,'hits':exact,'count':1})
    if not fallback:
        return env('OK','NOT_FOUND',{'source':identity,'symbol':symbol,'language':language,
                                     'match_kind':'NONE','fallback_used':False,'hits':[],'count':0})
    needle=symbol.casefold()
    hits=[{'line':n,'text':line[:1000]} for n,line in enumerate(lines,1) if needle in line.casefold()]
    return env('OK','FOUND' if hits else 'NOT_FOUND',
               {'source':identity,'symbol':symbol,'language':language,
                'match_kind':'TEXT_FALLBACK' if hits else 'NONE','fallback_used':bool(hits),
                'hits':hits[:20],'count':len(hits),'truncated':len(hits)>20})

def _archive_find_source(path, source_name, nested=None, max_nested=256):
    """Return an exact source member and nested chain without extracting."""
    def matches(z):
        exact=[n for n in z.namelist() if not n.endswith('/') and Path(n).name==source_name]
        if exact:
            ranked=sorted(exact,key=_source_member_priority)
            best=_source_member_priority(ranked[0])[0]
            preferred=[n for n in ranked if _source_member_priority(n)[0]==best]
            return preferred
        suffix=[n for n in z.namelist() if not n.endswith('/') and fnmatch.fnmatch(n,'*'+source_name)]
        if suffix:
            ranked=sorted(suffix,key=_source_member_priority)
            best=_source_member_priority(ranked[0])[0]
            return [n for n in ranked if _source_member_priority(n)[0]==best]
        return []
    if nested:
        z,opened,err=_open_zip_chain(path,nested)
        if err:return None,None,err
        try:ms=matches(z)
        finally:_close_zips(opened)
        if not ms:return None,None,env('OK','NOT_FOUND',{'source':source_name,'path':path,'nested':nested})
        if len(ms)>1:return None,None,env('OK','AMBIGUOUS',{'source':source_name,'matches':ms,'nested':nested})
        return nested,ms[0],None
    z,opened,err=_open_zip_chain(path,None)
    if err:return None,None,err
    try:
        ms=matches(z)
        if len(ms)==1:return None,ms[0],None
        if len(ms)>1:return None,None,env('OK','AMBIGUOUS',{'source':source_name,'matches':ms})
        nested_names=[i.filename for i in z.infolist() if not i.is_dir() and _kind_for_name(i.filename)=='archive'][:max_nested]
        found=[]
        for nzname in nested_names:
            info=z.getinfo(nzname)
            if info.file_size>MAX_ARCHIVE_MEMBER_BYTES:continue
            try:nz=zipfile.ZipFile(io.BytesIO(z.read(nzname)))
            except zipfile.BadZipFile:continue
            try:
                for m in matches(nz):found.append((nzname,m))
            finally:nz.close()
            if len(found)>1:break
        if not found:return None,None,env('OK','NOT_FOUND',{'source':source_name,'path':path,'nested_archives_examined':len(nested_names)})
        if len(found)>1:return None,None,env('OK','AMBIGUOUS',{'source':source_name,'matches':[{'nested':a,'member':b} for a,b in found]})
        return found[0][0],found[0][1],None
    finally:_close_zips(opened)

def examine_source(idx, source_name, location, nested=None, symbol=None, role='llm', sphere=None, excerpt_lines=5, symbol_fallback=False):
    if not source_name:return env('OK','INVALID_ARGUMENT',{'missing':['source']})
    if not location:return env('OK','INVALID_ARGUMENT',{'missing':['in']})
    p=Path(location)
    member=None; resolved_nested=nested
    if p.is_file() and zipfile.is_zipfile(p):
        resolved_nested,member,err=_archive_find_source(str(p),source_name,nested)
        if err:return err
        lm=language_module_resolve(idx,member)
        if lm['operation_status']['class']!='FOUND':
            return env('OK','UNSUPPORTED',{'source':source_name,'member':member,'kind':_kind_for_name(member)})
        module=lm['result']['module']; examine_cap=module.get('examiner_capability')
        if not examine_cap:return env('OK','UNSUPPORTED',{'source':source_name,'member':member,'language':module.get('id'),'reason':'no examiner capability'})
        effective_sphere=sphere or module.get('default_sphere') or 'oorexx'
        ex_args={'path':str(p),'member':member}
        if resolved_nested:ex_args['nested']=resolved_nested
        exam=invoke_via_finder(idx,examine_cap,ex_args,role,effective_sphere)
        if exam['tool_status']['class']!='OK' or exam['operation_status']['class']!='OK':return exam
        search=None; excerpt=None
        if symbol:
            sargs={'path':str(p),'member':member,'symbol':symbol,'language':module.get('symbol_language',module.get('id')),'fallback':False}
            if resolved_nested:sargs['nested']=resolved_nested
            search=invoke_via_finder(idx,'source.symbol.lookup',sargs,role,effective_sphere)
            if search.get('operation_status',{}).get('class')=='AMBIGUOUS':
                return search
            if search.get('operation_status',{}).get('class')!='FOUND' and symbol_fallback:
                sargs['fallback']=True
                search=invoke_via_finder(idx,'source.symbol.lookup',sargs,role,effective_sphere)
            if search.get('operation_status',{}).get('class')!='FOUND':
                return env('OK','NOT_FOUND',{'source':source_name,'location':str(p),'nested':resolved_nested,'member':member,
                    'symbol':symbol,'reason':'exact declaration not found','fallback_available':True,
                    'next': 'retry with --symbol-fallback to permit labelled text fallback'})
            first=(search.get('result') or {}).get('hits',[None])[0]
            start=max(1,int(first['line'])-2) if first else 1
        else:start=1
        rargs={'path':str(p),'member':member,'start_line':start,'max_lines':excerpt_lines}
        if resolved_nested:rargs['nested']=resolved_nested
        excerpt=invoke_via_finder(idx,'archive.zip.member.read',rargs,role,effective_sphere)
        raw=exam['result']; summary={'kind':module.get('id')}
        if module.get('id')=='oorexx':
            summary.update({'class_count':len(raw.get('classes',[])),'method_count':len(raw.get('methods',[])),'attribute_count':len(raw.get('attributes',[])),'classes':raw.get('classes',[])[:100]})
        elif module.get('id')=='java':
            summary.update({'type_count':len(raw.get('types',[])),'method_count':len(raw.get('methods',[])),'package':raw.get('package'),'types':raw.get('types',[])[:100]})
        elif module.get('id')=='python':
            summary.update({'class_count':len(raw.get('classes',[])),'function_count':len(raw.get('functions',[])),'classes':raw.get('classes',[])[:100]})
        else:
            summary.update({'class_count':len(raw.get('classes',[])),'function_count':len(raw.get('functions',[])),'classes':raw.get('classes',[])[:100]})
        return env('OK','EXAMINED',{'source':source_name,'location':str(p),'nested':resolved_nested,'member':member,'symbol':symbol,
            'summary':summary,'matches':(search or {}).get('result') if search else None,'excerpt':excerpt.get('result') if excerpt else None},
            evidence={'examine_route':exam.get('route'),'search_route':search.get('route') if search else None,'read_route':excerpt.get('route') if excerpt else None})
    # Filesystem source path: location may be a directory or the file itself.
    target=p if p.is_file() else p/source_name
    lm=language_module_resolve(idx,target.name)
    if lm['operation_status']['class']!='FOUND':return env('OK','UNSUPPORTED',{'source':source_name,'path':str(target)})
    module=lm['result']['module']; cap=module.get('examiner_capability')
    if not cap:return env('OK','UNSUPPORTED',{'source':source_name,'path':str(target),'language':module.get('id'),'reason':'no examiner capability'})
    effective_sphere=sphere or module.get('default_sphere') or 'oorexx'
    exam=invoke_via_finder(idx,cap,{'path':str(target)},role,effective_sphere)
    if exam['tool_status']['class']!='OK' or exam['operation_status']['class']!='OK':return exam
    lines=target.read_text(errors='replace').splitlines(); hits=[]; search=None
    if symbol:
        lang=module.get('symbol_language',module.get('id'))
        search=invoke_via_finder(idx,'source.symbol.lookup',{'path':str(target),'symbol':symbol,'language':lang,'fallback':False},role,effective_sphere)
        if search.get('operation_status',{}).get('class')=='AMBIGUOUS':return search
        if search.get('operation_status',{}).get('class')!='FOUND' and symbol_fallback:
            search=invoke_via_finder(idx,'source.symbol.lookup',{'path':str(target),'symbol':symbol,'language':lang,'fallback':True},role,effective_sphere)
        if search.get('operation_status',{}).get('class')!='FOUND':
            return env('OK','NOT_FOUND',{'source':source_name,'location':str(target),'member':None,
                'symbol':symbol,'reason':'exact declaration not found','fallback_available':True,
                'next':'retry with --symbol-fallback to permit labelled text fallback'})
        hits=(search.get('result') or {}).get('hits',[])
    start=max(1,hits[0]['line']-2) if hits else 1
    part=lines[start-1:start-1+excerpt_lines]
    raw=exam['result']; summary={'kind':module.get('id')}
    if module.get('id')=='oorexx':
        summary.update({'class_count':len(raw.get('classes',[])),'method_count':len(raw.get('methods',[])),'attribute_count':len(raw.get('attributes',[])),'classes':raw.get('classes',[])[:100]})
    elif module.get('id')=='java':
        summary.update({'type_count':len(raw.get('types',[])),'method_count':len(raw.get('methods',[])),'package':raw.get('package'),'types':raw.get('types',[])[:100]})
    elif module.get('id')=='python':
        summary.update({'class_count':len(raw.get('classes',[])),'function_count':len(raw.get('functions',[])),'classes':raw.get('classes',[])[:100]})
    else:
        summary.update({'class_count':len(raw.get('classes',[])),'function_count':len(raw.get('functions',[])),'classes':raw.get('classes',[])[:100]})
    return env('OK','EXAMINED',{'source':source_name,'location':str(target),'member':None,'symbol':symbol,'summary':summary,
        'matches':(search.get('result') if search else None),
        'excerpt':{'start_line':start,'returned_lines':len(part),'total_lines':len(lines),'lines':[{'line':start+i,'text':v} for i,v in enumerate(part)]}}, evidence={'examine_route':exam.get('route')})


def edit_method(idx, location, class_name, method_name, replacement, operation='REPLACE', language='auto', expected_sha256=None, role='llm', sphere='oorexx'):
    if not location or not class_name or not method_name or not replacement:
        missing=[n for n,v in [('in',location),('class',class_name),('method',method_name),('replacement',replacement)] if not v]
        return env('OK','INVALID_ARGUMENT',{'missing':missing})
    lang=language.lower()
    if lang=='auto':
        ext=Path(location).suffix.lower()
        if ext in ('.cls','.rex','.rxj'):lang='oorexx'
        elif ext=='.py':lang='python'
        else:return env('OK','UNSUPPORTED',{'path':location,'reason':'cannot infer source language','supported':['oorexx','python']})
    cap={'oorexx':'source.oorexx.method.edit','python':'source.python.method.edit'}.get(lang)
    if not cap:return env('OK','UNSUPPORTED',{'language':language,'supported':['oorexx','python']})
    args={'path':location,'class':class_name,'method':method_name,'operation':operation.upper(),'replacement_path':replacement}
    if expected_sha256:args['expected_sha256']=expected_sha256
    r=invoke_via_finder(idx,cap,args,role,sphere)
    if isinstance(r.get('result'),dict):
        r['result']['task']='edit method'; r['result']['capability']=cap
    return r


def _sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def _sphere_zip_identity(data, source, expected_id=None, outer_member=None):
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            names=z.namelist()
            profiles=[]
            for name in names:
                m=re.search(r'(^|/)profiles/([^/]+)\.json$',name)
                if not m:continue
                try:obj=json.loads(z.read(name).decode('utf-8'))
                except Exception:continue
                sid=str(obj.get('id') or m.group(2))
                if expected_id and sid!=expected_id:continue
                prefix=name[:m.start(0)] if m.start(0)>0 else ''
                # m.start(0) can include a slash; simpler derive from '/profiles/'.
                marker='profiles/'+m.group(2)+'.json'
                root_prefix=name[:-len(marker)]
                profiles.append((sid,obj,root_prefix,name))
            if not profiles:
                return None
            ids=sorted({x[0] for x in profiles})
            if len(ids)!=1:
                return {'error':'AMBIGUOUS_SPHERE_IDS','ids':ids,'source':source}
            sid=ids[0]
            prof=next(x for x in profiles if x[0]==sid)
            sphere_obj=None;sphere_path=None
            prefix=prof[2]
            for name in names:
                if not name.startswith(prefix):continue
                if '/packs/' not in '/'+name and not name.startswith(prefix+'packs/'):continue
                if not name.endswith('.json'):continue
                try:o=json.loads(z.read(name).decode('utf-8'))
                except Exception:continue
                if o.get('kind')=='sphere' and o.get('id')==sid:
                    sphere_obj=o;sphere_path=name;break
            return {
                'sphere':sid,
                'version':(sphere_obj or prof[1]).get('version'),
                'title':(sphere_obj or {}).get('title'),
                'profile_version':prof[1].get('version'),
                'profile_path':prof[3],
                'root_prefix':prefix,
                'sphere_path':sphere_path,
                'archive_sha256':_sha256_bytes(data),
                'archive_size':len(data),
                'source':source,
                'outer_member':outer_member,
            }
    except zipfile.BadZipFile:
        return {'error':'INVALID_ARCHIVE','source':source}

def _sphere_candidate_from_file(path, expected_id=None, source_class='local'):
    p=Path(path)
    if not p.is_file():return None
    try:data=p.read_bytes()
    except OSError:return None
    meta=_sphere_zip_identity(data,str(p),expected_id)
    if not meta:return None
    meta['source_class']=source_class
    meta['_bytes']=data
    return meta

def _common_api_rollup():
    explicit=os.environ.get('LLM_GOPHER_API_ROLLUP')
    if explicit and Path(explicit).is_file():return str(Path(explicit).resolve())
    candidates=[]
    for d in (Path('/mnt/data'),Path.home()/'Downloads'):
        if not d.is_dir():continue
        candidates.extend(x for x in d.glob('oorexxapis*.zip') if x.is_file())
    if not candidates:return None
    candidates.sort(key=lambda x:(x.stat().st_mtime,x.name),reverse=True)
    return str(candidates[0].resolve())

def _local_sphere_candidates(sphere_id, override_dir):
    d=Path(override_dir)
    if not d.is_dir():return []
    out=[]
    for p in sorted(d.glob('*.zip')):
        m=_sphere_candidate_from_file(p,sphere_id,'local_override')
        if m and not m.get('error'):out.append(m)
    return out

def _delivered_sphere_candidates(sphere_id, api_rollup):
    if not api_rollup:return [],None
    p=Path(api_rollup)
    if not p.is_file():return [],None
    out=[];note=None
    try:
        with zipfile.ZipFile(p) as outer:
            try:note=outer.read('current/sphere/Important.txt').decode('utf-8','replace').strip()
            except KeyError:pass
            for member in sorted(outer.namelist()):
                if not member.startswith('current/sphere/') or not member.lower().endswith('.zip'):continue
                try:data=outer.read(member)
                except Exception:continue
                meta=_sphere_zip_identity(data,str(p),sphere_id,member)
                if not meta or meta.get('error'):continue
                meta['source_class']='delivered'
                meta['_bytes']=data
                meta['api_rollup']=str(p.resolve())
                out.append(meta)
    except zipfile.BadZipFile:
        return [],note
    return out,note

def resolve_sphere_source(sphere_id, api_rollup=None, override=None, override_dir=None):
    sphere_id=str(sphere_id or '').strip()
    if not sphere_id:return env('OK','INVALID_ARGUMENT',{'missing':['sphere']})
    api_rollup=api_rollup or _common_api_rollup()
    env_root=Path(os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user'))))
    override_dir=override_dir or os.environ.get('LLM_GOPHER_SPHERE_OVERRIDE_DIR') or str(env_root/'overrides'/'spheres')
    explicit=[]
    if override:
        m=_sphere_candidate_from_file(override,sphere_id,'explicit_override')
        if not m:return env('OK','NOT_FOUND',{'sphere':sphere_id,'override':str(override),'reason':'override does not contain the requested sphere profile'})
        if m.get('error'):return env('OK','INVALID_ARCHIVE',m)
        explicit=[m]
    local=_local_sphere_candidates(sphere_id,override_dir)
    delivered,note=_delivered_sphere_candidates(sphere_id,api_rollup)
    if len(local)>1 and not explicit:
        return env('OK','AMBIGUOUS',{'sphere':sphere_id,'source_class':'local_override',
            'candidates':[{k:v for k,v in x.items() if not k.startswith('_')} for x in local]})
    if len(delivered)>1 and not explicit and not local:
        return env('OK','AMBIGUOUS',{'sphere':sphere_id,'source_class':'delivered',
            'candidates':[{k:v for k,v in x.items() if not k.startswith('_')} for x in delivered]})
    chosen=(explicit or local or delivered)
    if not chosen:
        return env('OK','NOT_FOUND',{'sphere':sphere_id,'api_rollup':api_rollup,'override_dir':override_dir})
    selected=chosen[0]
    public={k:v for k,v in selected.items() if not k.startswith('_')}
    return env('OK','FOUND',{
        'sphere':sphere_id,
        'selected':public,
        'precedence':['explicit_override','local_override','delivered'],
        'selected_reason':selected.get('source_class')+'_precedence',
        'local_override_dir':override_dir,
        'delivered_note':note,
        'delivered_candidates':[{k:v for k,v in x.items() if not k.startswith('_')} for x in delivered],
        'override_candidates':[{k:v for k,v in x.items() if not k.startswith('_')} for x in (explicit or local)],
    },_selected_bytes=selected.get('_bytes'))

def _sphere_registry_path(env_root):
    return Path(env_root)/'state'/'spheres.json'

def _load_sphere_registry(env_root):
    p=_sphere_registry_path(env_root)
    if not p.is_file():return {}
    try:return json.loads(p.read_text(encoding='utf-8'))
    except Exception:return {}

def _write_sphere_registry(env_root, registry):
    p=_sphere_registry_path(env_root)
    p.parent.mkdir(parents=True,exist_ok=True)
    tmp=p.with_suffix('.tmp')
    tmp.write_text(json.dumps(registry,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    os.replace(tmp,p)

def activate_sphere_source(sphere_id, api_rollup=None, override=None, override_dir=None, env_root=None):
    r=resolve_sphere_source(sphere_id,api_rollup,override,override_dir)
    if r['operation_status']['class']!='FOUND':return r
    data=r.pop('_selected_bytes',None)
    if data is None:return env('IMPLEMENTATION_FAILURE','UNKNOWN',None,diagnostics=['resolved sphere bytes missing'])
    selected=r['result']['selected']
    env_root=Path(env_root or os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user'))))
    os.umask(0o077)
    (env_root/'spheres').mkdir(parents=True,exist_ok=True)
    digest=selected['archive_sha256']
    target=env_root/'spheres'/sphere_id/digest
    if not target.is_dir():
        tmp=env_root/'spheres'/sphere_id/(digest+'.tmp')
        if tmp.exists():shutil.rmtree(tmp)
        tmp.mkdir(parents=True,exist_ok=True)
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                for info in z.infolist():
                    name=info.filename
                    # Reject absolute/traversal paths.
                    q=Path(name)
                    if q.is_absolute() or '..' in q.parts:
                        shutil.rmtree(tmp,ignore_errors=True)
                        return env('OK','INVALID_ARCHIVE',{'sphere':sphere_id,'member':name,'reason':'unsafe archive path'})
                z.extractall(tmp)
        except zipfile.BadZipFile:
            shutil.rmtree(tmp,ignore_errors=True)
            return env('OK','INVALID_ARCHIVE',{'sphere':sphere_id})
        target.parent.mkdir(parents=True,exist_ok=True)
        os.replace(tmp,target)
    prefix=selected.get('root_prefix') or ''
    active_root=(target/prefix).resolve()
    profile=active_root/'profiles'/(sphere_id+'.json')
    if not profile.is_file():
        return env('IMPLEMENTATION_FAILURE','UNKNOWN',{'sphere':sphere_id,'active_root':str(active_root)},diagnostics=['activated sphere profile missing'])
    registry=_load_sphere_registry(env_root)
    registry[sphere_id]={
        'sphere':sphere_id,'root':str(active_root),'archive_sha256':digest,
        'version':selected.get('version'),'source_class':selected.get('source_class'),
        'source':selected.get('source'),'outer_member':selected.get('outer_member'),
        'api_rollup':selected.get('api_rollup')
    }
    _write_sphere_registry(env_root,registry)
    out=dict(r['result'])
    out['active_root']=str(active_root)
    out['registry']=str(_sphere_registry_path(env_root))
    out['profile']=str(profile)
    return env('OK','ACTIVATED',out)

def active_spheres(env_root=None):
    env_root=Path(env_root or os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user'))))
    reg=_load_sphere_registry(env_root)
    return env('OK','OPENED',{'environment':str(env_root),'spheres':reg})

def profile_paths(profile_names, root):
    packs=[]
    env_root=Path(os.environ.get('LLM_GOPHER_ENV') or (Path(os.environ.get('TMPDIR','/tmp'))/('llm-gopher-'+os.environ.get('USER','user'))))
    registry=_load_sphere_registry(env_root)
    for name in profile_names:
        active=registry.get(name)
        profile_root=Path(active['root']) if active and active.get('root') else Path(root)
        pf=profile_root/'profiles'/(name+'.json')
        if not pf.is_file():
            # Built-in profile remains the fallback when there is no activated external profile.
            pf=Path(root)/'profiles'/(name+'.json')
            profile_root=Path(root)
        if not pf.is_file():return None,env('OK','NOT_FOUND',{'profile':name,'path':str(pf)})
        obj=load_json(pf)
        rels=list(obj.get('packs',[]))
        # Sphere-author shorthand: a profile may compose named spheres instead
        # of spelling internal pack paths. Resolve each sphere id to packs/<id>
        # first in the activated sphere root, then in the installed engine.
        if not rels and obj.get('spheres'):
            rels=['packs/'+str(sid) for sid in obj.get('spheres',[])]
        for rel in rels:
            local=(profile_root/rel).resolve()
            built=(Path(root)/rel).resolve()
            p=local if local.exists() else built
            if not p.exists():
                return None,env('OK','NOT_FOUND',{'profile':name,'pack':rel,'profile_root':str(profile_root),'root':str(root)})
            if str(p) not in packs:packs.append(str(p))
    return packs,None

def intent_plan(text,location=None,nested=None,sphere='oorexx'):
    low=text.lower(); steps=[]; command=None
    m=re.search(r'([A-Za-z0-9_.-]+\.(?:cls|rex|rxj|hpp|h|cpp|cc|cxx|c))\b',text,re.I)
    source=m.group(1) if m else None
    sm=re.search(r'\bclass\s+([A-Za-z_][\w.]*)',text,re.I); symbol=sm.group(1) if sm else None
    if ('examine' in low or 'inspect' in low or source) and source:
        args={'source':source,'in':location,'nested':nested,'symbol':symbol}
        steps=[{'operation':'resolve-source','bounded':True},{'operation':'examine-source','bounded':True},{'operation':'search-symbol','conditional':bool(symbol)},{'operation':'read-excerpt','bounded':True}]
        command='gopher --profile '+shlex.quote(sphere)+' examine source '+shlex.quote(source)+((' --in '+shlex.quote(location)) if location else '')+((' --nested '+shlex.quote(nested)) if nested else '')+((' --symbol '+shlex.quote(symbol)) if symbol else '')
        return env('OK','PLANNED',{'intent':text,'operation':'examine source','arguments':args,'steps':steps,'command':command,'requires_input':['in'] if not location else []})
    return env('OK','NOT_UNDERSTOOD',{'intent':text,'supported_intents':['examine/inspect a named source file']})




def capability_form(idx, capability, role='llm', sphere=None, return_to=None):
    schema=capability_schema(capability)
    if not schema:return env('OK','NOT_FOUND',{'capability':capability})
    svcs=find_services(idx,capability,role,sphere)
    if not svcs:return env('OK','DENIED',{'capability':capability,'sphere':sphere})
    fields=[]; ask=[]
    for name,spec in (schema.get('parameters') or {}).items():
        f={'name':name,'type':spec.get('type','string'),'required':bool(spec.get('required'))}
        for k in ('default','enum','minimum','maximum'): 
            if k in spec:f[k]=spec[k]
        fields.append(f)
        label=name + (' *' if spec.get('required') else '')
        if spec.get('enum'):
            ask.append('Choose: '+label+'\t'+'\t'.join(str(x) for x in spec['enum']))
        elif spec.get('type')=='boolean':
            ask.append('Choose: '+label+'\ttrue\tfalse')
        else:
            default=spec.get('default')
            ask.append('Ask: '+label+(('\t'+str(default)) if default is not None else ''))
    return env('OK','OPENED',{'capability':capability,'summary':schema.get('summary'),'fields':fields,
        'ask':ask,'submit_selector':'/submit/'+capability,'return_to':return_to,
        'service_proxies':[service_proxy(x,capability) for x in svcs]})

def submit_capability_form(idx, capability, values, role='llm', sphere=None, return_to=None):
    form=capability_form(idx,capability,role,sphere,return_to)
    if form['operation_status']['class']!='OPENED':return form
    fields=form['result']['fields']; args={}
    if isinstance(values,dict):
        args=dict(values)
    else:
        vals=list(values or [])
        for n,f in enumerate(fields):
            if n>=len(vals):break
            v=vals[n]
            if v!='':args[f['name']]=v
    r=invoke_via_finder(idx,capability,args,role,sphere)
    r['form']={'capability':capability,'return_to':return_to,'submitted_fields':sorted(args)}
    return r

def _gopher_plus_form_text(form):
    lines=['+INFO: '+form.get('capability',''),'+LLM-KIND: capability-form','+LLM-CAPABILITY: '+form.get('capability',''),'+ASK:']
    lines.extend(' '+x for x in form.get('ask',[]))
    if form.get('return_to'):lines.append('+LLM-RETURN: '+form['return_to'])
    return '\r\n'.join(lines)+'\r\n.\r\n'

def _gopher_line(item_type, title, selector, host='localhost', port=70):
    # RFC 1436 menu line. Keep title single-line and selector tab-free.
    title=str(title).replace('\t',' ').replace('\r',' ').replace('\n',' ')
    selector=str(selector).replace('\t','')
    return f"{item_type}{title}\t{selector}\t{host}\t{port}"



def _register_result(runtime, response, return_to=None, capability=None, sphere=None):
    if runtime is None:
        return None
    results=runtime.setdefault('results',{})
    material={
        'response':response,
        'return_to':return_to,
        'capability':capability,
        'sphere':sphere,
    }
    rid=digest(material)[:24]
    results[rid]=material
    return '/result/'+rid

def _result_rule_breaches(response):
    out=[]
    def collect(obj):
        if isinstance(obj,dict):
            if obj.get('status')=='BREACHED' and obj.get('rule'):
                out.append(obj)
            for v in obj.values(): collect(v)
        elif isinstance(obj,list):
            for v in obj: collect(v)
    collect(response.get('evidence'))
    collect(response.get('result'))
    seen=set(); uniq=[]
    for b in out:
        key=(b.get('rule'),str(b.get('where')))
        if key not in seen:
            seen.add(key); uniq.append(b)
    return uniq

def _result_summary_lines(response):
    lines=[]
    ts=(response.get('tool_status') or {}).get('class','UNKNOWN')
    os_=(response.get('operation_status') or {}).get('class','UNKNOWN')
    lines.append(('Tool status',ts)); lines.append(('Operation status',os_))
    result=response.get('result')
    if isinstance(result,dict):
        preferred=('task','capability','path','nested','member','class','method','name','line','committed')
        for key in preferred:
            if key in result and not isinstance(result[key],(dict,list)):
                lines.append((key,str(result[key])))
    route=(response.get('route') or (response.get('evidence') or {}).get('examiner_route'))
    if isinstance(route,dict):
        if route.get('service'): lines.append(('service',str(route['service'])))
        if route.get('fallback_depth') is not None: lines.append(('fallback_depth',str(route['fallback_depth'])))
    return lines[:18]

def _gopher_result_page(runtime, rid, role='llm', host='localhost', port=70, plus=False):
    material=(runtime or {}).get('results',{}).get(rid)
    if not material:return env('OK','NOT_FOUND',{'selector':'/result/'+rid})
    response=material['response']; lines=[]
    op=(response.get('operation_status') or {}).get('class','UNKNOWN')
    lines.append(_gopher_line('i','Result: '+op,'fake',host,port))
    for key,value in _result_summary_lines(response):
        lines.append(_gopher_line('i',f'{key}: {value}','fake',host,port))
    breaches=_result_rule_breaches(response)
    if breaches:
        lines.append(_gopher_line('i',f'Language-rule breaches: {len(breaches)}','fake',host,port))
        for b in breaches:
            rid2=b.get('rule'); correct=((b.get('fix') or {}).get('correct') or b.get('correct') or '')
            lines.append(_gopher_line('1','Rule: '+rid2,'/result/'+rid+'/rule/'+rid2,host,port))
            if correct: lines.append(_gopher_line('i','> CORRECT: '+str(correct),'fake',host,port))
    cap=material.get('capability')
    sphere=material.get('sphere')
    if cap and sphere:
        lines.append(_gopher_line('7','> Run again','/form/'+sphere+'/'+cap,host,port)+'	?')
    ret=material.get('return_to')
    if ret: lines.append(_gopher_line('1','< RETURN',ret,host,port))
    attrs=['+INFO: Result '+rid,'+LLM-KIND: operation-result','+LLM-RESULT: '+rid,'+LLM-STATUS: '+op]
    if ret: attrs.append('+LLM-RETURN: '+ret)
    text='\r\n'.join((attrs+[''] if plus else [])+lines)+'\r\n.\r\n'
    return env('OK','OPENED',{'selector':'/result/'+rid,'format':'gopher+' if plus else 'gopher','text':text,'items':len(lines),'attributes':attrs if plus else [],'response':response})
def gopher_selector(idx, selector='/', role='llm', host='localhost', port=70, plus=False, runtime=None):
    selector=(selector or '/').strip()
    if not selector.startswith('/'): selector='/'+selector
    parts=[x for x in selector.split('/') if x]
    lines=[]; attrs=[]
    if not parts:
        spheres=[]
        for (k,i),o in idx.items():
            if k!='sphere': continue
            if allowed(find_policy(idx,o),role,'read','sphere:'+i): spheres.append((i,o.get('title',i)))
        for i,title in sorted(spheres): lines.append(_gopher_line('1',title,'/sphere/'+i,host,port))
        attrs=['+INFO: LLM Gopher root','+LLM-KIND: root','+LLM-SCHEMA: '+SCHEMA]
    elif parts[0]=='sphere' and len(parts)==2:
        sid=parts[1]; sp=idx.get(('sphere',sid))
        if not sp or not allowed(find_policy(idx,sp),role,'read','sphere:'+sid): return env('OK','NOT_FOUND',{'selector':selector})
        for (k,i),a in sorted(idx.items()):
            if k=='article' and a.get('sphere')==sid and allowed(find_policy(idx,sp),role,'read','article:'+i):
                lines.append(_gopher_line('1',a.get('title',i),'/article/'+i,host,port))
        # Capabilities are useful as navigable reference objects, but not executable selectors.
        caps=[]
        for (k,i),svc in idx.items():
            if k=='service' and (svc.get('sphere') in (None,sid,'core') or sid=='core'):
                for cap in svc.get('capabilities',[]): caps.append(cap)
        for cap in sorted(set(caps)):
            if CAPABILITY_SCHEMAS.get(cap): lines.append(_gopher_line('0','Capability: '+cap,'/capability/'+sid+'/'+cap,host,port))
        attrs=['+INFO: '+sp.get('title',sid),'+LLM-KIND: sphere','+LLM-SPHERE: '+sid]
    elif parts[0]=='article' and len(parts)>=2:
        aid='/'.join(parts[1:]); r=open_article(idx,aid,role)
        if r['operation_status']['class']!='OPENED': return env('OK','NOT_FOUND',{'selector':selector})
        a=r['result']; lines.append(_gopher_line('i',a.get('title',aid),'fake',host,port))
        if a.get('summary'): lines.append(_gopher_line('i',a['summary'],'fake',host,port))
        for sel in a.get('selectors',[]):
            cap=sel.get('capability') or sel.get('target') or sel.get('id')
            title=sel.get('title') or sel.get('label') or sel.get('id','selector')
            if cap and CAPABILITY_SCHEMAS.get(cap): lines.append(_gopher_line('0','> '+title,'/capability/'+str(a.get('sphere','core'))+'/'+cap,host,port))
        attrs=['+INFO: '+a.get('title',aid),'+LLM-KIND: article','+LLM-ARTICLE: '+aid,'+LLM-SPHERE: '+str(a.get('sphere',''))]
    elif parts[0]=='capability' and len(parts)>=2:
        if len(parts)>=3 and ('sphere',parts[1]) in idx:
            sid=parts[1]; cap='/'.join(parts[2:])
        else:
            sid=None; cap='/'.join(parts[1:])
        r=describe_capability(idx,cap,role,sid)
        if r['operation_status']['class'] not in ('OK','FOUND','OPENED'): return env('OK','NOT_FOUND',{'selector':selector})
        rr=r.get('result') or {}; schema=rr.get('schema') or CAPABILITY_SCHEMAS.get(cap,{})
        lines.append(_gopher_line('i',cap,'fake',host,port))
        if schema.get('summary'): lines.append(_gopher_line('i',schema['summary'],'fake',host,port))
        for name,spec in (schema.get('parameters') or {}).items():
            req='required' if spec.get('required') else 'optional'
            lines.append(_gopher_line('i',f"{name}: {spec.get('type','string')} ({req})",'fake',host,port))
        if find_services(idx,cap,role,sid):
            formsel='/form/'+(sid+'/' if sid else '')+cap
            lines.append(_gopher_line('7','> Execute with form',formsel,host,port)+'\t?')
        attrs=['+INFO: '+cap,'+LLM-KIND: capability','+LLM-CAPABILITY: '+cap]
    elif parts[0]=='form' and len(parts)>=2:
        if len(parts)>=3 and ('sphere',parts[1]) in idx:
            sid=parts[1]; cap='/'.join(parts[2:])
        else:
            sid=None; cap='/'.join(parts[1:])
        r=capability_form(idx,cap,role,sid,return_to=selector)
        if r['operation_status']['class']!='OPENED':return r
        form=r['result']
        attrs=['+INFO: '+cap,'+LLM-KIND: capability-form','+LLM-CAPABILITY: '+cap,'+ASK:']+[' '+x for x in form.get('ask',[])]
        lines.append(_gopher_line('i','Form: '+cap,'fake',host,port))
        lines.append(_gopher_line('i','Submit using Gopher+ ASK responses','fake',host,port))
    elif parts[0]=='result' and len(parts)>=4 and parts[2]=='rule':
        result_id=parts[1]; rule_id='/'.join(parts[3:])
        if not (runtime or {}).get('results',{}).get(result_id):return env('OK','NOT_FOUND',{'selector':selector})
        r=rule_page(idx,rule_id,None,'/result/'+result_id)
        if r['operation_status']['class']!='OPENED':return r
        rr=r['result']; lines.append(_gopher_line('i',rr.get('title',rule_id),'fake',host,port))
        for key in ('purpose','correct','why'):
            if rr.get(key): lines.append(_gopher_line('i',str(rr[key]),'fake',host,port))
        lines.append(_gopher_line('1','< RETURN TO RESULT','/result/'+result_id,host,port))
        attrs=['+INFO: '+rr.get('title',rule_id),'+LLM-KIND: language-rule','+LLM-RULE: '+rule_id,'+LLM-RETURN: /result/'+result_id]
    elif parts[0]=='result' and len(parts)==2:
        return _gopher_result_page(runtime,parts[1],role,host,port,plus)
    elif parts[0]=='rule' and len(parts)>=2:
        rid='/'.join(parts[1:]); r=rule_page(idx,rid,None,None)
        if r['operation_status']['class']!='OPENED': return env('OK','NOT_FOUND',{'selector':selector})
        rr=r['result']; lines.append(_gopher_line('i',rr.get('title',rid),'fake',host,port))
        for key in ('purpose','correct','why'):
            if rr.get(key): lines.append(_gopher_line('i',str(rr[key]),'fake',host,port))
        attrs=['+INFO: '+rr.get('title',rid),'+LLM-KIND: language-rule','+LLM-RULE: '+rid]
    else:
        return env('OK','NOT_FOUND',{'selector':selector})
    text='\r\n'.join((attrs+[''] if plus else [])+lines)+('\r\n' if lines or attrs else '')+'.\r\n'
    return env('OK','OPENED',{'selector':selector,'format':'gopher+' if plus else 'gopher','text':text,'items':len(lines),'attributes':attrs if plus else []})


def _dot_stuffed_text(text):
    out=[]
    for line in str(text).splitlines():
        if line.startswith('.'):line='.'+line
        out.append(line)
    return '\r\n'.join(out)+'\r\n.\r\n'

def _parse_ask_body(rfile, max_lines=256, max_bytes=1024*1024):
    vals=[]; total=0
    first=True
    for _ in range(max_lines):
        raw=rfile.readline(65536)
        if not raw:break
        total+=len(raw)
        if total>max_bytes:raise ValueError('ASK body exceeds limit')
        line=raw.decode('utf-8','replace').rstrip('\r\n')
        if line=='.':return vals
        if first and line=='+-1':first=False;continue
        first=False
        if line.startswith('..'):line=line[1:]
        vals.append(line)
    raise ValueError('unterminated or oversized ASK body')

class _OneShotGopherServer(socketserver.TCPServer):
    allow_reuse_address=True

def serve_gopher(idx, role='llm', host='127.0.0.1', port=7070, once=False):
    runtime={'results':{}}
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            raw=self.rfile.readline(8192).decode('utf-8','replace').rstrip('\r\n')
            fields=raw.split('\t'); selector=fields[0] or '/'
            gplus=fields[1] if len(fields)>1 else ''
            is_submit=len(fields)>2 and fields[2]=='1'
            if is_submit and selector.startswith('/form/'):
                tail=selector[len('/form/'):]; bits=tail.split('/')
                if len(bits)>1 and ('sphere',bits[0]) in idx: sphere=bits[0]; cap='/'.join(bits[1:])
                else: sphere=None; cap=tail
                try: values=_parse_ask_body(self.rfile)
                except ValueError as e:
                    r=env('OK','INVALID_ARGUMENT',{'message':str(e),'capability':cap})
                else:
                    ret='/capability/'+((sphere+'/') if sphere else '')+cap
                    r=submit_capability_form(idx,cap,values,role,sphere,return_to=ret)
                    result_selector=_register_result(runtime,r,ret,cap,sphere)
                    if result_selector:
                        r.setdefault('navigation',{})['result_selector']=result_selector
                        r['navigation']['return_to']=ret
                self.wfile.write(_dot_stuffed_text(json.dumps(r,indent=2)).encode('utf-8'));return
            if selector.startswith('/form/') and gplus.startswith('!'):
                tail=selector[len('/form/'):]; bits=tail.split('/')
                if len(bits)>1 and ('sphere',bits[0]) in idx: sphere=bits[0]; cap='/'.join(bits[1:])
                else: sphere=None; cap=tail
                ret='/capability/'+((sphere+'/') if sphere else '')+cap
                r=capability_form(idx,cap,role,sphere,return_to=ret)
                if r['operation_status']['class']=='OPENED':data=_gopher_plus_form_text(r['result'])
                else:data=_dot_stuffed_text(json.dumps(r,indent=2))
                self.wfile.write(data.encode('utf-8'));return
            plus=gplus.startswith('+') or gplus.startswith('!')
            r=gopher_selector(idx,selector,role,self.server.server_address[0],self.server.server_address[1],plus,runtime)
            if r['operation_status']['class']=='OPENED': data=r['result']['text']
            else: data=_gopher_line('3','Not found',selector,self.server.server_address[0],self.server.server_address[1])+'\r\n.\r\n'
            self.wfile.write(data.encode('utf-8'))
    try:
        with _OneShotGopherServer((host,port),Handler) as srv:
            actual=srv.server_address[1]
            if once:
                srv.handle_request(); return env('OK','OK',{'host':host,'port':actual,'requests':1})
            srv.serve_forever()
    except PermissionError as e: return env('PERMISSION_DENIED','UNKNOWN',{'message':str(e)})
    except OSError as e: return env('DEPENDENCY_FAILURE','UNKNOWN',{'message':str(e)})

class JsonArgumentParser(argparse.ArgumentParser):
    def error(self,message):
        print(json.dumps(env('OK','INVALID_ARGUMENT',{'message':message}),indent=2))
        raise SystemExit(2)

def operational_help(idx, sphere, role='llm'):
    s=idx.get(('sphere',sphere))
    if not s:
        return env('OK','NOT_FOUND',{'sphere':sphere})
    policy=find_policy(idx,s)
    if not allowed(policy,role,'read','sphere:'+sphere):
        return env('OK','DENIED',{'sphere':sphere})
    articles=[]
    for (k,i),a in idx.items():
        if k!='article' or a.get('sphere')!=sphere: continue
        if not allowed(policy,role,'read','article:'+i): continue
        articles.append({
            'id':i,'title':a.get('title') or i,
            'summary':a.get('summary') or '',
            'procedure':a.get('procedure') or [],
            'invariants':a.get('invariants') or []
        })
    caps=[]
    seen=set()
    for (k,i),svc in idx.items():
        if k!='service': continue
        for cap in svc.get('capabilities',[]):
            if cap in seen: continue
            routes=finder(idx,cap,role,sphere)
            if routes['operation_status']['class'] not in ('FOUND','OK'): continue
            seen.add(cap)
            schema=capability_schema(cap)
            caps.append({
                'capability':cap,
                'summary':schema.get('summary',''),
                'required':[k for k,v in schema.get('parameters',{}).items() if v.get('required')],
                'supports':schema.get('supports',[])
            })
    return env('OK','OPENED',{
        'sphere':sphere,'title':s.get('title') or sphere,
        'inherits_services_from':sorted(inherited_service_spheres(idx,sphere)-{sphere}),
        'articles':sorted(articles,key=lambda x:x['id']),
        'capabilities':sorted(caps,key=lambda x:x['capability'])
    })

def print_operational_help_text(idx, sphere, role='llm'):
    r=operational_help(idx,sphere,role)
    if r['operation_status']['class']!='OPENED':
        print("Operational help unavailable for sphere:",sphere)
        return 1
    x=r['result']
    print("YOU SHOULD BE USING THIS")
    print("========================")
    print("Environment is usable. Prefer LLM Gopher's published operations over ad-hoc shell/file inspection.")
    print()
    print("Sphere:",x['title'],"("+x['sphere']+")")
    if x.get('inherits_services_from'):
        print("Inherits service scope from:",", ".join(x['inherits_services_from']))
    if x['articles']:
        print()
        print("Relevant operational pages:")
        for a in x['articles']:
            print("  "+a['id']+"  - "+a['title'])
            if a['summary']: print("      "+a['summary'])
    if x['capabilities']:
        print()
        print("Published service scope:")
        for c in x['capabilities']:
            req=(" required: "+", ".join(c['required'])) if c['required'] else ""
            print("  "+c['capability']+req)
            if c['summary']: print("      "+c['summary'])
    print()
    print("Sphere datasets:")
    print("  gopher sphere resolve "+sphere+" --api-rollup <oorexxapis.zip>")
    print("  gopher sphere load "+sphere+" --api-rollup <oorexxapis.zip>")
    print("  local override: $LLM_GOPHER_SPHERE_OVERRIDE_DIR or $LLM_GOPHER_ENV/overrides/spheres")
    print()
    print("Start here:")
    print("  gopher --profile "+sphere+" context "+sphere)
    print("  gopher --profile "+sphere+" menu "+sphere)
    print("  gopher --profile "+sphere+" open <article-id>")
    print("  gopher --profile "+sphere+" describe <capability>")
    print()
    print("Rule: if Gopher can perform or explain the task, use it before an ambient fallback.")
    return 0

def main():
    ap=JsonArgumentParser(
        prog='gopher',
        description='LLM Gopher: bounded, structured operational memory and tool execution for LLMs. Start with context/menu when discovering a sphere; use describe/form before low-level exec; use examine/edit/rules for source work; package stage/check before sealing.',
        epilog='LLM workflow: setup -> context <sphere> -> open/menu/describe -> examine/edit/rules/exec -> tests -> package stage -> package check. Responses are structured JSON; tool_status describes the tool, operation_status describes the requested operation.'
    )
    ap.add_argument('--version',action='version',version='LLM Gopher v0.21-dev1 ('+SCHEMA+')')
    ap.add_argument('--pack',action='append',default=[],help='Load a pack directory or JSON file. May be repeated.')
    ap.add_argument('--profile',action='append',default=[],help='Load a named pack profile, e.g. oorexx, flylo, federationbank.')
    ap.add_argument('--role',default='llm',help='Access-control role. Default: llm.')
    sp=ap.add_subparsers(dest='cmd',required=True)
    p=sp.add_parser('help',help='Show dynamic operational help from loaded sphere/pages/services.',description='Render LLM-oriented operational help from the actual loaded sphere, articles and capability schemas.');p.add_argument('sphere',nargs='?',default='oorexx');p.add_argument('--text',action='store_true')
    p=sp.add_parser('language',help='Describe/resolve loaded language modules.',description='Language modules map file extensions to source examination, symbol lookup, rule and compile capabilities.');lsp=p.add_subparsers(dest='language_kind',required=True)
    q=lsp.add_parser('describe',help='Describe one language module.');q.add_argument('language')
    q=lsp.add_parser('resolve',help='Resolve a source filename/path to its language module.');q.add_argument('source')
    p=sp.add_parser('sphere',help='Resolve/activate delivered or locally overridden spheres.',description='Find a sphere by embedded identity. Precedence is explicit override, local override directory, then current/sphere inside an ooRexx API roll-up.');ssp=p.add_subparsers(dest='sphere_kind',required=True)
    q=ssp.add_parser('resolve',help='Resolve which sphere ZIP would be used.');q.add_argument('sphere');q.add_argument('--api-rollup');q.add_argument('--override');q.add_argument('--override-dir')
    q=ssp.add_parser('load',help='Resolve and activate a sphere in the private environment.');q.add_argument('sphere');q.add_argument('--api-rollup');q.add_argument('--override');q.add_argument('--override-dir');q.add_argument('--env',dest='env_root')
    q=ssp.add_parser('list',help='List activated spheres in the private environment.');q.add_argument('--env',dest='env_root')
    q=ssp.add_parser('edit',help='Canonical sphere editor.',description='Create, mutate, validate, lint and package sphere work trees without hand-maintaining JSON layout.');esp2=q.add_subparsers(dest='sphere_edit_kind',required=True)
    e=esp2.add_parser('create',help='Create a canonical sphere scaffold.');e.add_argument('sphere');e.add_argument('--path',required=True);e.add_argument('--version',default='0.1');e.add_argument('--title',required=True);e.add_argument('--purpose')
    e=esp2.add_parser('import-legacy',help='Import a pre-kind legacy sphere ZIP/directory without parsing evidence prose.');e.add_argument('source');e.add_argument('--out',required=True)
    e=esp2.add_parser('template',help='Return/write a canonical sphere-object template.');e.add_argument('kind');e.add_argument('--sphere');e.add_argument('--id');e.add_argument('--title');e.add_argument('--version',default='0.1');e.add_argument('--out')
    e=esp2.add_parser('put',help='Create/replace one exact sphere object from JSON.');e.add_argument('kind');e.add_argument('--sphere',required=True);e.add_argument('--path',required=True);e.add_argument('--from',dest='source',required=True);e.add_argument('--expected-sha256')
    e=esp2.add_parser('evidence',help='Attach canonical structured provenance to one object.');e.add_argument('kind');e.add_argument('id');e.add_argument('--sphere',required=True);e.add_argument('--path',required=True);e.add_argument('--artifact',required=True);e.add_argument('--sha256',required=True);e.add_argument('--member',required=True);e.add_argument('--line-start',type=int);e.add_argument('--line-end',type=int);e.add_argument('--claim');e.add_argument('--note');e.add_argument('--expected-sha256')
    e=esp2.add_parser('record-put',help='Create/replace one corpus record by stable key/value.');e.add_argument('corpus');e.add_argument('--sphere',required=True);e.add_argument('--path',required=True);e.add_argument('--from',dest='source',required=True);e.add_argument('--key',default='id');e.add_argument('--value',required=True);e.add_argument('--expected-sha256')
    e=esp2.add_parser('changelog-add',help='Add one deduplicated changelog entry.');e.add_argument('--path',required=True);e.add_argument('--version',required=True);e.add_argument('--text',required=True)
    e=esp2.add_parser('validate',help='Validate sphere structure and references.');e.add_argument('sphere');e.add_argument('--path',required=True)
    e=esp2.add_parser('lint',help='Advisory lint of authoring quality/consistency.');e.add_argument('sphere');e.add_argument('--path',required=True)
    e=esp2.add_parser('package',help='Validate and package a sphere.');e.add_argument('sphere');e.add_argument('--path',required=True);e.add_argument('--out',required=True);e.add_argument('--require-clean-lint',action='store_true')
    p=sp.add_parser('merge',help='Merge pack JSON/directories with collision checking.',description='Merge pack sources. Fails on incompatible identity collisions; optionally write merged index JSON.');p.add_argument('packs',nargs='+');p.add_argument('--out')
    p=sp.add_parser('open',help='Open an operational article by id.',description='Open one structured operational article. Use menu/context to discover article ids.');p.add_argument('article')
    p=sp.add_parser('exec',help='Execute an exact capability with key=value arguments.',description='Execute a named capability. Prefer describe <capability> first when its argument contract is not already known. Arguments are key=value.');p.add_argument('capability');p.add_argument('kv',nargs='*')
    p=sp.add_parser('describe',help='Show machine-readable capability contract.',description='Describe required/optional arguments, result shape, examples and support of one capability.');p.add_argument('capability');p.add_argument('--sphere')
    p=sp.add_parser('menu',help='List articles in a sphere.',description='Return the bounded article menu for one sphere.');p.add_argument('sphere')
    p=sp.add_parser('find',help='Resolve a capability to permitted service routes.',description='Find permitted service/tool routes for a capability, optionally constrained to a sphere.');p.add_argument('capability');p.add_argument('--sphere')
    p=sp.add_parser('context',help='Discover a sphere and its usable capabilities.',description='Recommended discovery entry point. Returns compact sphere context; --full includes the expanded view.');p.add_argument('sphere');p.add_argument('--full',action='store_true')
    p=sp.add_parser('lookup',help='Typed exact-field corpus lookup.',description='Look up corpus records by FIELD=VALUE. Exact field matches win; bounded text fallback is used only when no exact match exists.');p.add_argument('predicate');p.add_argument('--sphere');p.add_argument('--corpus');p.add_argument('--no-fallback',action='store_true');p.add_argument('--max-matches',type=int,default=50)
    p=sp.add_parser('search',help='Search a configured corpus.',description='Search indexed corpus material with optional sphere/corpus restriction.');p.add_argument('query');p.add_argument('--sphere');p.add_argument('--corpus')
    p=sp.add_parser('render',help='Render an article with key=value bindings.',description='Render an operational article with supplied key=value bindings.');p.add_argument('article');p.add_argument('kv',nargs='*')
    p=sp.add_parser('instance',help='Create an executable article instance.',description='Instantiate an article/form workflow using key=value bindings.');p.add_argument('article');p.add_argument('kv',nargs='*')
    p=sp.add_parser('step',help='Invoke one step of an article instance.',description='Instantiate an article with bindings and execute the named step.');p.add_argument('article');p.add_argument('step_id');p.add_argument('kv',nargs='*')
    p=sp.add_parser('examine',help='Composite bounded source examination.',description='High-level source examination. Finds source in files/ZIPs/nested ZIPs and can locate a symbol with bounded evidence.');esp=p.add_subparsers(dest='examine_kind',required=True)
    q=esp.add_parser('source',help='Find/examine a source file, including nested ZIPs.',description='Composite source examination. SOURCE names the member; --in names filesystem/ZIP location; --nested names an inner ZIP; --symbol locates a class/method/symbol; excerpt is bounded.');q.add_argument('source',nargs='?');q.add_argument('--source',dest='source_opt');q.add_argument('--in',dest='location');q.add_argument('--path',dest='location_opt');q.add_argument('--nested');q.add_argument('--symbol');q.add_argument('--symbol-fallback',action='store_true',help='Permit labelled TEXT_FALLBACK when no exact declaration exists.');q.add_argument('--sphere',help='Destination sphere; default is inferred from the resolved language module.');q.add_argument('--excerpt-lines',type=int,default=5)
    p=sp.add_parser('edit',help='Perform bounded structural source edits.',description='Safe source editing with language-aware validation and optional stale-source SHA-256 fencing.');edp=p.add_subparsers(dest='edit_kind',required=True)
    q=edp.add_parser('method',help='Add or replace a method safely.',description='Bounded method edit for ooRexx/Python. Requires target, class, method and replacement text; optional SHA-256 prevents stale-source edits.');q.add_argument('class_name',nargs='?');q.add_argument('method_name',nargs='?');q.add_argument('--class',dest='class_opt');q.add_argument('--method',dest='method_opt');q.add_argument('--in',dest='location');q.add_argument('--path',dest='location_opt');q.add_argument('--replacement');q.add_argument('--operation',choices=['ADD','REPLACE'],default='REPLACE');q.add_argument('--language',choices=['auto','oorexx','python'],default='auto');q.add_argument('--expected-sha256');q.add_argument('--sphere',default='oorexx')
    p=sp.add_parser('rules',help='Check/show language rules and corrections.',description='Evaluate all applicable language rules together, or show the detail page for one rule.');rsp=p.add_subparsers(dest='rules_kind',required=True)
    q=rsp.add_parser('check',help='Evaluate all language rules for a source.',description='Return all applicable rule breaches together, each with cause/correction/detail navigation.');q.add_argument('location',nargs='?');q.add_argument('--in',dest='location_opt');q.add_argument('--language',choices=['auto','oorexx','python','java'],default='auto');q.add_argument('--sphere',default='oorexx')
    q=rsp.add_parser('show',help='Show one language-rule detail page.',description='Open one language rule and optionally carry a return-to selector.');q.add_argument('rule_id');q.add_argument('--language');q.add_argument('--return-to')
    p=sp.add_parser('query',help='Translate supported natural task intent into a safe plan.',description='Plan a supported high-level intent. This planner is bounded; NOT_UNDERSTOOD means use context/menu/describe rather than guessing.');p.add_argument('intent');p.add_argument('--in',dest='location');p.add_argument('--nested');p.add_argument('--sphere',default='oorexx')
    p=sp.add_parser('selector',help='Resolve a Gopher/Gopher+ selector.',description='Resolve one Gopher selector; --plus requests Gopher+ attributes.');p.add_argument('selector',nargs='?',default='/');p.add_argument('--plus',action='store_true');p.add_argument('--host',default='localhost');p.add_argument('--port',type=int,default=70)
    p=sp.add_parser('serve',help='Run the TCP Gopher server.',description='Serve Gopher/Gopher+ over TCP. Default bind is loopback 127.0.0.1:7070; --once handles one connection then exits.');p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=7070);p.add_argument('--once',action='store_true')
    p=sp.add_parser('reference',help='Read/search/navigate PDF or HTML references from file or URL.',description='Bounded primary-reference reader. Typical cycle: find/locate -> read -> move +/-N -> return to the originating task. PDF navigation uses physical PDF pages; --reference-page records an approximate printed/manual page citation.',epilog='Examples:  gopher reference find https://www.oorexx.org/docs/pdf/rexxref.pdf FORWARD  |  gopher reference locate manual.pdf --reference-page 55 --approx-page 73 --window 20  |  gopher reference read manual.pdf --page 73 --reference-page 55  |  gopher reference move manual.pdf --page 73 1') ;rsp=p.add_subparsers(dest='reference_kind',required=True)
    q=rsp.add_parser('locate');q.add_argument('source');q.add_argument('--type',dest='doc_kind',choices=['auto','pdf','html'],default='auto');q.add_argument('--reference-page',type=int);q.add_argument('--approx-page',type=int);q.add_argument('--reference');q.add_argument('--query');q.add_argument('--window',type=int,default=12)
    q=rsp.add_parser('find');q.add_argument('source');q.add_argument('query');q.add_argument('--type',dest='doc_kind',choices=['auto','pdf','html'],default='auto');q.add_argument('--case-sensitive',action='store_true');q.add_argument('--max-hits',type=int,default=50);q.add_argument('--context-chars',type=int,default=240);q.add_argument('--start-page',type=int,default=1);q.add_argument('--end-page',type=int)
    q=rsp.add_parser('read');q.add_argument('source');q.add_argument('--type',dest='doc_kind',choices=['auto','pdf','html'],default='auto');q.add_argument('--page',type=int,default=1);q.add_argument('--section',type=int);q.add_argument('--reference-page',type=int);q.add_argument('--step',type=int,default=5);q.add_argument('--max-chars',type=int,default=24000)
    q=rsp.add_parser('move');q.add_argument('source');q.add_argument('--type',dest='doc_kind',choices=['auto','pdf','html'],default='auto');q.add_argument('--page',type=int);q.add_argument('--section',type=int);q.add_argument('delta',type=int);q.add_argument('--step',type=int,default=5);q.add_argument('--max-chars',type=int,default=24000)
    p=sp.add_parser('workspace',help='Inspect workspace/materialisation/archive/handover readiness.',description='Operational workspace checks for short-lived coding sessions. Preflight capacity before extraction and advise handover when the session cannot safely complete the task.');wsp=p.add_subparsers(dest='workspace_kind',required=True)
    q=wsp.add_parser('inspect',help='Show byte/inode headroom and bounded /mnt/data usage.');q.add_argument('--path',default='/mnt/data')
    q=wsp.add_parser('preflight-zip',help='Check ZIP expansion against workspace bytes/inodes without extracting it.');q.add_argument('path');q.add_argument('--destination',default='/mnt/data');q.add_argument('--materialize-bytes',type=int,default=0);q.add_argument('--working-copies',type=int,default=1);q.add_argument('--workspace-root');q.add_argument('--workspace-limit-bytes',type=int);q.add_argument('--workspace-limit-inodes',type=int)
    q=wsp.add_parser('materialize-check',help='Check whether a needed file is mounted/materialised and whether expected bytes fit.');q.add_argument('--path');q.add_argument('--expected-bytes',type=int,default=0);q.add_argument('--destination',default='/mnt/data');q.add_argument('--workspace-root');q.add_argument('--workspace-limit-bytes',type=int)
    q=wsp.add_parser('handover-frame',help='Build a read-only structured handover frame from current workspace state.');q.add_argument('--task');q.add_argument('--next-action');q.add_argument('--artifact');q.add_argument('--env',dest='env_root')
    q=wsp.add_parser('recoverability',help='Check minimum continuity artifacts; advise handover if context cannot be safely reconstructed.');q.add_argument('--env',dest='env_root');q.add_argument('--qualification');q.add_argument('--changelog')
    p=sp.add_parser('package',help='Stage/check delivery packages.',description='Package workflow: stage a clean candidate tree, then check all packaging breaches before sealing.');pp=p.add_subparsers(dest='package_kind',required=True)
    q=pp.add_parser('check',help='Check a staged package for every known breach.',description='Examine a candidate stage in one pass: excluded content, dependency-root policy, changelog/version, tests and environment references.');q.add_argument('location',nargs='?');q.add_argument('--in',dest='location_opt');q.add_argument('--version')
    q=pp.add_parser('stage',help='Create a clean package staging tree.',description='Copy source to a clean stage while excluding VCS/cache/generated/prior root delivery artifacts.');q.add_argument('location',nargs='?');q.add_argument('--in',dest='location_opt');q.add_argument('--to',dest='stage')
    p=sp.add_parser('form',help='Return an executable capability form.',description='Return the Gopher+ style form/schema for a capability.');p.add_argument('capability');p.add_argument('--sphere');p.add_argument('--return-to')
    p=sp.add_parser('submit',help='Submit a capability form with key=value arguments.',description='Validate and execute a capability form submission using key=value arguments.');p.add_argument('capability');p.add_argument('kv',nargs='*');p.add_argument('--sphere');p.add_argument('--return-to')
    ns=ap.parse_args()
    if ns.cmd=='sphere':
        if ns.sphere_kind=='resolve':
            r=resolve_sphere_source(ns.sphere,ns.api_rollup,ns.override,ns.override_dir)
        elif ns.sphere_kind=='load':
            r=activate_sphere_source(ns.sphere,ns.api_rollup,ns.override,ns.override_dir,ns.env_root)
        elif ns.sphere_kind=='edit':
            if ns.sphere_edit_kind=='create':
                r=sphere_editor_create({'path':ns.path,'sphere':ns.sphere,'version':ns.version,'title':ns.title,'purpose':ns.purpose})
            elif ns.sphere_edit_kind=='import-legacy':
                r=sphere_editor_import_legacy({'source':ns.source,'out':ns.out})
            elif ns.sphere_edit_kind=='template':
                r=sphere_editor_template({'kind':ns.kind,'sphere':ns.sphere,'id':ns.id,'title':ns.title,'version':ns.version,'out':ns.out})
            elif ns.sphere_edit_kind=='put':
                r=sphere_editor_put({'path':ns.path,'sphere':ns.sphere,'kind':ns.kind,'from':ns.source,'expected_sha256':ns.expected_sha256})
            elif ns.sphere_edit_kind=='evidence':
                a={'path':ns.path,'sphere':ns.sphere,'kind':ns.kind,'id':ns.id,'artifact':ns.artifact,'sha256':ns.sha256,'member':ns.member,
                   'line_start':ns.line_start,'line_end':ns.line_end,'claim':ns.claim,'note':ns.note,'expected_sha256':ns.expected_sha256}
                r=sphere_editor_evidence_attach(a)
            elif ns.sphere_edit_kind=='record-put':
                r=sphere_editor_corpus_record_put({'path':ns.path,'sphere':ns.sphere,'corpus':ns.corpus,'from':ns.source,'key':ns.key,'value':ns.value,'expected_sha256':ns.expected_sha256})
            elif ns.sphere_edit_kind=='changelog-add':
                r=sphere_editor_changelog_add({'path':ns.path,'version':ns.version,'text':ns.text})
            elif ns.sphere_edit_kind=='validate':
                r=sphere_editor_validate({'path':ns.path,'sphere':ns.sphere})
            elif ns.sphere_edit_kind=='lint':
                r=sphere_editor_lint({'path':ns.path,'sphere':ns.sphere})
            else:
                r=sphere_editor_package({'path':ns.path,'sphere':ns.sphere,'out':ns.out,'require_clean_lint':ns.require_clean_lint})
        else:
            r=active_spheres(ns.env_root)
        # private byte payload is never serialized.
        r.pop('_selected_bytes',None)
        print(json.dumps(r,indent=2))
        if r['tool_status']['class']!='OK':return r['tool_status']['rc']
        if r['operation_status']['class']=='INVALID_ARGUMENT':return 2
        return 0 if r['operation_status']['rc']==0 else 1
    if ns.cmd=='merge':
        r=merge_packs(ns.packs)
        if ns.out and r['operation_status']['class']=='MERGED':Path(ns.out).write_text(json.dumps(r['result'],indent=2)+'\n')
        print(json.dumps(r,indent=2));return 0 if r['operation_status']['class']=='MERGED' else 1
    root=Path(__file__).resolve().parent.parent
    packs=list(ns.pack)
    if ns.profile:
        pp,err=profile_paths(ns.profile,root)
        if err:print(json.dumps(err,indent=2));return 1
        for x in pp:
            if x not in packs:packs.append(x)
    if not packs:
        pp,err=profile_paths(['oorexx'],root)
        packs=pp if not err else [str(root/'packs'/'core'),str(root/'packs'/'oorexx')]
    ix=build_index(packs)
    if ix['tool_status']['class']!='OK' or ix['operation_status']['class']!='OK':print(json.dumps(ix,indent=2));return 2
    idx=ix['result']['index']
    if ns.cmd=='reference':
        if ns.reference_kind=='locate':
            a={'source':ns.source,'kind':ns.doc_kind,'window':ns.window}
            if ns.reference_page is not None:a['reference_page']=ns.reference_page
            if ns.approx_page is not None:a['approx_page']=ns.approx_page
            if ns.reference:a['reference']=ns.reference
            if ns.query:a['query']=ns.query
            r=invoke_via_finder(idx,'reference.document.locate',a,ns.role,'core')
        elif ns.reference_kind=='find':
            a={'source':ns.source,'query':ns.query,'kind':ns.doc_kind,'case_sensitive':ns.case_sensitive,'max_hits':ns.max_hits,'context_chars':ns.context_chars,'start_page':ns.start_page}
            if ns.end_page is not None:a['end_page']=ns.end_page
            r=invoke_via_finder(idx,'reference.document.find',a,ns.role,'core')
        elif ns.reference_kind=='read':
            a={'source':ns.source,'kind':ns.doc_kind,'page':ns.page,'step':ns.step,'max_chars':ns.max_chars}
            if ns.section is not None:a['section']=ns.section
            if ns.reference_page is not None:a['reference_page']=ns.reference_page
            r=invoke_via_finder(idx,'reference.document.page.read',a,ns.role,'core')
        else:
            a={'source':ns.source,'kind':ns.doc_kind,'delta':ns.delta,'step':ns.step,'max_chars':ns.max_chars}
            if ns.page is not None:a['page']=ns.page
            if ns.section is not None:a['section']=ns.section
            r=invoke_via_finder(idx,'reference.document.navigate',a,ns.role,'core')
    elif ns.cmd=='workspace':
        if ns.workspace_kind=='inspect':
            r=invoke_via_finder(idx,'workspace.inspect',{'paths':'/mnt/data,/tmp,/','top_path':ns.path},ns.role,'core')
        elif ns.workspace_kind=='preflight-zip':
            args={'path':ns.path,'destination':ns.destination,'materialize_bytes':ns.materialize_bytes,'working_copies':ns.working_copies}
            if ns.workspace_root: args['workspace_root']=ns.workspace_root
            if ns.workspace_limit_bytes is not None: args['workspace_limit_bytes']=ns.workspace_limit_bytes
            if ns.workspace_limit_inodes is not None: args['workspace_limit_inodes']=ns.workspace_limit_inodes
            r=invoke_via_finder(idx,'workspace.archive.preflight',args,ns.role,'core')
        elif ns.workspace_kind=='materialize-check':
            args={'path':ns.path,'expected_bytes':ns.expected_bytes,'destination':ns.destination}
            if ns.workspace_root: args['workspace_root']=ns.workspace_root
            if ns.workspace_limit_bytes is not None: args['workspace_limit_bytes']=ns.workspace_limit_bytes
            r=invoke_via_finder(idx,'workspace.materialization.check',args,ns.role,'core')
        elif ns.workspace_kind=='handover-frame':
            args={}
            if ns.task: args['task']=ns.task
            if ns.next_action: args['next_action']=ns.next_action
            if ns.artifact: args['artifact']=ns.artifact
            if ns.env_root: args['env']=ns.env_root
            r=invoke_via_finder(idx,'workspace.handover.frame',args,ns.role,'core')
        else:
            args={}
            if ns.env_root: args['env']=ns.env_root
            if ns.qualification: args['qualification']=ns.qualification
            if ns.changelog: args['changelog']=ns.changelog
            r=invoke_via_finder(idx,'workspace.context.recoverability',args,ns.role,'core')
    elif ns.cmd=='language':
        r=language_module_describe(idx,ns.language) if ns.language_kind=='describe' else language_module_resolve(idx,ns.source)
    elif ns.cmd=='help':
        if ns.text:
            return print_operational_help_text(idx,ns.sphere,ns.role)
        r=operational_help(idx,ns.sphere,ns.role)
    elif ns.cmd in ('render','instance','step'):
        bindings={}
        for x in ns.kv:
            if '=' not in x:r=env('OK','INVALID_ARGUMENT',{'invalid':[{'value':x,'reason':'expected key=value'}]});break
            k,v=x.split('=',1);bindings[k]=v
        else:
            if ns.cmd=='render':r=render_page(idx,ns.article,bindings,ns.role)
            elif ns.cmd=='instance':r=new_page_instance(idx,ns.article,bindings,ns.role)
            else:
                ni=new_page_instance(idx,ns.article,bindings,ns.role)
                r=ni if ni['operation_status']['class']!='OPENED' else run_page_step(idx,ni['result'],ns.step_id,ns.role)
    elif ns.cmd=='open':r=open_article(idx,ns.article,ns.role)
    elif ns.cmd=='find':r=finder(idx,ns.capability,ns.role,ns.sphere)
    elif ns.cmd=='describe':r=describe_capability(idx,ns.capability,ns.role,ns.sphere)
    elif ns.cmd=='context':r=context_view(idx,ns.sphere,ns.role,ns.full)
    elif ns.cmd=='lookup':
        if '=' not in ns.predicate:
            r=env('OK','INVALID_ARGUMENT',{'invalid':[{'value':ns.predicate,'reason':'expected FIELD=VALUE'}]})
        else:
            field,value=ns.predicate.split('=',1)
            r=invoke_via_finder(idx,'corpus.record.lookup',{'field':field,'value':value,'corpus':ns.corpus,'fallback':not ns.no_fallback,'max_matches':ns.max_matches},ns.role,ns.sphere)
    elif ns.cmd=='search':r=corpus_search(idx,{'query':ns.query,'corpus':ns.corpus},ns.role,ns.sphere)
    elif ns.cmd=='edit':
        if ns.edit_kind=='method':
            loc=ns.location or ns.location_opt; cls=ns.class_name or ns.class_opt; meth=ns.method_name or ns.method_opt
            missing=[k for k,v in [('in',loc),('class',cls),('method',meth),('replacement',ns.replacement)] if not v]
            r=env('OK','INVALID_ARGUMENT',{'missing':missing}) if missing else edit_method(idx,loc,cls,meth,ns.replacement,ns.operation,ns.language,ns.expected_sha256,ns.role,ns.sphere)
    elif ns.cmd=='rules':
        if ns.rules_kind=='check':
            loc=ns.location or ns.location_opt
            r=env('OK','INVALID_ARGUMENT',{'missing':['in']}) if not loc else invoke_via_finder(idx,'source.language.rules.evaluate',{'path':loc,'language':ns.language},ns.role,ns.sphere)
        else:r=rule_page(idx,ns.rule_id,ns.language,ns.return_to)
    elif ns.cmd=='query':r=intent_plan(ns.intent,ns.location,ns.nested,ns.sphere)
    elif ns.cmd=='examine':
        if ns.examine_kind=='source':
            src=ns.source or ns.source_opt; loc=ns.location or ns.location_opt
            missing=[k for k,v in [('source',src),('in',loc)] if not v]
            r=env('OK','INVALID_ARGUMENT',{'missing':missing}) if missing else examine_source(idx,src,loc,ns.nested,ns.symbol,ns.role,ns.sphere,ns.excerpt_lines,ns.symbol_fallback)
    elif ns.cmd=='selector':r=gopher_selector(idx,ns.selector,ns.role,ns.host,ns.port,ns.plus)
    elif ns.cmd=='serve':
        r=serve_gopher(idx,ns.role,ns.host,ns.port,ns.once)
        if r is None:return 0
    elif ns.cmd=='package':
        loc=ns.location or ns.location_opt
        if ns.package_kind=='check':
            r=env('OK','INVALID_ARGUMENT',{'missing':['in']}) if not loc else invoke_via_finder(idx,'package.stage.check',{'path':loc,'version':ns.version} if ns.version else {'path':loc},ns.role,'oorexx')
        else:
            missing=[k for k,v in [('in',loc),('to',ns.stage)] if not v]
            r=env('OK','INVALID_ARGUMENT',{'missing':missing}) if missing else invoke_via_finder(idx,'package.stage.create',{'path':loc,'stage':ns.stage},ns.role,'oorexx')
    elif ns.cmd=='form':r=capability_form(idx,ns.capability,ns.role,ns.sphere,ns.return_to)
    elif ns.cmd=='submit':
        args={};bad=[]
        for x in ns.kv:
            if '=' not in x:bad.append({'value':x,'reason':'expected key=value'});continue
            k,v=x.split('=',1);args[k]=v
        r=env('OK','INVALID_ARGUMENT',{'capability':ns.capability,'invalid':bad}) if bad else submit_capability_form(idx,ns.capability,args,ns.role,ns.sphere,ns.return_to)
    elif ns.cmd=='exec':
        args={};bad=[]
        for x in ns.kv:
            if '=' not in x:bad.append({'value':x,'reason':'expected key=value'});continue
            k,v=x.split('=',1);args[k]=v
        if bad:r=env('OK','INVALID_ARGUMENT',{'capability':ns.capability,'invalid':bad,'schema':capability_schema(ns.capability)})
        else:
            sphere=args.pop('sphere',None)
            r=invoke_via_finder(idx,ns.capability,args,ns.role,sphere)
    else:
        s=idx.get(('sphere',ns.sphere))
        if not s:r=env('OK','NOT_FOUND',{'sphere':ns.sphere})
        elif not allowed(find_policy(idx,s),ns.role,'read','sphere:'+ns.sphere):r=env('OK','DENIED',{'sphere':ns.sphere})
        else:
            arts=[]
            for (k,i),a in idx.items():
                if k=='article' and a.get('sphere')==ns.sphere and allowed(find_policy(idx,s),ns.role,'read','article:'+i):arts.append({'id':i,'title':a.get('title'),'section':a.get('section'),'topics':a.get('topics',[])})
            arts_sorted=sorted(arts,key=lambda x:((x.get('section') or ''),x['id']))
            sections={}
            for a in arts_sorted:
                sec=a.get('section') or 'unsectioned'
                sections.setdefault(sec,[]).append({'id':a['id'],'title':a.get('title'),'topics':a.get('topics',[])})
            r=env('OK','OK',{'sphere':ns.sphere,'title':s.get('title'),'articles':arts_sorted,'sections':sections})
    print(json.dumps(r,indent=2))
    if r['tool_status']['class']!='OK':return r['tool_status']['rc']
    if r['operation_status']['class']=='INVALID_ARGUMENT':return 2
    return 0
if __name__=='__main__':raise SystemExit(main())
