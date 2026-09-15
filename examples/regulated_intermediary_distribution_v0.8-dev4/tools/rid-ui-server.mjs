#!/usr/bin/env node
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const option = (name, fallback='') => {
  const i = args.indexOf(name);
  return i >= 0 && args[i+1] != null ? args[i+1] : fallback;
};
const root = path.resolve(option('--root', path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'web')));
const entry = option('--entry', 'ui-preview.html');
const host = option('--host', process.env.RID_HTTP_HOST || '127.0.0.1');
const port = Number(option('--port', process.env.RID_HTTP_PORT || '8082'));
const gatewayUrl = option('--gateway-url', process.env.RID_GATEWAY_URL || '');
const accessPointId = option('--access-point-id', process.env.RID_ACCESS_POINT_ID || 'WEB');
const applicationId = option('--application-id', process.env.RID_APPLICATION_ID || 'RID-APP');
const sessionId = option('--session-id', process.env.RID_SESSION_ID || 'RID-BROWSER');

const types = new Map([
  ['.html','text/html; charset=utf-8'],['.js','text/javascript; charset=utf-8'],['.mjs','text/javascript; charset=utf-8'],
  ['.css','text/css; charset=utf-8'],['.json','application/json; charset=utf-8'],['.svg','image/svg+xml'],
  ['.png','image/png'],['.jpg','image/jpeg'],['.jpeg','image/jpeg'],['.webp','image/webp'],['.ico','image/x-icon']
]);

function safePath(urlPath) {
  const requested = decodeURIComponent(urlPath.split('?')[0]);
  const relative = requested === '/' ? entry : requested.replace(/^\/+/, '');
  const resolved = path.resolve(root, relative);
  if (resolved !== root && !resolved.startsWith(root + path.sep)) return null;
  return resolved;
}

function injectLiveConfig(text) {
  if (!gatewayUrl || !text.includes('</head>')) return text;
  const config = {
    gatewayUrl,
    outboundQueue: `WIREUI.IN.${accessPointId}`,
    applicationId,
    sessionId,
    accessPointId
  };
  const script = `<script>window.RID_BOOT_CONFIG=${JSON.stringify(config)};</script>`;
  return text.replace('</head>', `${script}\n</head>`);
}

const server = http.createServer(async (req,res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, {'content-type':'text/plain; charset=utf-8'}); res.end('Method not allowed'); return;
  }
  const target = safePath(req.url || '/');
  if (!target) { res.writeHead(400, {'content-type':'text/plain; charset=utf-8'}); res.end('Bad request'); return; }
  try {
    let data = await fs.readFile(target);
    const ext = path.extname(target).toLowerCase();
    if (ext === '.html') data = Buffer.from(injectLiveConfig(data.toString('utf8')));
    res.writeHead(200, {
      'content-type': types.get(ext) || 'application/octet-stream',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff'
    });
    if (req.method === 'HEAD') res.end(); else res.end(data);
  } catch (error) {
    if (error?.code === 'ENOENT' || error?.code === 'EISDIR') {
      res.writeHead(404, {'content-type':'text/plain; charset=utf-8'}); res.end('Not found'); return;
    }
    res.writeHead(500, {'content-type':'text/plain; charset=utf-8'}); res.end('Server error');
  }
});

server.listen(port, host, () => {
  console.log(`Federation Intermediary UI: http://${host}:${port}/`);
  if (gatewayUrl) console.log(`RID live gateway: ${gatewayUrl}`);
  else console.log('Mode: static UI preview (sample data)');
  console.log('Press Ctrl+C to stop.');
});

const stop = () => server.close(() => process.exit(0));
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
