function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).filter((key) => value[key] !== undefined).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function bytesToHex(bytes) {
  return [...new Uint8Array(bytes)].map((value) => value.toString(16).padStart(2, '0')).join('');
}

export function canonicalDefinition(definition) {
  if (!definition || typeof definition !== 'object') throw new TypeError('definition is required');
  const value = { ...definition };
  delete value.contentAddress;
  return canonical(value);
}

export async function definitionContentAddress(definition, cryptoImpl = globalThis.crypto) {
  if (!cryptoImpl?.subtle) throw new Error('Web Crypto SHA-256 support is required');
  const bytes = new TextEncoder().encode(canonicalDefinition(definition));
  const digest = await cryptoImpl.subtle.digest('SHA-256', bytes);
  return `sha256:${bytesToHex(digest)}`;
}

export async function verifyDefinitionContentAddress(definition, expected = definition?.contentAddress, cryptoImpl = globalThis.crypto) {
  if (!expected) return true;
  // Only sha256:<64 hex> is treated as a cryptographic address. Other values
  // remain valid opaque cache identities for compatibility with early server cuts.
  if (!/^sha256:[0-9a-f]{64}$/i.test(expected)) return true;
  const actual = await definitionContentAddress(definition, cryptoImpl);
  if (actual.toLowerCase() !== expected.toLowerCase()) {
    throw new Error(`definition content-address mismatch: expected ${expected}, got ${actual}`);
  }
  return true;
}
