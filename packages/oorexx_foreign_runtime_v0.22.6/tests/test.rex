lib=.foreign~load('../examples/test.bridge.json')
assertions=0
call ok lib~invoke('add',20,22)=42, 'add'; assertions+=1
call ok lib~invoke('weighted',2.5,4)=10, 'weighted'; assertions+=1
call ok lib~invoke('hello','Rexx')='hello Rexx', 'hello'; assertions+=1
call ok lib~add(20,22)=42, 'UNKNOWN direct foreign method add'; assertions+=1
call ok lib~HELLO('Rexx')='hello Rexx', 'UNKNOWN case-insensitive foreign method'; assertions+=1
v=lib~constant('MSINTHAXWINHDLNOTLOTUS')
call ok v~datatype~name='HWND', 'constant datatype object'; assertions+=1
call ok v~datatype~semanticKind='handle', 'handle semantic kind'; assertions+=1
call ok v~datatype~size=.foreign~datatype('uintptr')~size, 'handle pointer width'; assertions+=1
call ok v~value='0x12345678', 'constant value'; assertions+=1
v2=.foreign~constant('ANSWER')
call ok v2~datatypeName='i32', 'global constant datatype'; assertions+=1
call ok lib~invoke('echo_handle',v~value)=305419896, 'handle argument'; assertions+=1
dt=.foreign~datatype('DWORD')
call ok dt~carrier='u32', 'DWORD carrier'; assertions+=1
call ok dt~size=4, 'DWORD width'; assertions+=1
call ok .foreign~datatype('LPARAM')~size=.foreign~datatype('pointer')~size, 'LPARAM pointer width'; assertions+=1
call ok lib~invoke('echo_intptr',-17)=-17, 'signed pointer integer'; assertions+=1
payload='00610062ff00010203'x
call ok payload~length=9, 'embedded-NUL payload length'; assertions+=1
call ok lib~fnv1a_bytes(payload,payload~length)=4223895405, 'binary-exact bytes preserve embedded NUL'; assertions+=1
call ok lib~invoke('echo_utf16','Rexx 3')='Rexx 3', 'UTF16 round trip'; assertions+=1
top=lib~constant('HWND_TOPMOST_EXAMPLE')
call ok top~datatypeName='HWND', 'pseudo handle datatype'; assertions+=1
if .foreign~datatype('uintptr')~size=8 then expected='18446744073709551615'; else expected='4294967295'
call ok lib~invoke('echo_handle',top~value)=expected, 'pseudo handle machine value'; assertions+=1
call ok .foreign~datatypes~items >= 20, 'datatype catalogue'; assertions+=1
ri=.foreign~runtimeInfo
call ok ri~runtimeVersion='0.22.6', 'runtime version descriptor'; assertions+=1
call ok ri~boundary='published-ooRexx-native-package-api', 'small boring boundary'; assertions+=1
call ok ri~requiredInterpreter='5.0.0', 'minimum native API ooRexx 5.0.0 text'; assertions+=1
call ok ri~requiredInterpreterRaw=327680, 'minimum native API ooRexx 5.0.0 raw'; assertions+=1
call ok ri~interpreterVersion~pos('.') > 0, 'actual interpreter version text'; assertions+=1
call ok ri~interpreterVersionRaw >= ri~requiredInterpreterRaw, 'actual interpreter satisfies package ABI'; assertions+=1
call ok ri~pointerSize=.foreign~datatype('pointer')~size, 'descriptor pointer width'; assertions+=1
call ok (ri~maxArity=0 | ri~maxArity=3), 'dispatcher arity capability'; assertions+=1
call ok ri~nativeDispatcher<>'', 'native dispatcher descriptor'; assertions+=1
call ok .foreign~capabilities~items >= 20, 'runtime capability catalogue'; assertions+=1
call ok lib~provider='native', 'library provider identity'; assertions+=1
call ok lib~providerPath~pos('libforeign_test.so') > 0, 'resolved provider path'; assertions+=1
methods=lib~methods
call ok methods~items >= 10, 'logical method catalogue'; assertions+=1
addMethod=lib~method('add')
call ok addMethod~overloadCount=1, 'single signature method'; assertions+=1
addSig=addMethod~signatures[1]
call ok addSig~symbol='add_i32', 'signature foreign symbol'; assertions+=1
call ok addSig~inputs[1]~typeName='i32', 'signature first input type'; assertions+=1
call ok addSig~inputs[2]~typeName='i32', 'signature second input type'; assertions+=1
call ok addSig~returnType~name='i32', 'known return datatype object'; assertions+=1
over=lib~method('overloaded')
call ok over~overloadCount=2, 'overloaded logical method signatures'; assertions+=1
resolved=lib~methodByInputs('overloaded',7)
call ok resolved~symbol='echo_i32', 'methodByInputs numeric resolution'; assertions+=1
call ok resolved~returnTypeName='i32', 'methodByInputs numeric return type'; assertions+=1
resolved=lib~methodByInputs('overloaded','Rexx')
call ok resolved~symbol='hello', 'methodByInputs string resolution'; assertions+=1
call ok resolved~returnTypeName='utf8', 'methodByInputs string return type'; assertions+=1
call ok lib~overloaded(7)=7, 'UNKNOWN uses resolved numeric signature'; assertions+=1
call ok lib~overloaded('Rexx')='hello Rexx', 'UNKNOWN uses resolved string signature'; assertions+=1
call ok lib~signatures~items > lib~methods~items, 'signature catalogue preserves overloads'; assertions+=1
buf=.foreign~buffer(4)
dummy=lib~invoke('fill_bytes',buf,4)
call ok buf~hex='01020304', 'writable foreign buffer'; assertions+=1
box=lib~invoke('box_new',77)
call ok box~isA(.ForeignObject), 'opaque pointer becomes ForeignObject'; assertions+=1
call ok box~type='foreign_box', 'foreign object semantic type'; assertions+=1
call ok box~ownership='owned', 'foreign object ownership'; assertions+=1
call ok lib~invoke('box_value',box)=77, 'foreign object argument'; assertions+=1
call ok lib~box_value(box)=77, 'direct foreign object argument'; assertions+=1
box~close
call ok box~closed, 'owned foreign object close'; assertions+=1
buf~close
call ok buf~closed, 'foreign buffer close'; assertions+=1
auto=lib~make_pattern
call ok auto~isA(.ForeignResult), 'automatic out returns ForeignResult'; assertions+=1
call ok auto~out('pattern')~hex='a0a1a2a3a4a5a6a7', 'automatic sized out buffer'; assertions+=1
call ok auto~outputNames[1]='pattern', 'named automatic output'; assertions+=1
auto~out('pattern')~close
boxResult=lib~box_out
call ok boxResult~isA(.ForeignResult), 'pointer-to-pointer returns ForeignResult'; assertions+=1
call ok boxResult~returnValue=1, 'structured native return value'; assertions+=1
outBox=boxResult~out('box')
call ok outBox~isA(.ForeignObject), 'pointer-to-pointer object output'; assertions+=1
call ok outBox~type='foreign_box', 'pointer-to-pointer semantic object type'; assertions+=1
call ok lib~box_value(outBox)=31415, 'pointer-to-pointer object usable'; assertions+=1
outBox~close
if ri~maxArity=0 then do
  call ok lib~sum6(1,2,3,4,5,6)=21, 'dynamic arity six-argument dispatch'; assertions+=1
