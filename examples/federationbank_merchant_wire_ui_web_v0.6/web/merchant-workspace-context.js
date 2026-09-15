export class MerchantWorkspaceContextEcho {
  constructor({ comms, MessageKind, workspaceRef = 'FBM.BOOKS', contextInstanceId = 'workspace-context' }) {
    this.comms = comms;
    this.MessageKind = MessageKind;
    this.workspaceRef = workspaceRef;
    this.contextInstanceId = contextInstanceId;
    this.context = null;
    this.slots = new Map();
  }

  install() {
    this.comms.on(this.MessageKind.UI_VIEW_SNAPSHOT, (payload) => this.#snapshot(payload));
    this.comms.on(this.MessageKind.UI_VIEW_PATCH, (payload) => this.#patch(payload));
    const original = this.comms.send.bind(this.comms);
    this.comms.send = async (kind, payload, options) => {
      if (kind === this.MessageKind.UI_ACTION && this.context) {
        const detail = payload?.detail && typeof payload.detail === 'object' && !Array.isArray(payload.detail) ? payload.detail : {};
        payload = { ...payload, detail: { ...detail, workspaceContext: this.#copyContext() } };
      }
      return original(kind, payload, options);
    };
    return this;
  }

  #snapshot(payload) {
    this.slots.clear();
    for (const instance of payload?.elementInstances ?? []) {
      this.slots.set(String(instance.instanceId), { ...(instance.slots ?? {}) });
    }
    this.#refresh();
  }

  #patch(payload) {
    for (const op of payload?.operations ?? []) {
      if (op.op === 'CREATE_INSTANCE' || op.op === 'LIST_APPEND') {
        const instance = op.instance;
        if (instance?.instanceId) this.slots.set(String(instance.instanceId), { ...(instance.slots ?? {}) });
      } else if (op.op === 'DESTROY_INSTANCE' || op.op === 'LIST_REMOVE') {
        const id = op.instanceId ?? op.childInstanceId;
        if (id != null) this.slots.delete(String(id));
      } else if (op.op === 'SET_SLOT' && op.instanceId != null) {
        const id = String(op.instanceId);
        const slots = this.slots.get(id) ?? {};
        slots[op.slot] = op.value;
        this.slots.set(id, slots);
      }
    }
    this.#refresh();
  }

  #refresh() {
    const s = this.slots.get(this.contextInstanceId);
    if (!s || s.workspaceRef !== this.workspaceRef) return;
    let selectedIds = [];
    try {
      const parsed = JSON.parse(String(s.selectedIdsJson ?? '[]'));
      if (Array.isArray(parsed) && parsed.every((v) => typeof v === 'string')) selectedIds = parsed;
    } catch { selectedIds = []; }
    const integer = (name) => Number.isSafeInteger(Number(s[name])) ? Number(s[name]) : -1;
    this.context = Object.freeze({
      workspaceRef: this.workspaceRef,
      queryRevision: integer('queryRevision'),
      scopeRevision: integer('scopeRevision'),
      orderRevision: integer('orderRevision'),
      selectionRevision: integer('selectionRevision'),
      selectedIds: Object.freeze([...selectedIds]),
      resultRevision: integer('resultRevision'),
      resultQueryRevision: integer('resultQueryRevision'),
      resultScopeRevision: integer('resultScopeRevision'),
      resultOrderRevision: integer('resultOrderRevision')
    });
  }

  #copyContext() {
    return { ...this.context, selectedIds: [...this.context.selectedIds] };
  }
}
