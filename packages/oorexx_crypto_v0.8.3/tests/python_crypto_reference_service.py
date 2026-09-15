#!/usr/bin/env python3
"""Development/test runtime-reference provider for Crypto v0.5.

The TCP wire remains runtime.reference/0.1.  This service deliberately transports
private RSA material for equivalence/performance testing only; production private
keys should use provider-owned key handles (Java JCA/HSM/etc.) rather than clear
TCP key material.
"""
import argparse
import hashlib
import json
import socketserver

from cryptography.hazmat.primitives.asymmetric import ed25519, rsa

P = 2**255 - 19
D = (-121665 * pow(121666, -1, P)) % P


def add(p, q):
    x1, y1 = p
    x2, y2 = q
    t = (D * x1 * x2 * y1 * y2) % P
    x3 = ((x1*y2 + y1*x2) * pow((1+t) % P, -1, P)) % P
    y3 = ((y1*y2 + x1*x2) * pow((1-t) % P, -1, P)) % P
    return x3, y3


def multiply(point, scalar):
    r = (0, 1)
    b = point
    n = scalar
    while n > 0:
        if n & 1:
            r = add(r, b)
        b = add(b, b)
        n >>= 1
    return r


def x25519_ladder(scalar, u):
    x1=u; x2=1; z2=0; x3=u; z3=1; a24=121665
    for t in range(254,-1,-1):
        bit=(scalar >> t) & 1
        if bit:
            x2,x3=x3,x2; z2,z3=z3,z2
        A=(x2+z2)%P; AA=(A*A)%P
        B=(x2-z2)%P; BB=(B*B)%P
        E=(AA-BB)%P
        C=(x3+z3)%P; Dm=(x3-z3)%P
        DA=(Dm*A)%P; CB=(C*B)%P
        x3=((DA+CB)*(DA+CB))%P
        z3=(((DA-CB)*(DA-CB))%P*x1)%P
        x2=(AA*BB)%P
        z2=(E*(AA+a24*E))%P
        if bit:
            x2,x3=x3,x2; z2,z3=z3,z2
    return (x2 * pow(z2, P-2, P)) % P


def ed_scalar_from_seed(seed: bytes) -> int:
    raw = bytearray(hashlib.sha512(seed).digest()[:32])
    raw[0] &= 248
    raw[31] &= 127
    raw[31] |= 64
    return int.from_bytes(raw, "little")


def rsa_string_to_int(raw: bytes, modulus_n: int) -> int:
    mod_hex = format(modulus_n, "x")
    block_bytes = (len(mod_hex) - 1) // 2
    if len(raw) >= block_bytes:
        return -1
    pad_len = block_bytes - len(raw)
    padded = raw + bytes([pad_len]) * pad_len
    return int.from_bytes(padded, "big")


