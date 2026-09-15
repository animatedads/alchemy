package com.federationbank.atm.ui;

import java.io.BufferedReader;
import java.io.Console;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

public final class ConsoleIo {
    private final BufferedReader in;
    private final PrintStream out;
    private final Console console;
    private final boolean allowVisibleSecretFallback;

    public ConsoleIo(InputStream input, PrintStream out, boolean allowVisibleSecretFallback) {
        this.in = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
        this.out = out;
        this.console = (input == System.in && out == System.out) ? System.console() : null;
        this.allowVisibleSecretFallback = allowVisibleSecretFallback;
    }

    public String line(String prompt) throws IOException {
        out.print(prompt); out.flush();
        return in.readLine();
    }

    public char[] secret(String prompt) throws IOException {
        if (console != null) {
            char[] value = console.readPassword("%s", prompt);
            return value == null ? null : value;
        }
        if (!allowVisibleSecretFallback) throw new IOException(
                "secure console input is unavailable; use a real terminal or --allow-visible-demo-pin for the dummy demo only");
        String value = line(prompt);
        return value == null ? null : value.toCharArray();
    }

    public void println(String text) { out.println(text); }
    public void printf(String format, Object... args) { out.printf(format, args); }
}
