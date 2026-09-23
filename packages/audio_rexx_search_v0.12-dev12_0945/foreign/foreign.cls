::class ForeignDatatype public
::method init
  expose _name _semanticKind _size _alignment _signed _carrier _pointerTo _handleKind _encoding _callingConvention
  use strict arg name, info
  _name=name
  _semanticKind=info[1]
  _size=info[2]
  _alignment=info[3]
  _signed=info[4]
  _carrier=info[5]
  _pointerTo=info[6]
  _handleKind=info[7]
  _encoding=info[8]
  _callingConvention=info[9]
::method name
  expose _name
  return _name
::method semanticKind
  expose _semanticKind
  return _semanticKind
::method size
  expose _size
  return _size
::method alignment
  expose _alignment
  return _alignment
::method signed
  expose _signed
  return _signed
::method carrier
  expose _carrier
  return _carrier
::method pointerTo
  expose _pointerTo
  return _pointerTo
::method handleKind
  expose _handleKind
  return _handleKind
::method encoding
  expose _encoding
  return _encoding
::method callingConvention
  expose _callingConvention
  return _callingConvention
::method string
  expose _name
  return _name

::class ForeignValue public
::method init
  expose _datatype _value
  use strict arg datatype, value
  if datatype~isA(.ForeignDatatype) then _datatype=datatype
  else _datatype=.foreign~datatype(datatype)
  _value=value
::method datatype
  expose _datatype
  return _datatype
::method datatypeName
  expose _datatype
  return _datatype~name
::method value
  expose _value
  return _value
::method string
  expose _value
  return _value
::method unknown
  expose _value
  use strict arg name, args
  return _value~sendWith(name,args)

::class ForeignBuffer public
::method init
  expose _handle _closed
  use strict arg size=0, existingHandle=0
  if existingHandle=0 then _handle=rexx_foreign_buffer_create(size)
  else _handle=existingHandle
  _closed=.false
::method fromHandle class
  use strict arg handle
  return self~new(0,handle)
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return '@foreign-buffer:'_handle
::method handle
  expose _handle
  return _handle
::method size
  expose _handle _closed
  if _closed then return 0
  return rexx_foreign_buffer_size(_handle)
::method readonly
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_readonly(_handle)
::method hex
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_hex(_handle)
::method bytes
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_bytes(_handle)
::method u32
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_u32(_handle)
::method getBytes
  expose _handle _closed
  use strict arg offset, size
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_get_bytes(_handle,offset,size)
::method putBytes
  expose _handle _closed
  use strict arg offset, data
  if _closed then raise syntax 40.900 array('Foreign buffer is closed')
  return rexx_foreign_buffer_put_bytes(_handle,offset,data~string)
::method addressSpace
  return 'host'
::method closed
  expose _closed
  return _closed
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_buffer_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_buffer_close _handle
::method string
  return self~token


::class ForeignStruct public
::method init
  expose _library _handle _name _closed
  use arg library, name, source
  _library=library
  _name=name
  if arg(3,'O') then _handle=rexx_foreign_struct_create(library~handle,name)
  else _handle=rexx_foreign_struct_view(library~handle,name,source~string)
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign struct is closed')
  return '@foreign-struct:'_handle
::method handle
  expose _handle
  return _handle
::method name
  expose _name
  return _name
::method size
  expose _handle _closed
  if _closed then return 0
  return rexx_foreign_struct_info(_handle)[2]
::method alignment
  expose _handle _closed
  if _closed then return 0
  return rexx_foreign_struct_info(_handle)[3]
::method fields
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign struct is closed')
  return rexx_foreign_struct_info(_handle)[4]
::method get
  expose _handle _closed
  use strict arg field
  if _closed then raise syntax 40.900 array('Foreign struct is closed')
  return rexx_foreign_struct_get(_handle,field)
