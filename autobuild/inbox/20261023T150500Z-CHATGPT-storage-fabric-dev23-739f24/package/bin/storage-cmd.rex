/* Single-operation command endpoint.  Python CLI owns user argument parsing;
 * ooRexx owns Storage Fabric state and operations.  No command string eval. */
root=value("STORAGE_CLI_STATE_ROOT",,"ENVIRONMENT")
node=value("STORAGE_CLI_NODE",,"ENVIRONMENT")
if root="" | node="" then do
  say "RESULT"||"09"x||"CONFIGURATION_REQUIRED"
  exit 2
end
safety=value("STORAGE_CLI_LOCAL_SAFETY",,"ENVIRONMENT")
if safety="" then safety="UNKNOWN"
vendor=value("STORAGE_CLI_LOCAL_VENDOR",,"ENVIRONMENT")
site=value("STORAGE_CLI_LOCAL_SITE",,"ENVIRONMENT")
service=.StorageCommandService~new(root,node,safety,vendor,site)
op=value("STORAGE_CLI_OP",,"ENVIRONMENT")~lower
key=value("STORAGE_CLI_KEY",,"ENVIRONMENT")
path=value("STORAGE_CLI_PATH",,"ENVIRONMENT")
name=value("STORAGE_CLI_NAME",,"ENVIRONMENT")
media=value("STORAGE_CLI_MEDIA_TYPE",,"ENVIRONMENT")
if media="" then media="application/octet-stream"
peer=value("STORAGE_CLI_PEER",,"ENVIRONMENT")
virtual=value("STORAGE_CLI_VIRTUAL",,"ENVIRONMENT")
namespace=value("STORAGE_CLI_NAMESPACE",,"ENVIRONMENT")
if namespace="" then namespace="media"
description=value("STORAGE_CLI_DESCRIPTION",,"ENVIRONMENT")
tags=value("STORAGE_CLI_TAGS",,"ENVIRONMENT")
metadata=value("STORAGE_CLI_METADATA",,"ENVIRONMENT")
untags=value("STORAGE_CLI_UNTAGS",,"ENVIRONMENT")
unsets=value("STORAGE_CLI_UNSETS",,"ENVIRONMENT")
forget=value("STORAGE_CLI_FORGET",,"ENVIRONMENT")

if op="list" then do
  do obj over service~objects
    call outputObject obj,service
  end
  say "RESULT"||"09"x||"OK"
  exit 0
end
if op="locate" | op="status" then do
  got=service~lookup(key)
  if \got["ok"] then do
    say "RESULT"||"09"x||got["code"]
    exit 1
  end
  call outputObject got["object"],service
  say "RESULT"||"09"x||"OK"
  exit 0
end
select
  when op="register" then outcome=service~registerFile(path,name,media)
  when op="add" then outcome=service~addFile(path,name,virtual,namespace,description,tags,metadata,media)
  when op="bind" then outcome=service~bindExisting(key,virtual,namespace)
  when op="annotate" then outcome=service~annotate(key,description,tags,metadata,untags,unsets)
  when op="remove" then outcome=service~removeBinding(key,namespace,(forget="1"))
  otherwise outcome=.nil
end
if outcome==.nil then do
  repo=value("STORAGE_AZURE_GIT_REPO_URL",,"ENVIRONMENT")
  branch=value("STORAGE_AZURE_GIT_BRANCH",,"ENVIRONMENT")
  if branch="" then branch="storage-fabric"
  checkout=value("STORAGE_AZURE_GIT_CHECKOUT",,"ENVIRONMENT")
  if checkout="" then checkout=root||"/git-checkout"
  gitId=value("STORAGE_AZURE_GIT_PROVIDER_ID",,"ENVIRONMENT")
  if gitId="" then gitId="azure-git"
  gitSite=value("STORAGE_AZURE_GIT_SITE",,"ENVIRONMENT")
  if gitSite="" then gitSite="AZURE"
  if repo<>"" then do
    lifecycle=.StorageServiceLifecycle~new("SAFE","STABLE")
    git=.StorageGitProvider~new(gitId,repo,branch,checkout,"AZURE",gitSite,"AZURE/"||gitSite,lifecycle)
    service~configureGit(git)
  end
  select
    when op="ensure" then outcome=service~ensureAzure(key)
    when op="materialise" then outcome=service~materialise(key,path,peer)
    otherwise do
      say "RESULT"||"09"x||"UNKNOWN_COMMAND"
      exit 2
    end
  end
end
if outcome["object"]<>.nil then call outputObject outcome["object"],service
say "RESULT"||"09"x||outcome["code"]
if outcome["ok"] then exit 0
exit 1

::routine outputObject
  use arg obj,service
  dur=.StorageReplicaPolicy~new~durableReplicaCount(obj)
  requirement=service~snapshot~replicaPolicies~get(obj~ref~objectId)
  policy="NOT_SET"
  if requirement<>.nil then do
    assessment=.StorageReplicaPolicy~new~assess(obj,requirement)
    if assessment~satisfied then policy="SATISFIED"; else policy=assessment~reason
  end
  say "OBJECT"||"09"x||.StorageCodec~enc(obj~ref~objectId)||"09"x||.StorageCodec~enc(obj~displayName)||"09"x||obj~sizeBytes||"09"x||.StorageCodec~enc(obj~mediaType)||"09"x||.StorageCodec~enc(obj~ref~digest)||"09"x||obj~locations~items||"09"x||dur||"09"x||policy||"09"x||service~snapshot~revision
  do n over service~snapshot~allNamespaces
    do b over n~localBindings
      if b~ref~objectId=obj~ref~objectId then say "VPATH"||"09"x||.StorageCodec~enc(n~namespaceId)||"09"x||.StorageCodec~enc(b~path)
    end
  end
  do ea over obj~eas~all
    say "EA"||"09"x||.StorageCodec~enc(ea~namespace)||"09"x||.StorageCodec~enc(ea~name)||"09"x||.StorageCodec~enc(ea~value)
  end
  do l over obj~locations
    say "LOCATION"||"09"x||.StorageCodec~enc(l~providerId)||"09"x||.StorageCodec~enc(l~nodeId)||"09"x||.StorageCodec~enc(l~locator)||"09"x||l~state||"09"x||l~verified||"09"x||l~safetyClass||"09"x||l~lifecycleState||"09"x||.StorageCodec~enc(l~vendorId)||"09"x||.StorageCodec~enc(l~siteId)||"09"x||.StorageCodec~enc(l~failureDomainId)
  end
::requires "StorageCommand.cls"
