package org.alchemy.wireui.swing;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

record WireViewModel(
        String viewRef,
        long revision,
        String rootInstanceId,
        Map<String, WireInstance> instances,
        Map<String, List<String>> childOrder) {
    WireViewModel {
        viewRef = viewRef == null ? "" : viewRef;
        rootInstanceId = rootInstanceId == null ? "" : rootInstanceId;
        instances = Collections.unmodifiableMap(new LinkedHashMap<>(instances));
        Map<String, List<String>> frozen = new LinkedHashMap<>();
        for (Map.Entry<String, List<String>> entry : childOrder.entrySet()) {
            frozen.put(entry.getKey(), List.copyOf(entry.getValue()));
        }
        childOrder = Collections.unmodifiableMap(frozen);
    }

    static WireViewModel empty() { return new WireViewModel("", -1, "", Map.of(), Map.of()); }

    static WireViewModel fromOrderedInstances(String viewRef, long revision, String rootInstanceId, Map<String, WireInstance> instances) {
        Map<String, List<String>> order = new LinkedHashMap<>();
        for (WireInstance instance : instances.values()) {
            order.computeIfAbsent(instance.parentInstanceId(), ignored -> new ArrayList<>()).add(instance.instanceId());
        }
        return new WireViewModel(viewRef, revision, rootInstanceId, instances, order);
    }

    List<String> children(String parentId) {
        return childOrder.getOrDefault(parentId == null ? "" : parentId, List.of());
    }
}
