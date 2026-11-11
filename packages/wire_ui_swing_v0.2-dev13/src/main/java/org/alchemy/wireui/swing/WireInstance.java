package org.alchemy.wireui.swing;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public record WireInstance(String instanceId, String definitionKey, String parentInstanceId, Map<String, Object> slots) {
    public WireInstance {
        if (instanceId == null || instanceId.isBlank()) throw new IllegalArgumentException("instanceId is required");
        if (definitionKey == null || definitionKey.isBlank()) throw new IllegalArgumentException("definitionKey is required");
        parentInstanceId = parentInstanceId == null ? "" : parentInstanceId;
        slots = Collections.unmodifiableMap(new LinkedHashMap<>(slots == null ? Map.of() : slots));
    }

    public WireInstance withParent(String parentId) {
        return new WireInstance(instanceId, definitionKey, parentId, slots);
    }

    public WireInstance withSlot(String name, Object value) {
        Map<String, Object> next = new LinkedHashMap<>(slots);
        next.put(name, value);
        return new WireInstance(instanceId, definitionKey, parentInstanceId, next);
    }

    public static WireInstance fromWire(Map<String, Object> wire) {
        String key = WireValues.text(wire, "definitionKey", "");
        if (key.isBlank()) {
            String id = WireValues.text(wire, "definitionId", "");
            long version = WireValues.longValue(wire, "definitionVersion", WireValues.longValue(wire, "version", -1));
            key = id + "@" + version;
        }
        return new WireInstance(
                WireValues.text(wire, "instanceId", ""),
                key,
                WireValues.text(wire, "parentInstanceId", WireValues.text(wire, "parentId", "")),
                WireValues.map(wire.get("slots")));
    }
}
