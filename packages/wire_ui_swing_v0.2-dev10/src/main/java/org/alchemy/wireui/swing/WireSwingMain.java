package org.alchemy.wireui.swing;

import javax.swing.Timer;
import javax.swing.UIManager;
import java.awt.GraphicsEnvironment;

/** Executable entry point for the standalone Wire UI Swing renderer JAR. */
public final class WireSwingMain {
    private static final String VERSION = "0.2-dev10";

    private WireSwingMain() {}

    public static void main(String[] args) throws Exception {
        if (args.length > 1) {
            usage();
            System.exit(2);
            return;
        }
        if (args.length == 1) {
            switch (args[0]) {
                case "--version" -> {
                    System.out.println("wire-ui-swing " + VERSION);
                    return;
                }
                case "--help", "-h" -> {
                    usage();
                    return;
                }
                case "--smoke-window" -> { launchDemo(true, false); return; }
                case "--notnotes-demo" -> { launchDemo(false, false); return; }
                case "--notnotes-smoke" -> { launchDemo(true, true); return; }
                default -> {
                    System.err.println("Unknown option: " + args[0]);
                    usage();
                    System.exit(2);
                    return;
                }
            }
        }
        launchDemo(false, true);
    }

    private static void launchDemo(boolean autoClose, boolean notNotes) throws Exception {
        if (GraphicsEnvironment.isHeadless()) {
            throw new WireSwingException(
                    "HEADLESS_ENVIRONMENT",
                    "Standalone launch requires a graphics environment; use --version for a non-GUI check");
        }

        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        UIManager.put("defaultFont", new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 14));
        UIManager.put("Label.font", new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 14));
        UIManager.put("Button.font", new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 14));
        UIManager.put("TextField.font", new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 14));
        UIManager.put("List.font", new java.awt.Font("SansSerif", java.awt.Font.PLAIN, 14));
        WireSwingRuntime runtime = notNotes ? NotNotesSwingDemo.createRuntime() : WireSwingStandaloneDemo.createRuntime();
        WireSwingDesktopWindow window = WireSwingDesktopWindow.create(
                runtime, notNotes ? "notNotes — Java" : "Wire UI — Swing Desktop Renderer", notNotes ? 1180 : 900, notNotes ? 760 : 560);
        Timer authorityLoop = notNotes ? NotNotesSwingDemo.startAuthorityLoop(runtime) : WireSwingStandaloneDemo.startAuthorityLoop(runtime);
        window.showWindow();
        System.out.println("wire-ui-swing " + VERSION + " READY view=" + runtime.viewRef()
                + " revision=" + runtime.revision());

        if (autoClose) {
            Timer timer = new Timer(350, event -> {
                authorityLoop.stop();
                window.close();
            });
            timer.setRepeats(false);
            timer.start();
        }
    }

    private static void usage() {
        System.out.println("Usage: java -jar wire-ui-swing-v0.2-dev10.jar [--version|--help|--smoke-window|--notnotes-demo|--notnotes-smoke]");
        System.out.println("With no arguments, opens the standalone Swing renderer demonstration.");
    }
}