end
ignored=lib~box_free_pp_reset
pp=lib~box_out_pp
call ok pp~isA(.ForeignResult), 'pointer-to-pointer destructor result'; assertions+=1
ppBox=pp~out('box')
call ok ppBox~isA(.ForeignObject), 'pointer-to-pointer destructor object'; assertions+=1
call ok lib~box_value(ppBox)=27182, 'pointer-to-pointer destructor object usable'; assertions+=1
ppBox~close
call ok lib~box_free_pp_count=1, 'pointer-to-pointer destructor called exactly once'; assertions+=1
ppSig=lib~method('box_out_pp')~signatures[1]
call ok ppSig~inputs[1]~destructorPointerDepth=2, 'destructor pointer depth introspection'; assertions+=1
patternSig=lib~method('make_pattern')~signatures[1]
call ok patternSig~inputs[1]~name='pattern', 'output parameter name introspection'; assertions+=1
call ok patternSig~inputs[1]~size=8, 'output parameter size introspection'; assertions+=1
call ok patternSig~inputs[1]~direction='out', 'output parameter direction introspection'; assertions+=1
st=lib~struct('foreign_layout')
call ok st~name='foreign_layout', 'metadata-defined ForeignStruct name'; assertions+=1
call ok st~size=24, 'metadata-defined ForeignStruct size'; assertions+=1
call ok st~alignment=8, 'metadata-defined ForeignStruct alignment'; assertions+=1
call ok st~fields~items=4, 'metadata-defined ForeignStruct fields'; assertions+=1
ignored=lib~layout_fill(st,6,63)
call ok st~get('order')=1, 'ForeignStruct native write/read order'; assertions+=1
call ok st~get('channels')=6, 'ForeignStruct native write/read channels'; assertions+=1
call ok st~get('mask')=63, 'ForeignStruct native write/read mask'; assertions+=1
st~set('channels',2)
call ok lib~layout_channels(st)=2, 'ForeignStruct Rexx write/native read'; assertions+=1
call ok lib~layout_mask(st)=63, 'ForeignStruct pointer invocation'; assertions+=1
types=lib~structTypes; foundLayout=.false; do t over types; if t='foreign_layout' then foundLayout=.true; end; call ok foundLayout, 'library struct type catalogue'; assertions+=1
sa=lib~structArray('foreign_layout',2)
sa~set(1,'channels',2); sa~set(2,'channels',6)
call ok sa~count=2, 'ForeignStructArray count'; assertions+=1
call ok sa~get(2,'channels')=6, 'ForeignStructArray indexed field read/write'; assertions+=1
call ok lib~layout_array_channel_sum(sa,2)=8, 'ForeignStructArray contiguous native invocation'; assertions+=1
sa~close
b1=.foreign~buffer(1); b2=.foreign~buffer(1)
ignored=lib~fill_bytes(b1,1); ignored=lib~fill_bytes(b2,1)
pa=.foreign~pointerArray(2,'u8')
pa~put(b1,1); pa~put(b2,2)
call ok pa~size=2, 'ForeignPointerArray size'; assertions+=1
call ok lib~pointer_array_first_sum(pa,2)=2, 'typed pointer array native call'; assertions+=1
pa~close; b1~close; b2~close; st~close
ignored=lib~device_free_reset
vram=lib~device_alloc
call ok vram~isA(.ForeignObject), 'device allocation is ForeignObject'; assertions+=1
call ok vram~addressSpace='device', 'device address space retained'; assertions+=1
call ok vram~byteLength=64, 'device extent retained'; assertions+=1
call ok lib~device_consume(vram)=1, 'device-only argument accepts device resource'; assertions+=1
sig=lib~method('device_alloc')~signatures[1]
call ok sig~addressSpace='device', 'signature exposes return address space'; assertions+=1
call ok sig~byteLength=64, 'signature exposes return extent'; assertions+=1
call ok lib~threadingMode='thread-safe', 'library threading metadata'; assertions+=1
call ok lib~affinity='none', 'library affinity metadata'; assertions+=1
vram~close
call ok lib~device_free_count=1, 'device destructor exactly once'; assertions+=1

