package org.alchemy.wireui.swing;

import javax.swing.SwingUtilities;
import java.lang.reflect.InvocationTargetException;
import java.util.concurrent.Callable;

final class WireSwingEdt {
    public <T> T call(Callable<T> work) {
        if (SwingUtilities.isEventDispatchThread()) return callDirect(work);
        final Object[] box = new Object[2];
        try {
            SwingUtilities.invokeAndWait(() -> {
                try { box[0] = work.call(); }
                catch (Throwable t) { box[1] = t; }
            });
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new WireSwingException("EDT_INTERRUPTED", "Interrupted while marshalling to Swing EDT", e);
        } catch (InvocationTargetException e) {
            throw new WireSwingException("EDT_INVOCATION_FAILED", "Swing EDT invocation failed", e.getCause());
        }
        if (box[1] != null) rethrow((Throwable) box[1]);
        @SuppressWarnings("unchecked") T result = (T) box[0];
        return result;
    }

    public void run(Runnable work) { call(() -> { work.run(); return null; }); }

    public static void requireEdt() {
        if (!SwingUtilities.isEventDispatchThread()) throw new IllegalStateException("Swing access outside EDT");
    }

    private static <T> T callDirect(Callable<T> work) {
        try { return work.call(); }
        catch (RuntimeException | Error e) { throw e; }
        catch (Exception e) { throw new WireSwingException("EDT_WORK_FAILED", e.getMessage(), e); }
    }

    private static void rethrow(Throwable t) {
        if (t instanceof RuntimeException r) throw r;
        if (t instanceof Error e) throw e;
        throw new WireSwingException("EDT_WORK_FAILED", t.getMessage(), t);
    }
}
