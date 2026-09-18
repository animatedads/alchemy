/* Hercules printer-output edge adapter for WebDAV/Storage Fabric.
 * Converts a Hercules 1403/3211 host-file representation into canonical
 * PAPER_LISTING records. It does not control Hercules devices.
 */
::class WebDavHerculesPaperBuild public
::constant VERSION '0.1-dev3'
::constant API 'webdav.hercules-paper/0.1'

::class WebDavHerculesPaperBridge public
::method importPrinterFile class
  use arg mediaIdArg, pathArg, sourceRefArg=.nil
  path=pathArg~string
  if path='' then raise syntax 88.900 array('printer path is mandatory')
  if stream(path,'c','query exists')='' then raise syntax 88.900 array('printer path does not exist',path)
  size=stream(path,'c','query size')+0
  if size>0 then payload=charin(path,1,size); else payload=''
  call stream path,'c','close'
  return self~importPrinterBytes(mediaIdArg,payload,sourceRefArg)

::method importPrinterBytes class
  use arg mediaIdArg, payloadArg, sourceRefArg=.nil
  listing=.StoragePaperListingCodec~newListing(mediaIdArg,.StorageSequentialMediaEncoding~ASCII,sourceRefArg)
  s=payloadArg~string~changestr('0D0A'x,'0A'x)~changestr('0D'x,'0A'x)
  buf=''
  do i=1 to s~length
    c=s~substr(i,1)
    select
      when c='0C'x then do
        if buf<>'' then do; .StoragePaperListingCodec~addLine(listing,buf); buf=''; end
        .StoragePaperListingCodec~pageBreak(listing)
      end
      when c='0A'x then do
        .StoragePaperListingCodec~addLine(listing,buf); buf=''
      end
      otherwise buf=buf||c
    end
  end
  if buf<>'' then .StoragePaperListingCodec~addLine(listing,buf)
  return listing

::method publishToWebDav class
  use arg adapterArg, pathArg, mediaIdArg, printerPathArg, ifMatchArg=''
  image=self~importPrinterFile(mediaIdArg,printerPathArg)
  return adapterArg~putSequentialMedia(pathArg,image,'application/vnd.oorexx.storage.sequential-media',ifMatchArg,'')

::requires 'StorageSequentialMedia.cls'
::requires 'WebDavCore.cls'
