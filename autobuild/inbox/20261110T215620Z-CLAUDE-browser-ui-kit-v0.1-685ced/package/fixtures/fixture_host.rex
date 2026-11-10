/* fixture_host.rex -- serve the browser UI kit's test apps: Claude-shaped, ChatGPT-shaped, outside identity provider.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
 *
 *   rexx fixture_host.rex KIT_DIR
 *
 * Reads KIT_DIR/etc/fixtures.conf (ports, certificate, test account).  Three HTTPS servers in one process share
 * one FixtureStore, so the identity provider's tickets are redeemable by the apps.  Local only: 127.0.0.1.
 */
parse arg kit .
if kit='' then kit=directory()
conf=fxReadProps(kit'/etc/fixtures.conf')
local=fxReadProps(kit'/var/fixtures.local.conf')            /* this machine's paths (bridge_dir, wasm_assets) */
do k over local~allIndexes
  conf[k]=local[k]
end
do k over .array~of('claude_port', 'chatgpt_port', 'idp_port', 'certificate', 'private_key', 'bridge_dir', 'wasm_assets', 'test_user', 'test_password', 'test_code')
  if conf[k]=.nil then conf[k]=''
  if conf[k]=='' then do
    .error~lineout('fixture_host: no value for' k '(etc/fixtures.conf, or this machine''s var/fixtures.local.conf)')
    exit 2
  end
  conf[k]=conf[k]~changeStr('$KIT', kit)
end
store=.FixtureStore~new(conf)
idpOrigin='https://127.0.0.1:'conf['idp_port']
web=kit'/fixtures/web'
claude=.FixtureClaudeShaped~new('fc', conf['claude_port'], store, 'fxc_sid', idpOrigin, conf['wasm_assets'], web)
chatgpt=.FixtureChatGptShaped~new('fg', conf['chatgpt_port'], store, 'fxg_sid', idpOrigin, conf['wasm_assets'], web)
idp=.FixtureIdp~new('idp', conf['idp_port'], store, 'fxi_sid', idpOrigin, conf['wasm_assets'], web)
idp~addApp(claude)
idp~addApp(chatgpt)

servers=.array~new
do app over .array~of(claude, chatgpt, idp)
  c=.HttpsServerConfig~new
  c~bindAddress='127.0.0.1'
  c~port=app~port
  c~certificateFile=conf['certificate']
  c~privateKeyFile=conf['private_key']
  c~bridgeDirectory=conf['bridge_dir']
  c~connectionWorkers=6
  c~maxPendingConnections=32
  c~readTimeout=30
  c~maxBodyBytes=65536
  c~accessLog=.false
  s=.HttpsServer~new(c)
  s~interceptor(app, 'beforeRequest', '')
  servers~append(s)
end
say 'FIXTURES_READY claude=https://127.0.0.1:'claude~port 'chatgpt=https://127.0.0.1:'chatgpt~port 'idp='idpOrigin
servers[1]~start('serve')
servers[2]~start('serve')
servers[3]~serve
exit 0

::routine fxReadProps
  use strict arg file
  d=.directory~new
  if \SysFileExists(file) then return d
  s=.stream~new(file)
  s~open('read')
  do while s~lines>0
    l=s~linein~strip
    if l='' then iterate
    if l~left(1)='#' then iterate
    parse var l k '=' v
    d[k~strip~lower]=v~strip
  end
  s~close
  return d

::requires 'FixtureApps.cls'