def rsa_int_to_string(value: int, modulus_n: int) -> bytes:
    hex_str = format(value, "x") if value > 0 else ""
    mod_hex = format(modulus_n, "x")
    target = ((len(mod_hex) - 1) // 2) * 2
    hex_str = hex_str.rjust(target, "0")
    padded = bytes.fromhex(hex_str)
    if not padded:
        return padded
    pad_len = padded[-1]
    if pad_len < 1 or pad_len > len(padded):
        return padded
    return padded[:-pad_len]


def rsa_keypair_from_primes(p: int, q: int, e: int):
    n = p*q
    phi = (p-1)*(q-1)
    d = pow(e, -1, phi)
    return {"n": str(n), "e": str(e), "d": str(d), "phi": str(phi)}


def completed(op, impl, value):
    return {
        "protocol": "runtime.reference/0.1",
        "operation": op,
        "status": "completed",
        "provider": "python.crypto.reference",
        "implementation": impl,
        "value": value,
    }


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        raw = self.rfile.readline(16_777_217)
        if not raw:
            return
        op = ""
        try:
            req = json.loads(raw)
            op = req.get("operation") or ""
            if req.get("protocol") != "runtime.reference/0.1":
                out = {"protocol":"runtime.reference/0.1","operation":op,"status":"rejected_before_execution","detail":"protocol mismatch"}
            else:
                a = req.get("arguments") or {}
                if op == "crypto.sha256.digest/1":
                    data_hex = str(a["data_hex"])
                    if not data_hex.startswith("hex:"):
                        raise ValueError("SHA-256 data_hex encoding marker missing")
                    data = bytes.fromhex(data_hex[4:])
                    if data == b"runtime-reference-invalid-sha256":
                        out = completed(op, "python.sha256.invalid-test/1", "not-a-sha256-digest")
                    else:
                        out = completed(op, "python.hashlib.sha256/1", hashlib.sha256(data).hexdigest())
                elif op == "crypto.sha512.digest/1":
                    data_hex = str(a["data_hex"])
                    if not data_hex.startswith("hex:"):
                        raise ValueError("SHA-512 data_hex encoding marker missing")
                    data = bytes.fromhex(data_hex[4:])
                    if data == b"runtime-reference-invalid-sha512":
                        out = completed(op, "python.sha512.invalid-test/1", "not-a-sha512-digest")
                    else:
                        out = completed(op, "python.hashlib.sha512/1", hashlib.sha512(data).hexdigest())
                elif op == "crypto.edwards25519.multiply/1":
                    x, y = multiply((int(a["x"]), int(a["y"])), int(a["scalar"]))
                    out = completed(op, "python.edwards25519.multiply/1", {"x":str(x),"y":str(y)})
                elif op == "crypto.edwards25519.add/1":
                    # Deliberately invalid to preserve the v0.2 validation/fallback probe.
                    out = completed(op, "python.edwards25519.add/bad-test", {"x":"not-an-integer","y":"0"})
                elif op == "crypto.ed25519.keypair/1":
                    seed = bytes.fromhex(a["seed_hex"])
                    priv = ed25519.Ed25519PrivateKey.from_private_bytes(seed)
                    pub = priv.public_key().public_bytes_raw().hex()
                    out = completed(op, "python.ed25519.keypair/1", {"private":a["seed_hex"].lower(), "public":pub, "scalar":str(ed_scalar_from_seed(seed))})
                elif op == "crypto.ed25519.sign/1":
                    seed = bytes.fromhex(a["private_hex"])
                    sig = ed25519.Ed25519PrivateKey.from_private_bytes(seed).sign(a["message"].encode("latin-1"))
                    out = completed(op, "python.ed25519.sign/1", sig.hex())
                elif op == "crypto.ed25519.verify/1":
                    try:
                        pub = ed25519.Ed25519PublicKey.from_public_bytes(bytes.fromhex(a["public_hex"]))
                        pub.verify(bytes.fromhex(a["signature_hex"]), a["message"].encode("latin-1"))
                        value = "true"
                    except Exception:
                        value = "false"
                    out = completed(op, "python.ed25519.verify/1", value)
                elif op == "crypto.x25519.public_key/1":
                    value = x25519_ladder(int(a["private_scalar"]), 9)
                    out = completed(op, "python.x25519.public_key/1", str(value))
                elif op == "crypto.x25519.shared_secret/1":
                    value = x25519_ladder(int(a["my_private"]), int(a["their_public"]))
                    out = completed(op, "python.x25519.shared_secret/1", str(value))
                elif op == "crypto.rsa.keypair/1":
                    value = rsa_keypair_from_primes(int(a["p"]), int(a["q"]), int(a["e"]))
                    out = completed(op, "python.rsa.keypair/1", value)
                elif op == "crypto.rsa.generate_keypair/1":
                    e = int(a["e"])
                    if e not in (3, 65537):
                        out = {"protocol":"runtime.reference/0.1","operation":op,"status":"unsupported","provider":"python.crypto.reference","detail":"OpenSSL-backed generator supports e=3 or 65537"}
                    else:
                        key = rsa.generate_private_key(public_exponent=e, key_size=2048)
                        nums = key.private_numbers()
                        # OpenSSL supplies fast prime generation; derive d exactly as
                        # Crypto does (inverse mod phi), not OpenSSL's lambda(n) convention.
                        value = rsa_keypair_from_primes(nums.p, nums.q, e)
                        out = completed(op, "python.openssl-primes.rsa.generate_keypair/1", value)
                elif op == "crypto.rsa.encrypt/1":
                    n = int(a["n"]); e = int(a["e"])
                    m = rsa_string_to_int(bytes.fromhex(a["plaintext_hex"]), n)
                    if m < 0:
                        out = {"protocol":"runtime.reference/0.1","operation":op,"status":"rejected_before_execution","provider":"python.crypto.reference","detail":"plaintext too long for modulus"}
                    else:
                        out = completed(op, "python.rsa.encrypt/1", str(pow(m, e, n)))
                elif op == "crypto.rsa.decrypt/1":
                    n = int(a["n"]); d = int(a["d"]); c = int(a["ciphertext"])
                    plain = rsa_int_to_string(pow(c, d, n), n)
                    out = completed(op, "python.rsa.decrypt/1", plain.hex())
                elif op == "crypto.rsa.sign/1":
                    n = int(a["n"]); d = int(a["d"]); m = int(a["message_int"])
                    out = completed(op, "python.rsa.sign/1", str(pow(m, d, n)))
                elif op == "crypto.rsa.verify/1":
                    n = int(a["n"]); e = int(a["e"]); sig = int(a["signature"])
                    out = completed(op, "python.rsa.verify/1", str(pow(sig, e, n)))
                else:
                    out = {"protocol":"runtime.reference/0.1","operation":op,"status":"unsupported","provider":"python.crypto.reference","detail":"operation not implemented"}
            self.wfile.write((json.dumps(out, separators=(",", ":")) + "\n").encode())
        except Exception as exc:
            out = {"protocol":"runtime.reference/0.1","operation":op,"status":"fault","provider":"python.crypto.reference","detail":type(exc).__name__}
            self.wfile.write((json.dumps(out, separators=(",", ":")) + "\n").encode())


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--port-file", required=True)
    ns = ap.parse_args()
    with Server((ns.host, ns.port), Handler) as server:
        with open(ns.port_file, "w", encoding="ascii") as f:
            f.write(str(server.server_address[1]))
        server.serve_forever()
