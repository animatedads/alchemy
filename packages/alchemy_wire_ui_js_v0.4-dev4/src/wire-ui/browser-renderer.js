const primitiveFactories = Object.freeze({
  container: (d) => d.createElement('div'),
  text: (d) => d.createElement('span'),
  button: (d) => d.createElement('button'),
  input: (d) => d.createElement('input'),
  list: (d) => d.createElement('div'),
  form: (d) => d.createElement('form'),
  document: (d) => d.createElement('article'),
  'semantic-record': (d) => d.createElement('div'),
  label: (d) => d.createElement('label')
});

const slotCompilers = Object.freeze({
  text: (node) => (value) => { node.textContent = value == null ? '' : String(value); },
  enabled: (node) => (value) => { node.disabled = !value; },
  visible: (node) => (value) => { node.hidden = !value; },
  value: (node) => (value) => { if (node.value !== String(value ?? '')) node.value = String(value ?? ''); },
  checked: (node) => (value) => { node.checked = Boolean(value); },
  ariaLabel: (node) => (value) => value == null ? node.removeAttribute('aria-label') : node.setAttribute('aria-label', String(value)),
  collection: (node) => (value) => {
    const items = Array.isArray(value) ? value : [];
    node.replaceChildren();
    for (let index = 0; index < items.length; index += 1) {
      const item = items[index];
      const child = node.ownerDocument.createElement(node.__wireCollectionActionable ? 'button' : 'div');
      child.className = 'wui-collection-item';
      if (node.__wireCollectionActionable) child.setAttribute('type', 'button');
      child.__wireCollectionItem = true;
      const detail = { index };
      if (item && typeof item === 'object' && !Array.isArray(item)) {
        for (const key of ['offerId','id','key','code','ref']) {
          if (item[key] != null) { detail[key] = item[key]; break; }
        }
        const visible = Object.entries(item).filter(([,v]) => v == null || ['string','number','boolean'].includes(typeof v));
        child.textContent = visible.map(([k,v]) => `${k}: ${v ?? ''}`).join(' · ');
      } else {
        detail.value = item; child.textContent = item == null ? '' : String(item);
      }
      child.__wireActionDetail = detail;
      node.appendChild(child);
    }
  }
});

/**
 * DOM renderer. Definitions are interpreted exactly once per definition and
 * compiled into factories/slot writers for subsequent instance mutations.
 */
export class BrowserRenderer {
  constructor({ definitions, mount, document = globalThis.document }) {
    if (!document) throw new Error('document is required');
    if (!mount) throw new Error('mount element is required');
    this.definitions = definitions;
    this.mount = mount;
    this.document = document;
    this.compiled = new Map();
    this.instances = new Map();
    this.rootInstanceId = null;
    this.actionSink = null;
  }

  setActionSink(fn) { this.actionSink = fn; }

  prepareDefinition(definition) {
    this.#compile(definition);
  }

  reset() {
    this.instances.clear();
    this.rootInstanceId = null;
    this.mount.replaceChildren();
  }

  setRoot(instanceId) {
    this.rootInstanceId = instanceId;
    const instance = this.#requireInstance(instanceId);
    this.mount.replaceChildren(instance.root);
  }

  createInstance(instance) {
    const definition = this.definitions.get(instance.definitionId, instance.definitionVersion ?? 1);
    if (!definition) throw new Error(`definition not installed: ${instance.definitionId}@${instance.definitionVersion ?? 1}`);
    const compiled = this.#compile(definition);
    const live = compiled.create(instance.instanceId, (action, detail) => {
      this.actionSink?.({ instanceId: instance.instanceId, action, detail });
    });
    live.definitionId = instance.definitionId;
    live.definitionVersion = instance.definitionVersion ?? 1;
    live.parentInstanceId = instance.parentInstanceId ?? null;
    this.instances.set(instance.instanceId, live);

    if (Array.isArray(instance.slots)) {
      for (let i = 0; i < instance.slots.length; i += 1) {
        if (instance.slots[i] !== undefined) live.writers[i]?.(instance.slots[i]);
      }
    } else {
      for (const [name, value] of Object.entries(instance.slots ?? {})) {
        live.namedWriters[name]?.(value);
      }
    }

    if (instance.parentInstanceId != null) this.attachInstance(instance.parentInstanceId, instance.instanceId, instance.index);
  }

