::class ForeignPythonScalar public
::method init
  expose _marker _value
  use strict arg marker,value
  _marker=marker; _value=value
::method marshal
  expose _marker _value
  a=.array~new(2); a[1]=_marker; a[2]=_value; return a

::class ForeignPythonBytes subclass ForeignPythonScalar public
::method init
  use strict arg value
  self~init:super('__python_bytes__',value)

::class ForeignPythonText subclass ForeignPythonScalar public
::method init
  use strict arg value
  self~init:super('__python_text__',value)

::class ForeignPythonInteger subclass ForeignPythonScalar public
::method init
  use strict arg value
  self~init:super('__python_int__',value)

::class ForeignPythonFloat subclass ForeignPythonScalar public
::method init
  use strict arg value
  self~init:super('__python_float__',value)

::class ForeignPythonDict public
::method init
  expose _pairs
  _pairs=.array~new
::method put
  expose _pairs
  use strict arg name,value
  p=.array~of(name,value); _pairs~append(p); return self
::method marshal
  expose _pairs
  out=.array~new
  do p over _pairs
    v=p[2]
    if v~isA(.ForeignPythonScalar) then v=v~marshal
    else if v~isA(.ForeignPythonDict) then v=v~marshal
    else if v~isA(.ForeignBuffer) then v=.array~of('__foreign_buffer__',v~handle)
    else if v~isA(.ForeignPythonObject) then v=.array~of('__foreign_python_ref__',v~handle)
    out~append(.array~of(p[1],v))
  end
  return .array~of('__python_dict__',out)

::class ForeignPythonKeywords public
::method init
  expose _pairs
  _pairs=.array~new
::method put
  expose _pairs
  use strict arg name,value
  p=.array~of(name,value); _pairs~append(p); return self
::method marshal
  expose _pairs
  out=.array~new
  do p over _pairs
    v=p[2]
    if v~isA(.ForeignPythonScalar) then v=v~marshal
    else if v~isA(.ForeignPythonDict) then v=v~marshal
    else if v~isA(.ForeignBuffer) then v=.array~of('__foreign_buffer__',v~handle)
    else if v~isA(.ForeignPythonObject) then v=.array~of('__foreign_python_ref__',v~handle)
    out~append(.array~of(p[1],v))
  end
  return out

::class ForeignPythonParameter public
::method init
  expose _name _annotation _kind _required _defaultValue
  use strict arg name,annotation='',kind='',required=.true,defaultValue=''
  _name=name; _annotation=annotation; _kind=kind; _required=required; _defaultValue=defaultValue
::method name unguarded; expose _name; return _name
::method annotation unguarded; expose _annotation; return _annotation
::method kind unguarded; expose _kind; return _kind
::method required unguarded; expose _required; return _required
::method defaultValue unguarded; expose _defaultValue; return _defaultValue
::method string unguarded
  expose _name _annotation _kind _required _defaultValue
  s=_name; if _annotation<>'' then s=s':'_annotation
  if \_required then s=s'='_defaultValue
  return s

::class ForeignPythonSignature public
::method init
  expose _name _returnAnnotation _display _inputs
  use strict arg name,returnAnnotation='',display='',inputs=.nil
  _name=name; _returnAnnotation=returnAnnotation; _display=display
  if inputs=.nil then _inputs=.array~new; else _inputs=inputs
::method name unguarded; expose _name; return _name
::method inputs unguarded; expose _inputs; return _inputs
::method returnType unguarded; expose _returnAnnotation; return _returnAnnotation
::method returnAnnotation unguarded; expose _returnAnnotation; return _returnAnnotation
::method display unguarded; expose _display; return _display
::method string unguarded
  expose _name _display
  return _name||_display

::class ForeignPythonMethod public
::method init
  expose _name _signature
  use strict arg name,signature
  _name=name; _signature=signature
::method name unguarded; expose _name; return _name
::method signatures unguarded; expose _signature; return .array~of(_signature)
::method signature unguarded; expose _signature; return _signature
::method overloadCount unguarded; return 1
::method returnType unguarded; expose _signature; return _signature~returnType

