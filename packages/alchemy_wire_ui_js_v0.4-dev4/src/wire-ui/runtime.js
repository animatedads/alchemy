import { MessageKind } from '../protocol.js';
import { adaptServerDefinition, adaptServerSnapshot, adaptServerPatch } from '../server-semantic-adapter.js';

export class WireUIRuntime {
  constructor({ comms, definitions, renderer, ownership = {}, serverSemantic = false, renderProfile = null }) {
    this.comms = comms;
    this.definitions = definitions;
    this.renderer = renderer;
    this.ownership = { ...ownership };
    this.serverSemantic = serverSemantic;
    this.renderProfile = renderProfile;
    this.viewRef = null;
    this.revision = null;
    this.waitingForResync = false;
    this.pendingSnapshot = null;
    this.pendingPatches = [];
    this.pendingDefinitionRequestKey = null;

    renderer.setActionSink((action) => void this.#sendAction(action));
    comms.on(MessageKind.UI_DEFINITION, (payload) => this.#onDefinition(payload));
    comms.on(MessageKind.UI_VIEW_SNAPSHOT, (payload) => this.#onSnapshot(payload));
    comms.on(MessageKind.UI_VIEW_PATCH, (payload) => this.#onPatch(payload));
  }

  async #onDefinition(payload) {
    let definition = payload?.definition ?? payload;
    if (this.serverSemantic && definition?.definitionId) definition = adaptServerDefinition(definition);
    const installed = this.definitions.install(definition);
    await this.renderProfile?.cacheDefinition?.(installed);
    this.renderer.prepareDefinition?.(installed);
    if (this.pendingSnapshot && this.#missingDefinitions(this.pendingSnapshot).length === 0) {
      const snapshot = this.pendingSnapshot;
      this.pendingSnapshot = null;
      this.pendingDefinitionRequestKey = null;
      await this.#applySnapshot(snapshot);
    }
    await this.#drainPendingPatches();
  }

  async #onSnapshot(snapshot) {
    if (this.serverSemantic && snapshot?.elementInstances) snapshot = adaptServerSnapshot(snapshot);
    const missing = this.#missingDefinitions(snapshot);
    if (missing.length) {
      this.pendingSnapshot = snapshot;
      await this.#requestDefinitions(missing);
      return;
    }
    await this.#applySnapshot(snapshot);
  }

  async #applySnapshot(snapshot) {
    this.#validateSnapshot(snapshot);
    this.renderer.reset();
    for (const instance of snapshot.instances) this.renderer.createInstance(instance);
    this.renderer.setRoot(snapshot.rootInstanceId);
    this.viewRef = snapshot.viewRef;
    this.revision = snapshot.revision;
    this.waitingForResync = false;
    this.pendingPatches = [];
  }

  async #onPatch(patch) {
    if (this.serverSemantic) patch = adaptServerPatch(patch);
    if (this.waitingForResync) return;

    // A CREATE_INSTANCE may legitimately race ahead of its subscription-
    // delivered immutable definition on a cold cache. Preserve queue order and
    // hold the patch behind a definition barrier instead of misclassifying it
    // as corruption/resync. Subsequent patches queue behind the same barrier.
    const expectedPrevious = this.pendingPatches.length
      ? this.pendingPatches[this.pendingPatches.length - 1].newRevision
      : this.revision;
    if (this.viewRef !== patch.viewRef || expectedPrevious !== patch.previousRevision) {
      await this.#requestResync('revision-gap', patch);
      return;
    }
    this.pendingPatches.push(patch);
    await this.#drainPendingPatches();
  }

