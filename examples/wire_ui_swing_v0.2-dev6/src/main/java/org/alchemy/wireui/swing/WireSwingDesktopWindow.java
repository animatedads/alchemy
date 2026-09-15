package org.alchemy.wireui.swing;

import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.WindowConstants;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.Graphics2D;
import java.awt.GraphicsEnvironment;
import java.awt.image.BufferedImage;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Thin desktop shell for a {@link WireSwingRuntime}.
 *
 * <p>The window owns only desktop lifecycle/presentation. It never interprets
 * journey transitions, business state or semantic action authority. The
 * runtime's stable host component is attached once and authoritative snapshots
 * continue to replace content inside that host.</p>
 */
public final class WireSwingDesktopWindow implements AutoCloseable {
    private final WireSwingRuntime runtime;
    private final WireSwingEdt edt = new WireSwingEdt();
    private final JFrame frame;
    private volatile Runnable onClosed = () -> {};
    private final AtomicBoolean closedNotified = new AtomicBoolean();

    private WireSwingDesktopWindow(WireSwingRuntime runtime, String title, int width, int height) {
        this.runtime = runtime;
        this.frame = edt.call(() -> createFrame(title, width, height));
    }

    public static WireSwingDesktopWindow create(WireSwingRuntime runtime, String title, int width, int height) {
        Objects.requireNonNull(runtime, "runtime");
        if (GraphicsEnvironment.isHeadless()) {
            throw new WireSwingException("HEADLESS_ENVIRONMENT", "A desktop Swing window requires a graphics environment");
        }
        if (width < 320 || height < 240) {
            throw new IllegalArgumentException("desktop window must be at least 320x240");
        }
        return new WireSwingDesktopWindow(runtime, title == null ? "Wire UI" : title, width, height);
    }

    public void showWindow() {
        edt.run(() -> {
            frame.validate();
            frame.setVisible(true);
            frame.toFront();
        });
    }

    public void hideWindow() { edt.run(() -> frame.setVisible(false)); }

    public void setTitle(String title) { edt.run(() -> frame.setTitle(title == null ? "" : title)); }
    public void onClosed(Runnable callback) { onClosed = callback == null ? () -> {} : callback; }

    public boolean isDisplayable() { return edt.call(frame::isDisplayable); }
    public boolean isVisible() { return edt.call(frame::isVisible); }
    public Dimension size() { return edt.call(frame::getSize); }

    public void resizeWindow(int width, int height) {
        if (width < 320 || height < 240) throw new IllegalArgumentException("desktop window must be at least 320x240");
        edt.run(() -> {
            frame.setSize(width, height);
            frame.validate();
        });
    }

    /**
     * Paint the current window content to an image on the EDT. This is useful
     * for deterministic renderer tests and diagnostics without exposing the
     * JFrame itself across the ooRexx boundary.
     */
    public BufferedImage captureContent() {
        return edt.call(() -> {
            JPanel content = (JPanel) frame.getContentPane();
            Dimension size = content.getSize();
            if (size.width <= 0 || size.height <= 0) throw new WireSwingException("WINDOW_NOT_LAID_OUT", "desktop content has no drawable size");
            BufferedImage image = new BufferedImage(size.width, size.height, BufferedImage.TYPE_INT_ARGB);
            Graphics2D graphics = image.createGraphics();
            try { content.printAll(graphics); }
            finally { graphics.dispose(); }
            return image;
        });
    }

    @Override public void close() {
        edt.run(() -> {
            frame.dispose();
            notifyClosed();
        });
    }

    private void notifyClosed() {
        if (closedNotified.compareAndSet(false, true)) onClosed.run();
    }

    private JFrame createFrame(String title, int width, int height) {
        WireSwingEdt.requireEdt();
        JFrame result = new JFrame(title);
        result.setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
        result.addWindowListener(new WindowAdapter() { @Override public void windowClosed(WindowEvent e) { notifyClosed(); } });
        result.setMinimumSize(new Dimension(320, 240));

        JPanel content = new JPanel(new BorderLayout());
        content.setBorder(BorderFactory.createEmptyBorder(8, 8, 8, 8));
        JScrollPane viewport = new JScrollPane(runtime.hostComponent(), JScrollPane.VERTICAL_SCROLLBAR_AS_NEEDED, JScrollPane.HORIZONTAL_SCROLLBAR_AS_NEEDED);
        viewport.setBorder(BorderFactory.createEmptyBorder());
        viewport.getVerticalScrollBar().setUnitIncrement(16);
        content.add(viewport, BorderLayout.CENTER);
        result.setContentPane(content);
        result.setSize(width, height);
        result.setLocationByPlatform(true);
        return result;
    }
}
