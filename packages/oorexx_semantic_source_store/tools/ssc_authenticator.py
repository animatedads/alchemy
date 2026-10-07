#!/usr/bin/env python3
"""Semantic Source Control local authenticator.

Private keys remain local.  The tool can create an Ed25519 identity and sign a
server-issued SSC challenge.  It never decides permissions; the server's
Security Effect / Access Permissions stack does that after signature validation.
"""
from __future__ import annotations
import argparse, base64, json, os, sys
from pathlib import Path
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

SCHEMA = "semantic-source.auth.challenge/1"
PREFIX = "SSC-AUTH-1"

def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")

def canonical(ch: dict) -> bytes:
    required = ["challenge_id", "key_id", "audience", "nonce", "issued_at", "expires_at"]
    missing = [k for k in required if not str(ch.get(k, ""))]
    if missing:
        raise SystemExit("challenge missing required field(s): " + ", ".join(missing))
    fields = [
        PREFIX,
        str(ch["challenge_id"]),
        str(ch["key_id"]),
        str(ch["audience"]),
        str(ch.get("action", ch.get("action_name", ""))),
        str(ch.get("resource_id", "")),
        str(ch["nonce"]),
        str(ch["issued_at"]),
        str(ch["expires_at"]),
    ]
    return "\n".join(fields).encode("utf-8")

def keygen(args: argparse.Namespace) -> None:
    private = Ed25519PrivateKey.generate()
    pem = private.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    path = Path(args.private_key)
    path.write_bytes(pem)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    public = private.public_key().public_bytes(
        serialization.Encoding.Raw,
        serialization.PublicFormat.Raw,
    )
    print(json.dumps({
        "schema": "semantic-source.auth.public-key/1",
        "key_id": args.key_id,
        "algorithm": "Ed25519",
        "public_key_b64url": b64u(public),
        "private_key_file": str(path),
    }, indent=2))

def sign(args: argparse.Namespace) -> None:
    ch = json.loads(Path(args.challenge).read_text(encoding="utf-8")) if args.challenge != "-" else json.load(sys.stdin)
    if ch.get("schema") not in (None, SCHEMA):
        raise SystemExit("unsupported challenge schema")
    private = serialization.load_pem_private_key(Path(args.private_key).read_bytes(), password=None)
    if not isinstance(private, Ed25519PrivateKey):
        raise SystemExit("private key is not Ed25519")
    message = canonical(ch)
    sig = private.sign(message)
    token = {
        "schema": "semantic-source.auth.response/1",
        "challenge_id": ch["challenge_id"],
        "key_id": ch["key_id"],
        "signature_b64url": b64u(sig),
    }
    print(json.dumps(token, separators=(",", ":")))

def main() -> None:
    p = argparse.ArgumentParser(description="SSC local signed-challenge authenticator")
    sub = p.add_subparsers(dest="command", required=True)
    g = sub.add_parser("keygen", help="create an Ed25519 private key and print its public identity")
    g.add_argument("--key-id", required=True)
    g.add_argument("--private-key", required=True)
    g.set_defaults(func=keygen)
    s = sub.add_parser("sign", help="sign a server challenge with a local Ed25519 private key")
    s.add_argument("--private-key", required=True)
    s.add_argument("--challenge", required=True, help="challenge JSON file or - for stdin")
    s.set_defaults(func=sign)
    args = p.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
