/*----------------------------------------------------------------------------*/
/* ooRexx Virtual USB v0.1-dev3 - declarative device/profile loader.          */
/*----------------------------------------------------------------------------*/

::class UsbDeviceProfile public
::attribute schema get
::attribute sourceId get
::attribute definition get
::attribute metadata get

::method init
  expose schema sourceId definition metadata
  use strict arg schemaArg, sourceIdArg, definitionArg, metadataArg=.nil
  schema=schemaArg~string
  sourceId=sourceIdArg~string
  definition=definitionArg
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg

::class UsbDeviceProfileLoader public

::method loadFile class
  use strict arg filename
  return self~fromDocument(.json~fromJsonFile(filename))

::method fromDocument class
  use strict arg doc
  if doc==.nil | \doc~isA(.Directory) then raise syntax 93.900 array('USB device profile must be a JSON object')

  schema=self~get(doc,'schema','')~string
  if schema<>'oorexx.virtual.usb.device/0.2' & schema<>'oorexx.virtual.usb.device/0.3' then raise syntax 93.900 array('unsupported USB device profile schema '||schema)
  sourceId=self~get(doc,'sourceId','')~string
  if sourceId='' then raise syntax 93.900 array('USB device profile sourceId is required')

  d=self~get(doc,'device',.nil)
  if d==.nil then raise syntax 93.900 array('USB device profile device object is required')

  descriptor=.UsbDeviceDescriptor~new( -
      self~number(self~get(d,'vendorId',.nil)), -
      self~number(self~get(d,'productId',.nil)), -
      self~number(self~get(d,'bcdUSB',512)), -
      self~number(self~get(d,'bcdDevice',256)), -
      self~number(self~get(d,'class',0)), -
      self~number(self~get(d,'subclass',0)), -
      self~number(self~get(d,'protocol',0)), -
      self~number(self~get(d,'maxPacketSize0',64)), -
      self~number(self~get(d,'manufacturerIndex',1)), -
      self~number(self~get(d,'productIndex',2)), -
      self~number(self~get(d,'serialIndex',3)), -
      self~number(self~get(d,'configurations',1)))

  definition=.UsbDeviceDefinition~new(descriptor)

  strings=self~get(doc,'strings',.nil)
  if strings<>.nil then do item over strings
    definition~string(self~number(self~get(item,'index',.nil)),self~get(item,'value',''))
  end

  configs=self~get(doc,'configurations',.nil)
  if configs==.nil then raise syntax 93.900 array('USB device profile configurations are required')

  do cfgDoc over configs
    cfg=.UsbConfigurationDefinition~new( -
      self~number(self~get(cfgDoc,'value',1)), -
      self~get(cfgDoc,'name','default'), -
      self~number(self~get(cfgDoc,'stringIndex',0)), -
      self~number(self~get(cfgDoc,'attributes',128)), -
      self~number(self~get(cfgDoc,'maxPowerMa',100)))
    definition~addConfiguration(cfg)

    /* Direct interfaces remain supported for devices which do not need a
       higher semantic function grouping. */
    direct=self~get(cfgDoc,'interfaces',.nil)
    if direct<>.nil then do intfDoc over direct
      cfg~addInterface(self~interfaceFromDocument(intfDoc))
    end

    functions=self~get(cfgDoc,'functions',.nil)
    if functions<>.nil then do fnDoc over functions
      fn=.UsbFunctionDefinition~new(self~get(fnDoc,'name',''),cfg~value)
      if fn~name='' then raise syntax 93.900 array('USB function name is required')
      intfs=self~get(fnDoc,'interfaces',.nil)
      if intfs==.nil then raise syntax 93.900 array('USB function '||fn~name||' requires interfaces')
      do intfDoc over intfs
        fn~addInterface(self~interfaceFromDocument(intfDoc))
      end
      controls=self~get(fnDoc,'controls',.nil)
      if controls<>.nil then do ctrlDoc over controls
        fn~addControl(self~controlFromDocument(ctrlDoc,fn~name))
      end
      definition~addFunction(fn)
    end
  end

  /* Device-wide or explicitly interface-scoped controls. */
  controls=self~get(doc,'controls',.nil)
  if controls<>.nil then do ctrlDoc over controls
    definition~controlMap~add(self~controlFromDocument(ctrlDoc,''))
  end

  metadata=self~get(doc,'metadata',.directory~new)
  return .UsbDeviceProfile~new(schema,sourceId,definition,metadata)

