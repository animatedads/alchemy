package org.alchemy.wireui.swing;

import javax.swing.Timer;
import javax.swing.UIManager;
import java.awt.GraphicsEnvironment;

/** Executable entry point for the standalone Wire UI Swing renderer JAR. */
public final class WireSwingMain {
    private static final String VERSION = "0.2-dev3";

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
                case "--smoke-window" -> {
                    launchDemo(true);
                    return;
                }
                default -> {
                    System.err.println("Unknown option: " + args[0]);
                    usage();
                    System.exit(2);
                    return;
                }
            }
        }
        launchDemo(false);
    }

    private static void launchDemo(boolean autoClose) throws Exception {
        if (GraphicsEnvironment.isHeadless()) {
            throw new WireSwingException(
                    "HEADLESS_ENVIRONMENT",
                    "Standalone launch requires a graphics environment; use --version for a non-GUI check");
        }

        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        WireSwingRuntime runtime = WireSwingStandaloneDemo.createRuntime();
        WireSwingDesktopWindow window = WireSwingDesktopWindow.create(
                runtime, "Wire UI — Swing Desktop Renderer", 900, 560);
        Timer authorityLoop = WireSwingStandaloneDemo.startAuthorityLoop(runtime);
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
        System.out.println("Usage: java -jar wire-ui-swing-v0.2-dev3.jar [--version|--help|--smoke-window]");
        System.out.println("With no arguments, opens the standalone Swing renderer demonstration.");
    }
}
