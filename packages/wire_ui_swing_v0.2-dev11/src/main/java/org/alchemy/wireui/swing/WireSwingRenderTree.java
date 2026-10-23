package org.alchemy.wireui.swing;

import javax.swing.JComponent;
import javax.swing.JPanel;
import java.awt.BorderLayout;
import java.util.LinkedHashMap;
import java.util.Map;

final class WireSwingRenderTree {
    final JPanel host;
    final Map<String, WireSwingComponentBinding> bindings = new LinkedHashMap<>();
    JComponent root;

    WireSwingRenderTree() { this(new JPanel(new BorderLayout())); }
    WireSwingRenderTree(JPanel host) { this.host = host; }
}
