import { MessageKind } from './protocol.js';

/**
 * Positive-list observation plan. A disabled point is a genuine fast return:
 * payload factories are not called and nothing is queued.
 */
export class ObservationPlan {
  constructor({ comms }) {
    this.comms = comms;
    this.subscription = null;
    this.revision = null;
    this.points = new Map();
    this.comms.on(MessageKind.OBSERVATION_PLAN, (payload) => this.install(payload));
  }

  install({ subscription, revision, points = [] }) {
    if (!subscription) throw new TypeError('observation subscription is required');
    const compiled = new Map();
    for (const point of points) {
      if (!point?.id) throw new TypeError('observation point id is required');
      compiled.set(point.id, {
        id: point.id,
        allowedFields: point.allowedFields ? new Set(point.allowedFields) : null,
        purpose: point.purpose ?? null,
        evidenceStrength: point.evidenceStrength ?? 'CLIENT_APPLICATION_ASSERTED'
      });
    }
    this.subscription = subscription;
    this.revision = revision ?? null;
    this.points = compiled;
  }

  isEnabled(pointId) { return this.points.has(pointId); }

  async observe(pointId, payloadOrFactory = {}) {
    const point = this.points.get(pointId);
    if (!point) return false;

    const raw = typeof payloadOrFactory === 'function' ? payloadOrFactory() : payloadOrFactory;
    const payload = this.#projectFields(raw ?? {}, point.allowedFields);
    await this.comms.send(MessageKind.INTERACTION_OBSERVATION, {
      subscription: this.subscription,
      subscriptionRevision: this.revision,
      point: pointId,
      purpose: point.purpose,
      evidenceStrength: point.evidenceStrength,
      observation: payload
    });
    return true;
  }

  #projectFields(raw, allowedFields) {
    if (!allowedFields) return { ...raw };
    const projected = {};
    for (const field of allowedFields) if (Object.hasOwn(raw, field)) projected[field] = raw[field];
    return projected;
  }
}
