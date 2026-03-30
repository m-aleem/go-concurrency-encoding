package goencoding;

public final class Panic {
    private Panic() {
    }

    public static void panic(String message) {
        throw new RuntimeException("panic: " + message);
    }
}
