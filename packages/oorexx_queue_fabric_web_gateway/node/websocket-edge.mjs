import http from 'node:http';
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';

const MAGIC = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

function frame(opcode, payload = Buffer.alloc(0)) {
  const body = Buffer.isBuffer(payload) ? payload : Buffer.from(String(payload));
  let head;
  if (body.length < 126) { head = Buffer.alloc(2); head[1] = body.length; }
  else if (body.length <= 0xffff) { head = Buffer.alloc(4); head[1] = 126; head.writeUInt16BE(body.length, 2); }
  else { head = Buffer.alloc(10); head[1] = 127; head.writeBigUInt64BE(BigInt(body.length), 2); }
  head[0] = 0x80 | opcode;
  return Buffer.concat([head, body]);
}

class WebSocketPeer extends EventEmitter {
  constructor(socket, { maxFrameBytes = 1024 * 1024 } = {}) {
    super(); this.socket = socket; this.maxFrameBytes = maxFrameBytes; this.buffer = Buffer.alloc(0); this.closed = false;
    socket.on('data', (chunk) => { this.buffer = Buffer.concat([this.buffer, chunk]); this.#drain(); });
    socket.on('close', () => { this.closed = true; this.emit('close'); });
    socket.on('error', (error) => this.emit('error', error));
  }
  sendJSON(value) { if (!this.closed) this.socket.write(frame(0x1, JSON.stringify(value))); }
  close(code = 1000, reason = '') {
    if (this.closed) return;
    const b = Buffer.alloc(2 + Buffer.byteLength(reason)); b.writeUInt16BE(code, 0); b.write(reason, 2);
    this.socket.write(frame(0x8, b)); this.socket.end(); this.closed = true;
  }
  #drain() {
    while (this.buffer.length >= 2) {
      const b0 = this.buffer[0], b1 = this.buffer[1];
      const fin = (b0 & 0x80) !== 0, opcode = b0 & 0x0f, masked = (b1 & 0x80) !== 0;
      if (!fin) return this.close(1003, 'fragmentation-not-supported');
      if (!masked) return this.close(1002, 'client-frame-must-be-masked');
      let length = b1 & 0x7f, offset = 2;
      if (length === 126) { if (this.buffer.length < 4) return; length = this.buffer.readUInt16BE(2); offset = 4; }
      else if (length === 127) {
        if (this.buffer.length < 10) return;
        const n = this.buffer.readBigUInt64BE(2); if (n > BigInt(Number.MAX_SAFE_INTEGER)) return this.close(1009, 'frame-too-large');
        length = Number(n); offset = 10;
      }
      if (length > this.maxFrameBytes) return this.close(1009, 'frame-too-large');
      if (this.buffer.length < offset + 4 + length) return;
      const mask = this.buffer.subarray(offset, offset + 4); offset += 4;
      const payload = Buffer.from(this.buffer.subarray(offset, offset + length));
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
      this.buffer = this.buffer.subarray(offset + length);
      if (opcode === 0x8) { this.close(); this.emit('close'); return; }
      if (opcode === 0x9) { this.socket.write(frame(0xA, payload)); continue; }
      if (opcode === 0xA) continue;
      if (opcode !== 0x1) return this.close(1003, 'text-only');
      try { this.emit('json', JSON.parse(payload.toString('utf8'))); }
      catch { this.close(1007, 'invalid-json'); return; }
    }
  }
}

export class QueueFabricWebSocketEdge {
  constructor({ backend, inboundQueue, pollMs = 40, path = '/wire-ui', pathToken = '', host = '127.0.0.1', port = 0, bootstrap = null, bootstrapPath = null, publicGatewayUrl = '' }) {
    if (!backend) throw new TypeError('backend is required');
    if (!inboundQueue) throw new TypeError('inboundQueue is required');
    this.backend = backend; this.inboundQueue = inboundQueue; this.pollMs = pollMs; this.path = path; this.pathToken = pathToken; this.host = host; this.port = port;
    this.bootstrap = bootstrap == null ? null : Object.freeze({ ...bootstrap });
    this.bootstrapPath = bootstrapPath ?? `${path.replace(/\/$/, '')}/bootstrap`;
    this.publicGatewayUrl = String(publicGatewayUrl ?? '');
    this.server = null; this.peer = null; this.inflight = null; this.deliverySequence = 0; this.timer = null; this.pumping = false;
  }

  async start() {
    if (this.server) return;
    await this.backend.request('PING');
    this.server = http.createServer((req, res) => this.#handleHttp(req, res));
    this.server.on('upgrade', (req, socket) => this.#upgrade(req, socket));
    await new Promise((resolve, reject) => { this.server.once('error', reject); this.server.listen(this.port, this.host, resolve); });
    this.port = this.server.address().port;
  }

  async stop() {
    clearTimeout(this.timer); this.timer = null;
    if (this.inflight) { try { await this.backend.request('RELEASE', this.inflight); } catch {} this.inflight = null; }
    this.peer?.close(); this.peer = null;
    if (this.server) await new Promise((resolve) => this.server.close(resolve));
    this.server = null;
  }


  #handleHttp(req, res) {
    const url = new URL(req.url, 'http://gateway.invalid');
    if (req.method === 'GET' && this.bootstrap && url.pathname === this.bootstrapPath) {
      if (this.pathToken && url.searchParams.get('token') !== this.pathToken) {
        res.writeHead(404, { 'content-type':'text/plain; charset=utf-8', 'cache-control':'no-store' });
        res.end('Not found');
        return;
      }
      const gatewayUrl = this.#resolvedPublicGatewayUrl(req);
      const body = JSON.stringify(Object.freeze({
        ...this.bootstrap,
        gatewayUrl,
        outboundQueue: this.inboundQueue
      }));
      res.writeHead(200, {
        'content-type':'application/json; charset=utf-8',
        'cache-control':'no-store, private',
        'content-security-policy':"default-src 'none'; frame-ancestors 'none'",
        'x-content-type-options':'nosniff'
      });
      res.end(body);
      return;
    }
    res.writeHead(426, { 'content-type':'text/plain; charset=utf-8', 'cache-control':'no-store' });
    res.end('WebSocket required');
  }

  #resolvedPublicGatewayUrl(req) {
    if (this.publicGatewayUrl) return this.publicGatewayUrl;
    const host = req.headers.host || `${this.host}:${this.port}`;
    const forwarded = String(req.headers['x-forwarded-proto'] ?? '').split(',')[0].trim().toLowerCase();
    const wsScheme = forwarded === 'https' ? 'wss' : 'ws';
    const token = this.pathToken ? `?token=${encodeURIComponent(this.pathToken)}` : '';
    return `${wsScheme}://${host}${this.path}${token}`;
  }