::class ForeignPythonObject public
::method init
  expose _handle _typeName _closed
  use strict arg handle, typeName='object'
  _handle=handle; _typeName=typeName; _closed=.false
::method handle unguarded
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Python foreign object is closed')
  return _handle
::method typeName unguarded; expose _typeName; return _typeName
::method provider unguarded; return 'python'
::method threadingMode unguarded; return 'gil-managed'
::method _marshalOne unguarded
  use strict arg x
  if x~isA(.ForeignPythonScalar) then return x~marshal
  if x~isA(.ForeignPythonDict) then return x~marshal
  if x~isA(.ForeignBuffer) then return .array~of('__foreign_buffer__',x~handle)
  if x~isA(.ForeignPythonObject) then return .array~of('__foreign_python_ref__',x~handle)
  if x~isA(.array) then do
    out=.array~new
    do item over x; out~append(self~_marshalOne(item)); end
    return out
  end
  return x
::method _marshalArray unguarded
  use strict arg args
  out=.array~new
  do i=1 to args~items; out~append(self~_marshalOne(args[i])); end
  return out
::method _wrap unguarded
  use strict arg raw
  if raw~isA(.array) then if raw~items>=3 then if raw[1]='__foreign_python_object__' then return .ForeignPythonObject~new(raw[2],raw[3])
  return raw
::method invoke unguarded
  use strict arg name, ...
  a=.array~new
  do i=2 to arg(); a~append(arg(i)); end
  return self~_wrap(rexx_foreign_python_invoke(self~handle,name,self~_marshalArray(a)))
::method invokeKw unguarded
  use strict arg name,args=.nil,keywords=.nil
  if args=.nil then args=.array~new
  if keywords=.nil then keywords=.ForeignPythonKeywords~new
  return self~_wrap(rexx_foreign_python_invoke_kw(self~handle,name,self~_marshalArray(args),keywords~marshal))
::method call unguarded
  use strict arg ...
  a=.array~new
  do i=1 to arg(); a~append(arg(i)); end
  return self~_wrap(rexx_foreign_python_call(self~handle,self~_marshalArray(a)))
::method get unguarded
  use strict arg name
  return self~_wrap(rexx_foreign_python_get(self~handle,name))
::method items unguarded
  return rexx_foreign_python_length(self~handle)
::method at unguarded
  use strict arg index
  if \datatype(index,'W') | index < 1 then raise syntax 40.900 array('Foreign Python sequence index must be a positive whole number')
  return self~pythonAt(index-1)
::method "[]" unguarded
  use strict arg key
  if datatype(key,'W') then return self~at(key)
  return self~pythonAt(key)
::method pythonAt unguarded
  use strict arg index
  return self~_wrap(rexx_foreign_python_getitem(self~handle,self~_marshalOne(index)))
::method methods unguarded
  return rexx_foreign_python_methods(self~handle)
::method methodObjects unguarded
  names=self~methods; out=.array~new
  do n over names; out~append(self~method(n)); end
  return out
::method method unguarded
  use strict arg name
  raw=rexx_foreign_python_method_info(self~handle,name)
  pars=.array~new
  do p over raw[4]; pars~append(.ForeignPythonParameter~new(p[1],p[2],p[3],p[4],p[5])); end
  sig=.ForeignPythonSignature~new(raw[1],raw[2],raw[3],pars)
  return .ForeignPythonMethod~new(raw[1],sig)
::method signature unguarded
  use strict arg name
  return self~method(name)~signature~display
::method methodByInputs unguarded
  use strict arg name, ...
  a=.array~new
  do i=2 to arg(); a~append(self~_marshalOne(arg(i))); end
  raw=rexx_foreign_python_method_by_inputs(self~handle,name,a)
  pars=.array~new
  do p over raw[4]; pars~append(.ForeignPythonParameter~new(p[1],p[2],p[3],p[4],p[5])); end
  return .ForeignPythonSignature~new(raw[1],raw[2],raw[3],pars)
