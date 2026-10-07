/* Live Linux Raw Gadget FIDO2 authenticator demonstration.                  */
/* The Linux USB stack is the host.  FidoTestHost is deliberately absent.   */

signal on halt name halted

parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
driver=value('OOREXX_VUSB_UDC_DRIVER',,'ENVIRONMENT')
if driver='' then driver='dummy_udc'
udc=value('OOREXX_VUSB_UDC_DEVICE',,'ENVIRONMENT')
if udc='' then udc='dummy_udc.0'
speed=value('OOREXX_VUSB_SPEED',,'ENVIRONMENT')
if speed='' then speed='HIGH'
rawPath=value('OOREXX_VUSB_RAW_GADGET_PATH',,'ENVIRONMENT')
if rawPath='' then rawPath='/dev/raw-gadget'
provider=.LinuxRawGadgetProvider~new(driver,udc,speed,rawPath)
device=.VirtualUsbDevice~fromProfile(profile,provider)
auth=.Fido2Authenticator~new(device)
observer=.RawFidoObserver~new

device~on(.VirtualUsbEvents~CONNECTED,observer,'connected','SYNC')
device~on(.VirtualUsbEvents~CONFIGURED,observer,'configured','SYNC')
device~on(.VirtualUsbEvents~RESET,observer,'reset','SYNC')
device~on(.VirtualUsbEvents~DISCONNECTED,observer,'disconnected','SYNC')
auth~on(.Fido2Events~CHANNEL_ALLOCATED,observer,'channelAllocated','SYNC')
auth~on(.Fido2Events~CREDENTIAL_CREATED,observer,'credentialCreated','SYNC')
auth~on(.Fido2Events~ASSERTION_CREATED,observer,'assertionCreated','SYNC')

if \provider~available then do
  say 'RAW FIDO2: /dev/raw-gadget is unavailable'
  exit 2
end

if \device~present then do
  err=provider~lastPresentationError
  if err<>.nil then say 'RAW FIDO2: provider presentation failed operation='err['operation'] 'errno='err['errno'] err['message']
  else say 'RAW FIDO2: provider presentation failed'
  exit 3
end

say 'RAW FIDO2: PRESENT provider='provider~providerId 'path='provider~path
say 'RAW FIDO2: UDC driver='provider~driverName 'device='provider~deviceName 'speed='provider~speed

readyFile=value('OOREXX_VUSB_READY_FILE',,'ENVIRONMENT')
if readyFile<>'' then do
  call lineout readyFile,'PRESENTED provider='||provider~providerId||' udc='||provider~deviceName
  call stream readyFile,'C','CLOSE'
end

say 'RAW FIDO2: waiting for the Linux USB host; Ctrl-C stops the presenter'

ok=provider~run
if \ok then do
  err=provider~lastEventError
  if err<>.nil then say 'RAW FIDO2: event loop stopped errno='err['errno'] err['message']
  else say 'RAW FIDO2: event loop stopped'
  provider~close
  exit 4
end
provider~close
exit 0

halted:
  if symbol('provider')='VAR' then provider~close
  say 'RAW FIDO2: stopped'
  exit 130

::class RawFidoObserver
::method connected
  use strict arg event
  say 'USB connected'
::method configured
  use strict arg event
  say 'USB configured:' event~data
::method reset
  use strict arg event
  say 'USB reset'
::method disconnected
  use strict arg event
  say 'USB disconnected'
::method channelAllocated
  use strict arg event
  say 'CTAPHID channel allocated:' event~data
::method credentialCreated
  use strict arg event
  say 'Credential created for:' event~data~rpId
::method assertionCreated
  use strict arg event
  say 'Assertion signed for:' event~data~rpId

::requires 'Fido2Authenticator.cls'
::requires 'LinuxRawGadgetProvider.cls'
