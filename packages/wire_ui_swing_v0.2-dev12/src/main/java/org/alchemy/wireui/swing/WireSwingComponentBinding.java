package org.alchemy.wireui.swing;

import javax.swing.*;
import java.awt.Container;
import java.util.Map;

interface WireSwingComponentBinding {
    JComponent component();
    default Container mount() { return component(); }
    void applySlot(String slot, Object value);
    default Map<String, Object> actionDetail() { return Map.of(); }
}