cbtarget=.CallbackTarget~new
cb=lib~callback('binary_i32',cbtarget,'sum')
call ok cb~name='binary_i32', 'ForeignCallback name'; assertions+=1
call ok cb~threadPolicy='call-thread', 'ForeignCallback thread policy'; assertions+=1
call ok cb~lifetime='call', 'ForeignCallback lifetime'; assertions+=1
call ok cb~returnType~name='i32', 'ForeignCallback return type'; assertions+=1
call ok cb~inputs~items=2, 'ForeignCallback input introspection'; assertions+=1
call ok lib~callback_apply(cb,20,22)=42, 'synchronous ooRexx callback through libffi'; assertions+=1
call ok lib~callback_apply_twice(cb,5,7)=24, 'callback closure supports repeated entry during call'; assertions+=1
sig=lib~method('callback_apply')~signatures[1]
call ok sig~inputs[1]~callbackType='binary_i32', 'method introspection exposes callback signature'; assertions+=1
cb~close

/* inherited v0.13.1 borrowed/raw memory views */
viewBox=lib~box_new(909)
view=lib~structView('foreign_box',viewBox)
call ok view~get('value')=909, 'borrowed structView reads managed ForeignObject memory'; assertions+=1
view~close
viewBox~close
rawBytes=lib~raw_bytes_address
rawSlots=lib~raw_slots_address
call ok .foreign~pointerAt(rawSlots,0)=rawBytes, 'pointerAt reads pointer-sized slot'; assertions+=1
call ok .foreign~peekBytes(rawBytes,8)='dead00beef010203'x, 'peekBytes preserves exact binary memory'; assertions+=1