::method set
  expose _handle _closed
  use strict arg field, value
  if _closed then raise syntax 40.900 array('Foreign struct is closed')
  if value==.nil then marshalled='@foreign-null'
  else if value~isA(.ForeignBuffer) then marshalled=value~token
  else if value~isA(.ForeignObject) then marshalled=value~token
  else if value~isA(.ForeignStruct) then marshalled=value~token
  else if value~isA(.ForeignPointerArray) then marshalled=value~token
  else if value~isA(.ForeignStructArray) then marshalled=value~token
  else marshalled=value~string
  call rexx_foreign_struct_set _handle,field,marshalled
  return self
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_struct_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_struct_close _handle
::method string
  return self~token

::class ForeignStructArray public
::method init
  expose _library _handle _name _count _closed
  use strict arg library, name, count
  _library=library
  _name=name
  _count=count
  _handle=rexx_foreign_struct_array_create(library~handle,name,count)
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign struct array is closed')
  return '@foreign-struct-array:'_handle
::method count
  expose _handle _closed
  if _closed then return 0
  return rexx_foreign_struct_array_count(_handle)
::method get
  expose _handle _closed
  use strict arg index, field
  if _closed then raise syntax 40.900 array('Foreign struct array is closed')
  return rexx_foreign_struct_array_get(_handle,index,field)
::method set
  expose _handle _closed
  use strict arg index, field, value
  if _closed then raise syntax 40.900 array('Foreign struct array is closed')
  call rexx_foreign_struct_array_set _handle,index,field,value~string
  return self
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_struct_array_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_struct_array_close _handle
::method string
  return self~token

::class ForeignPointerArray public
::method init
  expose _handle _count _elementType _closed
  use strict arg count, elementType='pointer'
  _count=count
  _elementType=elementType
  _handle=rexx_foreign_pointer_array_create(count,elementType)
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign pointer array is closed')
  return '@foreign-pointer-array:'_handle
::method handle
  expose _handle
  return _handle
::method size
  expose _handle _closed
  if _closed then return 0
  return rexx_foreign_pointer_array_size(_handle)
::method elementType
  expose _elementType
  return _elementType
::method put
  expose _handle _closed
  use strict arg value,index
  if _closed then raise syntax 40.900 array('Foreign pointer array is closed')
  if value==.nil then token='@foreign-null'
  else if value~isA(.ForeignBuffer) then token=value~token
  else if value~isA(.ForeignObject) then token=value~token
  else raise syntax 40.900 array('Pointer array requires ForeignBuffer, ForeignObject, or .nil')
  call rexx_foreign_pointer_array_set _handle,index,token
  return self
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_pointer_array_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_pointer_array_close _handle
::method string
  return self~token

::class ForeignHandle public
::method init
  expose _handle _type _carrier _ownership _value _closed
  use strict arg handle, type, carrier, ownership, value
  _handle=handle
  _type=type
  _carrier=carrier
  _ownership=ownership
  _value=value
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign handle is closed')
  return '@foreign-handle:'_handle
::method handle
  expose _handle
  return _handle
::method type
  expose _type
  return _type
::method carrier
  expose _carrier
  return .foreign~datatype(_carrier)
::method ownership
  expose _ownership
  return _ownership
::method value
  expose _value _closed
  if _closed then raise syntax 40.900 array('Foreign handle is closed')
  return _value
::method closed
  expose _closed
  return _closed
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_handle_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_handle_close _handle
::method string
  return self~token

::class ForeignObject public
::method init
  expose _handle _type _ownership _addressSpace _byteLength _closed
  use strict arg handle, type, ownership, addressSpace='host', byteLength=0
  _handle=handle
  _type=type
  _ownership=ownership
  _addressSpace=addressSpace
  _byteLength=byteLength
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign object is closed')
  return '@foreign-object:'_handle
::method handle
  expose _handle
  return _handle
::method type
  expose _type
  return _type
::method ownership
  expose _ownership
  return _ownership
::method addressSpace
  expose _addressSpace
  return _addressSpace
::method byteLength
  expose _byteLength
  return _byteLength
::method closed
  expose _closed
  return _closed
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_object_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_object_close _handle
::method string
  return self~token


