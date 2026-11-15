// fetch_mock_server.mjs -- a local stand-in for api.anthropic.com's
// /v1/messages, for tests/test_fetch_client.rex (ooRexx/WASM in Node).
// It answers what the fixture curl answers, and records each request's
// headers so the test can see that no later request carries the key.
// Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
// usage: node fetch_mock_server.mjs PORT
import http from 'node:http';
const port = Number(process.argv[2] || 8971);
const seen = [];
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    const h = req.headers;
    seen.push({ path: req.url, method: req.method, key: h['x-api-key'] || '', version: h['anthropic-version'] || '', browser: h['anthropic-dangerous-direct-browser-access'] || '' });
    res.setHeader('content-type', 'application/json');
    if (req.url === '/seen') { res.end(JSON.stringify(seen)); return; }
    if (req.url === '/v1/messages' && req.method === 'POST') {
      if (h['x-api-key'] !== 'FAKE-SECRET-91') {
        res.statusCode = 401;
        res.end(JSON.stringify({ type: 'error', error: { type: 'authentication_error', message: 'invalid x-api-key sk-ant-api03-ABCDEF123456 rejected' } }));
        return;
      }
      let parsed = {}; try { parsed = JSON.parse(body); } catch (e) { /* bad body */ }
      if (!parsed.messages) { res.statusCode = 400; res.end(JSON.stringify({ type: 'error', error: { type: 'invalid_request_error', message: 'messages required' } })); return; }
      res.end(JSON.stringify({ id: 'msg_1', type: 'message', model: parsed.model, stop_reason: 'end_turn',
        content: [{ type: 'text', text: 'say "hello"' }],
        usage: { input_tokens: 120, output_tokens: 9, cache_creation_input_tokens: 800, cache_read_input_tokens: 0 } }));
      return;
    }
    res.statusCode = 404; res.end('{}');
  });
}).listen(port, '127.0.0.1');
