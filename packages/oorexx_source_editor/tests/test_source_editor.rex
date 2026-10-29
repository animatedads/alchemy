call rxfuncadd 'SysLoadFuncs','rexxutil','SysLoadFuncs'
call SysLoadFuncs
base=directory()
tmp=base||'/tests/.tmp-source-editor'
call SysMkDir tmp
signal on syntax name failed

/* C++ first-tier test */
cpp=tmp||'/widget.cpp'
text='#include <string>'||d2c(10)||d2c(10)||'class Widget {'||d2c(10)||'public:'||d2c(10)||'    int value;'||d2c(10)||'};'||d2c(10)||d2c(10)||'int add(int a, int b) {'||d2c(10)||'    return a + b;'||d2c(10)||'}'||d2c(10)
dummy=.SourceEditorUtil~writeAll(cpp,text)
d=.SourceDocument~new(cpp)
call assertEq 'cpp',d~language,'language cpp'
s=d~findSymbol('Widget','class'); call assertEq 3,s~startLine,'class start'
f=d~findSymbol('add','function'); call assertEq 8,f~startLine,'function start'
d~replaceLine(5,'    long value;')
d~save
call assertTrue d~lastBackupResult~ok,'atomic backup publish'
call assertTrue d~lastPublicationResult~ok,'atomic live publish'
call assertTrue d~lastPublicationResult~durabilityRequested='FULL','atomic full durability requested'
call assertTrue .SourceEditorUtil~readAll(cpp)~pos('long value;')>0,'C++ save'

/* stale generation refusal */
d2=.SourceDocument~new(cpp)
dummy=.SourceEditorUtil~writeAll(cpp,.SourceEditorUtil~readAll(cpp)||'// external'||d2c(10))
d2~replaceLine(5,'    int other;')
signal on syntax name expectedConflict
d2~save
say 'FAIL stale generation was accepted'; exit 1
expectedConflict:
  signal off syntax
  say 'PASS stale generation rejected'

/* JSON is a real profile and validates with shipped json.cls. */
json=tmp||'/config.json'; dummy=.SourceEditorUtil~writeAll(json,'{"worker":{"restart":3}}'||d2c(10))
j=.SourceDocument~new(json); call assertEq 'json',j~language,'language json'; call assertTrue j~validate,'json valid'

/* ooRexx class editor requirement resolution fails closed. */
req=tmp||'/Dependency.cls'; dummy=.SourceEditorUtil~writeAll(req,'::class Dependency public'||d2c(10))
cls=tmp||'/Thing.cls'; dummy=.SourceEditorUtil~writeAll(cls,'::class Thing public'||d2c(10)||'::method ping'||d2c(10)||'return 1'||d2c(10))
paths=.array~of(tmp)
ce=.RexxClassEditor~new(cls,paths)
r=ce~addRequires('Dependency.cls'); call assertTrue r<>'','require resolved'
ce~document~save
call assertTrue .SourceEditorUtil~readAll(cls)~pos('::requires "Dependency.cls"')>0,'require inserted'

/* C++ class editor can add a member. */
cpe=.CppClassEditor~new(cpp)
cpe~addMember('Widget','void reset();')
cpe~document~save
call assertTrue .SourceEditorUtil~readAll(cpp)~pos('void reset();')>0,'cpp member inserted'

/* reusable finder: text mode sees comments; code mode projects comments away. */
findFile=tmp||'/find.rex'
findText='/* secret token */'||d2c(10)||'say "visible token"'||d2c(10)||'::method tokenMethod'||d2c(10)||'return "token"'||d2c(10)
dummy=.SourceEditorUtil~writeAll(findFile,findText)
fd=.SourceDocument~new(findFile)
ft=fd~find('secret token','text','sensitive'); call assertEq 1,ft~items,'find text comment'
fc=fd~find('secret token','code','sensitive'); call assertEq 0,fc~items,'find code ignores comment'
fv=fd~find('visible token','code','sensitive'); call assertEq 1,fv~items,'find code visible'
fm=fd~find('token','code','insensitive'); call assertTrue fm~items>=2,'find code repeated'
/* grep delegates regex matching to ooRexx RegularExpression while retaining source semantics. */
gr=fd~grep('vis[a-z]+ token','code','sensitive'); call assertEq 1,gr~items,'grep regex code'
gc=fd~grep('secret.*token','code','sensitive'); call assertEq 0,gc~items,'grep regex ignores comment'
gt=fd~grep('secret[ ]+token','text','sensitive'); call assertEq 1,gt~items,'grep regex text comment'
gi=fd~grep('VISIBLE TOKEN','code','insensitive'); call assertEq 1,gi~items,'grep regex insensitive'
/* tree finder uses RexxUtil SysFileTree, not a find subprocess. */
treeDir=tmp||'/tree'; call SysMkDir treeDir
probe=treeDir||'/treeprobe.rex'
dummy=.SourceEditorUtil~writeAll(probe,'/* hidden tree token */'||d2c(10)||'say "tree visible"'||d2c(10))
tf=.SourceTreeFinder~new(tmp)
files=tf~files('treeprobe.rex','oorexx'); call assertEq 1,files~items,'tree file find'
tg=tf~grep('tree[ ]+visible','treeprobe.rex','code','sensitive','oorexx'); call assertEq 1,tg~items,'tree grep code'
th=tf~grep('hidden[ ]+tree','treeprobe.rex','code','sensitive','oorexx'); call assertEq 0,th~items,'tree grep ignores comment'
/* CLI search argument model preserves multi-word expressions after shell quote removal. */
ca=.array~of('find','dummy.rex','visible','token','--mode','code','--case','insensitive')
cpArgs=.SourceEditorCliSearchArgs~parse(ca,3,'text','sensitive')
call assertEq 'visible token',cpArgs~expression,'cli multiword expression'
call assertEq 'code',cpArgs~mode,'cli explicit mode'
call assertEq 'insensitive',cpArgs~caseMode,'cli explicit case'

legacy=.array~of('grep','dummy.rex','token','code','insensitive')
legacyArgs=.SourceEditorCliSearchArgs~parse(legacy,3,'text','sensitive')
call assertEq 'token',legacyArgs~expression,'cli legacy expression'
call assertEq 'code',legacyArgs~mode,'cli legacy mode'
call assertEq 'insensitive',legacyArgs~caseMode,'cli legacy case'

/* completion provider is semantic and deterministic; CLI/UI/MCP may project the same candidates. */
cp=.SourceCompletionProvider~new
cc=cp~completeDocument(.SourceDocument~new(rootFile()),'Source','class')
call assertTrue cc~items>=5,'completion document classes'
call assertEq 'SourceCompletionCandidate',cc[1]~label,'completion deterministic order'
ct=cp~completeTree(tmp,'tree','treeprobe.rex','oorexx')
call assertEq 1,ct~items,'completion tree file'
say 'PASS ooRexx source editor dev7'
exit 0

failed:
  say 'FAIL syntax:' condition('D')
  exit 1

assertEq:
  use arg expected,actual,label
  if expected\=actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
  say 'PASS' label
return
assertTrue:
  use arg value,label
  if \value then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
return

rootFile:
  return directory()||'/src/SourceEditor.cls'
::requires "SourceEditor.cls"