::class ForeignParameter public
::method init
  expose _type _direction _objectType _name _size _resultType _pointerDepth _ownership _destructor _destructorPointerDepth _addressSpace _byteLength _callbackType _resourceType _resourceCarrier _invalid _outputsOnReturn
  use strict arg info
  _type=.foreign~datatype(info[1])
  _direction=info[2]
  _objectType=info[3]
  _name=info[4]
  _size=info[5]
  _resultType=info[6]
  _pointerDepth=info[7]
  _ownership=info[8]
  _destructor=info[9]
  _destructorPointerDepth=info[10]
  _addressSpace=info[11]
  _byteLength=info[12]
  _callbackType=info[13]
  _resourceType=info[14]
  _resourceCarrier=info[15]
  _invalid=info[16]
  _outputsOnReturn=info[17]
::method type
  expose _type
  return _type
::method typeName
  expose _type
  return _type~name
::method direction
  expose _direction
  return _direction
::method objectType
  expose _objectType
  return _objectType
::method name
  expose _name
  return _name
::method size
  expose _size
  return _size
::method resultType
  expose _resultType
  return _resultType
::method pointerDepth
  expose _pointerDepth
  return _pointerDepth
::method ownership
  expose _ownership
  return _ownership
::method destructor
  expose _destructor
  return _destructor
::method destructorPointerDepth
  expose _destructorPointerDepth
  return _destructorPointerDepth
::method string
  expose _type _direction _objectType
  text=_type~name
  if _objectType<>'' then text=text'<'_objectType'>'
  if _direction<>'in' then text=text'['_direction']'
  return text

::method addressSpace
  expose _addressSpace
  return _addressSpace
::method byteLength
  expose _byteLength
  return _byteLength
::method callbackType
  expose _callbackType
  return _callbackType
::method resourceType
  expose _resourceType
  return _resourceType
::method resourceCarrier
  expose _resourceCarrier
  return _resourceCarrier
::method invalid
  expose _invalid
  return _invalid
::method outputsOnReturn
  expose _outputsOnReturn
  return _outputsOnReturn

::class ForeignSignature public
::method init
  expose _name _symbol _inputs _returnType _returnObjectType _ownership _callingConvention _destructor _destructorPointerDepth _addressSpace _byteLength _capturesErrno _returnResourceType _returnResourceCarrier _invalid
  use strict arg info
  _name=info[1]
  _symbol=info[2]
  _inputs=.array~new
  rawInputs=info[3]
  do i=1 to rawInputs~items
    _inputs~append(.ForeignParameter~new(rawInputs[i]))
  end
  _returnType=.foreign~datatype(info[4])
  _returnObjectType=info[5]
  _ownership=info[6]
  _callingConvention=info[7]
  _destructor=info[8]
  _destructorPointerDepth=info[9]
  _addressSpace=info[10]
  _byteLength=info[11]
  _capturesErrno=info[12]
  _returnResourceType=info[13]
  _returnResourceCarrier=info[14]
  _invalid=info[15]
::method name
  expose _name
  return _name
::method symbol
  expose _symbol
  return _symbol
::method inputs
  expose _inputs
  return _inputs
::method inputCount
  expose _inputs
  return _inputs~items
::method returnType
  expose _returnType
  return _returnType
::method returnTypeName
  expose _returnType
  return _returnType~name
::method returnObjectType
  expose _returnObjectType
  return _returnObjectType
::method ownership
  expose _ownership
  return _ownership
::method callingConvention
  expose _callingConvention
  return _callingConvention
::method destructor
  expose _destructor
  return _destructor
::method destructorPointerDepth
  expose _destructorPointerDepth
  return _destructorPointerDepth
::method addressSpace
  expose _addressSpace
  return _addressSpace
::method byteLength
  expose _byteLength
  return _byteLength
::method capturesErrno
  expose _capturesErrno
  return _capturesErrno
::method returnResourceType
  expose _returnResourceType
  return _returnResourceType
::method returnResourceCarrier
  expose _returnResourceCarrier
  return _returnResourceCarrier
::method invalid
  expose _invalid
  return _invalid
