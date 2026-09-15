#!/usr/bin/env node
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const pkgRoot = path.resolve(here, '..');
const webRoot = path.join(pkgRoot, 'web');

function parseArgs(argv) {
  const out = {
    host: '127.0.0.1',
    port: 8080,
    mode: 'preview',
    bootstrapUrl: '',
    bootstrapFile: '',
    wireUiJsRoot: '',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const value = () => {
      if (i + 1 >= argv.length) throw new Error(`${a} requires a value`);
      i += 1;
      return argv[i];
    };
    if (a === '--host') out.host = value();
    else if (a === '--port') out.port = Number(value());
    else if (a === '--mode') out.mode = value();
    else if (a === '--bootstrap-url') out.bootstrapUrl = value();
    else if (a === '--bootstrap-file') out.bootstrapFile = path.resolve(value());
    else if (a === '--wire-ui-js-root') out.wireUiJsRoot = path.resolve(value());
    else throw new Error(`unknown argument: ${a}`);
  }
  if (!Number.isInteger(out.port) || out.port < 0 || out.port > 65535) throw new Error('port must be 0..65535');
  if (!['preview', 'live'].includes(out.mode)) throw new Error('mode must be preview or live');
  if (out.bootstrapUrl && out.bootstrapFile) throw new Error('use either --bootstrap-url or --bootstrap-file, not both');
  if (out.mode === 'live' && !out.bootstrapUrl && !out.bootstrapFile) {
    throw new Error('live mode requires --bootstrap-url or --bootstrap-file');
  }
  return out;
}

const opts = parseArgs(process.argv.slice(2));

const mime = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.txt', 'text/plain; charset=utf-8'],
]);

function safeJoin(root, urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0]);
  const rel = decoded.replace(/^\/+/, '');
  const resolved = path.resolve(root, rel);
  const base = path.resolve(root) + path.sep;
  if (resolved !== path.resolve(root) && !resolved.startsWith(base)) return null;
  return resolved;
}

function sendJson(res, code, value) {
  const body = Buffer.from(JSON.stringify(value));
  res.writeHead(code, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store, private',
    'content-length': body.length,
  });
  res.end(body);
}

function sendFile(res, filePath) {
  let stat;
  try { stat = fs.statSync(filePath); } catch { return false; }
  if (!stat.isFile()) return false;
  const type = mime.get(path.extname(filePath).toLowerCase()) || 'application/octet-stream';
  res.writeHead(200, {
    'content-type': type,
    'cache-control': type.startsWith('text/html') ? 'no-store' : 'no-cache',
    'content-length': stat.size,
  });
  fs.createReadStream(filePath).pipe(res);
  return true;
}

function maybeRewriteBootstrap(value) {
  if (!opts.wireUiJsRoot) return value;
  return { ...value, moduleUrl: '/__wire_ui_runtime__/src/index.js' };
}

async function bootstrapValue() {
  if (opts.bootstrapFile) {
    const raw = fs.readFileSync(opts.bootstrapFile, 'utf8');
    const value = JSON.parse(raw);
    return maybeRewriteBootstrap(value);
  }
  const response = await fetch(opts.bootstrapUrl, {
    method: 'GET',
    headers: { accept: 'application/json' },
    cache: 'no-store',
  });
  if (!response.ok) throw new Error(`upstream bootstrap returned ${response.status}`);
  const value = await response.json();
  return maybeRewriteBootstrap(value);
}

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    let pathname = requestUrl.pathname;

    if (pathname === '/__health') {
      return sendJson(res, 200, { ok: true, mode: opts.mode });
    }

    if (opts.mode === 'live' && pathname === '/wire-ui/bootstrap') {
      try {
        return sendJson(res, 200, await bootstrapValue());
      } catch (error) {
        return sendJson(res, 502, { ok: false, code: 'BOOTSTRAP_UNAVAILABLE', detail: error.message });
      }
    }

    if (pathname.startsWith('/__wire_ui_runtime__/')) {
      if (!opts.wireUiJsRoot) return sendJson(res, 404, { ok: false, code: 'WIRE_UI_RUNTIME_NOT_CONFIGURED' });
      const rel = pathname.slice('/__wire_ui_runtime__/'.length);
      const filePath = safeJoin(opts.wireUiJsRoot, rel);
      if (!filePath || !sendFile(res, filePath)) return sendJson(res, 404, { ok: false, code: 'NOT_FOUND' });
      return;
    }

    if (pathname === '/') pathname = opts.mode === 'preview' ? '/preview.html' : '/index.html';
    const filePath = safeJoin(webRoot, pathname);
    if (!filePath || !sendFile(res, filePath)) return sendJson(res, 404, { ok: false, code: 'NOT_FOUND' });
  } catch (error) {
    sendJson(res, 500, { ok: false, code: 'SERVER_ERROR', detail: error.message });
  }
});

server.listen(opts.port, opts.host, () => {
  const address = server.address();
  const port = typeof address === 'object' && address ? address.port : opts.port;
  const host = opts.host === '0.0.0.0' ? '127.0.0.1' : opts.host;
  console.log(`FederationBank Merchant Wire UI (${opts.mode})`);
  console.log(`MERCHANT_WIRE_UI_URL=http://${host}:${port}/`);
  if (opts.mode === 'live') console.log('Wire UI bootstrap is exposed locally at /wire-ui/bootstrap');
});

function shutdown() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 2000).unref();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
