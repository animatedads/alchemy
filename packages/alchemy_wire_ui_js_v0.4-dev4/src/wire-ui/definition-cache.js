function clone(value) {
  return typeof structuredClone === 'function' ? structuredClone(value) : JSON.parse(JSON.stringify(value));
}

function cacheKey({ siteId = '*', profileId = '*', contentAddress }) {
  if (!contentAddress) throw new TypeError('contentAddress is required');
  return `${siteId}|${profileId}|${contentAddress}`;
}

/**
 * In-memory content-addressed definition cache.  Useful for tests and as a
 * fallback when persistent browser storage is unavailable.
 */
export class MemoryDefinitionCache {
  constructor() { this.entries = new Map(); }

  async get(ref) {
    const value = this.entries.get(cacheKey(ref));
    return value ? clone(value) : null;
  }

  async put(ref, definition) {
    this.entries.set(cacheKey(ref), clone(definition));
    return definition;
  }

  async has(ref) { return this.entries.has(cacheKey(ref)); }

  async remove(ref) { this.entries.delete(cacheKey(ref)); }

  async clear() { this.entries.clear(); }
}

/**
 * Persistent browser cache for immutable element definitions.  No session or
 * live UI state is stored here.  localStorage is deliberately sufficient for
 * the small v0.3 contract; a future IndexedDB backend can implement the same
 * async interface without changing Wire UI.
 */
export class LocalStorageDefinitionCache {
  constructor({ storage = globalThis.localStorage, prefix = 'alchemy.wireui.definition' } = {}) {
    if (!storage) throw new Error('persistent storage is not available');
    this.storage = storage;
    this.prefix = prefix;
  }

  #key(ref) { return `${this.prefix}:${encodeURIComponent(cacheKey(ref))}`; }

  async get(ref) {
    const text = this.storage.getItem(this.#key(ref));
    if (text == null) return null;
    try { return JSON.parse(text); }
    catch {
      this.storage.removeItem(this.#key(ref));
      return null;
    }
  }

  async put(ref, definition) {
    this.storage.setItem(this.#key(ref), JSON.stringify(definition));
    return definition;
  }

  async has(ref) { return this.storage.getItem(this.#key(ref)) != null; }

  async remove(ref) { this.storage.removeItem(this.#key(ref)); }
}