  async #drainPendingPatches() {
    if (this.waitingForResync || this.pendingSnapshot) return;
    while (this.pendingPatches.length) {
      const patch = this.pendingPatches[0];
      if (this.viewRef !== patch.viewRef || this.revision !== patch.previousRevision) {
        await this.#requestResync('revision-gap', patch);
        return;
      }
      const missing = this.#missingDefinitionsForPatch(patch);
      if (missing.length) {
        await this.#requestDefinitions(missing);
        return;
      }
      try {
        for (const op of patch.operations ?? []) this.#applyOperation(op);
        this.revision = patch.newRevision;
        this.pendingPatches.shift();
      } catch (error) {
        await this.#requestResync('patch-apply-failed', patch, error);
        return;
      }
    }
    this.pendingDefinitionRequestKey = null;
  }

  #applyOperation(op) {
    switch (op.op) {
      case 'SET_SLOT':
        this.renderer.setSlot(op.instanceId, op.slot, op.value);
        break;
      case 'CREATE_INSTANCE':
        this.renderer.createInstance(op.instance);
        break;
      case 'DESTROY_INSTANCE':
        this.renderer.destroyInstance(op.instanceId);
        break;
      case 'LIST_APPEND':
        if (op.instance) {
          this.renderer.createInstance({ ...op.instance, parentInstanceId: op.parentInstanceId });
        } else {
          this.renderer.attachInstance(op.parentInstanceId, op.childInstanceId);
        }
        break;
      case 'LIST_REMOVE':
        this.renderer.destroyInstance(op.childInstanceId);
        break;
      case 'LIST_MOVE':
        this.renderer.moveInstance(op.parentInstanceId, op.childInstanceId, op.index);
        break;
      default:
        throw new Error(`unknown UI patch operation ${op.op}`);
    }
  }

  async #sendAction({ instanceId, action, detail }) {
    return this.sendSemanticAction(action, { instanceId, detail });
  }

  /**
   * Public semantic-action seam used by rendered elements and authorised
   * non-decorative access-point capabilities such as interaction-profile
   * selection. The server remains authoritative and must revalidate it.
   */
  async sendSemanticAction(action, {
    instanceId = null,
    detail = {},
    viewRef = this.viewRef,
    renderedRevision = this.revision
  } = {}) {
    if (!action) throw new TypeError('semantic action is required');
    if (viewRef == null || renderedRevision == null) return null;
    return this.comms.send(MessageKind.UI_ACTION, {
      ...this.ownership,
      viewRef,
      renderedRevision,
      elementInstance: instanceId,
      action,
      detail
    });
  }

  async #requestResync(reason, patch, error = null) {
    this.waitingForResync = true;
    await this.comms.send(MessageKind.UI_RESYNC_REQUEST, {
      ...this.ownership,
      viewRef: this.viewRef,
      haveRevision: this.revision,
      receivedPreviousRevision: patch?.previousRevision ?? null,
      receivedNewRevision: patch?.newRevision ?? null,
      reason,
      error: error ? String(error.message ?? error) : null
    });
  }

  #missingDefinitions(snapshot) {
    const unique = new Map();
    for (const instance of snapshot.instances ?? []) {
      const version = instance.definitionVersion ?? 1;
      if (!this.definitions.has(instance.definitionId, version)) {
        unique.set(`${instance.definitionId}@${version}`, { id: instance.definitionId, version });
      }
    }
    return [...unique.values()];
  }

  #missingDefinitionsForPatch(patch) {
    const unique = new Map();
    for (const op of patch.operations ?? []) {
      const instance = (op.op === 'CREATE_INSTANCE' || op.op === 'LIST_APPEND') ? op.instance : null;
      if (!instance) continue;
      const version = instance.definitionVersion ?? 1;
      if (!this.definitions.has(instance.definitionId, version)) {
        unique.set(`${instance.definitionId}@${version}`, { id: instance.definitionId, version });
      }
    }
    return [...unique.values()];
  }

  async #requestDefinitions(missing) {
    const requestKey = JSON.stringify(missing);
    if (requestKey === this.pendingDefinitionRequestKey) return;
    this.pendingDefinitionRequestKey = requestKey;
    await this.comms.send(MessageKind.UI_DEFINITION_REQUIRED, { definitions: missing });
  }

  #validateSnapshot(snapshot) {
    if (!snapshot?.viewRef) throw new TypeError('snapshot viewRef is required');
    if (!Number.isSafeInteger(snapshot.revision) || snapshot.revision < 0) throw new TypeError('snapshot revision is invalid');
    if (!Array.isArray(snapshot.instances)) throw new TypeError('snapshot instances are required');
    if (snapshot.rootInstanceId == null) throw new TypeError('snapshot rootInstanceId is required');
  }
}
