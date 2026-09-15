import { MessageKind } from '../protocol.js';

function normaliseEntry(value) {
  if (typeof value === 'string') return { name: value, revision: null, purpose: null };
  if (!value?.name) throw new TypeError('subscription entry name is required');
  return {
    name: value.name,
    revision: value.revision ?? null,
    purpose: value.purpose ?? null
  };
}

/**
 * Browser-side executor for a server-authored journey projection.
 *
 * This class does not predict journeys. It only:
 *   - reconciles ACTIVE/PREFETCH subscription intent supplied by the server;
 *   - records ON_DEMAND capabilities without activating them;
 *   - requests one named ON_DEMAND capability explicitly when needed;
 *   - exposes interaction-profile offers and sends the explicit semantic
 *     INTERACTION.PROFILE.SELECT action.
 */
export class WireUIJourneyController {
  constructor({ comms, runtime = null }) {
    if (!comms) throw new TypeError('comms is required');
    this.comms = comms;
    this.runtime = runtime;
    this.plan = null;
    this.onDemand = new Map();
    this.profileOffers = new Map();
    this.handlers = new Set();

    comms.on(MessageKind.UI_JOURNEY_PLAN, (payload) => this.installPlan(payload));
    comms.on(MessageKind.INTERACTION_PROFILE_OFFER, (payload) => this.installProfileOffer(payload));
  }

  onState(handler) {
    this.handlers.add(handler);
    return () => this.handlers.delete(handler);
  }

  async installPlan(plan = {}) {
    if (!plan.planId) throw new TypeError('journey planId is required');
    const active = (plan.active ?? []).map(normaliseEntry);
    const prefetch = (plan.prefetch ?? []).map(normaliseEntry);
    const onDemand = (plan.onDemand ?? []).map((entry) => {
      const value = normaliseEntry(entry);
      return { ...value, capability: entry.capability ?? value.name };
    });

    const desired = [...active, ...prefetch];
    await this.comms.reconcileSubscriptions(desired);

    this.onDemand = new Map(onDemand.map((entry) => [entry.capability, entry]));
    this.plan = Object.freeze({
      planId: plan.planId,
      revision: plan.revision ?? null,
      journeyRef: plan.journeyRef ?? null,
      transitionRef: plan.transitionRef ?? null,
      active,
      prefetch,
      onDemand
    });
    this.#emit({ type: 'journey-plan-installed', plan: this.plan });
    return this.plan;
  }

  getPlan() { return this.plan; }

  listOnDemand() { return [...this.onDemand.values()]; }

  async requestOnDemand(capability, { reason = 'explicit-request', detail = null } = {}) {
    const entry = this.onDemand.get(capability);
    if (!entry) throw new Error(`on-demand capability is not offered by the current journey plan: ${capability}`);

    const envelope = await this.comms.send(MessageKind.UI_ON_DEMAND_REQUEST, {
      planId: this.plan?.planId ?? null,
      planRevision: this.plan?.revision ?? null,
      journeyRef: this.plan?.journeyRef ?? null,
      transitionRef: this.plan?.transitionRef ?? null,
      capability,
      subscription: entry.name,
      subscriptionRevision: entry.revision,
      purpose: entry.purpose,
      reason,
      detail
    });
    this.#emit({ type: 'on-demand-requested', capability, messageId: envelope.messageId });
    return envelope;
  }

  installProfileOffer(offer = {}) {
    if (!offer.offerId) throw new TypeError('interaction profile offerId is required');
    const profiles = Array.isArray(offer.profiles) ? [...offer.profiles] : [];
    const frozen = Object.freeze({
      offerId: offer.offerId,
      profiles,
      elementInstance: offer.elementInstance ?? null,
      viewRef: offer.viewRef ?? null,
      revision: offer.revision ?? null,
      purpose: offer.purpose ?? null,
      expiresAt: offer.expiresAt ?? null
    });
    this.profileOffers.set(frozen.offerId, frozen);
    this.#emit({ type: 'interaction-profile-offer', offer: frozen });
    return frozen;
  }

  getProfileOffer(offerId) { return this.profileOffers.get(offerId) ?? null; }

  async selectInteractionProfile(offerId, profileId, detail = {}) {
    const offer = this.profileOffers.get(offerId);
    if (!offer) throw new Error(`unknown interaction profile offer ${offerId}`);
    if (!offer.profiles.includes(profileId)) throw new Error(`profile ${profileId} is not offered by ${offerId}`);

    const payloadDetail = { ...detail, offerId, profileId };
    if (this.runtime?.sendSemanticAction) {
      return this.runtime.sendSemanticAction('INTERACTION.PROFILE.SELECT', {
        instanceId: offer.elementInstance,
        detail: payloadDetail,
        viewRef: offer.viewRef,
        renderedRevision: offer.revision
      });
    }

    return this.comms.send(MessageKind.UI_ACTION, {
      viewRef: offer.viewRef,
      renderedRevision: offer.revision,
      elementInstance: offer.elementInstance,
      action: 'INTERACTION.PROFILE.SELECT',
      detail: payloadDetail
    });
  }

  #emit(event) {
    for (const handler of [...this.handlers]) handler(event);
  }
}
