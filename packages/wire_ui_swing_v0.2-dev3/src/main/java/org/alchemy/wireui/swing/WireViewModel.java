package org.alchemy.wireui.swing;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

record WireViewModel(String viewRef, long revision, String rootInstanceId, Map<String, WireInstance> instances) {
    WireViewModel {
        viewRef = viewRef == null ? "" : viewRef;
        rootInstanceId = rootInstanceId == null ? "" : rootInstanceId;
        instances = Collections.unmodifiableMap(new LinkedHashMap<>(instances));
    }

    static WireViewModel empty() { return new WireViewModel("", -1, "", Map.of()); }
}