  destroyInstance(instanceId) {
    const live = this.instances.get(instanceId);
    if (!live) return;
    live.root.remove();
    this.instances.delete(instanceId);
  }

  setSlot(instanceId, slot, value) {
    const live = this.#requireInstance(instanceId);
    const writer = Number.isInteger(slot) ? live.writers[slot] : live.namedWriters[slot];
    if (!writer) throw new Error(`slot ${slot} not defined for instance ${instanceId}`);
    writer(value);
  }

  attachInstance(parentId, childId, index = undefined) {
    const parent = this.#requireInstance(parentId);
    const child = this.#requireInstance(childId);
    child.parentInstanceId = parentId;
    const target = parent.mount;
    if (index == null || index >= target.children.length) target.appendChild(child.root);
    else target.insertBefore(child.root, target.children[index]);
  }

  moveInstance(parentId, childId, index) { this.attachInstance(parentId, childId, index); }

  #compile(definition) {
    const key = `${definition.id}@${definition.version}`;
    if (this.compiled.has(key)) return this.compiled.get(key);

    // Validate/normalise once. No primitive/writer lookup is performed in the
    // live update path after create().
    const nodeSpecs = definition.nodes.map((spec) => {
      const factory = primitiveFactories[spec.primitive];
      if (!factory) throw new Error(`unknown primitive ${spec.primitive}`);
      return { ...spec, factory };
    });
    const slotSpecs = definition.slots.map((slot) => {
      const compiler = slotCompilers[slot.writer];
      if (!compiler) throw new Error(`unknown slot writer ${slot.writer}`);
      return { ...slot, compiler };
    });
    const actionSpecs = definition.actions.map((action) => ({ ...action }));

    const compiled = {
      create: (instanceId, emitAction) => {
        const nodes = new Map();
        for (const spec of nodeSpecs) {
          const node = spec.factory(this.document);
          if (spec.className) node.className = spec.className;
          if (spec.role) node.setAttribute('role', spec.role);
          if (spec.text != null) node.textContent = String(spec.text);
          if (spec.collectionActionable) node.__wireCollectionActionable = true;
          for (const [name, value] of Object.entries(spec.attrs ?? {})) node.setAttribute(name, String(value));
          nodes.set(spec.key, node);
          if (spec.parent) nodes.get(spec.parent).appendChild(node);
        }

        const writers = [];
        const namedWriters = Object.create(null);
        for (const slot of slotSpecs) {
          const writer = slot.compiler(nodes.get(slot.target));
          writers[slot.index] = writer;
          if (slot.name) namedWriters[slot.name] = writer;
        }
        for (const action of actionSpecs) {
          const node = nodes.get(action.target);
          node.addEventListener(action.event, (event) => {
            if (action.preventDefault) event.preventDefault();
            let detail = {};
            if (action.detail === 'value') detail = { value: event.currentTarget.value };
            else if (action.detail?.kind === 'fields') {
              detail = {};
              for (const field of action.detail.fields ?? []) { const target=nodes.get(field.target); detail[field.name] = field.property==='checked' ? Boolean(target?.checked) : (target?.value ?? ''); }
            } else if (action.detail?.kind === 'collection-item') {
              let item = event.target ?? null;
              while (item && !item.__wireCollectionItem) item = item.parentElement ?? item.parent ?? null;
              if (!item?.__wireCollectionItem) return;
              detail = { ...(item.__wireActionDetail ?? {}) };
            }
            emitAction(action.action, detail);
          });
        }

        const root = nodes.get(definition.root ?? nodeSpecs[0].key);
        const mount = nodes.get(definition.mount ?? definition.root ?? nodeSpecs[0].key);
        return { instanceId, root, mount, nodes, writers, namedWriters };
      }
    };
    this.compiled.set(key, compiled);
    return compiled;
  }

  #requireInstance(instanceId) {
    const value = this.instances.get(instanceId);
    if (!value) throw new Error(`unknown instance ${instanceId}`);
    return value;
  }
}
