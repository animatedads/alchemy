/* Local executable example of the same protocol used between Storage peers. */
source=arg(1); target=arg(2)
if source="" | target="" then do
  say "usage: rexx examples/peer_transfer.rex SOURCE TARGET"
  exit 2
end
ver=.StoragePosixSha256Verifier~new
digest=ver~digestFile(source)
if digest="" then do; say "cannot digest source"; exit 3; end
size=stream(source,"c","query size")+0
ref=.StorageRef~new("example:"||filespec("N",source),"sha256:"||digest)
registry=.StoragePeerExportRegistry~new
registry~publish(.StoragePeerExport~new(ref,size,.StoragePeerLocalFileSourceFactory~new(source)))
transport=.StoragePeerInProcessTransport~new~bind("ED209B",.StoragePeerService~new("ED209B",registry))
client=.StoragePeerClient~new("ED209A",transport)
r=.StoragePeerMaterialiser~new~materialise(client,"ED209B",ref,target)
say "storageRef=" ref~objectId ref~digest
say "result=" r~ok r~code "bytes="r~bytes
if r~ok then do
  cat=.StorageCatalogue~new
  a=.StoragePeerReplicaAdmission~new~admit(cat,"ED209A",r,"peer-cache","example-workspace")
  say "admission=" a~ok a~code "durable="a~location~countsAsDurable
end
exit (r~ok<>.true)
::requires "StoragePeer.cls"
