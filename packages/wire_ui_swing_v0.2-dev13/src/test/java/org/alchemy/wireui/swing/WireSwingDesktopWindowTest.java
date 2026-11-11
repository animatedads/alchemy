package org.alchemy.wireui.swing;

import javax.swing.JButton;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import java.awt.Component;
import java.awt.Container;
import java.awt.GraphicsEnvironment;
import java.awt.KeyboardFocusManager;
import java.awt.image.BufferedImage;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

public final class WireSwingDesktopWindowTest {
    public static void main(String[] args) {
        if (GraphicsEnvironment.isHeadless()) throw new AssertionError("desktop test requires a display");
        WireSwingRuntime runtime = new WireSwingRuntime();
        runtime.hello("desktop-test", "session", "swing");
        runtime.accept(message("UI_DEFINITION", Map.of(
                "definitionId", "ROOT", "definitionVersion", 1, "definitionKey", "ROOT@1", "primitive", "PANEL", "contentAddress", "root")));
        runtime.accept(message("UI_DEFINITION", Map.of(
                "definitionId", "INPUT", "definitionVersion", 1, "definitionKey", "INPUT@1", "primitive", "INPUT", "contentAddress", "input")));
        runtime.accept(message("UI_DEFINITION", Map.of(
                "definitionId", "EXTRA", "definitionVersion", 1, "definitionKey", "EXTRA@1", "primitive", "BUTTON", "contentAddress", "extra")));
        runtime.accept(message("UI_VIEW_SNAPSHOT", Map.of(
                "viewRef", "desktop-view", "revision", 0, "rootInstanceId", "root",
                "instances", List.of(
                        instance("root", "ROOT@1", "", Map.of()),
                        instance("input", "INPUT@1", "root", Map.of("value", "server-value"))))));

        AtomicInteger closed = new AtomicInteger();
        WireSwingDesktopWindow window = WireSwingDesktopWindow.create(runtime, "Wire UI Desktop Test", 800, 520);
        window.onClosed(closed::incrementAndGet);
        try {
            window.showWindow();
            if (!window.isDisplayable() || !window.isVisible()) throw new AssertionError("desktop window did not become visible");
            BufferedImage image = window.captureContent();
            if (image.getWidth() < 700 || image.getHeight() < 400) throw new AssertionError("unexpected capture size " + image.getWidth() + "x" + image.getHeight());
            int[][] sizes = { {360, 260}, {1280, 760}, {640, 420}, {900, 560} };
            for (int[] size : sizes) {
                window.resizeWindow(size[0], size[1]);
                BufferedImage resized = window.captureContent();
                if (resized.getWidth() < 300 || resized.getHeight() < 200) {
                    throw new AssertionError("resize capture collapsed at " + size[0] + "x" + size[1]);
                }
            }

            JTextField field = find(runtime.hostComponent(), JTextField.class);
            if (field == null) throw new AssertionError("input field not rendered");
            onEdt(() -> {
                field.setText("unsent-local-edit");
                field.requestFocus();
            });
            drainEdt();
            if (focusOwner() != field) throw new AssertionError("input did not own focus before structural patch");

            runtime.accept(message("UI_VIEW_PATCH", Map.of(
                    "viewRef", "desktop-view", "previousRevision", 0, "newRevision", 1,
                    "operations", List.of(Map.of(
                            "op", "CREATE_INSTANCE",
                            "instance", instance("extra", "EXTRA@1", "root", Map.of("text", "Extra")))))));
            JTextField after = find(runtime.hostComponent(), JTextField.class);
            if (after != field) throw new AssertionError("structural relayout replaced surviving editor component");
            if (!"unsent-local-edit".equals(after.getText())) throw new AssertionError("structural relayout lost unsent local editor value");
            if (focusOwner() != field) throw new AssertionError("structural relayout lost surviving editor focus");
            if (find(runtime.hostComponent(), JButton.class) == null) throw new AssertionError("structural patch did not render new child");
        } finally {
            window.close();
        }
        if (closed.get() != 1) throw new AssertionError("onClosed callback count=" + closed.get());
        System.out.println("PASS WireSwingDesktopWindow visible/capture/resize + focus/editor preservation + onClosed lifecycle");
    }

    private static Component focusOwner() {
        final Component[] value = new Component[1];
        onEdt(() -> value[0] = KeyboardFocusManager.getCurrentKeyboardFocusManager().getFocusOwner());
        return value[0];
    }

    private static void drainEdt() { onEdt(() -> { }); }

    private static void onEdt(Runnable action) {
        try {
            if (SwingUtilities.isEventDispatchThread()) action.run();
            else SwingUtilities.invokeAndWait(action);
        } catch (Exception e) {
            throw new AssertionError("EDT operation failed", e);
        }
    }

    private static <T extends Component> T find(Container root, Class<T> type) {
        if (type.isInstance(root)) return type.cast(root);
        for (Component child : root.getComponents()) {
            if (type.isInstance(child)) return type.cast(child);
            if (child instanceof Container container) {
                T found = find(container, type);
                if (found != null) return found;
            }
        }
        return null;
    }

    private static Map<String, Object> instance(String id, String key, String parent, Map<String, Object> slots) {
        return Map.of("instanceId", id, "definitionKey", key, "parentId", parent, "slots", slots);
    }

    private static Map<String, Object> message(String type, Map<String, Object> fields) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("protocolVersion", "WIRE-UI/0.1");
        result.putAll(fields);
        return result;
    }
}
