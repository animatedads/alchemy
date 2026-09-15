/** Deterministic renderer used for server-contract and runtime tests. */
export class MemoryRenderer {
  constructor({ definitions }) {
    this.definitions = definitions;
    this.instances = new Map();
    this.rootInstanceId = null;
    this.actionSink = null;
  }

  setActionSink(fn) { this.actionSink = fn; }
  prepareDefinition() {}
  reset() { this.instances.clear(); this.rootInstanceId = null; }
  setRoot(instanceId) { this.rootInstanceId = instanceId; }

  createInstance(instance) {
    const definition = this.definitions.get(instance.definitionId, instance.definitionVersion ?? 1);
    if (!definition) throw new Error(`definition not installed: ${instance.definitionId}@${instance.definitionVersion ?? 1}`);
    if (this.instances.has(instance.instanceId)) throw new Error(`instance already exists: ${instance.instanceId}`);
    this.instances.set(instance.instanceId, {
      ...structuredClone(instance),
      slots: Array.isArray(instance.slots) ? [...instance.slots] : { ...(instance.slots ?? {}) },
      children: []
    });
    if (instance.parentInstanceId != null) this.attachInstance(instance.parentInstanceId, instance.instanceId, instance.index);
  }

  destroyInstance(instanceId) {
    const instance = this.instances.get(instanceId);
    if (!instance) return;
    for (const child of [...instance.children]) this.destroyInstance(child);
    if (instance.parentInstanceId != null) {
      const parent = this.instances.get(instance.parentInstanceId);
      if (parent) parent.children = parent.children.filter((id) => id !== instanceId);
    }
    this.instances.delete(instanceId);
  }

  setSlot(instanceId, slot, value) {
    const instance = this.#require(instanceId);
    instance.slots[slot] = structuredClone(value);
  }

  attachInstance(parentId, childId, index = undefined) {
    const parent = this.#require(parentId);
    const child = this.#require(childId);
    if (child.parentInstanceId != null && child.parentInstanceId !== parentId) {
      const oldParent = this.instances.get(child.parentInstanceId);
      if (oldParent) oldParent.children = oldParent.children.filter((id) => id !== childId);
    }
    child.parentInstanceId = parentId;
    parent.children = parent.children.filter((id) => id !== childId);
    const pos = index == null ? parent.children.length : Math.max(0, Math.min(index, parent.children.length));
    parent.children.splice(pos, 0, childId);
  }

  moveInstance(parentId, childId, index) { this.attachInstance(parentId, childId, index); }
  getInstance(instanceId) { return this.instances.get(instanceId) ?? null; }

  emitAction(instanceId, action, detail = {}) {
    this.actionSink?.({ instanceId, action, detail });
  }

  #require(instanceId) {
    const value = this.instances.get(instanceId);
    if (!value) throw new Error(`unknown instance ${instanceId}`);
    return value;
  }
}