  #upgrade(req, socket) {
    const url = new URL(req.url, 'http://gateway.invalid');
    if (url.pathname !== this.path || (this.pathToken && url.searchParams.get('token') !== this.pathToken)) {
      socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n'); return;
    }
    if (this.peer && !this.peer.closed) { socket.end('HTTP/1.1 409 Conflict\r\nConnection: close\r\n\r\n'); return; }
    const key = req.headers['sec-websocket-key'];
    if (!key || String(req.headers.upgrade).toLowerCase() !== 'websocket') { socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'); return; }
    const accept = crypto.createHash('sha1').update(String(key) + MAGIC).digest('base64');
    socket.write(['HTTP/1.1 101 Switching Protocols','Upgrade: websocket','Connection: Upgrade',`Sec-WebSocket-Accept: ${accept}`,'',''].join('\r\n'));
    const peer = new WebSocketPeer(socket); this.peer = peer; this.deliverySequence = 0;
    peer.on('json', (message) => void this.#onFrame(peer, message));
    peer.on('close', () => void this.#onClose(peer));
    peer.on('error', () => void this.#onClose(peer));
    void this.#pump(peer);
  }

  async #onClose(peer) {
    if (this.peer !== peer) return;
    clearTimeout(this.timer); this.timer = null; this.peer = null;
    if (this.inflight) { const claimed = this.inflight; this.inflight = null; try { await this.backend.request('RELEASE', claimed); } catch {} }
  }

  async #onFrame(peer, message) {
    try {
      if (message?.type === 'QUEUE_PUT') {
        const id = String(message.clientPutId ?? '');
        if (!id) return peer.sendJSON({ type:'QUEUE_PUT_RESULT', clientPutId:'', accepted:false, code:'CLIENT_PUT_ID_REQUIRED' });
        if (String(message.queue ?? '') !== this.inboundQueue) return peer.sendJSON({ type:'QUEUE_PUT_RESULT', clientPutId:id, accepted:false, code:'QUEUE_NOT_BOUND' });
        const result = await this.backend.request('PUT', { payload: message.payload, correlationId: message.correlationId ?? '' });
        peer.sendJSON({ type:'QUEUE_PUT_RESULT', clientPutId:id, accepted:true, packageId:result?.packageId ?? null, code:'OK' });
        return;
      }
      if (message?.type === 'QUEUE_DELIVERY_ACK' || message?.type === 'QUEUE_DELIVERY_NACK') {
        const current = this.inflight;
        if (!current || String(message.deliveryId ?? '') !== current.deliveryId || String(message.messageId ?? '') !== current.packageId) {
          peer.close(1008, 'delivery-identity-mismatch'); return;
        }
        const op = message.type === 'QUEUE_DELIVERY_ACK' ? 'ACK' : 'NACK';
        this.inflight = null;
        await this.backend.request(op, { packageId: current.packageId, claimToken: current.claimToken });
        void this.#pump(peer); return;
      }
      peer.close(1008, 'gateway-frame-unsupported');
    } catch (error) {
      if (message?.type === 'QUEUE_PUT') peer.sendJSON({ type:'QUEUE_PUT_RESULT', clientPutId:String(message.clientPutId ?? ''), accepted:false, code:error.code ?? 'QUEUE_BACKEND_FAILED', detail:error.detail ?? error.message });
      else peer.close(1011, 'queue-backend-failed');
    }
  }

  async #pump(peer) {
    if (this.pumping || this.inflight || this.peer !== peer || peer.closed) return;
    this.pumping = true;
    try {
      const claimed = await this.backend.request('CLAIM');
      if (this.peer !== peer || peer.closed) {
        if (claimed?.package && claimed?.claimToken) await this.backend.request('RELEASE', { packageId:claimed.package.packageId, claimToken:claimed.claimToken });
        return;
      }
      const deliveryId = crypto.randomUUID();
      this.deliverySequence += 1;
      this.inflight = { deliveryId, packageId: String(claimed.package.packageId), claimToken: String(claimed.claimToken) };
      peer.sendJSON({ type:'QUEUE_DELIVERY', deliveryId, deliverySequence:this.deliverySequence, package:claimed.package });
    } catch (error) {
      if (error.code !== 'QUEUE_EMPTY' && !String(error.message).includes('QUEUE_EMPTY')) {
        peer.close(1011, 'queue-claim-failed');
        return;
      }
      clearTimeout(this.timer);
      this.timer = setTimeout(() => void this.#pump(peer), this.pollMs);
    } finally { this.pumping = false; }
  }
}
