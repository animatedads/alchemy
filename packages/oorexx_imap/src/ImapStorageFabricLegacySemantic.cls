/* Legacy StorageSemantic adapter retained for older Storage Fabric consumers.
 *
 * Current Storage Fabric dev23 no longer publishes StorageSemantic.cls.
 * Requiring this file therefore intentionally requires the older optional
 * semantic-provider API.  The main IMAP Storage projection does not require it.
 */

::class ImapStorageSemanticProvider subclass StorageSemanticProvider public
::method init
  expose namespace session
  use arg namespaceArg, sessionArg=.nil
  namespace=namespaceArg; session=sessionArg
  if namespace==.nil then raise syntax 88.900 array("IMAP_STORAGE_NAMESPACE_REQUIRED")
::method resolve
  expose namespace session
  use arg basePath, selector
  resolved=namespace~resolve(basePath)
  if \resolved~found then return .nil
  obj=namespace~catalogue~get(resolved~entry~ref~objectId)
  if obj==.nil then return .nil
  head=selector~head~lower
  if selector~tailCount>0 then return .nil
  select
    when head="subject" then return .StorageSemanticResult~scalar(obj~eaValue("imap.subject"))
    when head="from" then return .StorageSemanticResult~scalar(obj~eaValue("imap.from"))
    when head="mailbox" then return .StorageSemanticResult~scalar(obj~eaValue("imap.mailbox"))
    when head="uid" then return .StorageSemanticResult~scalar(obj~eaValue("imap.uid"))
    when head="uidvalidity" then return .StorageSemanticResult~scalar(obj~eaValue("imap.uidvalidity"))
    when head="flags" then return .StorageSemanticResult~scalar(obj~eaValue("imap.flags"))
    when head="message-id" then return .StorageSemanticResult~scalar(obj~eaValue("imap.message-id"))
    when head="internal-date" then return .StorageSemanticResult~scalar(obj~eaValue("imap.internal-date"))
    when head="size" then return .StorageSemanticResult~scalar(obj~eaValue("imap.size"))
    when head="account-key" then return .StorageSemanticResult~scalar(obj~eaValue("imap.account-key"))
    when head="raw" then do
      if session==.nil then return .nil
      src=.ImapStorageRawByteSource~new(session,obj~eaValue("imap.account-key"),obj~eaValue("imap.mailbox"),obj~eaValue("imap.uidvalidity"),obj~eaValue("imap.uid"),obj~sizeBytes)
      return .StorageSemanticResult~object(obj~ref,src,obj~mediaType,obj~sizeBytes)
    end
    otherwise return .nil
  end

::requires "ImapStorageFabricProjection.cls"
::requires "StorageSemantic.cls"
