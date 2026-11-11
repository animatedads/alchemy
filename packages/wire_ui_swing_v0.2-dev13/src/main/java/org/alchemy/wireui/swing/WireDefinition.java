package org.alchemy.wireui.swing;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

public record WireDefinition(
        String definitionId,
        long version,
        String definitionKey,
        String primitive,
        String action,
        String label,
        String styleRole,
        String contentAddress,
        String profileId,
        Map<String, Object> metadata) {

    public WireDefinition {
        definitionId = requireText(definitionId, "definitionId");
        if (version < 1) throw new IllegalArgumentException("definition version must be >= 1");
        definitionKey = requireText(definitionKey, "definitionKey");
        String exact = definitionId + "@" + version;
        if (!definitionKey.equals(exact)) throw new IllegalArgumentException("definitionKey must be exact: " + exact);
        primitive = requireText(primitive, "primitive").toUpperCase();
        action = action == null ? "" : action;
        label = label == null ? "" : label;
        styleRole = styleRole == null ? "" : styleRole;
        contentAddress = contentAddress == null ? "" : contentAddress;
        profileId = profileId == null ? "" : profileId;
        metadata = Collections.unmodifiableMap(new LinkedHashMap<>(metadata == null ? Map.of() : metadata));
    }

    public static WireDefinition fromWire(Map<String, Object> wire) {
        Objects.requireNonNull(wire, "wire");
        String id = WireValues.text(wire, "definitionId", "");
        long version = WireValues.longValue(wire, "definitionVersion", WireValues.longValue(wire, "version", -1));
        String key = WireValues.text(wire, "definitionKey", id + "@" + version);
        Map<String, Object> metadata = normalisedMetadata(wire);
        return new WireDefinition(id, version, key,
                WireValues.text(wire, "primitive", ""),
                WireValues.text(wire, "action", WireValues.text(wire, "semanticAction", "")),
                WireValues.text(wire, "label", ""),
                WireValues.text(wire, "styleRole", WireValues.text(metadata, "styleRole", "")),
                WireValues.text(wire, "contentAddress", ""),
                WireValues.text(wire, "profileId", ""),
                metadata);
    }

    private static Map<String, Object> normalisedMetadata(Map<String, Object> wire) {
        Map<String, Object> source = WireValues.map(wire.get("metadata"));
        Map<String, Object> result = new LinkedHashMap<>(source);
        for (String key : new String[] { "bindings", "profile", "materialRole", "semanticElementRef", "projectionRef", "componentRef", "releaseRef" }) {
            if (wire.containsKey(key)) result.put(key, WireValues.freezeValue(wire.get(key)));
        }
        return result;
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " is required");
        return value.trim();
    }
}
