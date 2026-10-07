parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
provider=.LinuxRawGadgetProvider~new('dummy_udc','dummy_udc.0','HIGH','/definitely/not/a/raw-gadget-node')
device=.VirtualUsbDevice~fromProfile(profile,provider)
if device~present then do
  say 'FAIL raw-gadget missing-node presentation unexpectedly succeeded'
  exit 1
end
err=provider~lastPresentationError
if err==.nil then do
  say 'FAIL raw-gadget presentation failure did not retain diagnostics'
  exit 2
end
if err['operation']<>'OPEN' then do
  say 'FAIL raw-gadget presentation operation expected OPEN got' err['operation']
  exit 3
end
if err['errno']=0 then do
  say 'FAIL raw-gadget presentation errno was not retained'
  exit 4
end
say 'VIRTUAL USB RAW GADGET PRESENTATION ERROR: OK errno='err['errno']
exit 0
::requires 'UsbDeviceProfiles.cls'
::requires 'LinuxRawGadgetProvider.cls'
