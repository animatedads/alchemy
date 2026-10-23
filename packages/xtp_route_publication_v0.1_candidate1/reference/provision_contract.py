"""Offline protocol/authority reference for xtp.provision/1.

NOT an XTP transport, registry installer, gateway, or production authority.
All crypto keys in tests are ephemeral. This reference only verifies envelopes,
leases, identity/scopes, sequence monotonicity, and quorum. It deliberately
performs no network IO or route-file writes.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Mapping

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey

DOMAIN = b"XTP-PROVISION/1\x00"
MAX_BODY = 1024 * 1024
MAX_LEASE_SECONDS = 24 * 60 * 60
NODE_RE = re.compile(r"^[a-z][a-z0-9._-]{0,127}$")
SERVICE_RE = re.compile(r"^[a-z][a-z0-9-]{0,62}(?:\.[a-z][a-z0-9-]{0,62})+$")
KEY_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ROUTE_KEYS = {"peer", "layer", "carrier", "destination", "interface", "metric", "wire_filters", "multicast", "enabled"}
SERVICE_KEYS = {"name", "route_peer", "service_point"}
ALLOC_SERVICE_KEYS = SERVICE_KEYS | {"operational_class"}
ANNOUNCEMENT_KEYS = {"protocol", "kind", "domain", "origin_mi", "sequence", "not_before", "expires_at", "service_points", "route_candidates"}
ALLOCATION_KEYS = {"protocol", "kind", "domain", "target_mi", "authority_epoch", "revision", "not_before", "expires_at", "services", "routes", "revocations"}


class Rejected(ValueError):
    """A message or policy was denied; callers must not install it."""


def _unique_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise Rejected("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def strict_load_json(wire: bytes) -> Any:
    if len(wire) > MAX_BODY * 2:
        raise Rejected("WIRE_TOO_LARGE")
    try:
        return json.loads(wire.decode("utf-8", errors="strict"), object_pairs_hook=_unique_pairs,
                          parse_constant=lambda s: (_ for _ in ()).throw(Rejected("FLOAT_FORBIDDEN")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise Rejected("INVALID_JSON") from exc


def _check_profile(value: Any, depth: int = 0) -> None:
    if depth > 12:
        raise Rejected("NESTING_LIMIT")
    if value is None or isinstance(value, (float, complex)):
        raise Rejected("UNSUPPORTED_TYPE")
    if isinstance(value, (bool, int)):
        if isinstance(value, int) and not isinstance(value, bool) and not (-2**53 < value < 2**53):
            raise Rejected("INTEGER_RANGE")
    elif isinstance(value, str):
        if not value.isascii() or any(ord(c) < 32 or ord(c) > 126 for c in value):
            raise Rejected("NON_ASCII_PROFILE")
        if len(value) > 4096:
            raise Rejected("FIELD_TOO_LONG")
    elif isinstance(value, list):
        if len(value) > 2048:
            raise Rejected("ARRAY_TOO_LARGE")
        for child in value:
            _check_profile(child, depth + 1)
    elif isinstance(value, dict):
        if len(value) > 48:
            raise Rejected("OBJECT_TOO_LARGE")
        for key, child in value.items():
            if not isinstance(key, str) or not KEY_RE.fullmatch(key):
                raise Rejected("INVALID_KEY")
            _check_profile(child, depth + 1)
    else:
        raise Rejected("UNSUPPORTED_TYPE")


def canonical_body(body: dict[str, Any]) -> bytes:
    _check_profile(body)
    out = json.dumps(body, ensure_ascii=True, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("ascii")
    if len(out) > MAX_BODY:
        raise Rejected("BODY_TOO_LARGE")
    return out


def signed_bytes(body: dict[str, Any]) -> bytes:
    kind = body.get("kind")
    if kind not in ("node.announce", "authority.allocation"):
        raise Rejected("UNKNOWN_KIND")
    return DOMAIN + kind.encode("ascii") + b"\x00" + canonical_body(body)


def sign_envelope(body: dict[str, Any], key_id: str, private_key: Ed25519PrivateKey) -> dict[str, Any]:
    return {"body": body, "signatures": [{"key_id": key_id, "signature": private_key.sign(signed_bytes(body)).hex()}]}


def add_signature(envelope: dict[str, Any], key_id: str, private_key: Ed25519PrivateKey) -> None:
    envelope["signatures"].append({"key_id": key_id, "signature": private_key.sign(signed_bytes(envelope["body"])).hex()})


def check_signatures(envelope: dict[str, Any], trusted: Mapping[str, Ed25519PublicKey]) -> set[str]:
    if not isinstance(envelope, dict) or set(envelope) != {"body", "signatures"}:
        raise Rejected("INVALID_ENVELOPE")
    body = envelope["body"]
    if not isinstance(body, dict):
        raise Rejected("BODY_REQUIRED")
    payload = signed_bytes(body)
    sigs = envelope["signatures"]
    if not isinstance(sigs, list) or len(sigs) < 1 or len(sigs) > 8:
        raise Rejected("SIGNATURE_COUNT")
    present: set[str] = set()
    for entry in sigs:
        if not isinstance(entry, dict) or set(entry) != {"key_id", "signature"}:
            raise Rejected("INVALID_SIGNATURE_ENTRY")
        kid, sig_hex = entry["key_id"], entry["signature"]
        if not isinstance(kid, str) or not isinstance(sig_hex, str):
            raise Rejected("INVALID_SIGNATURE_ENTRY")
        if kid in present:
            raise Rejected("DUPLICATE_SIGNER")
        if kid not in trusted:
            raise Rejected("UNTRUSTED_SIGNER")
        try:
            sig = bytes.fromhex(sig_hex)
            if len(sig) != 64:
                raise ValueError("length")
            trusted[kid].verify(sig, payload)
        except (ValueError, InvalidSignature) as exc:
            raise Rejected("BAD_SIGNATURE") from exc
        present.add(kid)
    return present


def _require_keys(obj: Any, required: set[str], label: str) -> None:
    if not isinstance(obj, dict) or set(obj) != required:
        raise Rejected("INVALID_" + label)


def _name(name: Any, service: bool = False) -> str:
    regex = SERVICE_RE if service else NODE_RE
    if not isinstance(name, str) or not regex.fullmatch(name):
        raise Rejected("INVALID_NAME")
    return name


def _utc(t: Any) -> datetime:
    if not isinstance(t, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", t):
        raise Rejected("INVALID_UTC")
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00"))
    except ValueError as exc:
        raise Rejected("INVALID_UTC") from exc


def _lease(body: dict[str, Any], now: datetime) -> None:
    start, end = _utc(body["not_before"]), _utc(body["expires_at"])
    if end <= start or (end - start).total_seconds() > MAX_LEASE_SECONDS:
        raise Rejected("INVALID_LEASE")
    if now.tzinfo is None:
        raise Rejected("TRUSTED_CLOCK_REQUIRED")
    if not start <= now.astimezone(timezone.utc) < end:
        raise Rejected("LEASE_NOT_CURRENT")


def _service(service: Any, allocated: bool) -> None:
    _require_keys(service, ALLOC_SERVICE_KEYS if allocated else SERVICE_KEYS, "SERVICE")
    _name(service["name"], service=True)
    _name(service["route_peer"])
    _name(service["service_point"], service=True)
    if allocated:
        _name(service["operational_class"])


def _route(route: Any) -> None:
    _require_keys(route, ROUTE_KEYS, "ROUTE")
    _name(route["peer"])
    if type(route["layer"]) is not int or route["layer"] not in (2, 3, 4):
        raise Rejected("INVALID_LAYER")
    carriers = {2: "l2", 3: "raw36", 4: "udp"}
    if route["carrier"] != carriers[route["layer"]]:
        raise Rejected("UNSUPPORTED_CARRIER")
    if not isinstance(route["destination"], str) or not 1 <= len(route["destination"]) <= 255:
        raise Rejected("INVALID_DESTINATION")
    if not isinstance(route["interface"], str) or len(route["interface"]) > 63:
        raise Rejected("INVALID_INTERFACE")
    if route["layer"] == 2 and not route["interface"]:
        raise Rejected("L2_INTERFACE_REQUIRED")
    if type(route["metric"]) is not int or not 0 <= route["metric"] <= 65535:
        raise Rejected("INVALID_METRIC")
    if type(route["multicast"]) is not bool or type(route["enabled"]) is not bool:
        raise Rejected("INVALID_BOOLEAN")
    if not isinstance(route["wire_filters"], str) or len(route["wire_filters"]) > 256:
        raise Rejected("INVALID_FILTERS")
    if any(c in (route["destination"] + route["interface"] + route["wire_filters"]) for c in ("\t", "\n", "\r")):
        raise Rejected("INVALID_SEPARATOR")


@dataclass(frozen=True)
class NodePolicy:
    domain: str
    origin_mi: str
    key_id: str
    allowed_services: frozenset[str]
    allowed_route_peers: frozenset[str]


@dataclass(frozen=True)
class AuthorityPolicy:
    domain: str
    target_mi: str
    controller_ids: frozenset[str]
    quorum: int
    class_map: Mapping[str, str]
    protected_bootstrap_peers: frozenset[str]


def verify_announcement(envelope: dict[str, Any], trusted: Mapping[str, Ed25519PublicKey],
                        policy: NodePolicy, previous_sequence: int, now: datetime) -> str:
    body = envelope["body"]
    _require_keys(body, ANNOUNCEMENT_KEYS, "ANNOUNCEMENT")
    if body["protocol"] != "xtp.provision/1" or body["kind"] != "node.announce":
        raise Rejected("WRONG_PROTOCOL")
    if body["domain"] != policy.domain or body["origin_mi"] != policy.origin_mi:
        raise Rejected("UNAUTHORIZED_ORIGIN")
    if type(body["sequence"]) is not int or body["sequence"] <= previous_sequence:
        raise Rejected("STALE_SEQUENCE")
    _lease(body, now)
    signers = check_signatures(envelope, trusted)
    if signers != {policy.key_id}:
        raise Rejected("ORIGIN_SIGNER_MISMATCH")
    points = body["service_points"]
    routes = body["route_candidates"]
    if not isinstance(points, list) or not isinstance(routes, list) or len(points) > 256 or len(routes) > 256:
        raise Rejected("INVALID_SCOPE_SIZE")
    names = set()
    for item in points:
        _service(item, allocated=False)
        if item["name"] in names:
            raise Rejected("DUPLICATE_SERVICE")
        names.add(item["name"])
        if item["name"] not in policy.allowed_services or item["route_peer"] not in policy.allowed_route_peers:
            raise Rejected("OUTSIDE_PUBLICATION_SCOPE")
    for item in routes:
        _route(item)
        if item["peer"] not in policy.allowed_route_peers:
            raise Rejected("OUTSIDE_ROUTE_SCOPE")
    return hashlib.sha256(canonical_body(body)).hexdigest()


def verify_allocation(envelope: dict[str, Any], trusted: Mapping[str, Ed25519PublicKey],
                      policy: AuthorityPolicy, floor_epoch: int, floor_revision: int,
                      now: datetime) -> str:
    body = envelope["body"]
    _require_keys(body, ALLOCATION_KEYS, "ALLOCATION")
    if body["protocol"] != "xtp.provision/1" or body["kind"] != "authority.allocation":
        raise Rejected("WRONG_PROTOCOL")
    if body["domain"] != policy.domain or body["target_mi"] != policy.target_mi:
        raise Rejected("WRONG_TARGET")
    epoch, revision = body["authority_epoch"], body["revision"]
    if type(epoch) is not int or type(revision) is not int or epoch < floor_epoch or revision < 1:
        raise Rejected("STALE_EPOCH")
    if epoch == floor_epoch and revision <= floor_revision:
        raise Rejected("STALE_REVISION")
    _lease(body, now)
    signers = check_signatures(envelope, trusted)
    if not signers.issubset(policy.controller_ids) or len(signers) < policy.quorum:
        raise Rejected("INSUFFICIENT_CONTROLLER_QUORUM")
    if policy.quorum < 2 or policy.quorum > len(policy.controller_ids):
        raise Rejected("INVALID_QUORUM_POLICY")
    services, routes, revocations = body["services"], body["routes"], body["revocations"]
    if not all(isinstance(x, list) for x in (services, routes, revocations)):
        raise Rejected("INVALID_COLLECTION")
    if any(len(x) > 2048 for x in (services, routes, revocations)):
        raise Rejected("COLLECTION_TOO_LARGE")
    names = set()
    for service in services:
        _service(service, allocated=True)
        name = service["name"]
        if name in names:
            raise Rejected("DUPLICATE_SERVICE")
        names.add(name)
        if policy.class_map.get(name) != service["operational_class"]:
            raise Rejected("OPERATIONAL_CLASS_NOT_AUTHORISED")
    peers = set()
    for route in routes:
        _route(route)
        peers.add(route["peer"])
        if route["peer"] in policy.protected_bootstrap_peers:
            raise Rejected("BOOTSTRAP_ROUTE_IMMUTABLE")
    for item in revocations:
        _name(item)
        if item in policy.protected_bootstrap_peers:
            raise Rejected("BOOTSTRAP_ROUTE_IMMUTABLE")
    if peers.intersection(revocations):
        raise Rejected("CONFLICTING_ROUTE_STATE")
    return hashlib.sha256(canonical_body(body)).hexdigest()