::method string
  expose _name _symbol _inputs _returnType _returnObjectType
  args=''
  do i=1 to _inputs~items
    if i>1 then args=args', '
    args=args||_inputs[i]~string
  end
  ret=_returnType~name
  if _returnObjectType<>'' then ret=ret'<'_returnObjectType'>'
  return _name'('args') -> 'ret' ['_symbol']'

::class ForeignMethod public
::method init
  expose _library _name _signatures
  use strict arg library, name, signatures
  _library=library
  _name=name
  _signatures=signatures
::method name
  expose _name
  return _name
::method signatures
  expose _signatures
  return _signatures
::method overloadCount
  expose _signatures
  return _signatures~items
::method string
  expose _name
  return _name

::class ForeignResult public
::method init
  expose _returnValue _names _values _errno _errorMessage
  use strict arg returnValue, rawOutputs, errno=0, errorMessage=''
  _errno=errno
  _errorMessage=errorMessage
  _returnValue=returnValue
  _names=.array~new
  _values=.array~new
  do i=1 to rawOutputs~items
    q=rawOutputs[i]
    name=q[1]
    kind=q[2]
    if kind='handle' then do
      raw=q[3]
      value=.ForeignHandle~new(raw[2],raw[3],raw[4],raw[5],raw[6])
    end
    else if kind='object' then do
      raw=q[3]
      if raw==.nil then value=.nil
      else value=.ForeignObject~new(raw[2],raw[3],raw[4],raw[5],raw[6])
    end
    else do
      b=.ForeignBuffer~fromHandle(q[3])
      if kind='u32' then do
        value=b~u32
        b~close
      end
      else value=b
    end
    _names~append(name)
    _values~append(value)
  end
::method returnValue
  expose _returnValue
  return _returnValue
::method out
  expose _names _values
  use strict arg name
  do i=1 to _names~items
    if _names[i]~caselessCompare(name)=0 then return _values[i]
  end
  raise syntax 40.900 array('Unknown foreign output',name)
::method outputNames
  expose _names
  return _names
::method outputs
  expose _values
  return _values
::method errno
  expose _errno
  return _errno
::method errorMessage
  expose _errorMessage
  return _errorMessage
::method string
  expose _returnValue
  return _returnValue~string

::class ForeignLibrary public
::method init
  expose _handle _methodCache _methodsCache _signaturesCache
  use strict arg definition
  _handle=rexx_foreign_load_definition(definition)
  _methodCache=.directory~new
  _methodsCache=.array~new
  _signaturesCache=.array~new
  names=rexx_foreign_method_names(_handle)
  do i=1 to names~items
    name=names[i]
    raw=rexx_foreign_method_signatures(_handle,name)
    sigs=.array~new
    do j=1 to raw~items
      sig=.ForeignSignature~new(raw[j])
      sigs~append(sig)
      _signaturesCache~append(sig)
    end
    method=.ForeignMethod~new(self,name,sigs)
    _methodCache[name~upper]=method
    _methodsCache~append(method)
  end
::method handle unguarded
  expose _handle
  return _handle
::method _marshalArray unguarded
  use strict arg args
  marshalled=.array~new
  do i=1 to args~items
    x=args[i]
    if x==.nil then marshalled~append('@foreign-null')
    else if x~isA(.ForeignBuffer) then marshalled~append(x~token)
    else if x~isA(.ForeignObject) then marshalled~append(x~token)
    else if x~isA(.ForeignHandle) then marshalled~append(x~token)
    else if x~isA(.ForeignStruct) then marshalled~append(x~token)
    else if x~isA(.ForeignPointerArray) then marshalled~append(x~token)
    else if x~isA(.ForeignStructArray) then marshalled~append(x~token)
    else if x~isA(.ForeignCallback) then marshalled~append(x~token)
    else if x~isA(.ForeignOut) then marshalled~append('@foreign-out')
    else marshalled~append(x~string)
  end
  return marshalled
::method invoke unguarded
  use strict arg name, ...
  a=.array~new
  do i=2 to arg()
    a~append(arg(i))
  end
  return self~invokeArray(name,a)