/* v0.14 scalar resources and errno */
ignored=lib~fake_handle_close_reset
fh=lib~fake_handle_new
call ok fh~isA(.ForeignHandle), 'scalar resource return is ForeignHandle'; assertions+=1
call ok fh~type='TEST_FD', 'ForeignHandle semantic resource type'; assertions+=1
call ok fh~carrier~name='i32', 'ForeignHandle carrier datatype'; assertions+=1
call ok fh~value=123, 'ForeignHandle scalar value'; assertions+=1
call ok lib~fake_handle_value(fh)=123, 'ForeignHandle marshals to scalar carrier'; assertions+=1
fh~close
call ok lib~fake_handle_close_count=1, 'ForeignHandle destructor exactly once'; assertions+=1
err=lib~fake_errno_failure
call ok err~isA(.ForeignResult), 'errno capture returns ForeignResult'; assertions+=1
call ok err~returnValue=-1, 'errno failure return retained'; assertions+=1
call ok err~errno=22, 'errno captured immediately'; assertions+=1
call ok err~errorMessage<>'', 'errno message exposed'; assertions+=1
sig=lib~method('fake_errno_failure')~signatures[1]
call ok sig~capturesErrno, 'signature introspection exposes errno capture'; assertions+=1
outH=lib~fake_out_handle_success
call ok outH~returnValue=0, 'out handle success return'; assertions+=1
fd=outH~out('fd')
call ok fd~isA(.ForeignHandle), 'out scalar resource becomes ForeignHandle'; assertions+=1
call ok fd~value=88, 'out scalar resource value'; assertions+=1
fd~close
call ok lib~fake_handle_close_count=2, 'out ForeignHandle destructor exactly once'; assertions+=1
bad=lib~fake_out_handle_failure
call ok bad~returnValue=-1, 'failed out resource return retained'; assertions+=1
call ok bad~errno=22, 'failed out resource errno retained'; assertions+=1
call ok bad~outputNames~items=0, 'failed out resource does not manufacture handle'; assertions+=1
invalid=lib~fake_handle_invalid
call ok invalid~returnValue=-1, 'invalid direct resource remains scalar'; assertions+=1
call ok invalid~errno=22, 'invalid direct resource errno retained'; assertions+=1
call ok invalid~returnValue~isA(.ForeignHandle)=.false, 'invalid direct resource not wrapped'; assertions+=1

lib~close

say 'PASS' assertions 'assertions' 
exit 0
ok: procedure
 use arg truth,label
 if \truth then do
   say 'FAIL:' label
   exit 1
 end
 return
::class CallbackTarget
::method sum
  use strict arg a,b
  return a+b

::requires '../rexx/foreign.cls'
