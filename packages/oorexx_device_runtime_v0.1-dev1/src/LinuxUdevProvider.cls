/*----------------------------------------------------------------------------*/
/* Linux libudev provider for ooRexx Device Runtime v0.1-dev1                 */
/* Native calls are described entirely through Foreign Runtime metadata.       */
/*----------------------------------------------------------------------------*/

::class LinuxUdevNative private

::method configure class
  expose udevBridge pollBridge udevLib pollLib
  use strict arg udevPath, pollPath
  if symbol('udevLib')='VAR' | symbol('pollLib')='VAR' then raise syntax 40.900 array('LinuxUdevNative already loaded')
  udevBridge=udevPath
  pollBridge=pollPath
  return 0

::method udev class unguarded
  expose udevBridge udevLib
  if symbol('udevLib')<>'VAR' then do
    if symbol('udevBridge')<>'VAR' then do
      udevBridge=value('OOREXX_DEVICE_UDEV_BRIDGE',,'ENVIRONMENT')
      if udevBridge=='' then do
        parse source . . sourceFile
        udevBridge=filespec('location',sourceFile)||'../bridge/libudev.bridge.json'
      end
    end
    udevLib=.foreign~load(udevBridge)
    info=.foreign~runtimeInfo
    if \udevLib~abiQualified | udevLib~abiProfile<>info~abiProfile then raise syntax 40.900 array('libudev bridge is not qualified for ABI '||info~abiProfile)
  end
  return udevLib

::method poll class unguarded
  expose pollBridge pollLib
  if symbol('pollLib')<>'VAR' then do
    if symbol('pollBridge')<>'VAR' then do
      pollBridge=value('OOREXX_DEVICE_POLL_BRIDGE',,'ENVIRONMENT')
      if pollBridge=='' then do
        parse source . . sourceFile
        pollBridge=filespec('location',sourceFile)||'../bridge/libc-poll.bridge.json'
      end
    end
    pollLib=.foreign~load(pollBridge)
    info=.foreign~runtimeInfo
    if \pollLib~abiQualified | pollLib~abiProfile<>info~abiProfile then raise syntax 40.900 array('poll bridge is not qualified for ABI '||info~abiProfile)
  end
  return pollLib


::class LinuxUdevProvider public inherit DeviceProvider
::attribute context get
::attribute monitor get
::attribute monitorFd get
::attribute subsystem get

::method init
  expose context monitor monitorFd subsystem started
  lib=.LinuxUdevNative~udev
  context=lib~udev_new
  if context==.nil then raise syntax 40.900 array('udev_new failed')
  monitor=.nil
  monitorFd=-1
  subsystem=''
  started=.false

::method providerId
  return 'linux-udev'

::method _text private
  use strict arg value
  if value==.nil then return ''
  return value~string

::method _properties private
  use strict arg nativeDevice
  lib=.LinuxUdevNative~udev
  props=.directory~new
  entry=lib~udev_device_get_properties_list_entry(nativeDevice)
  do while entry<>.nil
    name=lib~udev_list_entry_get_name(entry)
    value=lib~udev_list_entry_get_value(entry)
    if name<>.nil then do
      if value==.nil then props[name~string]=''
      else props[name~string]=value~string
    end
    entry=lib~udev_list_entry_get_next(entry)
  end
  return props

::method _identity private
  expose context
  use strict arg nativeDevice
  lib=.LinuxUdevNative~udev
  syspath=self~_text(lib~udev_device_get_syspath(nativeDevice))
  subsystem=self~_text(lib~udev_device_get_subsystem(nativeDevice))
  sysname=self~_text(lib~udev_device_get_sysname(nativeDevice))
  devnode=self~_text(lib~udev_device_get_devnode(nativeDevice))
  devtype=self~_text(lib~udev_device_get_devtype(nativeDevice))
  key=syspath
  if key=='' then key=subsystem||':'||sysname
  return .DeviceIdentity~new(key,self~providerId,subsystem,sysname,syspath,devnode,devtype,self~_properties(nativeDevice))

::method enumerate
  expose context
  use strict arg subsystemFilter=''
  lib=.LinuxUdevNative~udev
  enum=lib~udev_enumerate_new(context)
  if enum==.nil then return .array~new
  if subsystemFilter<>'' then do
    rc=lib~udev_enumerate_add_match_subsystem(enum,subsystemFilter)
    if rc<0 then do; enum~close; return .array~new; end
  end
  rc=lib~udev_enumerate_scan_devices(enum)
  out=.array~new
  if rc>=0 then do
    entry=lib~udev_enumerate_get_list_entry(enum)
    do while entry<>.nil
      syspath=lib~udev_list_entry_get_name(entry)
      if syspath<>.nil then do
        dev=lib~udev_device_new_from_syspath(context,syspath)
        if dev<>.nil then do
          out~append(self~_identity(dev))
          dev~close
        end
      end
      entry=lib~udev_list_entry_get_next(entry)
    end
  end
  enum~close
  return out

::method start
  expose context monitor monitorFd subsystem started
  use strict arg subsystemFilter=''
  if started then return .true
  lib=.LinuxUdevNative~udev
  monitor=lib~udev_monitor_new_from_netlink(context,'udev')
  if monitor==.nil then return .false
  subsystem=subsystemFilter~string
  if subsystem<>'' then do
    rc=lib~udev_monitor_filter_add_match_subsystem_devtype(monitor,subsystem,.nil)
    if rc<0 then do; monitor~close; monitor=.nil; return .false; end
  end
  rc=lib~udev_monitor_enable_receiving(monitor)
  if rc<0 then do; monitor~close; monitor=.nil; return .false; end
  monitorFd=lib~udev_monitor_get_fd(monitor)
  if monitorFd<0 then do; monitor~close; monitor=.nil; return .false; end
  started=.true
  return .true

::method pollEvent
  expose monitor monitorFd started
  use strict arg timeoutMs=0
  if \started then do
    if \self~start then return .nil
  end
  if timeoutMs~datatype('W')<>1 | timeoutMs < -1 then raise syntax 93.905 array('timeoutMs',timeoutMs)
  pollLib=.LinuxUdevNative~poll
  fds=pollLib~structArray('pollfd',1)
  fds~set(1,'fd',monitorFd)
  fds~set(1,'events',pollLib~constant('POLLIN')~value)
  fds~set(1,'revents',0)
  r=pollLib~invoke('posix_poll',fds,1,timeoutMs)
  if r~isA(.ForeignResult) then ready=r~returnValue
  else ready=r
  revents=fds~get(1,'revents')
  fds~close
  if ready<=0 | revents=0 then return .nil
  lib=.LinuxUdevNative~udev
  dev=lib~udev_monitor_receive_device(monitor)
  if dev==.nil then return .nil
  action=self~_text(lib~udev_device_get_action(dev))~upper
  if action=='' then action='CHANGE'
  identity=self~_identity(dev)
  dev~close
  return .DeviceEvent~new(0,action,identity,self~providerId)

::method stop
  expose monitor monitorFd started
  if monitor<>.nil then monitor~close
  monitor=.nil
  monitorFd=-1
  started=.false
  return .true

::method close
  expose context
  self~stop
  if context<>.nil then context~close
  context=.nil
  return .true

::method uninit
  self~close

::requires 'DeviceRuntime.cls'
::requires 'foreign.cls'