::method invokeArray unguarded
  use strict arg name, args
  marshalled=self~_marshalArray(args)
  raw=rexx_foreign_invoke(self~handle,name,marshalled)
  if raw~isA(.array) then do
    if raw~items>=4 then if raw[1]='__foreign_object__' then return .ForeignObject~new(raw[2],raw[3],raw[4],raw[5],raw[6])
    if raw~items>=5 then if raw[1]='__foreign_handle__' then return .ForeignHandle~new(raw[2],raw[3],raw[4],raw[5],raw[6])
    if raw~items>=3 then if raw[1]='__foreign_result__' then do
      rv=raw[2]
      if rv~isA(.array) then do
        if rv~items>=4 then if rv[1]='__foreign_object__' then rv=.ForeignObject~new(rv[2],rv[3],rv[4],rv[5],rv[6])
        if rv~items>=5 then if rv[1]='__foreign_handle__' then rv=.ForeignHandle~new(rv[2],rv[3],rv[4],rv[5],rv[6])
      end
      return .ForeignResult~new(rv,raw[3],raw[4],raw[5])
    end
  end
  return raw
::method unknown unguarded
  use strict arg name, args
  if rexx_foreign_function_exists(self~handle,name) then return self~invokeArray(name,args)
  raise syntax 97.1 array(name)
::method provider unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[1]
::method requestedProvider unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[2]
::method providerPath unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[3]
::method definitionPath unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[4]
::method threadingMode unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[5]
::method affinity unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[6]
::method abiProfile unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[7]
::method abiQualified unguarded
  info=rexx_foreign_library_info(self~handle)
  return info[8]
::method methods unguarded
  expose _methodsCache
  return _methodsCache
::method method unguarded
  expose _methodCache
  use strict arg name
  method=_methodCache[name~upper]
  if method==.nil then raise syntax 40.900 array('Unknown foreign method',name)
  return method
::method signatures unguarded
  expose _signaturesCache
  return _signaturesCache
::method methodByInputs unguarded
  use strict arg name, ...
  a=.array~new
  do i=2 to arg()
    a~append(arg(i))
  end
  method=self~method(name)
  index=rexx_foreign_method_by_inputs_index(self~handle,name,self~_marshalArray(a))
  return method~signatures[index]
::method constant unguarded
  use strict arg name
  raw=rexx_foreign_constant_raw(self~handle,name)
  return .ForeignValue~new(.foreign~datatype(raw[1]),raw[2])
::method datatype unguarded
  use strict arg name
  return .foreign~datatype(name)
::method struct unguarded
  use strict arg name
  return .ForeignStruct~new(self,name)
::method structView unguarded
  use strict arg name, source
  return .ForeignStruct~new(self,name,source)
::method structTypes unguarded
  return rexx_foreign_struct_type_names(self~handle)
::method structArray unguarded
  use strict arg name, count
  return .ForeignStructArray~new(self,name,count)
::method pointerArray unguarded
  use strict arg count, elementType='pointer'
  return .ForeignPointerArray~new(count,elementType)
::method callbacks unguarded
  return rexx_foreign_callback_names(self~handle)
::method callback unguarded
  use strict arg name, target, method='call'
  return .ForeignCallback~new(self,name,target,method)
::method close unguarded
  call rexx_foreign_close self~handle


::class ForeignCallback public
::method init
  expose _library _handle _name _target _method _closed
  use strict arg library, name, target, method='call'
  _library=library
  _name=name
  _target=target
  _method=method
  _handle=rexx_foreign_callback_create(library~handle,name,target,method)
  _closed=.false
::method token
  expose _handle _closed
  if _closed then raise syntax 40.900 array('Foreign callback is closed')
  return '@foreign-callback:'_handle
::method name
  expose _name
  return _name
::method info
  expose _library _name
  return rexx_foreign_callback_info(_library~handle,_name)
::method returnType
  return .foreign~datatype(self~info[2])
::method inputs
  return self~info[3]
::method threadPolicy
  return self~info[4]
::method lifetime
  return self~info[5]
::method close
  expose _handle _closed
  if \_closed then do
    call rexx_foreign_callback_close _handle
    _closed=.true
  end