::method interfaceFromDocument class private
  use strict arg doc
  name=self~get(doc,'name','')~string
  if name='' then raise syntax 93.900 array('USB interface name is required')
  intf=.UsbInterfaceDefinition~new( -
    name, -
    self~number(self~get(doc,'number',.nil)), -
    self~number(self~get(doc,'class',255)), -
    self~number(self~get(doc,'subclass',0)), -
    self~number(self~get(doc,'protocol',0)), -
    self~number(self~get(doc,'alternateSetting',0)), -
    self~number(self~get(doc,'stringIndex',0)))
  hid=self~get(doc,'hid',.nil)
  if hid<>.nil then do
    reportHex=self~get(hid,'reportDescriptorHex','')~string~space(0)
    if reportHex='' then raise syntax 93.900 array('HID reportDescriptorHex is required')
    report=x2c(reportHex)
    bcd=self~number(self~get(hid,'bcdHID',273))
    country=self~number(self~get(hid,'countryCode',0))
    hidDescriptor=d2c(9)||d2c(33)||.UsbBinary~u16le(bcd)||d2c(country)||d2c(1)||d2c(34)||.UsbBinary~u16le(report~length)
    intf~addDescriptor(.UsbInterfaceDescriptorDefinition~new(33,0,hidDescriptor,.true))
    intf~addDescriptor(.UsbInterfaceDescriptorDefinition~new(34,0,report,.false))
  end
  endpoints=self~get(doc,'endpoints',.nil)
  if endpoints<>.nil then do epDoc over endpoints
    ep=.UsbEndpointDefinition~new( -
      self~get(epDoc,'name',''), -
      self~number(self~get(epDoc,'address',.nil)), -
      self~get(epDoc,'transferType','BULK'), -
      self~number(self~get(epDoc,'maxPacketSize',64)), -
      self~number(self~get(epDoc,'interval',0)))
    if ep~name='' then raise syntax 93.900 array('USB endpoint name is required')
    intf~addEndpoint(ep)
  end
  return intf

::method controlFromDocument class private
  use strict arg doc, functionName=''
  name=self~get(doc,'name','')~string
  if name='' then raise syntax 93.900 array('USB control name is required')
  value=self~optionalNumber(doc,'value')
  index=self~optionalNumber(doc,'index')
  return .UsbControlMapEntry~new( -
    name, -
    self~number(self~get(doc,'requestType',.nil)), -
    self~number(self~get(doc,'request',.nil)), -
    value,index, -
    self~number(self~get(doc,'requestTypeMask',255)), -
    self~get(doc,'interface',''), -
    functionName)

::method optionalNumber class private
  use strict arg doc,key
  if \doc~hasIndex(key) then return .nil
  if doc[key]==.nil then return .nil
  return self~number(doc[key])

::method number class private
  use strict arg value
  if value==.nil then raise syntax 93.900 array('required numeric USB profile field is missing')
  text=value~string~strip
  if text~length>=2 & text~left(2)~upper='0X' then return x2d(text~substr(3))
  if \text~datatype('N') then raise syntax 93.900 array('invalid numeric USB profile value '||text)
  return text+0

::method get class private
  use strict arg directory,key,default=.nil
  if directory<>.nil then if directory~hasIndex(key) then return directory[key]
  return default

::requires 'UsbModel.cls'
::requires 'json.cls'
