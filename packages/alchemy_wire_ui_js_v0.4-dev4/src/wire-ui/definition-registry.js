function clone(value) {
  return typeof structuredClone === 'function' ? structuredClone(value) : JSON.parse(JSON.stringify(value));
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export class DefinitionRegistry {
  constructor({ profileId = '*' } = {}) {
    this.profileId = profileId;
    this.definitions = new Map();
    this.canonical = new Map();
  }

  key(id, version = 1) { return `${id}@${version}`; }

  setProfileId(profileId) {
    if (!profileId) throw new TypeError('profileId is required');
    if (this.definitions.size && this.profileId !== '*' && this.profileId !== profileId) {
      throw new Error(`cannot change render profile with installed definitions (${this.profileId} -> ${profileId})`);
    }
    this.profileId = profileId;
  }

  install(definition) {
    this.#validate(definition);
    const key = this.key(definition.id, definition.version);
    const text = canonical(definition);
    if (this.definitions.has(key)) {
      if (this.canonical.get(key) !== text) throw new Error(`immutable definition conflict for ${key}`);
      return this.definitions.get(key);
    }
    const frozen = clone(definition);
    this.definitions.set(key, frozen);
    this.canonical.set(key, text);
    return frozen;
  }

  get(id, version = 1) { return this.definitions.get(this.key(id, version)) ?? null; }
  has(id, version = 1) { return this.definitions.has(this.key(id, version)); }

  #validate(definition) {
    if (!definition?.id) throw new TypeError('definition id is required');
    if (!Number.isSafeInteger(definition.version) || definition.version < 1) throw new TypeError('definition version must be a positive integer');
    if (definition.profileId && definition.profileId !== '*' && definition.profileId !== this.profileId) {
      throw new Error(`definition ${definition.id} is for render profile ${definition.profileId}, not ${this.profileId}`);
    }
    if (!Array.isArray(definition.nodes) || definition.nodes.length === 0) throw new TypeError('definition nodes are required');
    if (!Array.isArray(definition.slots)) definition.slots = [];
    if (!Array.isArray(definition.actions)) definition.actions = [];
  }
}
