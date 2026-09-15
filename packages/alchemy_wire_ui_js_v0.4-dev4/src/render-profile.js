import { MessageKind } from './protocol.js';
import { capabilityFingerprint, detectRenderCapabilities } from './profile.js';
import { verifyDefinitionContentAddress } from './content-address.js';

/**
 * One-time render-profile/bootstrap negotiation.  Capability decisions are
 * made here, not in the live render/update path.
 */
export class RenderProfileController {
  constructor({ comms, definitions, definitionCache = null, renderer = null, siteId = '*', capabilities = null }) {
    this.comms = comms;
    this.definitions = definitions;
    this.definitionCache = definitionCache;
    this.renderer = renderer;
    this.siteId = siteId;
    this.capabilities = capabilities ?? detectRenderCapabilities();
    this.fingerprint = capabilityFingerprint(this.capabilities);
    this.profileId = definitions.profileId ?? '*';
    this.manifestId = null;
    this.manifest = new Map();

    comms.on(MessageKind.UI_RENDER_PROFILE, (payload) => this.#applyProfile(payload));
    comms.on(MessageKind.UI_DEFINITION_MANIFEST, (payload) => this.#applyManifest(payload));
  }

  helloPayload(extra = {}) {
    return {
      ...extra,
      renderCapabilities: this.capabilities,
      capabilityFingerprint: this.fingerprint,
      cachedManifestId: this.manifestId
    };
  }

  async #applyProfile(payload = {}) {
    if (!payload.profileId) throw new TypeError('render profileId is required');
    this.profileId = payload.profileId;
    this.siteId = payload.siteId ?? this.siteId;
    this.manifestId = payload.manifestId ?? this.manifestId;
    this.definitions.setProfileId?.(this.profileId);
    if (Array.isArray(payload.definitions)) await this.#applyManifest({
      siteId: this.siteId,
      profileId: this.profileId,
      manifestId: this.manifestId,
      definitions: payload.definitions
    });
  }

  async #applyManifest(payload = {}) {
    const profileId = payload.profileId ?? this.profileId;
    const siteId = payload.siteId ?? this.siteId;
    if (profileId !== this.profileId) throw new Error(`definition manifest profile ${profileId} does not match selected profile ${this.profileId}`);
    this.manifestId = payload.manifestId ?? this.manifestId;
    this.manifest.clear();

    const missing = [];
    for (const entry of payload.definitions ?? []) {
      if (!entry?.id) throw new TypeError('manifest definition id is required');
      const version = Number(entry.version ?? 1);
      const ref = {
        id: entry.id,
        version,
        contentAddress: entry.contentAddress ?? null,
        siteId,
        profileId
      };
      this.manifest.set(`${entry.id}@${version}`, ref);
      if (this.definitions.has(entry.id, version)) continue;

      let cached = null;
      if (this.definitionCache && ref.contentAddress) {
        cached = await this.definitionCache.get(ref);
      }
      if (cached) {
        await verifyDefinitionContentAddress(cached, ref.contentAddress);
        const installed = this.definitions.install(cached);
        this.renderer?.prepareDefinition?.(installed);
      } else {
        missing.push({ id: entry.id, version, contentAddress: ref.contentAddress });
      }
    }

    if (missing.length) {
      await this.comms.send(MessageKind.UI_DEFINITION_REQUIRED, {
        siteId,
        profileId,
        manifestId: this.manifestId,
        definitions: missing
      });
    }
    return { loadedFromCache: (payload.definitions?.length ?? 0) - missing.length, missing };
  }

  async cacheDefinition(definition) {
    if (!this.definitionCache || !definition?.contentAddress) return;
    await verifyDefinitionContentAddress(definition);
    await this.definitionCache.put({
      siteId: this.siteId,
      profileId: definition.profileId === '*' ? this.profileId : (definition.profileId ?? this.profileId),
      contentAddress: definition.contentAddress
    }, definition);
  }
}
