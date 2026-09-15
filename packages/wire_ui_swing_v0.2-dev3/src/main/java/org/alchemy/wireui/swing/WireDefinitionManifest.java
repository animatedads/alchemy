package org.alchemy.wireui.swing;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

record WireDefinitionManifest(String manifestId, String profileId, Map<String, String> contentAddresses) {
    WireDefinitionManifest {
        manifestId = manifestId == null ? "" : manifestId;
        profileId = profileId == null ? "" : profileId;
        contentAddresses = Collections.unmodifiableMap(new LinkedHashMap<>(contentAddresses));
    }
    boolean allows(WireDefinition d) {
        if (!profileId.isBlank() && !d.profileId().isBlank() && !profileId.equals(d.profileId())) return false;
        if (!contentAddresses.containsKey(d.definitionKey())) return false;
        String expected = contentAddresses.get(d.definitionKey());
        return expected == null || expected.isBlank() || expected.equals(d.contentAddress());
    }
    boolean allowsKey(String key) { return contentAddresses.containsKey(key); }
    String address(String key) { return contentAddresses.getOrDefault(key, ""); }
    static WireDefinitionManifest empty() { return new WireDefinitionManifest("", "", Map.of()); }
}