::method info unguarded; return rexx_foreign_python_info(self~handle)
::method providerPath unguarded; return self~info[4]
::method pythonVersion unguarded; return self~info[5]
::method repr unguarded; return self~info[3]
::method asBuffer unguarded
  raw=rexx_foreign_python_as_buffer(self~handle)
  return .ForeignBuffer~fromHandle(raw[1])
::method asTensor unguarded
  raw=rexx_foreign_python_as_tensor(self~handle)
  return .ForeignTensor~new(raw[1],self~typeName,raw[2],raw[3])
::method unknown unguarded
  use strict arg name,args
  if args~items>0 then do
    last=args[args~items]
    if last~isA(.ForeignPythonKeywords) then do
      pos=.array~new
      if args~items>1 then do i=1 to args~items-1; pos~append(args[i]); end
      return self~_wrap(rexx_foreign_python_invoke_kw(self~handle,name,self~_marshalArray(pos),last~marshal))
    end
  end
  return self~_wrap(rexx_foreign_python_invoke(self~handle,name,self~_marshalArray(args)))
::method close unguarded
  expose _handle _closed
  if \_closed then do; call rexx_foreign_python_close _handle; _closed=.true; end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_python_close _handle

::class ForeignTensor subclass ForeignPythonObject public
::method init
  expose _tensorInfo _nativeTensorHandle _tensorClosed
  use strict arg handle,typeName='tensor',tensorInfo=.nil,nativeTensorHandle=0
  self~init:super(handle,typeName)
  _nativeTensorHandle=nativeTensorHandle; _tensorClosed=.false
  if tensorInfo=.nil then _tensorInfo=rexx_foreign_python_tensor_info(handle); else _tensorInfo=tensorInfo
::method _info unguarded; expose _tensorInfo; return _tensorInfo
::method protocol unguarded; expose _tensorInfo; return _tensorInfo[1]
::method dtype unguarded; expose _tensorInfo; return _tensorInfo[2]
::method shape unguarded; expose _tensorInfo; return _tensorInfo[3]
::method strides unguarded; expose _tensorInfo; return _tensorInfo[4]
::method deviceType unguarded; expose _tensorInfo; return _tensorInfo[5]
::method deviceId unguarded; expose _tensorInfo; return _tensorInfo[6]
::method device unguarded; expose _tensorInfo; return _tensorInfo[7]
::method readonly unguarded; expose _tensorInfo; return _tensorInfo[8]
::method nativeHandle unguarded; expose _nativeTensorHandle; return _nativeTensorHandle
::method close unguarded
  expose _nativeTensorHandle _tensorClosed
  if \_tensorClosed then do; if _nativeTensorHandle<>0 then call rexx_foreign_python_tensor_native_close _nativeTensorHandle; _tensorClosed=.true; end
  forward class (super)
::method toDLPack unguarded
  use strict arg targetModule,targetFunction='from_dlpack'
  raw=rexx_foreign_python_tensor_to_dlpack(self~handle,targetModule,targetFunction)
  return self~_wrap(raw)

::class ForeignPythonModule subclass ForeignPythonObject public
::method init
  expose _module
  use strict arg handle,module
  self~init:super(handle,'module'); _module=module
::method moduleName unguarded; expose _module; return _module

::class ForeignPython public
::method canImport class
  use strict arg module
  return rexx_foreign_python_can_import(module)
::method import class
  use strict arg module
  raw=rexx_foreign_python_import(module)
  return .ForeignPythonModule~new(raw[1],raw[2])
::method bytes class
  use strict arg value
  return .ForeignPythonBytes~new(value)
::method text class
  use strict arg value
  return .ForeignPythonText~new(value)
::method integer class
  use strict arg value
  return .ForeignPythonInteger~new(value)
::method float class
  use strict arg value
  return .ForeignPythonFloat~new(value)
::method dict class; return .ForeignPythonDict~new
::method keywords class; return .ForeignPythonKeywords~new

::requires 'foreign.cls'
::requires 'foreign_python' library
