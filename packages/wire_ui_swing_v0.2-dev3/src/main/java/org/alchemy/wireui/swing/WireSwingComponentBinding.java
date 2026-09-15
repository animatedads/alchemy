package org.alchemy.wireui.swing;

import javax.swing.*;
import java.util.Map;

interface WireSwingComponentBinding {
    JComponent component();
    void applySlot(String slot, Object value);
    default Map<String, Object> actionDetail() { return Map.of(); }
}
