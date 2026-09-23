parse arg path
if path == '' then path = '.'
p = .Posix~new
say 'provider:' p~provider
say 'capabilities:' p~capabilities~string
r = p~statBasic(path)
if \r~ok then do
  say r~error~string
  exit 1
end
s = r~value
say 'path:' s~path
say 'device:' s~device
say 'inode:' s~inode
say 'size:' s~size
say 'permissions:' s~permissions
say 'uid/gid:' s~uid '/' s~gid
say 'coherent:' s~coherent
say 'evidence:' r~evidence~string
exit 0
::requires 'Posix.cls'
