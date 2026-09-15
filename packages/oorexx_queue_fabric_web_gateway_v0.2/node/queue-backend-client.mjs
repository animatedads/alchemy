import net from 'node:net';

export class QueueBackendClient {
  constructor({ host = '127.0.0.1', port, bridgeToken, timeoutMs = 5000 }) {
    if (!Number.isSafeInteger(Number(port)) || Number(port) < 1) throw new TypeError('backend port is required');
    if (!bridgeToken) throw new TypeError('bridgeToken is required');
    this.host = host;
    this.port = Number(port);
    this.bridgeToken = String(bridgeToken);
    this.timeoutMs = timeoutMs;
  }

  request(op, fields = {}) {
    return new Promise((resolve, reject) => {
      const socket = net.createConnection({ host: this.host, port: this.port });
      let text = '';
      const timer = setTimeout(() => {
        socket.destroy();
        reject(new Error(`Queue Fabric bridge timeout for ${op}`));
      }, this.timeoutMs);
      const finish = (fn, value) => { clearTimeout(timer); socket.destroy(); fn(value); };
      socket.setEncoding('utf8');
      socket.on('connect', () => socket.write(`${JSON.stringify({ bridgeToken: this.bridgeToken, op, ...fields })}\r\n`));
      socket.on('data', (chunk) => {
        text += chunk;
        const at = text.indexOf('\n');
        if (at < 0) return;
        try {
          const reply = JSON.parse(text.slice(0, at).trim());
          if (!reply.ok) {
            const error = new Error(`Queue Fabric bridge ${reply.code ?? 'FAILED'}${reply.detail ? `: ${reply.detail}` : ''}`);
            error.code = reply.code ?? 'QUEUE_BACKEND_FAILED';
            error.detail = reply.detail ?? null;
            return finish(reject, error);
          }
          finish(resolve, reply.value ?? null);
        } catch (error) { finish(reject, error); }
      });
      socket.on('error', (error) => finish(reject, error));
      socket.on('end', () => {
        if (!text.includes('\n')) finish(reject, new Error('Queue Fabric bridge closed without result'));
      });
    });
  }
}
