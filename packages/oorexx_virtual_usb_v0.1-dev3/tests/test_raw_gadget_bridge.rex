provider=.LinuxRawGadgetProvider~new
bridge=provider~bridgeInfo
info=.foreign~runtimeInfo
if \bridge['abiQualified'] | bridge['abiProfile']<>info~abiProfile then do
  say 'FAIL raw-gadget ABI qualification'
  exit 1
end
if bridge['ioctlInit']<>1090606336 then do
  say 'FAIL raw-gadget ioctl constant mismatch'
  exit 2
end
if \provider~available then do
  say 'VIRTUAL USB RAW GADGET: SKIP /dev/raw-gadget unavailable; ABI bridge qualified'
  exit 0
end
say 'VIRTUAL USB RAW GADGET: AVAILABLE path='provider~path
exit 0
::requires 'LinuxRawGadgetProvider.cls'