::method uninit
  expose _handle _closed
  if symbol('_closed')='VAR' then if \_closed then call rexx_foreign_callback_close _handle
::method string
  return self~token

::class ForeignOut public
::method string
  return '@foreign-out'

::class foreign public
::method load class
  use strict arg definition
  return .ForeignLibrary~new(definition)
::method buffer class
  use strict arg size
  return .ForeignBuffer~new(size)
::method out class
  return .ForeignOut~new
::method structArray class
  use strict arg library, name, count
  return .ForeignStructArray~new(library,name,count)
::method pointerArray class
  use strict arg count, elementType='pointer'
  return .ForeignPointerArray~new(count,elementType)
::method pointerAt class
  use strict arg address, index=0
  return rexx_foreign_pointer_at(address,index)
::method peekBytes class
  use strict arg address, size
  return rexx_foreign_peek_bytes(address,size)
::method constant class
  use strict arg name
  raw=rexx_foreign_constant_raw(,name)
  return .ForeignValue~new(.foreign~datatype(raw[1]),raw[2])
::method datatype class
  use strict arg name
  info=rexx_foreign_datatype_info(name)
  if info==.nil then raise syntax 40.900 array('Unknown foreign datatype',name)
  return .ForeignDatatype~new(name,info)
::method datatypes class
  return rexx_foreign_datatype_names()
::method runtimeInfo class
  return .ForeignRuntimeDescriptor~new(rexx_foreign_runtime_info())
::method capabilities class
  return rexx_foreign_runtime_capabilities()
::method qualifiedAbiProfiles class
  return rexx_foreign_qualified_abi_profiles()

::class ForeignRuntimeDescriptor public
::method init
  expose _runtimeVersion _requiredInterpreter _interpreterVersion _languageLevel _packageApi _pointerSize _platform _loader _boundary _compiler _endianness _maxArity _requiredInterpreterRaw _interpreterVersionRaw _nativeDispatcher _abiProfile _abiQualified _architecture _dataModel _osFamily
  use strict arg info
  _runtimeVersion=info[1]
  _requiredInterpreter=info[2]
  _interpreterVersion=info[3]
  _languageLevel=info[4]
  _packageApi=info[5]
  _pointerSize=info[6]
  _platform=info[7]
  _loader=info[8]
  _boundary=info[9]
  _compiler=info[10]
  _endianness=info[11]
  _maxArity=info[12]
  _requiredInterpreterRaw=info[13]
  _interpreterVersionRaw=info[14]
  _nativeDispatcher=info[15]
  _abiProfile=info[16]
  _abiQualified=info[17]
  _architecture=info[18]
  _dataModel=info[19]
  _osFamily=info[20]
::method runtimeVersion
  expose _runtimeVersion
  return _runtimeVersion
::method requiredInterpreter
  expose _requiredInterpreter
  return _requiredInterpreter
::method interpreterVersion
  expose _interpreterVersion
  return _interpreterVersion
::method languageLevel
  expose _languageLevel
  return _languageLevel
::method packageApi
  expose _packageApi
  return _packageApi
::method pointerSize
  expose _pointerSize
  return _pointerSize
::method platform
  expose _platform
  return _platform
::method loader
  expose _loader
  return _loader
::method boundary
  expose _boundary
  return _boundary
::method compiler
  expose _compiler
  return _compiler
::method endianness
  expose _endianness
  return _endianness
::method maxArity
  expose _maxArity
  return _maxArity
::method nativeDispatcher
  expose _nativeDispatcher
  return _nativeDispatcher
::method requiredInterpreterRaw
  expose _requiredInterpreterRaw
  return _requiredInterpreterRaw
::method interpreterVersionRaw
  expose _interpreterVersionRaw
  return _interpreterVersionRaw
::method abiProfile
  expose _abiProfile
  return _abiProfile
::method abiQualified
  expose _abiQualified
  return _abiQualified
::method architecture
  expose _architecture
  return _architecture
::method dataModel
  expose _dataModel
  return _dataModel
::method osFamily
  expose _osFamily
  return _osFamily

::requires 'foreign_runtime' library
