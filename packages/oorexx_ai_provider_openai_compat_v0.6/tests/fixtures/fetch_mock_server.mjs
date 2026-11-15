// fetch_mock_server.mjs -- a local stand-in for an OpenAI-compatible
// /v1/chat/completions, for tests/test_fetch_transport.rex (ooRexx/WASM in
// Node).  It records each request's Authorization header so the test can see
// that no later request carries the key.
// Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
// usage: node fetch_mock_server.mjs PORT
import http from 'node:http';
const port = Number(process.argv[2] || 8972);
const seen = [];
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    seen.push({ path: req.url, auth: req.headers.authorization || '' });
    res.setHeader('content-type', 'application/json');
    if (req.url === '/seen') { res.end(JSON.stringify(seen)); return; }
    if (req.headers.authorization !== 'Bearer FAKE-OPENAI-SECRET-7E4B') {
      res.statusCode = 401; res.end(JSON.stringify({ error: { message: 'Incorrect API key provided: sk-proj-ABC123', type: 'invalid_request_error' } })); return;
    }
    let p = {}; try { p = JSON.parse(body); } catch (e) { /* bad body */ }
    const said = (p.messages || []).map((m) => m.content).join(' ');
    res.end(JSON.stringify({ id: 'chatcmpl-1', model: 'fixture-model-actual',
      choices: [{ index: 0, finish_reason: 'stop', message: { role: 'assistant', content: 'provider says hello' } }],
      usage: { prompt_tokens: 2, completion_tokens: 3, total_tokens: 5 }, echo: said }));
  });
}).listen(port, '127.0.0.1');
