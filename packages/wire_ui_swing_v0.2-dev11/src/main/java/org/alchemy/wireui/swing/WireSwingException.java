package org.alchemy.wireui.swing;

public final class WireSwingException extends RuntimeException {
    private static final long serialVersionUID = 1L;
    private final String code;
    public WireSwingException(String code, String message) { super(message); this.code = code; }
    public WireSwingException(String code, String message, Throwable cause) { super(message, cause); this.code = code; }
    public String code() { return code; }
}
