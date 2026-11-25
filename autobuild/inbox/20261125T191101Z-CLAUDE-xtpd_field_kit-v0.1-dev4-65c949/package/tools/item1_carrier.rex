/* item1_carrier.rex -- switches this node's item 1 peer line between carriers.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 *
 * Usage (as root, with the kit's rexx):
 *   kit-rexx item1_carrier.rex raw36|udp [DIR]
 * DIR defaults to /etc/xtpd.  Reads the node name from DIR/xtpd.conf, finds the
 * one peer line in DIR/peers.txt, and rewrites it for the chosen carrier:
 *   raw36  PEER 3 raw36 IPV4            XTP's own protocol, IP protocol 36 (layer 3)
 *   udp    PEER 4 udp IPV4:47036        XTP over UDP (layer 4)
 * The address is kept; only the layer, carrier and port change.  The old file is
 * kept as DIR/peers.txt.prev.  Restart xtpd afterwards for it to take effect.
 * Prints the line before and after; touches nothing else. */
parse arg carrier dir extra
if dir == '' then dir = '/etc/xtpd'
if extra \== '' | \.array~of('raw36', 'udp')~hasItem(carrier) then do
  say 'usage: item1_carrier.rex raw36|udp [DIR]'
  exit 2
end
lines = .XtpdText~lines(dir'/peers.txt')
peerLines = .array~new
do l over lines
  if l \== '' then peerLines~append(l)
end
if peerLines~items \= 1 then do
  say 'FAIL' dir'/peers.txt must hold exactly one peer line; it holds' peerLines~items
  exit 3
end
parse value peerLines[1] with peer layer old address .
host = address~changeStr(':', ' ')~word(1)
if \.XtpdCheck~ipv4(host) then do
  say 'FAIL the peer line has no IPv4 address:' peerLines[1]
  exit 3
end
if carrier == 'raw36' then new = peer '3 raw36' host
else new = peer '4 udp' host':47036'
if \.XtpdCheck~route(new~word(2), new~word(3), new~word(4)) then do
  say 'FAIL the new line is not a valid route:' new
  exit 3
end
say 'before:' peerLines[1]
if new == peerLines[1] then do
  say 'PASS already' carrier '- nothing changed'
  exit 0
end
/* keep the old file, then replace atomically: SysFileMove will not replace an existing file */
old = .stream~new(dir'/peers.txt'); oldBytes = old~charin(1, old~chars); old~close
keep = .AtomicFile~new~replace(dir'/peers.txt.prev', oldBytes, .AtomicFileOptions~new)
if \(keep~ok & keep~published) then do; say 'FAIL could not keep' dir'/peers.txt.prev:' keep~errorMessage; exit 4; end
r = .AtomicFile~new~replace(dir'/peers.txt', new || '0a'x, .AtomicFileOptions~new)
if \(r~ok & r~published) then do; say 'FAIL could not write' dir'/peers.txt:' r~errorMessage; exit 4; end
check = .XtpdText~lines(dir'/peers.txt')
if check[1] \== new then do; say 'FAIL' dir'/peers.txt does not hold the new line'; exit 4; end
say 'after: ' new
say 'PASS peer line set to' carrier '(restart xtpd to use it)'
exit 0
::requires 'Xtpd.cls'
::requires 'AtomicFile.cls'
