import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { pathToFileURL, fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const gatewayRoot = process.env.WIRE_UI_GATEWAY_SRC;
const jsRoot = process.env.WIRE_UI_JS_SRC;
const rexx = process.env.REXX;
const chromium = process.env.CHROMIUM_BIN || '/usr/bin/chromium';
if (!gatewayRoot) throw new Error('WIRE_UI_GATEWAY_SRC is required');
if (!jsRoot) throw new Error('WIRE_UI_JS_SRC is required');
if (!rexx) throw new Error('REXX is required');

const gatewayApi = await import(pathToFileURL(path.join(gatewayRoot, 'src/index.js')).href);
const { OoRexxQueueFabricPort, WireUIQueueGateway, StaticBindingResolver } = gatewayApi;

async function staticServer() {
  const demo = path.join(HERE, 'browser-full-session.html');
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      fs.createReadStream(demo).pipe(res);
      return;
    }
    if (url.pathname.startsWith('/wire-ui-js/')) {
      const rel = url.pathname.slice('/wire-ui-js/'.length);
      const target = path.resolve(jsRoot, rel);
      if (!target.startsWith(path.resolve(jsRoot) + path.sep) || !fs.existsSync(target)) {
        res.writeHead(404); res.end(); return;
      }
      res.writeHead(200, { 'content-type': target.endsWith('.js') ? 'text/javascript; charset=utf-8' : 'text/plain; charset=utf-8', 'cache-control': 'no-store' });
      fs.createReadStream(target).pipe(res);
      return;
    }
    res.writeHead(404); res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server;
}

test('real ooRexx WireUIApplication crosses Queue Fabric gateway into Chromium and back', { timeout: 20000, skip: process.env.RUN_CHROMIUM_ACCEPTANCE !== '1' }, async () => {
  const port = new OoRexxQueueFabricPort({
    rexx,
    bridgeScript: path.join(HERE, 'full_session_bridge.rex'),
    cwd: HERE,
    env: { ...process.env },
    args: ['WIREUI.IN.AP1', 'WIREUI.OUT.AP1', 'wireui-gateway', 'WIREUI', '']
  });
  await port.start();
  const gateway = await new WireUIQueueGateway({
    queuePort: port,
    bindingResolver: new StaticBindingResolver({
      flylo: { inboundQueue: 'WIREUI.IN.AP1', outboundQueue: 'WIREUI.OUT.AP1', principal: 'wireui-gateway' }
    }),
    pollIntervalMs: 5
  }).listen();
  const web = await staticServer();
  const webPort = web.address().port;

  const proc = spawn(chromium, [
    '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
    '--virtual-time-budget=12000', '--dump-dom',
    `http://127.0.0.1:${webPort}/?gatewayPort=${gateway.port}`
  ], { stdio: ['ignore', 'pipe', 'pipe'] });
  let stdout = ''; let stderr = '';
  proc.stdout.on('data', (d) => { stdout += d; });
  proc.stderr.on('data', (d) => { stderr += d; });
  const exit = await new Promise((resolve) => proc.on('close', (code, signal) => resolve({ code, signal })));

  try {
    assert.equal(exit.code, 0, stderr.slice(-2000));
    assert.match(stdout, /data-acceptance="PASS"/);
    assert.match(stdout, /data-render-profile="[^"]+"/);
    assert.match(stdout, /data-manifest="wui-manifest-[0-9A-F]+"/);
    assert.match(stdout, /Nothing has been added to your booking\./);
    assert.match(stdout, />Ask FlyLo<\/button>/);
    // Cold session must have requested definitions through the authoritative manifest path.
    const m = stdout.match(/data-definition-requests="(\d+)"/);
    assert.ok(m && Number(m[1]) >= 1, stdout.slice(-5000));
  } finally {
    await new Promise((resolve) => web.close(resolve));
    await gateway.close();
    await port.close();
  }
});
